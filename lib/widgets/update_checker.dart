import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/apk_download_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class UpdateCheckerWidget extends StatefulWidget {
  final Widget? child;
  final bool showSnackbarOnNoUpdate;

  const UpdateCheckerWidget({
    super.key,
    this.child,
    this.showSnackbarOnNoUpdate = false,
  });

  @override
  State<UpdateCheckerWidget> createState() => _UpdateCheckerWidgetState();

  static Widget _buildUpdateDialogContent(
    BuildContext context,
    UpdateInfo updateInfo,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发现新版本',
                    style: TextStyle(
                      fontSize: AppTheme.textTitleLarge,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'v${updateInfo.version}',
                      style: const TextStyle(
                        fontSize: AppTheme.textLabelMedium,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceLarge),
        const Text(
          '更新内容',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppTheme.textBodyLarge,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        if (updateInfo.releaseNotes.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: AppTheme.getSecondaryBackground(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.getDividerColor(context),
                width: 0.5,
              ),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                updateInfo.releaseNotes,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppTheme.textBodySmall,
                  height: 1.6,
                ),
              ),
            ),
          )
        else
          Text(
            '暂无更新说明',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppTheme.textBodySmall,
            ),
          ),
        const SizedBox(height: AppTheme.spaceSmall),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppTheme.spaceXSmall),
            Text(
              '发布时间: ${_formatDateStatic(updateInfo.releaseDate)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppTheme.textLabelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        // WHY: 更新方式按平台区分——Web 端刷新即可；Android 端应用内下载 APK 覆盖安装
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: (kIsWeb ? AppTheme.successColor : AppTheme.primaryColor)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Row(
            children: [
              Icon(
                kIsWeb ? Icons.check_circle_rounded : Icons.download_rounded,
                color: kIsWeb ? AppTheme.successColor : AppTheme.primaryColor,
                size: 16,
              ),
              SizedBox(width: AppTheme.spaceXSmall),
              Expanded(
                child: Text(
                  kIsWeb
                      ? 'Web 应用自动更新，无需重装，数据安全保留'
                      : '点击“立即更新”将在应用内下载并调起安装，记账数据自动保留',
                  style: TextStyle(
                    color:
                        kIsWeb ? AppTheme.successColor : AppTheme.primaryColor,
                    fontSize: AppTheme.textLabelMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 通过系统浏览器下载新版本（应用内下载失败时的降级路径，兼作 Web 端入口）。
  ///
  /// WHY: Web 端为免安装应用，刷新页面即可加载新版本；
  /// Android 端优先走 [_UpdateActionDialog] 应用内下载，仅当用户主动选择
  /// "浏览器下载"或应用内下载失败时才走该路径，由系统浏览器/安装器接力完成
  ///
  /// @param context 用于获取 ScaffoldMessenger 的上下文（需为页面级持久 context）
  /// @param updateInfo 包含下载地址的版本信息
  /// @return 无返回值；失败时通过 SnackBar 提示
  static Future<void> performUpdateAction(
      BuildContext context, UpdateInfo updateInfo) async {
    // WHY: 在 await 之前捕获 ScaffoldMessenger，避免对话框关闭后 context 失活
    final messenger = ScaffoldMessenger.of(context);

    if (kIsWeb) {
      _showWebRefreshHint(context);
      return;
    }

    final uri = Uri.tryParse(updateInfo.downloadUrl);
    bool launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        launched = false;
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              launched
                  ? Icons.download_done_rounded
                  : Icons.error_outline_rounded,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                launched
                    ? '已打开浏览器下载新版本，下载完成后点击安装包覆盖安装，数据不会丢失'
                    : '无法打开下载链接，请前往 GitHub Releases 页面手动下载安装',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// 手动触发一次检查更新（供"关于"对话框等入口调用）。
  ///
  /// WHY: 手动检查需绕过 1 小时更新缓存并忽略"跳过此版本"标记，
  /// 确保能看到 GitHub 上的真实最新版本；与启动时静默检查（读缓存）区分开。
  ///
  /// @param context 用于展示 SnackBar 与更新对话框的上下文，
  ///                调用方需保证检查期间该 context 所属页面仍挂载（如页面级 context）
  /// @return 无返回值；有新版时弹出更新对话框，无新版时提示"当前已是最新版本"
  static Future<void> manualCheck(BuildContext context) async {
    // WHY: 在 await 之前捕获 ScaffoldMessenger，避免检查期间页面切换后提示失败
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在检查更新…'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );

    final updateInfo = await UpdateService.checkForUpdate(
      ignoreSkip: true,
      forceRefresh: true,
    );

    if (!context.mounted) return;

    // WHY: 先清除"正在检查更新"提示，避免与结果提示堆叠
    messenger.clearSnackBars();
    if (updateInfo != null) {
      showUpdateDialog(context, updateInfo);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('当前已是最新版本'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// WHY: Web 端刷新提示抽为独立方法，供静态对话框与实例对话框复用
  static void _showWebRefreshHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '请刷新浏览器页面即可完成更新，数据将自动保留',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '刷新',
          onPressed: () {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
      ),
    );
  }

  /// 弹出更新对话框（带应用内下载进度）。
  ///
  /// WHY: barrierDismissible 设为 false——下载过程中点击外部关闭会导致
  /// 下载中断且无法调起安装器，用户必须通过对话框内按钮显式操作
  ///
  /// @param context 页面级上下文，同时作为下载完成后 SnackBar 的持久 context
  /// @param updateInfo 新版本信息
  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _UpdateActionDialog(
        updateInfo: updateInfo,
        parentContext: context,
      ),
    );
  }

  static String _formatDateStatic(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// 更新对话框的下载阶段状态机
enum _DownloadPhase { ready, downloading, done, failed }

/// 带应用内下载进度的更新对话框
///
/// 状态流转：ready（更新内容）→ downloading（进度条，可取消）→ done（调起安装器）；
/// 下载异常进入 failed，可重试或降级为浏览器下载
class _UpdateActionDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  /// 页面级持久 context：对话框 pop 后其自身 context 失活，
  /// SnackBar 与浏览器降级下载必须挂在页面级 context 上
  final BuildContext parentContext;

  const _UpdateActionDialog({
    required this.updateInfo,
    required this.parentContext,
  });

  @override
  State<_UpdateActionDialog> createState() => _UpdateActionDialogState();
}

class _UpdateActionDialogState extends State<_UpdateActionDialog>
    with WidgetsBindingObserver {
  // WHY: downloadId 持久化键——进程被杀后重开应用时据此恢复下载进度/安装提示
  static const String _kDownloadIdKey = 'update_download_id';
  static const String _kDownloadVersionKey = 'update_download_version';

  _DownloadPhase _phase = _DownloadPhase.ready;
  int _received = 0;
  int _total = 0;
  String? _apkFilePath;
  bool _installLaunchFailed = false;

  // WHY: Android 系统下载的进度轮询定时器；对话框关闭（dispose）时取消轮询，
  // 下载本身在系统层继续，下次打开对话框通过 initState 恢复现场
  Timer? _pollTimer;
  int? _downloadId;

  bool get _isSystemDownload => ApkDownloadService.supportsSystemDownload;

  @override
  void initState() {
    super.initState();
    if (_isSystemDownload) {
      WidgetsBinding.instance.addObserver(this);
      _restorePersistedDownload();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_isSystemDownload) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WHY: 用户从后台回到前台时立即刷新一次进度，缩短轮询延迟感知
    if (state == AppLifecycleState.resumed &&
        _phase == _DownloadPhase.downloading &&
        _downloadId != null) {
      _pollOnce(_downloadId!);
    }
  }

  /// 恢复上次未完成的系统下载任务（进程被杀/对话框关闭后重进）
  ///
  /// WHY: downloadId 与目标版本号持久化到 SharedPreferences，对话框打开时
  /// 检测进行中/已完成的下载并恢复到对应阶段，避免重复下载
  Future<void> _restorePersistedDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kDownloadIdKey);
    final savedVersion = prefs.getString(_kDownloadVersionKey);
    if (savedId == null || savedVersion == null) return;
    if (savedVersion != widget.updateInfo.version) {
      // WHY: 目标版本已变化，旧任务与持久化记录一并清理
      await ApkDownloadService.cancelSystemDownload(savedId);
      await _clearPersistedDownload();
      return;
    }
    final Map<String, dynamic>? status;
    try {
      status = await ApkDownloadService.querySystemDownload(savedId);
    } catch (e) {
      debugPrint('[Update] 恢复下载任务查询失败: $e');
      return;
    }
    if (!mounted) return;
    if (status == null) {
      // WHY: 任务已被系统/用户清除，持久化记录失去意义
      await _clearPersistedDownload();
      return;
    }
    // WHY: try 块内赋值的可空变量提升在闭包内失效，改用非空别名供闭包安全访问
    final Map<String, dynamic> data = status;
    switch (data['status'] as String?) {
      case 'successful':
        final path = data['filePath'] as String?;
        if (path == null) {
          await _clearPersistedDownload();
          return;
        }
        _downloadId = savedId;
        _apkFilePath = path;
        setState(() => _phase = _DownloadPhase.done);
        await _launchInstaller();
      case 'failed':
        await _clearPersistedDownload();
      default:
        // WHY: running/paused/pending 均视为下载中，恢复进度显示并继续轮询
        _downloadId = savedId;
        setState(() {
          _phase = _DownloadPhase.downloading;
          _received = (data['bytesSoFar'] as num?)?.toInt() ?? 0;
          _total = (data['totalBytes'] as num?)?.toInt() ?? 0;
        });
        _startPolling(savedId);
    }
  }

  /// Android 端：创建系统下载任务并持久化任务 ID
  Future<void> _startSystemDownload() async {
    try {
      final id = await ApkDownloadService.startSystemDownload(
          widget.updateInfo.downloadUrl);
      if (!mounted) return;
      _downloadId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDownloadIdKey, id);
      await prefs.setString(_kDownloadVersionKey, widget.updateInfo.version);
      if (!mounted) return;
      _startPolling(id);
    } catch (e) {
      debugPrint('[Update] 创建系统下载任务失败: $e');
      if (!mounted) return;
      setState(() => _phase = _DownloadPhase.failed);
    }
  }

  /// 启动进度轮询（1 秒间隔），状态迁移：downloading → done/failed
  void _startPolling(int id) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollOnce(id),
    );
  }

  /// 执行一次进度查询（轮询周期体与回前台刷新共用）
  Future<void> _pollOnce(int id) async {
    final Map<String, dynamic>? status;
    try {
      status = await ApkDownloadService.querySystemDownload(id);
    } catch (e) {
      // WHY: 单次查询失败不打断轮询，下个周期自动重试
      debugPrint('[Update] 查询下载进度失败: $e');
      return;
    }
    if (!mounted) {
      _pollTimer?.cancel();
      return;
    }
    if (status == null) {
      // WHY: 任务被系统/用户清除，转为失败态并清理持久化
      _pollTimer?.cancel();
      await _clearPersistedDownload();
      if (!mounted) return;
      setState(() => _phase = _DownloadPhase.failed);
      return;
    }
    // WHY: try 块内赋值的可空变量提升在闭包内失效，改用非空别名供闭包安全访问
    final Map<String, dynamic> data = status;
    switch (data['status'] as String?) {
      case 'successful':
        _pollTimer?.cancel();
        _apkFilePath = data['filePath'] as String?;
        setState(() => _phase = _DownloadPhase.done);
        await _launchInstaller();
      case 'failed':
        _pollTimer?.cancel();
        await _clearPersistedDownload();
        if (!mounted) return;
        setState(() => _phase = _DownloadPhase.failed);
      default:
        setState(() {
          _received = (data['bytesSoFar'] as num?)?.toInt() ?? 0;
          _total = (data['totalBytes'] as num?)?.toInt() ?? 0;
        });
    }
  }

  /// 清除 downloadId 持久化记录
  Future<void> _clearPersistedDownload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDownloadIdKey);
    await prefs.remove(_kDownloadVersionKey);
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _DownloadPhase.downloading;
      _received = 0;
      _total = 0;
    });
    // WHY: Android 优先走系统 DownloadManager 后台下载，离开应用不中断；
    // 桌面平台无系统下载器，保持原有 http 流式前台下载
    if (_isSystemDownload) {
      await _startSystemDownload();
      return;
    }
    try {
      final filePath = await ApkDownloadService.downloadApk(
        widget.updateInfo.downloadUrl,
        (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      _apkFilePath = filePath;
      setState(() => _phase = _DownloadPhase.done);
      await _launchInstaller();
    } catch (e) {
      debugPrint('[Update] 应用内下载失败: $e');
      if (!mounted) return;
      // WHY: 用户主动取消时 _phase 已被 _cancelDownload 重置为 ready，不再覆盖为 failed
      if (_phase != _DownloadPhase.downloading) return;
      setState(() => _phase = _DownloadPhase.failed);
    }
  }

  void _cancelDownload() {
    _pollTimer?.cancel();
    setState(() {
      _phase = _DownloadPhase.ready;
      _received = 0;
      _total = 0;
    });
    if (_isSystemDownload) {
      final id = _downloadId;
      _downloadId = null;
      if (id != null) {
        // WHY: 取消即删除系统任务与持久化记录，避免残留半成品占用空间
        ApkDownloadService.cancelSystemDownload(id)
            .then((_) => _clearPersistedDownload());
      }
    } else {
      ApkDownloadService.cancelDownload();
    }
  }

  Future<void> _launchInstaller() async {
    final path = _apkFilePath;
    if (path == null) return;
    final ok = await ApkDownloadService.installApk(path);
    if (!mounted) return;
    // WHY: 调起失败不弹 SnackBar（会被对话框遮挡），改为在 done 视图中内联警示
    setState(() => _installLaunchFailed = !ok);
    // WHY: 安装器调起成功后清除持久化，防止下次打开重复进入"待安装"状态；
    // 调起失败保留记录便于重试
    if (ok) {
      await _clearPersistedDownload();
    }
  }

  void _downloadViaBrowser() {
    Navigator.of(context).pop();
    UpdateCheckerWidget.performUpdateAction(
        widget.parentContext, widget.updateInfo);
  }

  void _skipVersion() {
    Navigator.of(context).pop();
    UpdateService.skipVersion(widget.updateInfo.version);
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      const SnackBar(
        content: Text('已跳过此版本，下次更新时将重新提醒'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onUpdatePressed() {
    if (kIsWeb) {
      // WHY: Web 端免安装，关闭对话框后提示刷新即可
      Navigator.of(context).pop();
      UpdateCheckerWidget.performUpdateAction(
          widget.parentContext, widget.updateInfo);
      return;
    }
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // WHY: 桌面流式下载中仍拦截返回键（下载绑定在对话框生命周期）；
      // Android 系统下载独立于应用进程，允许关闭对话框退到后台继续下载
      canPop: _phase != _DownloadPhase.downloading || _isSystemDownload,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        contentPadding: const EdgeInsets.all(AppTheme.spaceLarge),
        content: switch (_phase) {
          _DownloadPhase.ready => UpdateCheckerWidget._buildUpdateDialogContent(
              context, widget.updateInfo),
          _DownloadPhase.downloading => _buildDownloading(context),
          _DownloadPhase.done => _buildDone(context),
          _DownloadPhase.failed => _buildFailed(context),
        },
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildDownloading(BuildContext context) {
    final hasTotal = _total > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(
            Icons.download_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        Text(
          '正在下载 v${widget.updateInfo.version}',
          style: TextStyle(
            fontSize: AppTheme.textTitleLarge,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceLarge),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: LinearProgressIndicator(
            value: hasTotal ? _received / _total : null,
            minHeight: 6,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Text(
          hasTotal
              ? '${(_received / _total * 100).toStringAsFixed(0)}% · '
                  '${_formatMb(_received)} / ${_formatMb(_total)} MB'
              : '已下载 ${_formatMb(_received)} MB',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTheme.textLabelMedium,
          ),
        ),
        // WHY: 仅系统后台下载显示该提示——用户可放心离开应用，下载在系统层继续
        if (_isSystemDownload) ...[
          const SizedBox(height: AppTheme.spaceSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_done_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.spaceXSmall),
              Text(
                '离开应用下载不中断，通知栏可查看进度',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppTheme.textLabelSmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.successColor,
            size: 28,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        Text(
          '下载完成',
          style: TextStyle(
            fontSize: AppTheme.textTitleLarge,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Text(
          _installLaunchFailed
              ? '自动调起安装器失败，请点击下方“重新安装”重试'
              : '已调起系统安装器，按提示覆盖安装即可，数据自动保留',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _installLaunchFailed
                ? AppTheme.warningColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTheme.textBodySmall,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorColor,
            size: 28,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        Text(
          '下载失败',
          style: TextStyle(
            fontSize: AppTheme.textTitleLarge,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Text(
          '请检查网络后重试，或改用浏览器下载',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTheme.textBodySmall,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    return switch (_phase) {
      _DownloadPhase.ready => [
          TextButton(
            onPressed: _skipVersion,
            child: const Text('跳过此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后提醒'),
          ),
          ElevatedButton(
            onPressed: _onUpdatePressed,
            child: const Text('立即更新'),
          ),
        ],
      _DownloadPhase.downloading => [
          // WHY: 系统下载支持退到后台继续，提供"后台下载"快速关闭入口；
          // 桌面流式下载关闭即中断，不显示该按钮
          if (_isSystemDownload)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('后台下载'),
            ),
          TextButton(
            onPressed: _cancelDownload,
            child: const Text('取消下载'),
          ),
        ],
      _DownloadPhase.done => [
          TextButton(
            onPressed: _launchInstaller,
            child: const Text('重新安装'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      _DownloadPhase.failed => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: _downloadViaBrowser,
            child: const Text('浏览器下载'),
          ),
          ElevatedButton(
            onPressed: _startDownload,
            child: const Text('重试'),
          ),
        ],
    };
  }

  // 字节数格式化为 MB（保留 1 位小数）
  String _formatMb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
}

class _UpdateCheckerWidgetState extends State<UpdateCheckerWidget> {
  bool _isChecking = false;

  Future<void> checkForUpdate({bool ignoreSkip = false}) async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final updateInfo =
          await UpdateService.checkForUpdate(ignoreSkip: ignoreSkip);

      if (!mounted) return;

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      } else if (widget.showSnackbarOnNoUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前已是最新版本'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    // WHY: 与静态入口逻辑完全一致，直接复用避免重复维护
    UpdateCheckerWidget.showUpdateDialog(context, updateInfo);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return RefreshIndicator(
        onRefresh: () async => checkForUpdate(),
        child: widget.child is ScrollView
            ? widget.child!
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: widget.child!,
              ),
      );
    }

    return UpdateCheckButton(
      onPressed: () => checkForUpdate(ignoreSkip: true),
      isLoading: _isChecking,
    );
  }
}

class UpdateCheckButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const UpdateCheckButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '检查更新',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppTheme.spaceXSmall),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              const Icon(Icons.search_rounded,
                  color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}

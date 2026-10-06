import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
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
    UpdateInfo updateInfo, {
    required VoidCallback onUpdate,
  }) {
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
        // WHY: 更新方式按平台区分——Web 端刷新即可；Android 端需下载 APK 覆盖安装，
        // 旧版本硬编码为 Web 提示导致手机 App 用户无法更新
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: (kIsWeb ? AppTheme.successColor : AppTheme.primaryColor)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                kIsWeb ? Icons.check_circle_rounded : Icons.download_rounded,
                color: kIsWeb ? AppTheme.successColor : AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spaceXSmall),
              Expanded(
                child: Text(
                  kIsWeb
                      ? 'Web 应用自动更新，无需重装，数据安全保留'
                      : '点击“立即更新”将下载 APK 安装包，覆盖安装即可，记账数据自动保留',
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

  /// 执行更新动作。
  ///
  /// WHY: Web 端为免安装应用，刷新页面即可加载新版本；
  /// Android 端通过系统浏览器打开 APK 下载链接，下载完成后由系统安装器覆盖安装，
  /// 避免在应用内自行处理下载与 REQUEST_INSTALL_PACKAGES 权限的复杂逻辑。
  ///
  /// @param context 用于获取 ScaffoldMessenger 的上下文
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

  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        contentPadding: const EdgeInsets.all(AppTheme.spaceLarge),
        content: _buildUpdateDialogContent(
          context,
          updateInfo,
          onUpdate: () {
            Navigator.pop(context);
            UpdateService.skipVersion(updateInfo.version);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已跳过此版本，下次更新时将重新提醒'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              UpdateService.skipVersion(updateInfo.version);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已跳过此版本，下次更新时将重新提醒'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('跳过此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后提醒'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              performUpdateAction(context, updateInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  static String _formatDateStatic(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        contentPadding: const EdgeInsets.all(AppTheme.spaceLarge),
        content: UpdateCheckerWidget._buildUpdateDialogContent(
          dialogContext,
          updateInfo,
          onUpdate: () {},
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              UpdateService.skipVersion(updateInfo.version);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已跳过此版本，下次更新时将重新提醒'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('跳过此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后提醒'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // WHY: 使用 State 的持久 context 而非 dialogContext（pop 后即失活）
              UpdateCheckerWidget.performUpdateAction(context, updateInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
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

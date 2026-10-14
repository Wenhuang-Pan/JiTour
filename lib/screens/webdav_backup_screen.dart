import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/webdav_backup_service.dart';
import '../services/webdav_backup_types.dart';
import '../theme/app_theme.dart';

/// WebDAV 云端备份页面
///
/// 功能：
/// - WebDAV 服务器配置（地址/用户名/密码）与连接测试
/// - 自动备份开关与频率设置（启动时惰性检查执行）
/// - 手动立即备份到云端
/// - 云端备份列表：恢复（覆盖本地，需确认）与删除（需确认）
class WebdavBackupScreen extends StatefulWidget {
  const WebdavBackupScreen({super.key});

  @override
  State<WebdavBackupScreen> createState() => _WebdavBackupScreenState();
}

class _WebdavBackupScreenState extends State<WebdavBackupScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isUploading = false;
  bool _isListLoading = false;

  bool _autoBackupEnabled = false;
  int _frequencyDays = 1;
  DateTime? _lastBackupTime;

  List<WebdavBackupItem> _backups = [];
  String? _listError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final config = await WebdavBackupService.getConfig();
    final enabled = await WebdavBackupService.isAutoBackupEnabled();
    final frequency = await WebdavBackupService.getFrequencyDays();
    final lastTime = await WebdavBackupService.getLastBackupTime();

    if (!mounted) return;
    setState(() {
      _urlController.text = config.url;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _autoBackupEnabled = enabled;
      _frequencyDays = frequency;
      _lastBackupTime = lastTime;
      _isLoading = false;
    });

    if (config.isValid) {
      await _refreshBackups();
    }
  }

  /// 从表单字段构造配置对象
  WebdavConfig _configFromFields() {
    return WebdavConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  /// 校验服务器地址格式
  ///
  /// @return 错误提示文案；合法时返回 null
  String? _validateUrl(String url) {
    if (url.isEmpty) return '请输入服务器地址';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return '服务器地址需以 http:// 或 https:// 开头';
    }
    return null;
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final error = _validateUrl(url);
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    await WebdavBackupService.saveConfig(_configFromFields());
    if (!mounted) return;
    _showSnackBar('服务器配置已保存');
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final error = _validateUrl(url);
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    setState(() => _isTesting = true);
    try {
      await WebdavBackupService.testConnection(_configFromFields());
      if (!mounted) return;
      _showSnackBar('连接成功，服务器可用');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('连接失败：${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    if (value) {
      // WHY: 开启前要求配置已保存且可用，否则自动备份必然失败
      final config = await WebdavBackupService.getConfig();
      if (!config.isValid) {
        if (!mounted) return;
        _showSnackBar('请先填写并保存服务器配置', isError: true);
        return;
      }
    }

    await WebdavBackupService.setAutoBackupEnabled(value);
    if (!mounted) return;
    setState(() => _autoBackupEnabled = value);
    _showSnackBar(value ? '云端自动备份已开启' : '云端自动备份已关闭');
  }

  Future<void> _setFrequency(int days) async {
    await WebdavBackupService.setFrequencyDays(days);
    if (!mounted) return;
    setState(() => _frequencyDays = days);
  }

  Future<void> _uploadNow() async {
    final config = await WebdavBackupService.getConfig();
    if (!config.isValid) {
      _showSnackBar('请先填写并保存服务器配置', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final fileName = await WebdavBackupService.uploadBackup();
      if (!mounted) return;
      _showSnackBar('备份成功：$fileName');
      final lastTime = await WebdavBackupService.getLastBackupTime();
      if (!mounted) return;
      setState(() => _lastBackupTime = lastTime);
      await _refreshBackups();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('备份失败：${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _refreshBackups() async {
    if (!mounted) return;
    setState(() {
      _isListLoading = true;
      _listError = null;
    });
    try {
      final backups = await WebdavBackupService.listBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _isListLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = _friendlyError(e);
        _isListLoading = false;
      });
    }
  }

  /// 将底层异常转换为用户可读的简短提示
  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401')) return '认证失败，请检查用户名和密码';
    if (msg.contains('403')) return '无访问权限，请检查账号权限设置';
    if (msg.contains('404')) return '资源不存在，请检查服务器地址';
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return '无法连接服务器，请检查网络与地址';
    }
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return '连接超时，请稍后重试';
    }
    // WHY: 原始异常信息过长（含堆栈），截断展示关键部分
    return msg.length > 80 ? '${msg.substring(0, 80)}…' : msg;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
    );
  }

  String _getFrequencyText(int days) {
    switch (days) {
      case 1:
        return '每天';
      case 7:
        return '每周';
      case 30:
        return '每月';
      default:
        return '每$days天';
    }
  }

  /// 格式化云端备份条目时间：优先服务端修改时间，其次从文件名解析
  String _formatItemTime(WebdavBackupItem item) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    if (item.modifiedAt != null) return dateFormat.format(item.modifiedAt!);

    try {
      final dateStr = item.name
          .replaceAll('jitu_webdav_', '')
          .replaceAll('.json', '');
      return dateFormat.format(DateFormat('yyyyMMdd_HHmmss').parse(dateStr));
    } catch (_) {
      return '未知时间';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 云备份'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildConfigCard(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildAutoBackupCard(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildUploadButton(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildBackupListCard(context),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildWarningCard(context),
                  const SizedBox(height: AppTheme.spaceXXXLarge),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.cloud_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '云端备份',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '将数据备份到你自己的 WebDAV 服务器（如坚果云、Nextcloud、NAS），数据完全由你掌控。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '服务器配置',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildTextField(
            controller: _urlController,
            label: '服务器地址',
            hint: 'https://dav.jianguoyun.com/dav/',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildTextField(
            controller: _usernameController,
            label: '用户名',
            hint: 'WebDAV 账号',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildTextField(
            controller: _passwordController,
            label: '密码',
            hint: '建议使用应用专用密码',
            icon: Icons.lock_rounded,
            obscureText: _obscurePassword,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '提示：坚果云等服务需在网页端生成"第三方应用密码"，勿使用登录密码。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(_isTesting ? '测试中' : '测试连接'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.all(AppTheme.spaceMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('保存配置'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(AppTheme.spaceMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.getSecondaryBackground(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceMedium,
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _autoBackupEnabled
                      ? AppTheme.successColor.withValues(alpha: 0.10)
                      : AppTheme.getSecondaryBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  Icons.cloud_sync_rounded,
                  color: _autoBackupEnabled
                      ? AppTheme.successColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动备份到云端',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _autoBackupEnabled
                          ? '已开启 · ${_getFrequencyText(_frequencyDays)} · 启动应用时执行'
                          : '已关闭',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoBackupEnabled,
                onChanged: _toggleAutoBackup,
                activeThumbColor: AppTheme.successColor,
              ),
            ],
          ),
          if (_autoBackupEnabled) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Row(
              children: [
                _buildFrequencyOption(context, 1, '每天'),
                const SizedBox(width: AppTheme.spaceSmall),
                _buildFrequencyOption(context, 7, '每周'),
                const SizedBox(width: AppTheme.spaceSmall),
                _buildFrequencyOption(context, 30, '每月'),
              ],
            ),
          ],
          if (_lastBackupTime != null) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  Text(
                    '上次云端备份：${DateFormat('yyyy-MM-dd HH:mm').format(_lastBackupTime!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(BuildContext context, int days, String label) {
    final isSelected = _frequencyDays == days;

    return Expanded(
      child: InkWell(
        onTap: () => _setFrequency(days),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.10)
                : AppTheme.getSecondaryBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.getDividerColor(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.successGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.successColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isUploading ? null : _uploadNow,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Center(
              child: _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: AppTheme.spaceSmall),
                        Text(
                          '立即备份到云端',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupListCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSmall),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.cloud_queue_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMedium),
                  Text(
                    '云端备份',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_backups.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.spaceSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSmall,
                        vertical: AppTheme.spaceXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getSecondaryBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        '共 ${_backups.length} 个',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新列表',
                onPressed: _isListLoading ? null : _refreshBackups,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          if (_isListLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spaceXLarge),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_listError != null)
            _buildListError(context)
          else if (_backups.isEmpty)
            _buildEmptyState(context)
          else
            Column(
              children: _backups
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppTheme.spaceSmall),
                        child: _buildBackupItem(context, item),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildListError(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '获取云端备份列表失败',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            _listError!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          TextButton.icon(
            onPressed: _refreshBackups,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.getDividerColor(context),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '暂无云端备份',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '保存配置后点击"立即备份到云端"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BuildContext context, WebdavBackupItem item) {
    final sizeKb = (item.size / 1024).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.getDividerColor(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatItemTime(item),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Text(
                    '${item.name} · $sizeKb KB',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') {
                  _showRestoreDialog(item);
                } else if (value == 'delete') {
                  _showDeleteDialog(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore_rounded,
                          size: 20, color: AppTheme.successColor),
                      SizedBox(width: AppTheme.spaceSmall),
                      Text('恢复'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded,
                          size: 20, color: AppTheme.errorColor),
                      SizedBox(width: AppTheme.spaceSmall),
                      Text('删除', style: TextStyle(color: AppTheme.errorColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          const Expanded(
            child: Text(
              '恢复云端备份将覆盖当前所有数据，请谨慎操作！',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(WebdavBackupItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('确认恢复'),
          ],
        ),
        content: Text(
          '将从云端恢复 ${_formatItemTime(item)} 的备份，覆盖当前所有数据，确定要继续吗？\n\n建议先在本地创建一份新备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.neutral600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _performRestore(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(WebdavBackupItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final success = await WebdavBackupService.restoreBackup(item.path);
      // WHY: await 之后组件可能已销毁，pop 与使用 context 前须校验 mounted
      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        _showSnackBar('数据恢复成功！');
      } else {
        _showSnackBar('数据恢复失败：备份文件格式错误', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('数据恢复失败：${_friendlyError(e)}', isError: true);
    }
  }

  void _showDeleteDialog(WebdavBackupItem item) {
    showDialog(
      context: context,
      // WHY: 重命名 builder 的 context，避免遮蔽 State.context，
      // 使闭包内 context/mounted 指向 State，异步间隙后可直接校验
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: AppTheme.errorColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('确认删除'),
          ],
        ),
        content: Text('确定要删除云端备份 ${item.name} 吗？删除后无法找回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.neutral600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await WebdavBackupService.deleteBackup(item.path);
                if (!mounted) return;
                _showSnackBar('云端备份已删除');
                await _refreshBackups();
              } catch (e) {
                if (!mounted) return;
                _showSnackBar('删除失败：${_friendlyError(e)}', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

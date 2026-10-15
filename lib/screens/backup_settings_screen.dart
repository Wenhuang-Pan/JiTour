import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/auto_backup_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _autoBackupEnabled = false;
  int _backupFrequency = 7; // 默认每周
  DateTime? _lastBackupTime;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final enabled = await AutoBackupService.isAutoBackupEnabled();
    final frequency = await AutoBackupService.getBackupFrequency();
    final lastTime = await AutoBackupService.getLastBackupTime();

    setState(() {
      _autoBackupEnabled = enabled;
      _backupFrequency = frequency;
      _lastBackupTime = lastTime;
      _isLoading = false;
    });
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await AutoBackupService.setAutoBackupEnabled(value);
    // WHY: 异步调用后组件可能已销毁，使用 context 前须校验 mounted
    if (!mounted) return;
    setState(() => _autoBackupEnabled = value);

    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自动备份已开启')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自动备份已关闭')),
      );
    }
  }

  Future<void> _setFrequency(int days) async {
    await AutoBackupService.setBackupFrequency(days);
    // WHY: 异步调用后组件可能已销毁，使用 context 前须校验 mounted
    if (!mounted) return;
    setState(() => _backupFrequency = days);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('备份频率已设置为${_getFrequencyText(days)}')),
    );
  }

  Future<void> _backupNow() async {
    setState(() => _isLoading = true);

    final path = await AutoBackupService.performBackupNow();
    // WHY: 异步备份后组件可能已销毁，使用 context 前须校验 mounted
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('备份成功！可在备份管理页查看')),
      );
      await _loadSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('备份失败')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动备份设置'),
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
                  _buildAutoBackupSwitch(context),
                  if (_autoBackupEnabled) ...[
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildFrequencySelector(context),
                  ],
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildManualBackupButton(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  if (_lastBackupTime != null) _buildLastBackupInfo(context),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildCloudSyncTip(context),
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
                  Icons.backup_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '自动备份',
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
            '开启自动备份后，数据会定期备份到手机本地目录。\n配合云盘同步功能，实现数据安全备份。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBackupSwitch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
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
              Icons.schedule_rounded,
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
                  '自动备份',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _autoBackupEnabled
                      ? '已开启 · ${_getFrequencyText(_backupFrequency)}'
                      : '已关闭',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildFrequencySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '备份频率',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
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
    );
  }

  Widget _buildFrequencyOption(BuildContext context, int days, String label) {
    final isSelected = _backupFrequency == days;

    return Expanded(
      child: InkWell(
        onTap: () => _setFrequency(days),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.10)
                : AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.getDividerColor(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualBackupButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _backupNow,
        icon: const Icon(Icons.backup_rounded),
        label: const Text('立即备份'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildLastBackupInfo(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.successColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上次备份时间',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  dateFormat.format(_lastBackupTime!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSyncTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_rounded,
                color: AppTheme.warningColor,
                size: 18,
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Text(
                '云盘同步指南',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '自动备份文件保存在应用私有目录，自动保留最近 10 份，'
            '可在「数据备份」管理页查看、分享与恢复。\n\n'
            '需要云端容灾时，可在备份管理页使用 WebDAV 云备份，'
            '或通过分享功能导出到网盘。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

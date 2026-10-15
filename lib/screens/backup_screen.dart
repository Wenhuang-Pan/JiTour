import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/backup_service.dart';
import 'backup_settings_screen.dart';
import 'webdav_backup_screen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<FileSystemEntity> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoading = true);
    final files = await BackupService.getBackupFiles();
    setState(() {
      _backupFiles = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context),
            const SizedBox(height: AppTheme.spaceXLarge),
            _buildActionButtons(context),
            const SizedBox(height: AppTheme.spaceMedium),
            _buildAutoBackupButton(context),
            // WHY: WebDAV 依赖 dart:io（webdav_client），Web 平台不支持，隐藏入口
            if (!kIsWeb) ...[
              const SizedBox(height: AppTheme.spaceMedium),
              _buildWebdavButton(context),
            ],
            const SizedBox(height: AppTheme.spaceXLarge),
            _buildBackupList(context),
            const SizedBox(height: AppTheme.spaceMedium),
            _buildWarningCard(context),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
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
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '备份说明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Column(
              children: [
                _buildInfoItem('备份将保存所有账单记录和预算设置'),
                const SizedBox(height: AppTheme.spaceSmall),
                _buildInfoItem('备份文件可在需要时恢复数据'),
                const SizedBox(height: AppTheme.spaceSmall),
                _buildInfoItem('建议定期进行数据备份，防止数据丢失'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppTheme.spaceSmall),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
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
                onTap: _createBackup,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.backup_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: AppTheme.spaceSmall),
                      Text(
                        '创建备份',
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
        ),
        const SizedBox(width: AppTheme.spaceMedium),
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _restoreFromFile,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restore_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      SizedBox(width: AppTheme.spaceSmall),
                      Text(
                        '从文件恢复',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoBackupButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BackupSettingsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.schedule_rounded),
        label: const Text('自动备份设置'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildWebdavButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WebdavBackupScreen(),
            ),
          );
        },
        icon: const Icon(Icons.cloud_rounded),
        label: const Text('WebDAV 云备份'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
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
                        Icons.history_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    const Text(
                      '历史备份',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_backupFiles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSmall,
                      vertical: AppTheme.spaceXSmall,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '共 ${_backupFiles.length} 个',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spaceXLarge),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_backupFiles.isEmpty)
              _buildEmptyState(context)
            else
              Column(
                children: _backupFiles
                    .map((file) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppTheme.spaceSmall),
                          child: _buildBackupItem(context, file),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.neutral200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const Icon(
              Icons.backup_outlined,
              size: 40,
              color: AppTheme.neutral400,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          const Text(
            '暂无备份记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral600,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          const Text(
            '点击上方"创建备份"按钮开始备份',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BuildContext context, FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    // WHY: 自动备份（jitu_auto_backup_）与手动备份（jitu_backup_）统一展示，
    // 解析时间戳前需剥离两种前缀；isAuto 用于展示来源标识
    final isAuto = fileName.contains('jitu_auto_backup_');
    final dateStr = fileName
        .replaceAll('jitu_auto_backup_', '')
        .replaceAll('jitu_backup_', '')
        .replaceAll('.json', '');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    DateTime? dateTime;
    try {
      final parsed = DateFormat('yyyyMMdd_HHmmss').parse(dateStr);
      dateTime = parsed;
    } catch (e) {
      dateTime = file.statSync().modified;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.neutral200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () {},
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              dateFormat.format(dateTime),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isAuto) ...[
                            const SizedBox(width: AppTheme.spaceSmall),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceXSmall,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                '自动',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      _shareBackup(File(file.path));
                    } else if (value == 'restore') {
                      _showRestoreDialog(File(file.path));
                    } else if (value == 'delete') {
                      _showDeleteDialog(File(file.path));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded,
                              size: 20, color: AppTheme.primaryColor),
                          SizedBox(width: AppTheme.spaceSmall),
                          Text('分享'),
                        ],
                      ),
                    ),
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
                          Text('删除',
                              style: TextStyle(color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          width: 1,
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
              '恢复备份将覆盖当前所有数据，请谨慎操作！',
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

  Future<void> _createBackup() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      );

      final content = await BackupService.createBackup();
      final file = await BackupService.saveBackupToFile(content);

      // WHY: await 之后组件可能已销毁，pop 前须校验 mounted
      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '记途数据备份',
      );

      await _loadBackupFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('备份创建成功！'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      // WHY: 异常分支同样在 await 之后，pop 前须校验 mounted
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份创建失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _restoreFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        if (!mounted) return;

        _showRestoreDialog(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  void _showRestoreDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        content: const Text(
          '恢复备份将覆盖当前所有数据，确定要继续吗？\n\n建议在恢复前先创建一份新的备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.neutral600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performRestore(file);
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

  Future<void> _performRestore(File file) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      );

      final content = await file.readAsString();
      final success = await BackupService.restoreBackup(content);

      // WHY: await 之后组件可能已销毁，pop 前须校验 mounted
      if (mounted) Navigator.pop(context);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('数据恢复成功！'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('数据恢复失败：文件格式错误'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // WHY: 异常分支同样在 await 之后，pop 前须校验 mounted
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据恢复失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  void _showDeleteDialog(File file) {
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
        content: const Text('确定要删除这个备份吗？'),
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
              final success = await BackupService.deleteBackupFile(file);
              if (success) {
                await _loadBackupFiles();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('备份已删除'),
                      backgroundColor: AppTheme.neutral600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  );
                }
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

  Future<void> _shareBackup(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '记途数据备份',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }
}

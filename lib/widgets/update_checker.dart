import 'package:flutter/material.dart';
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
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
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
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'v${updateInfo.version}',
                      style: TextStyle(
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
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.successColor,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spaceXSmall),
              Expanded(
                child: Text(
                  'Web 应用自动更新，无需重装，数据安全保留',
                  style: TextStyle(
                    color: AppTheme.successColor,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
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
      final updateInfo = await UpdateService.checkForUpdate(ignoreSkip: ignoreSkip);

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
              _performUpdate(updateInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  void _performUpdate(UpdateInfo updateInfo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 20),
            const SizedBox(width: 12),
            const Expanded(
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
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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
            Text(
              '检查更新',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppTheme.spaceXSmall),
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}

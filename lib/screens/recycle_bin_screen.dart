import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../utils/icon_library.dart';

/// 回收站页面：展示已软删除的交易，支持恢复与永久删除
///
/// 交易保留 [DatabaseService.recycleBinRetention] 后由启动流程自动清除
class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          final deleted = DatabaseService.getDeletedTransactions();

          if (deleted.isEmpty) {
            return _buildEmpty(context);
          }

          return Column(
            children: [
              _buildInfoBanner(context),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMedium,
                    AppTheme.spaceMedium,
                    AppTheme.spaceMedium,
                    AppTheme.spaceXXLarge,
                  ),
                  itemCount: deleted.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppTheme.spaceSmall),
                  itemBuilder: (context, index) =>
                      _buildTransactionCard(context, deleted[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final days = DatabaseService.recycleBinRetention.inDays;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spaceMedium,
        AppTheme.spaceMedium,
        AppTheme.spaceMedium,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMedium,
        vertical: AppTheme.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.getPrimaryColor(context),
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          Expanded(
            child: Text(
              '删除的交易保留 $days 天，逾期自动清除',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getPrimaryColor(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            size: 64,
            color: AppTheme.neutral300,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '回收站是空的',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.neutral400,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '删除的交易会在这里保留 ${DatabaseService.recycleBinRetention.inDays} 天',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral400,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    final categoryColor = _getCategoryColor(transaction.category);
    final remainingDays = _remainingDays(transaction);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: categoryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.account} · ${DateFormat('yyyy/M/d').format(transaction.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  remainingDays > 0
                      ? '删除于 ${DateFormat('M/d HH:mm').format(transaction.deletedAt!)} · 剩余 $remainingDays 天'
                      : '删除于 ${DateFormat('M/d HH:mm').format(transaction.deletedAt!)} · 即将清除',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: remainingDays > 3
                            ? AppTheme.neutral400
                            : AppTheme.warningColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isIncome ? '+' : '-'}¥${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: transaction.isIncome
                          ? AppTheme.successColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.restore_rounded,
                    color: AppTheme.getPrimaryColor(context),
                    tooltip: '恢复',
                    onTap: () => _confirmRestore(context, transaction),
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  _buildActionButton(
                    context,
                    icon: Icons.delete_forever_rounded,
                    color: AppTheme.errorColor,
                    tooltip: '永久删除',
                    onTap: () => _confirmPermanentDelete(context, transaction),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceXSmall),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // 计算距自动清除的剩余天数，到期返回 0
  int _remainingDays(Transaction transaction) {
    final deletedAt = transaction.deletedAt;
    if (deletedAt == null) return 0;
    final deadline = deletedAt.add(DatabaseService.recycleBinRetention);
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  Category _getCategory(String categoryName) {
    final categories = [
      ...CategoryService.getIncomeCategories(),
      ...CategoryService.getExpenseCategories(),
    ];
    final matched = categories.where((c) => c.name == categoryName).firstOrNull;
    if (matched != null) {
      return matched;
    }
    return Category(
      id: '',
      name: categoryName,
      iconName: 'category',
      isIncome: false,
      color: '#6B7280',
      createdAt: DateTime.now(),
    );
  }

  Color _getCategoryColor(String category) {
    final cat = _getCategory(category);
    return Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
  }

  IconData _getCategoryIcon(String category) {
    final cat = _getCategory(category);
    try {
      return IconLibrary.getIconByName(cat.iconName);
    } catch (e) {
      return Icons.category;
    }
  }

  void _confirmRestore(BuildContext context, Transaction transaction) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复交易'),
        content: Text(
          '确定要恢复这笔${transaction.isIncome ? '收入' : '支出'}吗？'
          '账户余额将重新计入该笔金额。',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final restored =
                  await DatabaseService.restoreTransaction(transaction.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(restored ? '已恢复，余额已同步更新' : '恢复失败，交易不存在'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getPrimaryColor(context),
            ),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, Transaction transaction) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除'),
        content: const Text('确定要永久删除这笔交易吗？此操作不可撤销，数据将无法找回。'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await DatabaseService.permanentDeleteTransaction(transaction.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已永久删除'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
  }
}

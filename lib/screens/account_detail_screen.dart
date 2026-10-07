import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/stats_service.dart';
import '../utils/icon_library.dart';
import 'add_transaction_screen.dart';

/// 账户流水详情页面
/// 展示单个账户的交易记录和统计信息
class AccountDetailScreen extends StatelessWidget {
  /// 账户信息
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加交易',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          // 获取该账户的所有交易（排除软删除账单）
          final accountTransactions = box.values
              .where((t) => t.account == account.name && !t.isDeleted)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          // 计算统计数据
          final totalIncome =
              StatsService.calculateTotal(accountTransactions, true);
          final totalExpense =
              StatsService.calculateTotal(accountTransactions, false);
          final monthTransactions =
              StatsService.getMonthTransactions(accountTransactions);
          final monthIncome =
              StatsService.calculateTotal(monthTransactions, true);
          final monthExpense =
              StatsService.calculateTotal(monthTransactions, false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 账户概览卡片
                _buildAccountOverviewCard(context),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 统计概览
                _buildStatsOverview(context, totalIncome, totalExpense,
                    monthIncome, monthExpense),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 交易列表
                _buildTransactionList(context, accountTransactions),
                const SizedBox(height: AppTheme.spaceXXXLarge),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建账户概览卡片
  Widget _buildAccountOverviewCard(BuildContext context) {
    final icon = IconLibrary.getIconByName(account.iconName);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
      decoration: BoxDecoration(
        color: AppTheme.getPrimaryColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppTheme.spaceLarge),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: AppTheme.textTitleLarge,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '初始余额: ¥${account.initialBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: AppTheme.textBodySmall,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXLarge),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前余额',
                      style: TextStyle(
                        fontSize: AppTheme.textBodySmall,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${account.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMedium,
                  vertical: AppTheme.spaceSmall,
                ),
                decoration: BoxDecoration(
                  color: (account.currentBalance >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor)
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  account.currentBalance >= 0 ? '正常' : '透支',
                  style: const TextStyle(
                    fontSize: AppTheme.textLabelSmall,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计概览
  Widget _buildStatsOverview(
    BuildContext context,
    double totalIncome,
    double totalExpense,
    double monthIncome,
    double monthExpense,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '统计概览', '该账户收支情况'),
        const SizedBox(height: AppTheme.spaceMedium),
        Row(
          children: [
            // 累计收入
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '累计收入',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.neutral500,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '¥${totalIncome.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            // 累计支出
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '累计支出',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.neutral500,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '¥${totalExpense.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.errorColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            // 本月收支
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月收支',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.neutral500,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '¥${(monthIncome - monthExpense).toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: (monthIncome - monthExpense) >= 0
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建交易列表
  Widget _buildTransactionList(
      BuildContext context, List<Transaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '交易记录', '该账户所有交易'),
        const SizedBox(height: AppTheme.spaceMedium),
        if (transactions.isEmpty)
          _buildEmptyState(context)
        else
          ...transactions.map((transaction) {
            // 获取日期分组
            final dateKey = transaction.date.toString().split(' ')[0];
            final prevTransaction = transactions.indexOf(transaction) > 0
                ? transactions[transactions.indexOf(transaction) - 1]
                : null;
            final prevDateKey = prevTransaction != null
                ? prevTransaction.date.toString().split(' ')[0]
                : '';

            return Column(
              children: [
                // 日期分隔线（仅在日期变化时显示）
                if (dateKey != prevDateKey)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceMedium,
                    ),
                    child: _buildDateDivider(context, transaction.date),
                  ),
                _buildTransactionCard(context, transaction),
              ],
            );
          }),
      ],
    );
  }

  /// 构建日期分隔线
  Widget _buildDateDivider(BuildContext context, DateTime date) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.neutral200,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMedium),
        Text(
          _formatDate(date),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.neutral500,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: AppTheme.spaceMedium),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.neutral200,
          ),
        ),
      ],
    );
  }

  /// 构建交易卡片
  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            // 分类图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: transaction.isIncome
                    ? AppTheme.successColor.withValues(alpha: 0.12)
                    : AppTheme.errorColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                transaction.isIncome
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: transaction.isIncome
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            // 交易信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.category,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        transaction.account,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                      ),
                      if (transaction.note != null &&
                          transaction.note!.isNotEmpty) ...[
                        const SizedBox(width: AppTheme.spaceXSmall),
                        const Text(
                          '·',
                          style: TextStyle(color: AppTheme.neutral400),
                        ),
                        const SizedBox(width: AppTheme.spaceXSmall),
                        Text(
                          transaction.note!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.neutral500,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 金额和时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.isIncome ? '+' : '-'}¥${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppTheme.textBodyLarge,
                    fontWeight: FontWeight.w700,
                    color: transaction.isIncome
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXSmall),
                Text(
                  _formatTime(transaction.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_rounded,
                size: 40,
                color: AppTheme.getPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXXLarge),
            Text(
              '暂无交易记录',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              '该账户还没有交易记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutral400,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建区域标题
  Widget _buildSectionTitle(
      BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceXSmall),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.neutral500,
              ),
        ),
      ],
    );
  }

  /// 格式化日期显示
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else if (targetDate == tomorrow) {
      return '明天';
    } else {
      final diff = today.difference(targetDate).inDays;
      if (diff > 0 && diff < 7) {
        final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return weekdays[date.weekday % 7];
      } else {
        return '${date.month}月${date.day}日';
      }
    }
  }

  /// 格式化时间显示
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

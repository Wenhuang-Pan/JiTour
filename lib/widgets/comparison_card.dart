import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';

/// 对比分析卡片组件
/// 展示收支对比数据和变化率
class ComparisonCard extends StatelessWidget {
  /// 当前收入
  final double currentIncome;

  /// 当前支出
  final double currentExpense;

  /// 对比收入（上月/去年同月/上周）
  final double compareIncome;

  /// 对比支出（上月/去年同月/上周）
  final double compareExpense;

  /// 对比标题（如"vs 上月"、"vs 去年同月"、"vs 上周"）
  final String compareTitle;

  /// 卡片标题
  final String title;

  const ComparisonCard({
    super.key,
    required this.currentIncome,
    required this.currentExpense,
    required this.compareIncome,
    required this.compareExpense,
    required this.compareTitle,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // 计算变化率
    final incomeChangeRate =
        StatsService.calculateChangeRate(currentIncome, compareIncome);
    final expenseChangeRate =
        StatsService.calculateChangeRate(currentExpense, compareExpense);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  compareTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.neutral400,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 收入对比
            _buildComparisonRow(
              context,
              label: '收入',
              currentValue: currentIncome,
              compareValue: compareIncome,
              changeRate: incomeChangeRate,
              isIncome: true,
            ),
            const SizedBox(height: AppTheme.spaceLarge),

            // 支出对比
            _buildComparisonRow(
              context,
              label: '支出',
              currentValue: currentExpense,
              compareValue: compareExpense,
              changeRate: expenseChangeRate,
              isIncome: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建对比行
  Widget _buildComparisonRow(
    BuildContext context, {
    required String label,
    required double currentValue,
    required double compareValue,
    required double? changeRate,
    required bool isIncome,
  }) {
    return Row(
      children: [
        // 标签
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
        ),

        // 当前值
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '¥${currentValue.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),

        const SizedBox(width: AppTheme.spaceSmall),

        // 对比值
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '¥${compareValue.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.neutral400,
                  ),
            ),
          ),
        ),

        const SizedBox(width: AppTheme.spaceSmall),

        // 变化率
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                changeRate != null && changeRate >= 0
                    ? (isIncome
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded)
                    : (isIncome
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded),
                size: 16,
                color: StatsService.getChangeRateColor(changeRate, isIncome),
              ),
              const SizedBox(width: 2),
              // WHY: 使用 Flexible + FittedBox 防止百分比文本过长导致横向溢出
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    StatsService.formatChangeRate(changeRate),
                    style: TextStyle(
                      fontSize: AppTheme.textBodySmall,
                      fontWeight: FontWeight.w600,
                      color:
                          StatsService.getChangeRateColor(changeRate, isIncome),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 紧凑版对比卡片，用于首页或概览区域
class CompactComparisonCard extends StatelessWidget {
  /// 当前收入
  final double currentIncome;

  /// 当前支出
  final double currentExpense;

  /// 收入变化率
  final double? incomeChangeRate;

  /// 支出变化率
  final double? expenseChangeRate;

  /// 卡片标题
  final String title;

  const CompactComparisonCard({
    super.key,
    required this.currentIncome,
    required this.currentExpense,
    required this.incomeChangeRate,
    required this.expenseChangeRate,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.neutral500,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Row(
            children: [
              // 收入
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¥${currentIncome.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successColor,
                            ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          incomeChangeRate != null && incomeChangeRate! >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: StatsService.getChangeRateColor(
                              incomeChangeRate, true),
                        ),
                        const SizedBox(width: 2),
                        // WHY: 使用 Flexible 防止百分比文本过长导致横向溢出
                        Flexible(
                          child: Text(
                            StatsService.formatChangeRate(incomeChangeRate),
                            style: TextStyle(
                              fontSize: AppTheme.textLabelSmall,
                              fontWeight: FontWeight.w500,
                              color: StatsService.getChangeRateColor(
                                  incomeChangeRate, true),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              // 支出
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '¥${currentExpense.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorColor,
                            ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          expenseChangeRate != null && expenseChangeRate! >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: StatsService.getChangeRateColor(
                              expenseChangeRate, false),
                        ),
                        const SizedBox(width: 2),
                        // WHY: 使用 Flexible 防止百分比文本过长导致横向溢出
                        Flexible(
                          child: Text(
                            StatsService.formatChangeRate(expenseChangeRate),
                            style: TextStyle(
                              fontSize: AppTheme.textLabelSmall,
                              fontWeight: FontWeight.w500,
                              color: StatsService.getChangeRateColor(
                                  expenseChangeRate, false),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

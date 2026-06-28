import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../utils/icon_library.dart';
import '../services/category_service.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  List<Transaction> _getMonthTransactions(List<Transaction> allTransactions) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return allTransactions.where((t) => t.date.isAfter(startOfMonth)).toList();
  }

  double _calculateTotal(List<Transaction> transactions, bool isIncome) {
    return transactions
        .where((t) => t.isIncome == isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> _calculateCategoryStats(List<Transaction> transactions, bool isIncome) {
    final filtered = transactions.where((t) => t.isIncome == isIncome).toList();
    final stats = <String, double>{};
    for (final t in filtered) {
      stats[t.category] = (stats[t.category] ?? 0) + t.amount;
    }
    return stats;
  }

  Map<String, Map<String, double>> _calculateTrendData(List<Transaction> allTransactions) {
    final trend = <String, Map<String, double>>{};
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);

      final monthTransactions = allTransactions.where((t) =>
          t.date.year == month.year && t.date.month == month.month).toList();

      trend[monthKey] = {
        'income': monthTransactions
            .where((t) => t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount),
        'expense': monthTransactions
            .where((t) => !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount),
      };
    }

    return trend;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          final allTransactions = box.values.toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final monthTransactions = _getMonthTransactions(allTransactions);
          final totalIncome = _calculateTotal(monthTransactions, true);
          final totalExpense = _calculateTotal(monthTransactions, false);
          final balance = totalIncome - totalExpense;
          final expenseStats = _calculateCategoryStats(monthTransactions, false);
          final incomeStats = _calculateCategoryStats(monthTransactions, true);
          final trendData = _calculateTrendData(allTransactions);

          if (allTransactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLarge),
                    Text(
                      '暂无统计数据',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.neutral700,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '添加交易后即可查看统计',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI 概览卡片
                _buildKpiSection(context, totalIncome, totalExpense, balance),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 收支趋势图
                if (trendData.isNotEmpty) ...[
                  _buildSectionTitle(context, '收支趋势', '近6个月'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildTrendChart(context, trendData),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                // 支出分类
                if (expenseStats.isNotEmpty) ...[
                  _buildSectionTitle(context, '支出分类', '本月支出构成'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildDonutChart(
                    context,
                    expenseStats,
                    totalExpense,
                    AppTheme.errorColor,
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildCategoryList(context, expenseStats, AppTheme.errorColor),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                // 收入分类
                if (incomeStats.isNotEmpty) ...[
                  _buildSectionTitle(context, '收入分类', '本月收入构成'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildDonutChart(
                    context,
                    incomeStats,
                    totalIncome,
                    AppTheme.successColor,
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildCategoryList(context, incomeStats, AppTheme.successColor),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                const SizedBox(height: AppTheme.spaceXXXLarge),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiSection(BuildContext context, double income, double expense, double balance) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '本月概览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            children: [
              Expanded(
                child: _buildKpiItem('收入', income, AppTheme.successLight),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: _buildKpiItem('支出', expense, AppTheme.errorLight),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '结余',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '¥${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, double amount, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, String subtitle) {
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

  Widget _buildTrendChart(BuildContext context, Map<String, Map<String, double>> trendData) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateMaxY(trendData) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.neutral200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatAxisValue(value),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.neutral500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < trendData.keys.length) {
                          final monthKey = trendData.keys.elementAt(index);
                          final month = int.parse(monthKey.split('-')[1]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${month}月',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.neutral500,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildIncomeLine(trendData),
                  _buildExpenseLine(trendData),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isIncome = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? "收入" : "支出"}: ¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: isIncome ? AppTheme.successColor : AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('收入', AppTheme.successColor),
              const SizedBox(width: AppTheme.spaceXLarge),
              _buildLegendItem('支出', AppTheme.errorColor),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateMaxY(Map<String, Map<String, double>> trendData) {
    double maxValue = 0;
    for (final data in trendData.values) {
      for (final value in data.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue > 0 ? maxValue * 1.2 : 1000;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(0)}k';
    }
    return '¥${value.toStringAsFixed(0)}';
  }

  LineChartBarData _buildIncomeLine(Map<String, Map<String, double>> trendData) {
    return LineChartBarData(
      spots: trendData.entries.toList().asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.value['income'] ?? 0);
      }).toList(),
      isCurved: true,
      gradient: AppTheme.successGradient,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppTheme.successColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor.withOpacity(0.15),
            AppTheme.successColor.withOpacity(0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  LineChartBarData _buildExpenseLine(Map<String, Map<String, double>> trendData) {
    return LineChartBarData(
      spots: trendData.entries.toList().asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.value['expense'] ?? 0);
      }).toList(),
      isCurved: true,
      gradient: AppTheme.warningGradient,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppTheme.warningColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withOpacity(0.15),
            AppTheme.warningColor.withOpacity(0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildDonutChart(
    BuildContext context,
    Map<String, double> categoryStats,
    double total,
    Color primaryColor,
  ) {
    final sortedEntries = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = _getCategoryColors(sortedEntries.length);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sortedEntries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final percentage = (data.value / total) * 100;
                      return PieChartSectionData(
                        value: data.value,
                        color: colors[index],
                        radius: 24,
                        showTitle: false,
                      );
                    }).toList(),
                    centerSpaceRadius: 48,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¥${_formatAmount(total)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                    ),
                    Text(
                      '总计',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceLarge),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedEntries.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final percentage = (data.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[index],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSmall),
                      Expanded(
                        child: Text(
                          data.key,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getCategoryColors(int count) {
    final baseColors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.primaryLight,
      AppTheme.neutral600,
    ];
    return List.generate(count, (index) => baseColors[index % baseColors.length]);
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildCategoryList(BuildContext context, Map<String, double> categoryStats, Color primaryColor) {
    final sortedEntries = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = categoryStats.values.fold(0.0, (sum, val) => sum + val);
    final colors = _getCategoryColors(sortedEntries.length);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final percentage = (data.value / total) * 100;
          final isLast = index == sortedEntries.length - 1;

          return Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: AppTheme.neutral200,
                        width: 1,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors[index].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Center(
                    child: Icon(
                      IconLibrary.getIconByName(data.key),
                      size: 18,
                      color: colors[index],
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: AppTheme.neutral200,
                          valueColor: AlwaysStoppedAnimation<Color>(colors[index]),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${data.value.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.neutral600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

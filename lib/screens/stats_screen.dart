import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/account_service.dart';
import '../services/tag_service.dart';
import '../services/stats_service.dart';
import '../utils/icon_library.dart';
import '../widgets/comparison_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// 当前选中的年份
  late int _selectedYear;

  /// 当前选中的月份（1-12）
  late int _selectedMonth;

  /// 视图模式（月/年）
  bool _isYearView = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  /// 切换到上一月
  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  /// 切换到下一月
  void _nextMonth() {
    final now = DateTime.now();
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
      // 限制不能超过当前月
      if (_selectedYear == now.year && _selectedMonth > now.month) {
        _selectedYear = now.year;
        _selectedMonth = now.month;
      }
    });
  }

  /// 切换到上一年
  void _prevYear() {
    setState(() {
      _selectedYear--;
    });
  }

  /// 切换到下一年
  void _nextYear() {
    final now = DateTime.now();
    setState(() {
      if (_selectedYear < now.year) {
        _selectedYear++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildTimeSelector(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          final allTransactions = box.values.toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          // 根据视图模式获取交易数据
          final periodTransactions = _isYearView
              ? StatsService.getTransactionsForYear(
                  allTransactions, _selectedYear)
              : StatsService.getTransactionsForMonth(
                  allTransactions, _selectedYear, _selectedMonth);

          final totalIncome =
              StatsService.calculateTotal(periodTransactions, true);
          final totalExpense =
              StatsService.calculateTotal(periodTransactions, false);
          final balance = totalIncome - totalExpense;
          final expenseStats =
              StatsService.calculateCategoryStats(periodTransactions, false);
          final incomeStats =
              StatsService.calculateCategoryStats(periodTransactions, true);

          // 趋势数据始终基于全量交易计算（近6月）
          final trendData = StatsService.calculateTrendData(allTransactions);

          // 对比分析数据
          final monthComparison = _isYearView
              ? _calculateYearComparison(allTransactions)
              : StatsService.calculateMonthComparisonForMonth(
                  allTransactions, _selectedYear, _selectedMonth);
          final yearComparison = _isYearView
              ? _calculateYearComparison2(allTransactions)
              : StatsService.calculateYearComparisonForMonth(
                  allTransactions, _selectedYear, _selectedMonth);

          if (allTransactions.isEmpty) {
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
                        color: AppTheme.getPrimaryColor(context)
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 40,
                        color: AppTheme.getPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXXLarge),
                    Text(
                      '暂无统计数据',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '添加交易后即可查看统计',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.neutral400,
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
                _buildKpiSection(context, totalIncome, totalExpense, balance,
                    isYearView: _isYearView),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 对比分析区域
                _buildComparisonSection(
                    context, monthComparison, yearComparison,
                    isYearView: _isYearView),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 收支趋势图
                if (trendData.isNotEmpty) ...[
                  _buildSectionTitle(context, '收支趋势', '近6个月'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildTrendChart(context, trendData),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                // 账户分布
                _buildAccountDistribution(context),
                const SizedBox(height: AppTheme.spaceXLarge),

                // 支出分类
                if (expenseStats.isNotEmpty) ...[
                  _buildSectionTitle(
                      context, '支出分类', _isYearView ? '年度支出构成' : '本月支出构成'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildDonutChart(
                    context,
                    expenseStats,
                    totalExpense,
                    AppTheme.errorColor,
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildCategoryList(context, expenseStats, AppTheme.errorColor,
                      periodTransactions, false),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                // 收入分类
                if (incomeStats.isNotEmpty) ...[
                  _buildSectionTitle(
                      context, '收入分类', _isYearView ? '年度收入构成' : '本月收入构成'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  _buildDonutChart(
                    context,
                    incomeStats,
                    totalIncome,
                    AppTheme.successColor,
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildCategoryList(context, incomeStats,
                      AppTheme.successColor, periodTransactions, true),
                  const SizedBox(height: AppTheme.spaceXLarge),
                ],

                // 标签统计
                _buildTagStats(context, periodTransactions),
                const SizedBox(height: AppTheme.spaceXLarge),

                // TOP N 排行榜
                _buildTopRankingSection(context, periodTransactions,
                    isYearView: _isYearView),
                const SizedBox(height: AppTheme.spaceXLarge),

                const SizedBox(height: AppTheme.spaceXXXLarge),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建时间选择器（月/年切换 + 导航）
  Widget _buildTimeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMedium,
        vertical: AppTheme.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.getDividerColor(context),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // 月/年视图切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isYearView = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: AppTheme.spaceXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: !_isYearView
                        ? AppTheme.getPrimaryColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    '月',
                    style: TextStyle(
                      color: !_isYearView ? Colors.white : AppTheme.neutral500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              GestureDetector(
                onTap: () => setState(() => _isYearView = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: AppTheme.spaceXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: _isYearView
                        ? AppTheme.getPrimaryColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    '年',
                    style: TextStyle(
                      color: _isYearView ? Colors.white : AppTheme.neutral500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          // 日期导航
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一月/上一年
              GestureDetector(
                onTap: _isYearView ? _prevYear : _prevMonth,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: AppTheme.neutral600,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              // 日期显示
              GestureDetector(
                onTap: _selectDatePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge,
                    vertical: AppTheme.spaceXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    _isYearView
                        ? '${_selectedYear}年'
                        : '$_selectedYear年$_selectedMonth月',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.getPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              // 下一月/下一年
              GestureDetector(
                onTap: _isYearView ? _nextYear : _nextMonth,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.neutral600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 选择日期的日期选择器弹窗
  Future<void> _selectDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month),
      builder: (context, child) {
        if (child == null) return const SizedBox();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              primary: AppTheme.getPrimaryColor(context),
              onPrimary: Colors.white,
              secondary: AppTheme.getPrimaryColor(context),
              onSecondary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
              error: AppTheme.errorColor,
              onError: Colors.white,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedYear = picked.year;
        _selectedMonth = picked.month;
      });
    }
  }

  /// 年度对比：当前年 vs 上一年
  Map<String, Map<String, double>> _calculateYearComparison(
      List<Transaction> allTransactions) {
    final currentYearTransactions =
        StatsService.getTransactionsForYear(allTransactions, _selectedYear);
    final previousYearTransactions =
        StatsService.getTransactionsForYear(allTransactions, _selectedYear - 1);

    return {
      'current': {
        'income': StatsService.calculateTotal(currentYearTransactions, true),
        'expense': StatsService.calculateTotal(currentYearTransactions, false),
      },
      'previous': {
        'income': StatsService.calculateTotal(previousYearTransactions, true),
        'expense': StatsService.calculateTotal(previousYearTransactions, false),
      },
    };
  }

  /// 年度同比：当前年 vs 去年同期
  Map<String, Map<String, double>> _calculateYearComparison2(
      List<Transaction> allTransactions) {
    return _calculateYearComparison(allTransactions);
  }

  Widget _buildKpiSection(
      BuildContext context, double income, double expense, double balance,
      {bool isYearView = false}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.getPrimaryGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isYearView ? '年度概览' : '本月概览',
            style: const TextStyle(
              fontSize: AppTheme.textBodyMedium,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXXLarge),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '收入',
                      style: TextStyle(
                        fontSize: AppTheme.textBodySmall,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      '¥${income.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: AppTheme.textHeadlineSmall,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '支出',
                      style: TextStyle(
                        fontSize: AppTheme.textBodySmall,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      '¥${expense.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: AppTheme.textHeadlineSmall,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLarge,
              vertical: AppTheme.spaceMedium,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isYearView ? '年度结余' : '本月结余',
                  style: TextStyle(
                    fontSize: AppTheme.textBodySmall,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '¥${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: AppTheme.textTitleLarge,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTrendChart(
      BuildContext context, Map<String, Map<String, double>> trendData) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
                  horizontalInterval: StatsService.calculateMaxY(trendData) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.getDividerColor(context),
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
                          StatsService.formatAxisValue(value),
                          style: const TextStyle(
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
                              '$month月',
                              style: const TextStyle(
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
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildIncomeLine(trendData, context),
                  _buildExpenseLine(trendData, context),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isIncome = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? "收入" : "支出"}: ¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: isIncome
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
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

  LineChartBarData _buildIncomeLine(
      Map<String, Map<String, double>> trendData, BuildContext context) {
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
            strokeColor: AppTheme.getCardColor(context),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor.withValues(alpha: 0.15),
            AppTheme.successColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  LineChartBarData _buildExpenseLine(
      Map<String, Map<String, double>> trendData, BuildContext context) {
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
            strokeColor: AppTheme.getCardColor(context),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withValues(alpha: 0.15),
            AppTheme.warningColor.withValues(alpha: 0.02),
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

    final colors = StatsService.getCategoryColors(sortedEntries.length);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
                      '¥${StatsService.formatAmount(total)}',
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
              children:
                  sortedEntries.take(5).toList().asMap().entries.map((entry) {
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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

  Widget _buildCategoryList(
      BuildContext context,
      Map<String, double> categoryStats,
      Color primaryColor,
      List<Transaction> periodTransactions,
      bool isIncome) {
    final sortedEntries = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = categoryStats.values.fold(0.0, (sum, val) => sum + val);
    final colors = StatsService.getCategoryColors(sortedEntries.length);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final percentage = (data.value / total) * 100;
          final isLast = index == sortedEntries.length - 1;

          return InkWell(
            onTap: () => _showCategoryDetail(
                context, data.key, periodTransactions, isIncome),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: AppTheme.getDividerColor(context),
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
                      color: colors[index].withValues(alpha: 0.12),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor:
                                AppTheme.getSecondaryBackground(context),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors[index]),
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
                  const SizedBox(width: AppTheme.spaceXSmall),
                  // WHY: 提示可点击查看明细
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.neutral400,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 显示分类下当期所有交易明细
  ///
  /// @param context BuildContext
  /// @param categoryName 分类名称
  /// @param periodTransactions 当期所有交易
  /// @param isIncome 是否为收入分类
  void _showCategoryDetail(BuildContext context, String categoryName,
      List<Transaction> periodTransactions, bool isIncome) {
    // WHY: 筛选该分类下当期的所有交易，并按日期倒序排列便于查看
    final categoryTransactions = periodTransactions
        .where((t) => t.category == categoryName && t.isIncome == isIncome)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalAmount =
        categoryTransactions.fold(0.0, (sum, t) => sum + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spaceLarge,
                right: AppTheme.spaceLarge,
                bottom: AppTheme.spaceXLarge,
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceMedium),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.neutral300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Text(
                    '${categoryTransactions.length} 笔 · 合计 ¥${totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  Expanded(
                    child: categoryTransactions.isEmpty
                        ? Center(
                            child: Text(
                              '暂无明细',
                              style: TextStyle(
                                color: AppTheme.neutral400,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: categoryTransactions.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: AppTheme.getDividerColor(context),
                            ),
                            itemBuilder: (context, index) {
                              final t = categoryTransactions[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTheme.spaceSmall,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.note?.isNotEmpty == true
                                                ? t.note!
                                                : t.account,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('yyyy-MM-dd HH:mm')
                                                .format(t.date),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppTheme.neutral400,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${t.isIncome ? '+' : '-'}¥${t.amount.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: t.isIncome
                                                ? AppTheme.successColor
                                                : AppTheme.neutral900,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.neutral600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 账户分布饼图
  Widget _buildAccountDistribution(BuildContext context) {
    final accounts = AccountService.getActiveAccounts();
    if (accounts.isEmpty) return const SizedBox.shrink();

    // 按账户余额排序
    final sortedAccounts = accounts.toList()
      ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

    final totalBalance = AccountService.getTotalBalance();
    if (totalBalance <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '账户分布', '各账户资产占比'),
        const SizedBox(height: AppTheme.spaceMedium),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sortedAccounts.asMap().entries.map((entry) {
                          final account = entry.value;
                          return PieChartSectionData(
                            value: account.currentBalance,
                            color: Color(account.colorValue),
                            radius: 20,
                            showTitle: false,
                          );
                        }).toList(),
                        centerSpaceRadius: 36,
                        sectionsSpace: 2,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¥${StatsService.formatAmount(totalBalance)}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          '总资产',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  children: sortedAccounts.take(5).map((account) {
                    final percentage =
                        (account.currentBalance / totalBalance) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color(account.colorValue),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSmall),
                          Icon(
                            IconLibrary.getIconByName(account.iconName),
                            size: 14,
                            color: Color(account.colorValue),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              account.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
        ),
      ],
    );
  }

  // 标签统计
  Widget _buildTagStats(BuildContext context, List<Transaction> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    // 统计各标签的交易金额
    final tagStats = <String, double>{};
    final tagCounts = <String, int>{};

    for (final t in transactions) {
      final tagIds = t.tagIds;
      for (final tagId in tagIds) {
        tagStats[tagId] = (tagStats[tagId] ?? 0) + t.amount;
        tagCounts[tagId] = (tagCounts[tagId] ?? 0) + 1;
      }
    }

    if (tagStats.isEmpty) return const SizedBox.shrink();

    // 转换为标签名称并排序
    final sortedTagStats = tagStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalAmount = tagStats.values.fold(0.0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '标签统计', '交易标签分布'),
        const SizedBox(height: AppTheme.spaceMedium),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(
            children:
                sortedTagStats.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final tagId = entry.value.key;
              final amount = entry.value.value;
              final count = tagCounts[tagId] ?? 0;
              final tag = TagService.getTagById(tagId);
              final percentage = (amount / totalAmount) * 100;
              final isLast = index == sortedTagStats.take(6).length - 1;

              if (tag == null) return const SizedBox.shrink();

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(
                            color: AppTheme.neutral100,
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
                        color: Color(tag.colorValue).withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        IconLibrary.getIconByName(tag.iconName),
                        size: 18,
                        color: Color(tag.colorValue),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tag.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count笔',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.neutral500,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: AppTheme.neutral200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(tag.colorValue),
                              ),
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
                          '¥${amount.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
        ),
      ],
    );
  }

  /// 构建对比分析区域
  Widget _buildComparisonSection(
    BuildContext context,
    Map<String, Map<String, double>> monthComparison,
    Map<String, Map<String, double>> yearComparison, {
    bool isYearView = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '对比分析', isYearView ? '年度对比' : '月度对比'),
        const SizedBox(height: AppTheme.spaceMedium),
        Column(
          children: [
            // 环比对比
            ComparisonCard(
              title: isYearView ? '年度环比' : '月度对比',
              compareTitle: isYearView ? 'vs 上年' : 'vs 上月',
              currentIncome: monthComparison['current']?['income'] ?? 0,
              currentExpense: monthComparison['current']?['expense'] ?? 0,
              compareIncome: monthComparison['previous']?['income'] ?? 0,
              compareExpense: monthComparison['previous']?['expense'] ?? 0,
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            // 同比对比
            ComparisonCard(
              title: isYearView ? '年度同比' : '同比分析',
              compareTitle: isYearView ? 'vs 去年' : 'vs 去年同月',
              currentIncome: yearComparison['current']?['income'] ?? 0,
              currentExpense: yearComparison['current']?['expense'] ?? 0,
              compareIncome: yearComparison['yearAgo']?['income'] ?? 0,
              compareExpense: yearComparison['yearAgo']?['expense'] ?? 0,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建 TOP N 排行榜区域
  Widget _buildTopRankingSection(
      BuildContext context, List<Transaction> transactions,
      {bool isYearView = false}) {
    final topExpenseCategories =
        StatsService.getTopExpenseCategories(transactions, 5);
    final topIncomeCategories =
        StatsService.getTopIncomeCategories(transactions, 5);
    final topMerchants = StatsService.getTopMerchants(transactions, 5);

    if (topExpenseCategories.isEmpty &&
        topIncomeCategories.isEmpty &&
        topMerchants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'TOP N 排行榜', isYearView ? '年度' : '本月'),
        const SizedBox(height: AppTheme.spaceMedium),

        // 支出分类 TOP 5
        if (topExpenseCategories.isNotEmpty) ...[
          _buildRankingCard(
            context,
            '支出分类 TOP 5',
            topExpenseCategories,
            AppTheme.errorColor,
            isAmount: true,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
        ],

        // 收入分类 TOP 5
        if (topIncomeCategories.isNotEmpty) ...[
          _buildRankingCard(
            context,
            '收入分类 TOP 5',
            topIncomeCategories,
            AppTheme.successColor,
            isAmount: true,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
        ],

        // 消费商家 TOP 5
        if (topMerchants.isNotEmpty) ...[
          _buildRankingCard(
            context,
            '消费商家 TOP 5',
            topMerchants,
            AppTheme.getPrimaryColor(context),
            isAmount: true,
          ),
        ],
      ],
    );
  }

  /// 构建排行榜卡片
  Widget _buildRankingCard(
    BuildContext context,
    String title,
    Map<String, double> data,
    Color primaryColor, {
    bool isAmount = true,
  }) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.values.fold(0.0, (sum, val) => sum + val);

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          ...sortedEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = total > 0 ? (item.value / total) * 100 : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // 排名标识
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getRankBackgroundColor(index, primaryColor),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRankTextColor(index),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMedium),

                  // 名称
                  Expanded(
                    child: Text(
                      item.key,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 金额和占比
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isAmount
                            ? '¥${StatsService.formatAmount(item.value)}'
                            : '${item.value}笔',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                      ),
                      if (isAmount && total > 0)
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.neutral500,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 获取排名背景色
  Color _getRankBackgroundColor(int index, Color primaryColor) {
    switch (index) {
      case 0:
        return Colors.amber.withValues(alpha: 0.15);
      case 1:
        return Colors.grey.withValues(alpha: 0.15);
      case 2:
        return Colors.orange.withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.05);
    }
  }

  /// 获取排名文字颜色
  Color _getRankTextColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber[600] ?? Colors.amber;
      case 1:
        return Colors.grey[600] ?? Colors.grey;
      case 2:
        return Colors.orange[600] ?? Colors.orange;
      default:
        return AppTheme.neutral400;
    }
  }
}

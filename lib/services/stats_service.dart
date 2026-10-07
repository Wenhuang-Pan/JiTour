import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import 'tag_service.dart';

/// 标签维度统计条目（纯内存 DTO，不入 Hive）
class TagStatEntry {
  /// 标签 ID
  final String tagId;

  /// 关联交易金额合计（一笔交易带多个标签时，会在每个标签下各计一次）
  final double amount;

  /// 关联交易笔数
  final int count;

  const TagStatEntry({
    required this.tagId,
    required this.amount,
    required this.count,
  });
}

class StatsService {
  StatsService._();

  /// 获取当月的交易记录
  static List<Transaction> getMonthTransactions(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    return getTransactionsForMonth(allTransactions, now.year, now.month);
  }

  /// 获取指定年月的交易记录
  ///
  /// @param allTransactions 所有交易记录
  /// @param year 年份
  /// @param month 月份 (1-12)
  /// @return 指定年月的交易列表
  static List<Transaction> getTransactionsForMonth(
      List<Transaction> allTransactions, int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    return allTransactions
        .where((t) =>
            !t.date.isBefore(startOfMonth) && !t.date.isAfter(endOfMonth))
        .toList();
  }

  /// 获取指定年份的交易记录
  ///
  /// @param allTransactions 所有交易记录
  /// @param year 年份
  /// @return 指定年份的交易列表
  static List<Transaction> getTransactionsForYear(
      List<Transaction> allTransactions, int year) {
    return allTransactions.where((t) => t.date.year == year).toList();
  }

  /// 计算总收入或总支出
  static double calculateTotal(List<Transaction> transactions, bool isIncome) {
    return transactions
        .where((t) => t.isIncome == isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// 计算分类统计
  static Map<String, double> calculateCategoryStats(
      List<Transaction> transactions, bool isIncome) {
    final filtered = transactions.where((t) => t.isIncome == isIncome).toList();
    final stats = <String, double>{};
    for (final t in filtered) {
      stats[t.category] = (stats[t.category] ?? 0) + t.amount;
    }
    return stats;
  }

  /// 计算标签维度统计（按收支类型）
  ///
  /// WHY: 标签与分类是多对多关系，一笔交易可带多个标签，故金额在每个
  /// 关联标签下各计一次，占比口径为"标签关联金额合计"而非收支总额。
  /// 物理删除（box 中已不存在）的标签 ID 跳过：既不进分子也不进分母，
  /// 避免其余标签占比失真；软删除标签仍可解析，由 UI 置灰展示。
  ///
  /// 时间复杂度：O(n·k + m log m)，n=交易数，k=单笔平均标签数，m=命中标签数
  ///
  /// @param transactions 当期交易列表
  /// @param isIncome true 统计收入标签，false 统计支出标签
  /// @return 按金额倒序排列的标签统计条目
  static List<TagStatEntry> calculateTagStats(
      List<Transaction> transactions, bool isIncome) {
    final amounts = <String, double>{};
    final counts = <String, int>{};

    for (final t in transactions) {
      if (t.isIncome != isIncome) continue;
      for (final tagId in t.tagIds) {
        // WHY: 物理删除的标签不可解析，跳过聚合防止金额"消失"进分母
        if (TagService.getTagById(tagId) == null) continue;
        amounts[tagId] = (amounts[tagId] ?? 0) + t.amount;
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }

    final entries = amounts.entries
        .map((e) => TagStatEntry(
              tagId: e.key,
              amount: e.value,
              count: counts[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return entries;
  }

  /// 计算趋势数据（近6个月）
  static Map<String, Map<String, double>> calculateTrendData(
      List<Transaction> allTransactions) {
    final trend = <String, Map<String, double>>{};
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);

      final monthTransactions = allTransactions
          .where(
              (t) => t.date.year == month.year && t.date.month == month.month)
          .toList();

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

  /// 计算趋势图表的最大Y值
  static double calculateMaxY(Map<String, Map<String, double>> trendData) {
    double maxValue = 0;
    for (final data in trendData.values) {
      for (final value in data.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue > 0 ? maxValue * 1.2 : 1000;
  }

  /// 格式化坐标轴数值
  static String formatAxisValue(double value) {
    if (value >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(0)}k';
    }
    return '¥${value.toStringAsFixed(0)}';
  }

  /// 获取分类颜色列表
  static List<Color> getCategoryColors(int count) {
    final baseColors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.primaryLight,
      AppTheme.neutral600,
    ];
    return List.generate(
        count, (index) => baseColors[index % baseColors.length]);
  }

  /// 格式化金额显示
  static String formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }

  /// 计算月度对比数据（指定月 vs 上月）
  /// @return Map 包含 'current' 和 'previous' 的收支数据
  static Map<String, Map<String, double>> calculateMonthComparison(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    return calculateMonthComparisonForMonth(
        allTransactions, now.year, now.month);
  }

  /// 计算指定月份的对比数据（当月 vs 上月）
  ///
  /// @param allTransactions 所有交易
  /// @param year 年份
  /// @param month 月份
  /// @return Map 包含 'current' 和 'previous' 的收支数据
  static Map<String, Map<String, double>> calculateMonthComparisonForMonth(
      List<Transaction> allTransactions, int year, int month) {
    final currentTransactions =
        getTransactionsForMonth(allTransactions, year, month);
    final previousMonthDate = DateTime(year, month - 1);
    final previousTransactions = getTransactionsForMonth(
        allTransactions, previousMonthDate.year, previousMonthDate.month);

    return {
      'current': {
        'income': calculateTotal(currentTransactions, true),
        'expense': calculateTotal(currentTransactions, false),
      },
      'previous': {
        'income': calculateTotal(previousTransactions, true),
        'expense': calculateTotal(previousTransactions, false),
      },
    };
  }

  /// 计算同比数据（本月 vs 去年同月）
  /// @return Map 包含 'current' 和 'yearAgo' 的收支数据
  static Map<String, Map<String, double>> calculateYearComparison(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    return calculateYearComparisonForMonth(
        allTransactions, now.year, now.month);
  }

  /// 计算指定月份的同比数据（当月 vs 去年同月）
  ///
  /// @param allTransactions 所有交易
  /// @param year 年份
  /// @param month 月份
  /// @return Map 包含 'current' 和 'yearAgo' 的收支数据
  static Map<String, Map<String, double>> calculateYearComparisonForMonth(
      List<Transaction> allTransactions, int year, int month) {
    final currentTransactions =
        getTransactionsForMonth(allTransactions, year, month);
    final yearAgoTransactions =
        getTransactionsForMonth(allTransactions, year - 1, month);

    return {
      'current': {
        'income': calculateTotal(currentTransactions, true),
        'expense': calculateTotal(currentTransactions, false),
      },
      'yearAgo': {
        'income': calculateTotal(yearAgoTransactions, true),
        'expense': calculateTotal(yearAgoTransactions, false),
      },
    };
  }

  /// 计算变化率
  /// @param current 当前值
  /// @param previous 对比值
  /// @return 变化率百分比，如果对比值为0则返回null
  static double? calculateChangeRate(double current, double previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /// 格式化变化率显示
  /// @param rate 变化率百分比
  /// @return 格式化后的字符串（如 "+12.5%" 或 "-8.3%"）
  static String formatChangeRate(double? rate) {
    if (rate == null) return '-';
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(1)}%';
  }

  /// 获取变化率颜色
  /// @param rate 变化率百分比
  /// @return 颜色（收入用绿色表示增长，支出用红色表示增长）
  static Color getChangeRateColor(double? rate, bool isIncome) {
    if (rate == null) return AppTheme.neutral400;
    // 收入增长是好事（绿色），支出增长是坏事（红色）
    if (isIncome) {
      return rate >= 0 ? AppTheme.successColor : AppTheme.errorColor;
    } else {
      return rate >= 0 ? AppTheme.errorColor : AppTheme.successColor;
    }
  }

  /// 计算本周对比数据（本周 vs 上周）
  static Map<String, Map<String, double>> calculateWeekComparison(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    // 获取本周一
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStartMidnight = DateTime(
        currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
    // 获取上周一开始
    final previousWeekStart =
        currentWeekStart.subtract(const Duration(days: 7));
    final previousWeekStartMidnight = DateTime(
        previousWeekStart.year, previousWeekStart.month, previousWeekStart.day);
    // 获取本周日结束
    final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));

    final currentTransactions = allTransactions
        .where((t) =>
            t.date.isAfter(currentWeekStartMidnight) &&
            t.date.isBefore(currentWeekEnd))
        .toList();

    final previousTransactions = allTransactions
        .where((t) =>
            t.date.isAfter(previousWeekStartMidnight) &&
            t.date.isBefore(currentWeekStartMidnight))
        .toList();

    return {
      'current': {
        'income': calculateTotal(currentTransactions, true),
        'expense': calculateTotal(currentTransactions, false),
      },
      'previous': {
        'income': calculateTotal(previousTransactions, true),
        'expense': calculateTotal(previousTransactions, false),
      },
    };
  }

  /// 获取 TOP N 支出分类排行
  /// @param transactions 交易列表
  /// @param n 排行数量
  /// @return 排序后的分类统计 Map
  static Map<String, double> getTopExpenseCategories(
      List<Transaction> transactions, int n) {
    final stats = calculateCategoryStats(transactions, false);
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }

  /// 获取 TOP N 收入分类排行
  /// @param transactions 交易列表
  /// @param n 排行数量
  /// @return 排序后的分类统计 Map
  static Map<String, double> getTopIncomeCategories(
      List<Transaction> transactions, int n) {
    final stats = calculateCategoryStats(transactions, true);
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }

  /// 获取 TOP N 账户交易金额排行
  /// @param transactions 交易列表
  /// @param n 排行数量
  /// @param isIncome 是否是收入
  /// @return 排序后的账户统计 Map
  static Map<String, double> getTopAccountsByAmount(
      List<Transaction> transactions, int n, bool isIncome) {
    final filtered = transactions.where((t) => t.isIncome == isIncome).toList();
    final stats = <String, double>{};
    for (final t in filtered) {
      stats[t.account] = (stats[t.account] ?? 0) + t.amount;
    }
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }

  /// 获取 TOP N 交易笔数最多的分类
  /// @param transactions 交易列表
  /// @param n 排行数量
  /// @param isIncome 是否是收入
  /// @return 排序后的分类统计 Map（value 为交易笔数）
  static Map<String, int> getTopCategoriesByCount(
      List<Transaction> transactions, int n, bool isIncome) {
    final filtered = transactions.where((t) => t.isIncome == isIncome).toList();
    final stats = <String, int>{};
    for (final t in filtered) {
      stats[t.category] = (stats[t.category] ?? 0) + 1;
    }
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }

  /// 获取 TOP N 消费商家排行（基于备注字段）
  /// @param transactions 交易列表
  /// @param n 排行数量
  /// @return 排序后的商家统计 Map
  static Map<String, double> getTopMerchants(
      List<Transaction> transactions, int n) {
    final expenseTransactions = transactions.where((t) => !t.isIncome).toList();
    final stats = <String, double>{};
    for (final t in expenseTransactions) {
      if (t.note != null && t.note!.isNotEmpty) {
        stats[t.note!] = (stats[t.note!] ?? 0) + t.amount;
      }
    }
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }
}

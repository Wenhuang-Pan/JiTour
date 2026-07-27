import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class StatsService {
  StatsService._();

  /// 获取当月的交易记录
  static List<Transaction> getMonthTransactions(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return allTransactions.where((t) => t.date.isAfter(startOfMonth)).toList();
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

  /// 计算月度对比数据（本月 vs 上月）
  /// @return Map 包含 'current' 和 'previous' 的收支数据
  static Map<String, Map<String, double>> calculateMonthComparison(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    final currentTransactions = allTransactions
        .where((t) =>
            t.date.year == currentMonth.year &&
            t.date.month == currentMonth.month)
        .toList();

    final previousTransactions = allTransactions
        .where((t) =>
            t.date.year == previousMonth.year &&
            t.date.month == previousMonth.month)
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

  /// 计算同比数据（本月 vs 去年同月）
  /// @return Map 包含 'current' 和 'yearAgo' 的收支数据
  static Map<String, Map<String, double>> calculateYearComparison(
      List<Transaction> allTransactions) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final yearAgoMonth = DateTime(now.year - 1, now.month, 1);

    final currentTransactions = allTransactions
        .where((t) =>
            t.date.year == currentMonth.year &&
            t.date.month == currentMonth.month)
        .toList();

    final yearAgoTransactions = allTransactions
        .where((t) =>
            t.date.year == yearAgoMonth.year &&
            t.date.month == yearAgoMonth.month)
        .toList();

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

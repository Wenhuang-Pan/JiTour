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
}

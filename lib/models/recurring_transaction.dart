import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'recurring_transaction.g.dart';

/// 定期交易周期类型
enum RecurringFrequency {
  daily, // 每天
  weekly, // 每周
  monthly, // 每月
  yearly, // 每年
}

/// 定期交易模型
@HiveType(typeId: 7)
class RecurringTransaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isIncome;

  @HiveField(3)
  Decimal amount;

  @HiveField(4)
  String category;

  @HiveField(5)
  String? subCategory;

  @HiveField(6)
  String account;

  @HiveField(7)
  String? account2;

  @HiveField(8)
  String currency;

  @HiveField(9)
  String frequency;

  @HiveField(10)
  DateTime startDate;

  @HiveField(11)
  DateTime? endDate;

  @HiveField(12)
  bool isEnabled;

  @HiveField(13)
  DateTime? lastExecutedDate;

  @HiveField(14)
  DateTime? nextExecutionDate;

  @HiveField(15)
  String? note;

  @HiveField(16)
  DateTime createdAt;

  @HiveField(17)
  DateTime updatedAt;

  /// 构造函数
  RecurringTransaction({
    required this.id,
    required this.name,
    required this.isIncome,
    required this.amount,
    required this.category,
    this.subCategory,
    required this.account,
    this.account2,
    this.currency = 'CNY',
    this.frequency = 'monthly',
    required this.startDate,
    this.endDate,
    this.isEnabled = true,
    this.lastExecutedDate,
    this.nextExecutionDate,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 获取周期枚举
  RecurringFrequency get frequencyEnum {
    switch (frequency) {
      case 'daily':
        return RecurringFrequency.daily;
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.monthly;
    }
  }

  /// 获取周期显示文本
  String get frequencyText {
    switch (frequencyEnum) {
      case RecurringFrequency.daily:
        return '每天';
      case RecurringFrequency.weekly:
        return '每周';
      case RecurringFrequency.monthly:
        return '每月';
      case RecurringFrequency.yearly:
        return '每年';
    }
  }

  /// 获取状态显示文本
  String get statusText {
    if (!isEnabled) return '已禁用';
    if (isExpired) return '已过期';
    return '运行中';
  }

  /// 获取状态颜色
  Color get statusColor {
    if (!isEnabled) return const Color(0xFF9E9E9E);
    if (isExpired) return const Color(0xFFF44336);
    return const Color(0xFF4CAF50);
  }

  /// 是否已过期
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// 是否应该执行（当前日期 >= 下次执行日期）
  bool get shouldExecute {
    if (!isEnabled) return false;
    if (isExpired) return false;
    if (nextExecutionDate == null) return false;
    return DateTime.now().isAfter(nextExecutionDate!) ||
        DateTime.now().isAtSameMomentAs(nextExecutionDate!);
  }

  /// 计算下一次执行日期
  /// @param fromDate 从该日期开始计算
  DateTime calculateNextExecutionDate({DateTime? fromDate}) {
    final baseDate = fromDate ?? lastExecutedDate ?? startDate;
    final now = DateTime.now();

    // 如果基准日期在未来，返回基准日期
    if (baseDate.isAfter(now)) {
      return baseDate;
    }

    DateTime nextDate;

    switch (frequencyEnum) {
      case RecurringFrequency.daily:
        nextDate = baseDate.add(const Duration(days: 1));
        break;
      case RecurringFrequency.weekly:
        nextDate = baseDate.add(const Duration(days: 7));
        break;
      case RecurringFrequency.monthly:
        // 处理月末情况
        try {
          nextDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
        } catch (_) {
          // 如果日期无效（如2月30日），取当月最后一天
          nextDate = DateTime(baseDate.year, baseDate.month + 2, 1)
              .subtract(const Duration(days: 1));
        }
        break;
      case RecurringFrequency.yearly:
        // 处理闰年2月29日的情况
        try {
          nextDate = DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
        } catch (_) {
          nextDate = DateTime(baseDate.year + 1, baseDate.month + 1, 1)
              .subtract(const Duration(days: 1));
        }
        break;
    }

    // 如果计算出的日期已过期，继续计算直到未来
    while (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now)) {
      switch (frequencyEnum) {
        case RecurringFrequency.daily:
          nextDate = nextDate.add(const Duration(days: 1));
          break;
        case RecurringFrequency.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case RecurringFrequency.monthly:
          try {
            nextDate =
                DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
          } catch (_) {
            nextDate = DateTime(nextDate.year, nextDate.month + 2, 1)
                .subtract(const Duration(days: 1));
          }
          break;
        case RecurringFrequency.yearly:
          try {
            nextDate =
                DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
          } catch (_) {
            nextDate = DateTime(nextDate.year + 1, nextDate.month + 1, 1)
                .subtract(const Duration(days: 1));
          }
          break;
      }
    }

    return nextDate;
  }

  /// 更新下次执行日期
  void updateNextExecutionDate() {
    nextExecutionDate = calculateNextExecutionDate();
    updatedAt = DateTime.now();
  }

  /// 标记为已执行
  void markAsExecuted() {
    lastExecutedDate = DateTime.now();
    updateNextExecutionDate();
    updatedAt = DateTime.now();
  }

  /// 获取下次执行日期的显示文本
  String get nextExecutionDateText {
    if (nextExecutionDate == null) return '未设置';

    final now = DateTime.now();
    final diff = nextExecutionDate!.difference(now).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff < 7) return '$diff天后';

    return '${nextExecutionDate!.month}月${nextExecutionDate!.day}日';
  }

  /// 获取金额显示文本
  String get amountText {
    final prefix = isIncome ? '+' : '-';
    return '$prefix${amount.toStringAsFixed(2)}';
  }

  /// 获取金额颜色
  Color get amountColor {
    return isIncome ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
  }

  RecurringTransaction copyWith({
    String? id,
    String? name,
    bool? isIncome,
    Decimal? amount,
    String? category,
    String? subCategory,
    String? account,
    String? account2,
    String? currency,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isEnabled,
    DateTime? lastExecutedDate,
    DateTime? nextExecutionDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      isIncome: isIncome ?? this.isIncome,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      account: account ?? this.account,
      account2: account2 ?? this.account2,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isEnabled: isEnabled ?? this.isEnabled,
      lastExecutedDate: lastExecutedDate ?? this.lastExecutedDate,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isIncome': isIncome,
      'amount': amount.toString(),
      'category': category,
      'subCategory': subCategory,
      'account': account,
      'account2': account2,
      'currency': currency,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isEnabled': isEnabled,
      'lastExecutedDate': lastExecutedDate?.toIso8601String(),
      'nextExecutionDate': nextExecutionDate?.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      name: json['name'] as String,
      isIncome: json['isIncome'] as bool? ?? false,
      amount: parseDecimal(json['amount']),
      category: json['category'] as String,
      subCategory: json['subCategory'] as String?,
      account: json['account'] as String,
      account2: json['account2'] as String?,
      currency: json['currency'] as String? ?? 'CNY',
      frequency: json['frequency'] as String? ?? 'monthly',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastExecutedDate: json['lastExecutedDate'] != null
          ? DateTime.parse(json['lastExecutedDate'] as String)
          : null,
      nextExecutionDate: json['nextExecutionDate'] != null
          ? DateTime.parse(json['nextExecutionDate'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

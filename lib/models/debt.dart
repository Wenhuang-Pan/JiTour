import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'debt.g.dart';

/// 负债状态枚举
enum DebtStatus {
  pending, // 待还款
  paying, // 还款中
  completed, // 已还清
}

/// 负债模型
@HiveType(typeId: 6)
class Debt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String creditor;

  @HiveField(3)
  Decimal totalAmount;

  @HiveField(4)
  Decimal paidAmount;

  @HiveField(5)
  double interestRate;

  @HiveField(6)
  DateTime dueDate;

  @HiveField(7)
  String status;

  @HiveField(8)
  String? note;

  @HiveField(9)
  String iconName;

  @HiveField(10)
  int colorValue;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  Debt({
    required this.id,
    required this.name,
    required this.creditor,
    required this.totalAmount,
    Decimal? paidAmount,
    this.interestRate = 0.0,
    required this.dueDate,
    this.status = 'pending',
    this.note,
    this.iconName = 'account_balance',
    this.colorValue = 0xFF6366F1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : paidAmount = paidAmount ?? Decimal.zero,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 获取未还金额
  Decimal get remainingAmount => totalAmount - paidAmount;

  /// 获取还款进度百分比
  double get progressPercent => totalAmount > Decimal.zero
      ? (paidAmount / totalAmount).toDouble() * 100
      : 0;

  /// 是否已还清
  bool get isCompleted => status == 'completed' || paidAmount >= totalAmount;

  /// 获取负债状态枚举
  DebtStatus get debtStatus {
    if (isCompleted) return DebtStatus.completed;
    if (paidAmount > Decimal.zero) return DebtStatus.paying;
    return DebtStatus.pending;
  }

  /// 设置负债状态
  void setStatus(DebtStatus status) {
    switch (status) {
      case DebtStatus.pending:
        this.status = 'pending';
        break;
      case DebtStatus.paying:
        this.status = 'paying';
        break;
      case DebtStatus.completed:
        this.status = 'completed';
        paidAmount = totalAmount;
        break;
    }
    updatedAt = DateTime.now();
  }

  /// 还款
  /// @param amount 还款金额
  void pay(Decimal amount) {
    if (amount <= Decimal.zero) return;
    // WHY: Decimal 无 clamp 方法，用比较实现上下界约束
    var newPaid = paidAmount + amount;
    if (newPaid < Decimal.zero) newPaid = Decimal.zero;
    if (newPaid > totalAmount) newPaid = totalAmount;
    paidAmount = newPaid;
    if (paidAmount >= totalAmount) {
      status = 'completed';
    } else if (paidAmount > Decimal.zero) {
      status = 'paying';
    }
    updatedAt = DateTime.now();
  }

  /// 获取状态显示文本
  String get statusText {
    switch (debtStatus) {
      case DebtStatus.pending:
        return '待还款';
      case DebtStatus.paying:
        return '还款中';
      case DebtStatus.completed:
        return '已还清';
    }
  }

  /// 获取状态颜色
  Color get statusColor {
    switch (debtStatus) {
      case DebtStatus.pending:
        return const Color(0xFFFF9800);
      case DebtStatus.paying:
        return const Color(0xFF6366F1);
      case DebtStatus.completed:
        return const Color(0xFF4CAF50);
    }
  }

  /// 获取剩余天数
  int? get remainingDays {
    if (isCompleted) return null;
    final now = DateTime.now();
    final diff = dueDate.difference(now).inDays;
    return diff;
  }

  /// 是否逾期
  bool get isOverdue {
    if (isCompleted) return false;
    return DateTime.now().isAfter(dueDate);
  }

  /// 计算利息
  /// @param days 天数
  /// @return 利息金额
  double calculateInterest(int days) {
    // WHY: interestRate 是百分比 double，与 Decimal 总额混合运算时先转 Decimal
    final rate = Decimal.parse(interestRate.toString());
    // WHY: 先算乘法（Decimal*Decimal=Decimal），最后一次除法返回 Rational 再转 double
    final interest = (totalAmount *
            rate *
            Decimal.fromInt(days) /
            (Decimal.fromInt(100) * Decimal.fromInt(365)))
        .toDouble();
    return interest;
  }

  Debt copyWith({
    String? id,
    String? name,
    String? creditor,
    Decimal? totalAmount,
    Decimal? paidAmount,
    double? interestRate,
    DateTime? dueDate,
    String? status,
    String? note,
    String? iconName,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      creditor: creditor ?? this.creditor,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      note: note ?? this.note,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creditor': creditor,
      'totalAmount': totalAmount.toString(),
      'paidAmount': paidAmount.toString(),
      'interestRate': interestRate,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'note': note,
      'iconName': iconName,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      name: json['name'] as String,
      creditor: json['creditor'] as String,
      totalAmount: parseDecimal(json['totalAmount']),
      paidAmount: parseDecimal(json['paidAmount']),
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String? ?? 'pending',
      note: json['note'] as String?,
      iconName: json['iconName'] as String? ?? 'account_balance',
      colorValue: json['colorValue'] as int? ?? 0xFF6366F1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

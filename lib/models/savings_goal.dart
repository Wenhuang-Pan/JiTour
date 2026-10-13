import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'savings_goal.g.dart';

@HiveType(typeId: 5)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  Decimal targetAmount;

  @HiveField(4)
  Decimal currentAmount;

  @HiveField(5)
  String iconName;

  @HiveField(6)
  int colorValue;

  @HiveField(7)
  DateTime startDate;

  @HiveField(8)
  DateTime? targetDate;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  String? accountId;

  SavingsGoal({
    required this.id,
    required this.name,
    this.description,
    required this.targetAmount,
    Decimal? currentAmount,
    required this.iconName,
    required this.colorValue,
    required this.startDate,
    this.targetDate,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.accountId,
  })  : currentAmount = currentAmount ?? Decimal.zero,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 进度百分比 (0-100)
  double get progressPercent {
    if (targetAmount <= Decimal.zero) return 0;
    // WHY: Decimal 除法返回 Rational，转 double 供 UI 进度条使用
    final percent = (currentAmount / targetAmount).toDouble() * 100;
    return percent > 100 ? 100 : percent;
  }

  // 距离目标还差多少
  Decimal get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining > Decimal.zero ? remaining : Decimal.zero;
  }

  // 是否已完成
  bool get isGoalReached => currentAmount >= targetAmount;

  // 预计完成天数（根据当前进度）
  int? get estimatedDaysToComplete {
    if (isCompleted) return 0;
    if (currentAmount <= Decimal.zero) return null;

    final daysPassed = DateTime.now().difference(startDate).inDays;
    if (daysPassed <= 0) return null;

    final dailyProgress =
        (currentAmount / Decimal.fromInt(daysPassed)).toDouble();
    if (dailyProgress <= 0) return null;

    return (remainingAmount.toDouble() / dailyProgress).ceil();
  }

  // 距离目标日期天数
  int? get daysToTargetDate {
    if (targetDate == null) return null;
    final days = targetDate!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  // 是否逾期
  bool get isOverdue {
    if (targetDate == null) return false;
    if (isCompleted) return false;
    return DateTime.now().isAfter(targetDate!);
  }

  // 更新时间戳
  void updateTimestamp() {
    updatedAt = DateTime.now();
  }

  // 添加存款
  void addSavings(Decimal amount) {
    currentAmount += amount;
    if (currentAmount >= targetAmount) {
      currentAmount = targetAmount;
      isCompleted = true;
    }
    updateTimestamp();
    save();
  }

  // 提取存款
  void withdrawSavings(Decimal amount) {
    currentAmount -= amount;
    if (currentAmount < Decimal.zero) currentAmount = Decimal.zero;
    isCompleted = false;
    updateTimestamp();
    save();
  }

  // 重置进度
  void reset() {
    currentAmount = Decimal.zero;
    isCompleted = false;
    updateTimestamp();
    save();
  }

  // 复制目标
  SavingsGoal copyWith({
    String? name,
    String? description,
    Decimal? targetAmount,
    String? iconName,
    int? colorValue,
    DateTime? startDate,
    DateTime? targetDate,
    String? accountId,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      accountId: accountId ?? this.accountId,
    );
  }
}

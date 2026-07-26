import 'package:hive/hive.dart';

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
  double targetAmount;

  @HiveField(4)
  double currentAmount;

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
    this.currentAmount = 0.0,
    required this.iconName,
    required this.colorValue,
    required this.startDate,
    this.targetDate,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.accountId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 进度百分比 (0-100)
  double get progressPercent {
    if (targetAmount <= 0) return 0;
    final percent = (currentAmount / targetAmount) * 100;
    return percent > 100 ? 100 : percent;
  }

  // 距离目标还差多少
  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining > 0 ? remaining : 0;
  }

  // 是否已完成
  bool get isGoalReached => currentAmount >= targetAmount;

  // 预计完成天数（根据当前进度）
  int? get estimatedDaysToComplete {
    if (isCompleted) return 0;
    if (currentAmount <= 0) return null;

    final daysPassed = DateTime.now().difference(startDate).inDays;
    if (daysPassed <= 0) return null;

    final dailyProgress = currentAmount / daysPassed;
    if (dailyProgress <= 0) return null;

    return (remainingAmount / dailyProgress).ceil();
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
  void addSavings(double amount) {
    currentAmount += amount;
    if (currentAmount >= targetAmount) {
      currentAmount = targetAmount;
      isCompleted = true;
    }
    updateTimestamp();
    save();
  }

  // 提取存款
  void withdrawSavings(double amount) {
    currentAmount -= amount;
    if (currentAmount < 0) currentAmount = 0;
    isCompleted = false;
    updateTimestamp();
    save();
  }

  // 重置进度
  void reset() {
    currentAmount = 0;
    isCompleted = false;
    updateTimestamp();
    save();
  }

  // 复制目标
  SavingsGoal copyWith({
    String? name,
    String? description,
    double? targetAmount,
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

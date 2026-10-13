import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:decimal/decimal.dart';
import '../models/savings_goal.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_util.dart';

class SavingsGoalService {
  static const String _boxName = 'savings_goals';
  static Box<SavingsGoal>? _box;

  // 初始化服务
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SavingsGoalAdapter());
    }
    _box = await Hive.openBox<SavingsGoal>(_boxName);
  }

  // 获取 Box
  static Box<SavingsGoal> get box {
    if (_box == null) {
      throw Exception('SavingsGoalService not initialized. Call init() first.');
    }
    return _box!;
  }

  // 获取所有目标
  static List<SavingsGoal> getAllGoals() {
    return box.values.toList();
  }

  // 获取活跃目标（按进度排序）
  static List<SavingsGoal> getActiveGoals() {
    final goals = getAllGoals().where((g) => !g.isCompleted).toList();
    goals.sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    return goals;
  }

  // 获取已完成目标
  static List<SavingsGoal> getCompletedGoals() {
    return getAllGoals().where((g) => g.isCompleted).toList();
  }

  // 获取即将到期的目标（7天内）
  static List<SavingsGoal> getUpcomingGoals() {
    return getActiveGoals().where((g) {
      if (g.targetDate == null) return false;
      final daysLeft = g.daysToTargetDate ?? 0;
      return daysLeft > 0 && daysLeft <= 7;
    }).toList();
  }

  // 获取逾期目标
  static List<SavingsGoal> getOverdueGoals() {
    return getAllGoals().where((g) => g.isOverdue).toList();
  }

  // 根据 ID 获取目标
  static SavingsGoal? getGoalById(String id) {
    return box.get(id);
  }

  // 创建新目标
  static Future<SavingsGoal> createGoal({
    required String name,
    String? description,
    required Decimal targetAmount,
    required String iconName,
    required int colorValue,
    DateTime? startDate,
    DateTime? targetDate,
    String? accountId,
  }) async {
    final goal = SavingsGoal(
      id: UuidUtil.generate(),
      name: name,
      description: description,
      targetAmount: targetAmount,
      iconName: iconName,
      colorValue: colorValue,
      startDate: startDate ?? DateTime.now(),
      targetDate: targetDate,
      accountId: accountId,
    );

    await box.put(goal.id, goal);
    return goal;
  }

  // 更新目标
  static Future<void> updateGoal(SavingsGoal goal) async {
    goal.updateTimestamp();
    await goal.save();
  }

  // 删除目标
  static Future<void> deleteGoal(String id) async {
    await box.delete(id);
  }

  // 添加存款
  static Future<void> addSavings(String goalId, Decimal amount) async {
    final goal = getGoalById(goalId);
    if (goal != null) {
      goal.addSavings(amount);
    }
  }

  // 提取存款
  static Future<void> withdrawSavings(String goalId, Decimal amount) async {
    final goal = getGoalById(goalId);
    if (goal != null) {
      goal.withdrawSavings(amount);
    }
  }

  // 重置目标
  static Future<void> resetGoal(String goalId) async {
    final goal = getGoalById(goalId);
    if (goal != null) {
      goal.reset();
    }
  }

  // 获取总目标金额
  static Decimal getTotalTargetAmount() {
    return getActiveGoals()
        .fold(Decimal.zero, (sum, g) => sum + g.targetAmount);
  }

  // 获取总当前金额
  static Decimal getTotalCurrentAmount() {
    return getActiveGoals()
        .fold(Decimal.zero, (sum, g) => sum + g.currentAmount);
  }

  // 获取总进度
  static double getTotalProgressPercent() {
    final total = getTotalTargetAmount();
    if (total <= Decimal.zero) return 0;
    // WHY: Decimal 除法返回 Rational，转 double 供 UI 进度条使用
    return (getTotalCurrentAmount() / total).toDouble() * 100;
  }

  // 获取默认图标列表
  static List<String> getDefaultIcons() {
    return [
      'savings_rounded',
      'flight_rounded',
      'home_rounded',
      'directions_car_rounded',
      'shopping_bag_rounded',
      'school_rounded',
      'favorite_rounded',
      'card_giftcard_rounded',
      'laptop_rounded',
      'phone_android_rounded',
      'restaurant_rounded',
      'local_cafe_rounded',
      'sports_esports_rounded',
      'movie_rounded',
      'fitness_center_rounded',
      'spa_rounded',
      'pets_rounded',
      'child_care_rounded',
      'castle_rounded',
      'beach_access_rounded',
    ];
  }

  // 获取默认颜色列表
  static List<int> getDefaultColors() {
    return [
      AppTheme.primaryColor.value,
      const Color(0xFFE91E63).value,
      const Color(0xFFFF9800).value,
      const Color(0xFF4CAF50).value,
      const Color(0xFF9C27B0).value,
      const Color(0xFFF44336).value,
      const Color(0xFF2196F3).value,
      const Color(0xFFFF5722).value,
      const Color(0xFF00BCD4).value,
      const Color(0xFF607D8B).value,
      const Color(0xFF673AB7).value,
      const Color(0xFF8BC34A).value,
      const Color(0xFFCDDC39).value,
      const Color(0xFF009688).value,
      const Color(0xFF795548).value,
    ];
  }
}

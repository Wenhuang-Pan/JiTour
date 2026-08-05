import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import 'database_service.dart';

/// 分类定义辅助类，用于初始化默认分类数据
class _CategoryDef {
  final String name;
  final IconData icon;
  final String color;

  const _CategoryDef(this.name, this.icon, this.color);

  /// WHY: 使用分类中文名作为 iconName，
  /// 因为 IconLibrary.getIconByName() 通过中文名在 expenseCategoryNames
  /// /incomeCategoryNames 列表中查找对应图标。
  /// 不能使用 icon.toString()，因为 IconData.toString() 返回的是
  /// "IconData(U+0E25C)" 格式，无法被 getIconByName 识别。
  String get iconName => name;
}

class CategoryService {
  static const _uuid = Uuid();

  static Box<Category> get _box => DatabaseService.categories;

  // 初始化分类服务
  static Future<void> init() async {
    // 如果是第一次使用，创建默认分类
    if (_box.isEmpty) {
      await _createDefaultCategories();
    } else {
      // 迁移旧版本分类数据
      await migrateCategories();
    }
  }

  // 创建默认分类
  static Future<void> _createDefaultCategories() async {
    // 支出分类（精简版，参考主流记账App分类体系）
    final defaultExpenseCategories = [
      _CategoryDef('餐饮', Icons.restaurant_rounded, '#F59E0B'),
      _CategoryDef('零食', Icons.icecream_rounded, '#FB923C'),
      _CategoryDef('水果', Icons.shopping_basket_rounded, '#F97316'),
      _CategoryDef('交通', Icons.directions_bus_rounded, '#3B82F6'),
      _CategoryDef('购物', Icons.shopping_bag_rounded, '#8B5CF6'),
      _CategoryDef('居住购房', Icons.apartment_rounded, '#78350F'),
      _CategoryDef('教育', Icons.school_rounded, '#6366F1'),
      _CategoryDef('日用杂', Icons.kitchen_rounded, '#84CC16'),
      _CategoryDef('医疗', Icons.medical_services_rounded, '#EF4444'),
      _CategoryDef('红包', Icons.card_giftcard_rounded, '#EC4899'),
      _CategoryDef('汽车/加油', Icons.local_gas_station_rounded, '#3B82F6'),
      _CategoryDef('请客送礼', Icons.redeem_rounded, '#F472B6'),
      _CategoryDef('运动', Icons.fitness_center_rounded, '#10B981'),
      _CategoryDef('其他', Icons.more_horiz_rounded, '#6B7280'),
      _CategoryDef('水电煤', Icons.electrical_services_rounded, '#06B6D4'),
      _CategoryDef('房租', Icons.house_rounded, '#A16207'),
      _CategoryDef('彩票', Icons.casino_rounded, '#F59E0B'),
      _CategoryDef('充电', Icons.electric_bolt_rounded, '#FACC15'),
      _CategoryDef('过路费', Icons.toll_rounded, '#78716C'),
      _CategoryDef('停车费', Icons.local_parking_rounded, '#14B8A6'),
      _CategoryDef('快递', Icons.local_shipping_rounded, '#0EA5E9'),
      _CategoryDef('鲜花', Icons.local_florist_rounded, '#F43F5E'),
    ];

    // 收入分类
    final defaultIncomeCategories = [
      _CategoryDef('工资', Icons.payments_rounded, '#10B981'),
      _CategoryDef('奖金', Icons.emoji_events_rounded, '#F59E0B'),
      _CategoryDef('投资', Icons.trending_up_rounded, '#3B82F6'),
      _CategoryDef('兼职', Icons.work_rounded, '#6366F1'),
      _CategoryDef('礼金', Icons.card_giftcard_rounded, '#EC4899'),
      _CategoryDef('补贴', Icons.support_agent_rounded, '#06B6D4'),
      _CategoryDef('其他收入', Icons.add_business_rounded, '#6B7280'),
    ];

    // 创建支出分类
    for (final def in defaultExpenseCategories) {
      final id = _uuid.v4();
      await _box.put(
        id,
        Category.createExpense(
          id: id,
          name: def.name,
          iconName: def.iconName,
          color: def.color,
        ),
      );
    }

    // 创建收入分类
    for (final def in defaultIncomeCategories) {
      final id = _uuid.v4();
      await _box.put(
        id,
        Category.createIncome(
          id: id,
          name: def.name,
          iconName: def.iconName,
          color: def.color,
        ),
      );
    }
  }

  // 获取所有收入分类
  static List<Category> getIncomeCategories() {
    return _box.values
        .where((category) => category.isIncome && !category.isDeleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // 获取所有支出分类
  static List<Category> getExpenseCategories() {
    return _box.values
        .where((category) => !category.isIncome && !category.isDeleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 迁移旧版本分类数据到新的精简分类体系
  static Future<void> migrateCategories() async {
    final allCategories = _box.values.toList();

    // WHY: 修复旧版本中 iconName 存储 IconData.toString() 乱码的问题，
    // 将 iconName 设置为分类中文名，使 getIconByName 能正确查找图标。
    for (final category in allCategories) {
      if (category.iconName.startsWith('IconData(') ||
          category.iconName.isEmpty ||
          category.iconName != category.name) {
        final updated = category.copyWith(
          iconName: category.name,
          name: category.name,
        );
        await _box.put(category.id, updated);
      }
    }

    final oldExpenseNames = [
      '外卖',
      '加油',
      '日用品',
      '娱乐',
      '游戏',
      '住房',
      '水电',
      '药品',
      '通讯',
      '旅行',
      '打车',
      '洗衣',
      '健身',
      '美容',
      '停车',
    ];
    final newExpenseNames = [
      '零食',
      '水果',
      '居住购房',
      '教育',
      '日用杂',
      '红包',
      '汽车/加油',
      '请客送礼',
      '运动',
      '其他',
      '水电煤',
      '房租',
      '彩票',
      '充电',
      '过路费',
      '停车费',
      '快递',
      '鲜花',
    ];

    for (final category in allCategories) {
      if (category.isIncome) continue;
      if (!oldExpenseNames.contains(category.name)) continue;

      String newName;
      String newColor;
      switch (category.name) {
        case '外卖':
          newName = '零食';
          newColor = '#FB923C';
          break;
        case '加油':
          newName = '汽车/加油';
          newColor = '#3B82F6';
          break;
        case '日用品':
          newName = '日用杂';
          newColor = '#84CC16';
          break;
        case '娱乐':
        case '游戏':
          newName = '运动';
          newColor = '#10B981';
          break;
        case '住房':
          newName = '居住购房';
          newColor = '#78350F';
          break;
        case '水电':
          newName = '水电煤';
          newColor = '#06B6D4';
          break;
        case '药品':
          newName = '医疗';
          newColor = '#EF4444';
          break;
        case '通讯':
          newName = '其他';
          newColor = '#6B7280';
          break;
        case '旅行':
          newName = '其他';
          newColor = '#6B7280';
          break;
        case '打车':
          newName = '交通';
          newColor = '#3B82F6';
          break;
        case '洗衣':
          newName = '日用杂';
          newColor = '#84CC16';
          break;
        case '健身':
          newName = '运动';
          newColor = '#10B981';
          break;
        case '美容':
          newName = '请客送礼';
          newColor = '#F472B6';
          break;
        case '停车':
          newName = '停车费';
          newColor = '#14B8A6';
          break;
        default:
          newName = '其他';
          newColor = '#6B7280';
      }

      final existingCategory = _box.values.firstWhere(
        (c) => c.name == newName && !c.isDeleted && !c.isIncome,
        orElse: () => Category(
          id: _uuid.v4(),
          name: newName,
          iconName: _getMigrationIcon(newName),
          color: newColor,
          isIncome: false,
          createdAt: DateTime.now(),
        ),
      );

      if (existingCategory.id == category.id) {
        await _box.put(category.id, category);
      } else {
        category.softDelete();
        await _box.put(category.id, category);
      }
    }

    // 新增的分类如果不存在则创建
    final existingNames = getExpenseCategories().map((c) => c.name).toSet();
    final allExistingNames = _box.values.map((c) => c.name).toSet();
    final needToCreate = newExpenseNames
        .where(
            (n) => !existingNames.contains(n) && !allExistingNames.contains(n))
        .toList();

    for (final name in needToCreate) {
      final id = _uuid.v4();
      await _box.put(
        id,
        Category.createExpense(
          id: id,
          name: name,
          iconName: _getMigrationIcon(name),
          color: _getMigrationColor(name),
        ),
      );
    }
  }

  static String _getMigrationIcon(String name) {
    switch (name) {
      case '零食':
        return 'icecream_rounded';
      case '水果':
        return 'shopping_basket_rounded';
      case '居住购房':
        return 'apartment_rounded';
      case '日用杂':
        return 'kitchen_rounded';
      case '红包':
        return 'card_giftcard_rounded';
      case '汽车/加油':
        return 'local_gas_station_rounded';
      case '请客送礼':
        return 'redeem_rounded';
      case '运动':
        return 'fitness_center_rounded';
      case '其他':
        return 'more_horiz_rounded';
      case '水电煤':
        return 'electrical_services_rounded';
      case '房租':
        return 'house_rounded';
      case '彩票':
        return 'casino_rounded';
      case '充电':
        return 'electric_bolt_rounded';
      case '过路费':
        return 'toll_rounded';
      case '停车费':
        return 'local_parking_rounded';
      case '快递':
        return 'local_shipping_rounded';
      case '鲜花':
        return 'local_florist_rounded';
      default:
        return 'category_rounded';
    }
  }

  static String _getMigrationColor(String name) {
    switch (name) {
      case '零食':
        return '#FB923C';
      case '水果':
        return '#F97316';
      case '居住购房':
        return '#78350F';
      case '日用杂':
        return '#84CC16';
      case '红包':
        return '#EC4899';
      case '汽车/加油':
        return '#3B82F6';
      case '请客送礼':
        return '#F472B6';
      case '运动':
        return '#10B981';
      case '其他':
        return '#6B7280';
      case '水电煤':
        return '#06B6D4';
      case '房租':
        return '#A16207';
      case '彩票':
        return '#F59E0B';
      case '充电':
        return '#FACC15';
      case '过路费':
        return '#78716C';
      case '停车费':
        return '#14B8A6';
      case '快递':
        return '#0EA5E9';
      case '鲜花':
        return '#F43F5E';
      default:
        return '#6B7280';
    }
  }

  // 根据ID获取分类
  static Category? getCategoryById(String id) {
    return _box.get(id);
  }

  // 根据名称获取分类
  static Category? getCategoryByName(String name, bool isIncome) {
    try {
      return _box.values.firstWhere(
        (category) =>
            category.name == name &&
            category.isIncome == isIncome &&
            !category.isDeleted,
      );
    } catch (e) {
      return null;
    }
  }

  // 添加分类
  static Future<void> addCategory(Category category) async {
    await _box.put(category.id, category);
  }

  // 更新分类
  static Future<void> updateCategory(Category category) async {
    await _box.put(category.id, category);
  }

  // 删除分类（软删除）
  static Future<void> deleteCategory(String id) async {
    final category = _box.get(id);
    if (category != null) {
      category.softDelete();
      await _box.put(id, category);
    }
  }

  // 恢复分类
  static Future<void> restoreCategory(String id) async {
    final category = _box.get(id);
    if (category != null) {
      category.restore();
      await _box.put(id, category);
    }
  }

  // 永久删除分类
  static Future<void> permanentlyDeleteCategory(String id) async {
    await _box.delete(id);
  }

  // 获取已删除的分类
  static List<Category> getDeletedCategories() {
    return _box.values.where((category) => category.isDeleted).toList()
      ..sort((a, b) => (b.deletedAt ?? DateTime.now())
          .compareTo(a.deletedAt ?? DateTime.now()));
  }

  // 清空所有分类
  static Future<void> clearAll() async {
    await _box.clear();
  }

  // 获取分类使用次数
  static int getCategoryUsageCount(String categoryId) {
    final category = _box.get(categoryId);
    if (category == null) return 0;
    return DatabaseService.transactions.values
        .where((transaction) =>
            transaction.category == category.name && !transaction.isDeleted)
        .length;
  }

  // 检查分类名称是否已存在
  static bool isCategoryNameExists(String name, bool isIncome,
      {String? excludeId}) {
    return _box.values.any((category) =>
        category.name == name &&
        category.isIncome == isIncome &&
        !category.isDeleted &&
        (excludeId == null || category.id != excludeId));
  }

  // 获取热门分类（使用次数最多的）
  static List<Category> getPopularCategories({int limit = 5, bool? isIncome}) {
    final categories = isIncome == null
        ? _box.values.where((c) => !c.isDeleted).toList()
        : _box.values
            .where((c) => c.isIncome == isIncome && !c.isDeleted)
            .toList();

    final categoryUsage = <String, int>{};
    for (final category in categories) {
      categoryUsage[category.id] = getCategoryUsageCount(category.id);
    }

    categories.sort((a, b) =>
        (categoryUsage[b.id] ?? 0).compareTo(categoryUsage[a.id] ?? 0));

    return categories.take(limit).toList();
  }

  // 导出所有分类
  static List<Map<String, dynamic>> exportCategories() {
    return _box.values
        .where((category) => !category.isDeleted)
        .map((category) => category.toMap())
        .toList();
  }

  // 导入分类
  static Future<void> importCategories(List<Map<String, dynamic>> data) async {
    for (final item in data) {
      try {
        final category = Category.fromMap(item);
        // 检查是否已存在同名分类
        if (!isCategoryNameExists(category.name, category.isIncome)) {
          await addCategory(category);
        }
      } catch (e) {
        // 跳过无效数据
        continue;
      }
    }
  }

  // 获取分类统计信息
  static Map<String, dynamic> getCategoryStatistics() {
    final incomeCategories = getIncomeCategories();
    final expenseCategories = getExpenseCategories();

    return {
      'totalIncomeCategories': incomeCategories.length,
      'totalExpenseCategories': expenseCategories.length,
      'totalCategories': incomeCategories.length + expenseCategories.length,
      'deletedCategories': getDeletedCategories().length,
    };
  }
}

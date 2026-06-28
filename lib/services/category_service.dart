import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class CategoryService {
  static const _uuid = Uuid();
  static const String _boxName = 'categories';

  static Box<Category> get _box => Hive.box<Category>(_boxName);

  // 初始化分类服务
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<Category>(_boxName);
      }
    } catch (e) {
      // 如果box不存在，创建它
      await Hive.openBox<Category>(_boxName);
    }
    
    // 如果是第一次使用，创建默认分类
    if (_box.isEmpty) {
      await _createDefaultCategories();
    }
  }

  // 创建默认分类
  static Future<void> _createDefaultCategories() async {
    // 使用IconLibrary中的标准分类名称
    final defaultIncomeCategories = [
      '工资',
      '奖金',
      '投资',
      '理财',
      '兼职',
      '礼金',
      '补贴',
    ];

    final defaultExpenseCategories = [
      '餐饮',
      '外卖',
      '交通',
      '加油',
      '购物',
      '日用品',
      '娱乐',
      '游戏',
      '住房',
      '水电',
      '医疗',
      '药品',
      '教育',
      '通讯',
      '旅行',
      '停车',
      '打车',
      '洗衣',
      '健身',
      '美容',
    ];

    // 创建收入分类
    for (final name in defaultIncomeCategories) {
      await _box.put(
        _uuid.v4(),
        Category.createIncome(
          id: _uuid.v4(),
          name: name,
          iconName: name, // 使用分类名称作为图标标识
          color: '#10B981',
        ),
      );
    }

    // 创建支出分类
    for (final name in defaultExpenseCategories) {
      // 为不同分类设置不同颜色
      String color;
      switch (name) {
        case '餐饮':
        case '外卖':
          color = '#F59E0B'; // 橙色 - 餐饮
          break;
        case '交通':
        case '加油':
          color = '#3B82F6'; // 蓝色 - 交通
          break;
        case '购物':
        case '日用品':
          color = '#8B5CF6'; // 紫色 - 购物
          break;
        case '娱乐':
        case '游戏':
          color = '#EC4899'; // 粉色 - 娱乐
          break;
        case '住房':
        case '水电':
          color = '#78350F'; // 棕色 - 住房
          break;
        case '医疗':
        case '药品':
          color = '#EF4444'; // 红色 - 医疗
          break;
        case '教育':
          color = '#3B82F6'; // 蓝色 - 教育
          break;
        case '通讯':
          color = '#06B6D4'; // 青色 - 通讯
          break;
        case '旅行':
        case '停车':
        case '打车':
          color = '#14B8A6'; // 深青色 - 旅行
          break;
        case '洗衣':
        case '健身':
        case '美容':
          color = '#10B981'; // 绿色 - 生活
          break;
        default:
          color = '#6B7280'; // 灰色 - 其他
      }

      await _box.put(
        _uuid.v4(),
        Category.createExpense(
          id: _uuid.v4(),
          name: name,
          iconName: name, // 使用分类名称作为图标标识
          color: color,
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

  // 根据ID获取分类
  static Category? getCategoryById(String id) {
    return _box.get(id);
  }

  // 根据名称获取分类
  static Category? getCategoryByName(String name, bool isIncome) {
    try {
      return _box.values.firstWhere(
        (category) => category.name == name && 
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
    return _box.values
        .where((category) => category.isDeleted)
        .toList()
      ..sort((a, b) => (b.deletedAt ?? DateTime.now())
          .compareTo(a.deletedAt ?? DateTime.now()));
  }

  // 清空所有分类
  static Future<void> clearAll() async {
    await _box.clear();
  }

  // 获取分类使用次数
  static int getCategoryUsageCount(String categoryId) {
    return DatabaseService.transactions.values
        .where((transaction) => 
            transaction.category == categoryId && 
            !transaction.isDeleted)
        .length;
  }

  // 检查分类名称是否已存在
  static bool isCategoryNameExists(String name, bool isIncome, {String? excludeId}) {
    return _box.values.any((category) =>
        category.name == name &&
        category.isIncome == isIncome &&
        !category.isDeleted &&
        (excludeId == null || category.id != excludeId)
    );
  }

  // 获取热门分类（使用次数最多的）
  static List<Category> getPopularCategories({int limit = 5, bool? isIncome}) {
    final categories = isIncome == null
        ? _box.values.where((c) => !c.isDeleted).toList()
        : _box.values.where((c) => c.isIncome == isIncome && !c.isDeleted).toList();

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

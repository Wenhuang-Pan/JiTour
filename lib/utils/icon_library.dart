import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

// 适合记账应用的Material Symbols图标库
// 图标名称 = 分类名称，使用固定的中文命名
class IconLibrary {
  // ========== 收入图标 ==========
  // 收入图标对应16个常用收入分类
  static const List<IconData> incomeIcons = [
    Symbols.payments,              // 工资
    Symbols.account_balance,       // 奖金
    Symbols.trending_up,           // 投资
    Symbols.savings,               // 理财
    Icons.wallet,                  // 兼职
    Icons.card_giftcard,            // 礼金
    Icons.business_center,         // 补贴
    Icons.celebration,             // 分红
    Icons.home,                     // 租金
    Icons.electric_car,             // 报销
    Icons.sports_esports,          // 佣金
    Icons.diamond,                  // 理财2
    Icons.monetization_on,          // 分成
    Icons.currency_yuan,            // 兑换
    Icons.attach_money,             // 其他收入
    Icons.favorite,                 // 赞助
  ];

  // 收入分类名称（符合记账习惯，16个）
  static const List<String> incomeCategoryNames = [
    '工资',
    '奖金',
    '投资',
    '理财',
    '兼职',
    '礼金',
    '补贴',
    '分红',
    '租金',
    '报销',
    '佣金',
    '理财收益',
    '分成',
    '兑换',
    '其他收入',
    '赞助',
  ];

  // ========== 支出图标 ==========
  // 支出图标对应最常用的支出分类
  static const List<IconData> expenseIcons = [
    Symbols.restaurant,             // 餐饮
    Icons.local_dining,             // 外卖
    Symbols.directions_car,         // 交通
    Icons.local_gas_station,       // 加油
    Icons.train,                    // 公交
    Icons.subway,                   // 地铁
    Symbols.shopping_bag,           // 购物
    Icons.shopping_cart,            // 日用品
    Icons.checkroom,                // 服装
    Symbols.movie,                  // 娱乐
    Icons.sports_esports,           // 游戏
    Icons.local_cafe,               // 咖啡
    Icons.local_bar,                // 聚会
    Symbols.home,                   // 住房
    Icons.kitchen,                  // 水电
    Icons.lightbulb,                // 物业
    Symbols.medical_services,       // 医疗
    Icons.local_pharmacy,           // 药品
    Icons.school,                   // 教育
    Icons.menu_book,                // 书籍
    Icons.phone_android,            // 通讯
    Icons.computer,                 // 数码
    Symbols.flight,                 // 旅行
    Icons.hotel,                    // 住宿
    Icons.pets,                     // 宠物
    Icons.child_care,               // 母婴
    Icons.fitness_center,           // 健身
    Icons.spa,                      // 美容
    Icons.content_cut,              // 理发
    Icons.build,                    // 维修
    Icons.cleaning_services,        // 家务
    Icons.local_florist,            // 花卉
    Icons.cake,                     // 生日
    Icons.family_restroom,          // 人情
    Icons.savings,                   // 储蓄
    Icons.volunteer_activism,       // 捐赠
    Icons.local_parking,            // 停车
    Icons.local_taxi,               // 打车
    Icons.airport_shuttle,          // 机场
    Icons.dry_cleaning,             // 洗衣
  ];

  // 支出分类名称（符合记账习惯，40个）
  static const List<String> expenseCategoryNames = [
    '餐饮',
    '外卖',
    '交通',
    '加油',
    '公交',
    '地铁',
    '购物',
    '日用品',
    '服装',
    '娱乐',
    '游戏',
    '咖啡',
    '聚会',
    '住房',
    '水电',
    '物业',
    '医疗',
    '药品',
    '教育',
    '书籍',
    '通讯',
    '数码',
    '旅行',
    '住宿',
    '宠物',
    '母婴',
    '健身',
    '美容',
    '理发',
    '维修',
    '家务',
    '花卉',
    '生日',
    '人情',
    '储蓄',
    '捐赠',
    '停车',
    '打车',
    '机场',
    '洗衣',
  ];

  // ========== 辅助方法 ==========
  
  // 获取所有图标
  static List<IconData> getAllIcons() {
    return [...incomeIcons, ...expenseIcons];
  }

  // 根据收入/支出类型获取图标
  static List<IconData> getIconsByType(bool isIncome) {
    return isIncome ? incomeIcons : expenseIcons;
  }

  // 根据收入/支出类型获取分类名称列表
  static List<String> getCategoryNamesByType(bool isIncome) {
    return isIncome ? incomeCategoryNames : expenseCategoryNames;
  }

  // 根据图标名称（分类名称）获取图标
  static IconData getIconByName(String categoryName) {
    // 查找收入图标
    final incomeIndex = incomeCategoryNames.indexOf(categoryName);
    if (incomeIndex != -1) {
      return incomeIcons[incomeIndex];
    }

    // 查找支出图标
    final expenseIndex = expenseCategoryNames.indexOf(categoryName);
    if (expenseIndex != -1) {
      return expenseIcons[expenseIndex];
    }

    return Icons.category;
  }

  // 根据图标获取分类名称
  static String getCategoryName(IconData icon) {
    // 查找收入图标
    final incomeIndex = incomeIcons.indexOf(icon);
    if (incomeIndex != -1) {
      return incomeCategoryNames[incomeIndex];
    }

    // 查找支出图标
    final expenseIndex = expenseIcons.indexOf(icon);
    if (expenseIndex != -1) {
      return expenseCategoryNames[expenseIndex];
    }

    return '其他';
  }

  // 获取默认图标（收入）
  static IconData getDefaultIncomeIcon() {
    return incomeIcons.isNotEmpty ? incomeIcons[0] : Icons.payments;
  }

  // 获取默认图标（支出）
  static IconData getDefaultExpenseIcon() {
    return expenseIcons.isNotEmpty ? expenseIcons[0] : Icons.restaurant;
  }

  // 获取默认分类名称（收入）
  static String getDefaultIncomeCategory() {
    return incomeCategoryNames.isNotEmpty ? incomeCategoryNames[0] : '工资';
  }

  // 获取默认分类名称（支出）
  static String getDefaultExpenseCategory() {
    return expenseCategoryNames.isNotEmpty ? expenseCategoryNames[0] : '餐饮';
  }

  // 检查分类名称是否存在
  static bool categoryExists(String categoryName, bool isIncome) {
    final names = getCategoryNamesByType(isIncome);
    return names.contains(categoryName);
  }
}

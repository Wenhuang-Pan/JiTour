import 'package:flutter/material.dart';

class IconLibrary {
  static const List<IconData> accountIcons = [
    Icons.wallet_rounded,
    Icons.credit_card_rounded,
    Icons.qr_code_rounded,
    Icons.message_rounded,
    Icons.account_balance_rounded,
    Icons.monetization_on_rounded,
    Icons.phone_rounded,
    Icons.home_rounded,
    Icons.car_rental_rounded,
  ];

  static const List<String> accountIconNames = [
    '现金',
    '银行卡',
    '支付宝',
    '微信',
    '储蓄',
    '零钱',
    '话费',
    '房贷',
    '车贷',
  ];

  static const List<IconData> incomeIcons = [
    Icons.payments_rounded,
    Icons.account_balance_rounded,
    Icons.trending_up_rounded,
    Icons.savings_rounded,
    Icons.work_rounded,
    Icons.card_giftcard_rounded,
    Icons.business_center_rounded,
    Icons.celebration_rounded,
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.add_business_rounded,
    Icons.diamond_rounded,
    Icons.attach_money_rounded,
    Icons.swap_horizontal_circle_rounded,
    Icons.money_rounded,
    Icons.favorite_rounded,
  ];

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

  static const List<IconData> expenseIcons = [
    Icons.restaurant_rounded,
    Icons.food_bank_rounded,
    Icons.directions_car_rounded,
    Icons.local_gas_station_rounded,
    Icons.train_rounded,
    Icons.subway_rounded,
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.checkroom_rounded,
    Icons.movie_rounded,
    Icons.sports_esports_rounded,
    Icons.local_cafe_rounded,
    Icons.local_bar_rounded,
    Icons.home_rounded,
    Icons.kitchen_rounded,
    Icons.lightbulb_rounded,
    Icons.medical_services_rounded,
    Icons.local_pharmacy_rounded,
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.phone_android_rounded,
    Icons.computer_rounded,
    Icons.flight_rounded,
    Icons.hotel_rounded,
    Icons.pets_rounded,
    Icons.child_care_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.content_cut_rounded,
    Icons.build_rounded,
    Icons.cleaning_services_rounded,
    Icons.local_florist_rounded,
    Icons.cake_rounded,
    Icons.family_restroom_rounded,
    Icons.savings_rounded,
    Icons.volunteer_activism_rounded,
    Icons.local_parking_rounded,
    Icons.local_taxi_rounded,
    Icons.airport_shuttle_rounded,
    Icons.dry_cleaning_rounded,
  ];

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

  static List<IconData> getAllIcons() {
    return [...incomeIcons, ...expenseIcons];
  }

  static List<IconData> getIconsByType(bool isIncome) {
    return isIncome ? incomeIcons : expenseIcons;
  }

  static List<String> getCategoryNamesByType(bool isIncome) {
    return isIncome ? incomeCategoryNames : expenseCategoryNames;
  }

  static const List<IconData> extraIcons = [
    Icons.savings_rounded,
    Icons.flight_rounded,
    Icons.home_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.school_rounded,
    Icons.favorite_rounded,
    Icons.card_giftcard_rounded,
    Icons.laptop_rounded,
    Icons.phone_android_rounded,
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.sports_esports_rounded,
    Icons.movie_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.pets_rounded,
    Icons.child_care_rounded,
    Icons.castle_rounded,
    Icons.beach_access_rounded,
  ];

  static const List<String> extraIconNames = [
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

  static IconData getIconByName(String iconName) {
    final extraIndex = extraIconNames.indexOf(iconName);
    if (extraIndex != -1) {
      return extraIcons[extraIndex];
    }

    final accountIndex = accountIconNames.indexOf(iconName);
    if (accountIndex != -1) {
      return accountIcons[accountIndex];
    }

    final incomeIndex = incomeCategoryNames.indexOf(iconName);
    if (incomeIndex != -1) {
      return incomeIcons[incomeIndex];
    }

    final expenseIndex = expenseCategoryNames.indexOf(iconName);
    if (expenseIndex != -1) {
      return expenseIcons[expenseIndex];
    }

    return Icons.category_rounded;
  }

  static String getCategoryName(IconData icon) {
    final incomeIndex = incomeIcons.indexOf(icon);
    if (incomeIndex != -1) {
      return incomeCategoryNames[incomeIndex];
    }

    final expenseIndex = expenseIcons.indexOf(icon);
    if (expenseIndex != -1) {
      return expenseCategoryNames[expenseIndex];
    }

    return '其他';
  }

  static String getIconName(IconData icon) {
    final incomeIndex = incomeIcons.indexOf(icon);
    if (incomeIndex != -1) {
      return incomeCategoryNames[incomeIndex];
    }

    final expenseIndex = expenseIcons.indexOf(icon);
    if (expenseIndex != -1) {
      return expenseCategoryNames[expenseIndex];
    }

    final iconMap = {
      Icons.home_rounded: 'home_rounded',
      Icons.shopping_bag_rounded: 'shopping_bag_rounded',
      Icons.restaurant_rounded: 'restaurant_rounded',
      Icons.directions_car_rounded: 'directions_car_rounded',
      Icons.movie_rounded: 'movie_rounded',
      Icons.favorite_rounded: 'favorite_rounded',
      Icons.school_rounded: 'school_rounded',
      Icons.card_giftcard_rounded: 'card_giftcard_rounded',
      Icons.flight_rounded: 'flight_rounded',
      Icons.work_rounded: 'work_rounded',
      Icons.star_rounded: 'star_rounded',
      Icons.book_rounded: 'book_rounded',
      Icons.pets_rounded: 'pets_rounded',
      Icons.sports_esports_rounded: 'sports_esports_rounded',
      Icons.music_note_rounded: 'music_note_rounded',
      Icons.photo_camera_rounded: 'photo_camera_rounded',
      Icons.phone_rounded: 'phone_rounded',
      Icons.laptop_rounded: 'laptop_rounded',
      Icons.coffee_rounded: 'coffee_rounded',
      Icons.local_bar_rounded: 'local_bar_rounded',
      Icons.local_offer_rounded: 'local_offer_rounded',
    };

    return iconMap[icon] ?? 'local_offer_rounded';
  }

  static IconData getDefaultIncomeIcon() {
    return incomeIcons.isNotEmpty ? incomeIcons[0] : Icons.payments_rounded;
  }

  static IconData getDefaultExpenseIcon() {
    return expenseIcons.isNotEmpty ? expenseIcons[0] : Icons.restaurant_rounded;
  }

  static String getDefaultIncomeCategory() {
    return incomeCategoryNames.isNotEmpty ? incomeCategoryNames[0] : '工资';
  }

  static String getDefaultExpenseCategory() {
    return expenseCategoryNames.isNotEmpty ? expenseCategoryNames[0] : '餐饮';
  }

  static bool categoryExists(String categoryName, bool isIncome) {
    final names = getCategoryNamesByType(isIncome);
    return names.contains(categoryName);
  }
}

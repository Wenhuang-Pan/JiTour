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
    Icons.icecream_rounded,
    Icons.shopping_basket_rounded,
    Icons.directions_bus_rounded,
    Icons.shopping_bag_rounded,
    Icons.apartment_rounded,
    Icons.school_rounded,
    Icons.kitchen_rounded,
    Icons.medical_services_rounded,
    Icons.card_giftcard_rounded,
    Icons.local_gas_station_rounded,
    Icons.redeem_rounded,
    Icons.fitness_center_rounded,
    Icons.more_horiz_rounded,
    Icons.electrical_services_rounded,
    Icons.house_rounded,
    Icons.casino_rounded,
    Icons.electric_bolt_rounded,
    Icons.toll_rounded,
    Icons.local_parking_rounded,
    Icons.local_shipping_rounded,
    Icons.local_florist_rounded,
  ];

  static const List<String> expenseCategoryNames = [
    '餐饮',
    '零食',
    '水果',
    '交通',
    '购物',
    '居住购房',
    '教育',
    '日用杂',
    '医疗',
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
    // 原额外图标
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
    // 新分类图标
    Icons.icecream_rounded,
    Icons.shopping_basket_rounded,
    Icons.apartment_rounded,
    Icons.kitchen_rounded,
    Icons.local_gas_station_rounded,
    Icons.redeem_rounded,
    Icons.fitness_center_rounded,
    Icons.more_horiz_rounded,
    Icons.electrical_services_rounded,
    Icons.electric_bolt_rounded,
    Icons.house_rounded,
    Icons.casino_rounded,
    Icons.toll_rounded,
    Icons.local_parking_rounded,
    Icons.local_shipping_rounded,
    Icons.local_florist_rounded,
    Icons.directions_bus_rounded,
    Icons.medical_services_rounded,
    Icons.payments_rounded,
    Icons.emoji_events_rounded,
    Icons.trending_up_rounded,
    Icons.work_rounded,
    Icons.support_agent_rounded,
    Icons.add_business_rounded,
    Icons.directions_bike_rounded,
    Icons.electric_car_rounded,
  ];

  static const List<String> extraIconNames = [
    // 原额外图标
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
    // 新分类图标名
    'icecream_rounded',
    'shopping_basket_rounded',
    'apartment_rounded',
    'kitchen_rounded',
    'local_gas_station_rounded',
    'redeem_rounded',
    'fitness_center_rounded',
    'more_horiz_rounded',
    'electrical_services_rounded',
    'electric_bolt_rounded',
    'house_rounded',
    'casino_rounded',
    'toll_rounded',
    'local_parking_rounded',
    'local_shipping_rounded',
    'local_florist_rounded',
    'directions_bus_rounded',
    'medical_services_rounded',
    'payments_rounded',
    'emoji_events_rounded',
    'trending_up_rounded',
    'work_rounded',
    'support_agent_rounded',
    'add_business_rounded',
    'directions_bike_rounded',
    'electric_car_rounded',
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

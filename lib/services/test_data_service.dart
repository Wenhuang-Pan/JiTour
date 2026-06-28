import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_service.dart';

class TestDataService {
  static final _uuid = const Uuid();
  static final _random = Random();

  static final List<String> _expenseCategories = ['餐饮', '交通', '购物', '娱乐', '居住', '医疗', '其他'];
  static final List<String> _incomeCategories = ['工资', '奖金', '投资', '其他'];
  static final List<String> _accounts = ['现金', '银行卡', '支付宝', '微信'];

  static Future<void> generateTestData() async {
    await _clearAllData();
    await _generateTransactions();
    await _generateBudgets();
  }

  static Future<void> _clearAllData() async {
    await DatabaseService.transactions.clear();
    await DatabaseService.budgets.clear();
  }

  static Future<void> _generateTransactions() async {
    final now = DateTime.now();

    // 生成最近3个月的数据
    for (int monthOffset = 2; monthOffset >= 0; monthOffset--) {
      final month = DateTime(now.year, now.month - monthOffset, 1);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      // 每月收入：1-2笔
      final incomeCount = _random.nextInt(2) + 1;
      for (int i = 0; i < incomeCount; i++) {
        final day = _random.nextInt(daysInMonth) + 1;
        final category = _incomeCategories[_random.nextInt(_incomeCategories.length)];
        final amount = _generateIncomeAmount(category);

        final transaction = Transaction(
          id: _uuid.v4(),
          amount: amount,
          isIncome: true,
          category: category,
          account: _accounts[_random.nextInt(_accounts.length)],
          date: DateTime(month.year, month.month, day, _random.nextInt(12) + 8, _random.nextInt(60)),
          note: _getIncomeNote(category),
        );
        await DatabaseService.addTransaction(transaction);
      }

      // 每月支出：15-30笔
      final expenseCount = _random.nextInt(16) + 15;
      for (int i = 0; i < expenseCount; i++) {
        final day = _random.nextInt(daysInMonth) + 1;
        final category = _expenseCategories[_random.nextInt(_expenseCategories.length)];
        final amount = _generateExpenseAmount(category);

        final transaction = Transaction(
          id: _uuid.v4(),
          amount: amount,
          isIncome: false,
          category: category,
          account: _accounts[_random.nextInt(_accounts.length)],
          date: DateTime(month.year, month.month, day, _random.nextInt(14) + 8, _random.nextInt(60)),
          note: _getExpenseNote(category),
        );
        await DatabaseService.addTransaction(transaction);
      }
    }
  }

  static Future<void> _generateBudgets() async {
    final now = DateTime.now();

    // 为当前月和下月生成预算
    for (int monthOffset = 0; monthOffset <= 1; monthOffset++) {
      final month = DateTime(now.year, now.month + monthOffset, 1);

      for (var category in _expenseCategories) {
        final amount = _generateBudgetAmount(category);
        if (amount > 0) {
          final budget = Budget(
            id: _uuid.v4(),
            category: category,
            amount: amount,
            year: month.year,
            month: month.month,
          );
          await DatabaseService.addBudget(budget);
        }
      }
    }
  }

  static double _generateIncomeAmount(String category) {
    switch (category) {
      case '工资':
        return 5000 + _random.nextInt(15000).toDouble();
      case '奖金':
        return 1000 + _random.nextInt(5000).toDouble();
      case '投资':
        return 100 + _random.nextInt(2000).toDouble();
      default:
        return 50 + _random.nextInt(500).toDouble();
    }
  }

  static double _generateExpenseAmount(String category) {
    switch (category) {
      case '餐饮':
        return 15 + _random.nextInt(200).toDouble();
      case '交通':
        return 5 + _random.nextInt(100).toDouble();
      case '购物':
        return 50 + _random.nextInt(500).toDouble();
      case '娱乐':
        return 30 + _random.nextInt(300).toDouble();
      case '居住':
        return 500 + _random.nextInt(2000).toDouble();
      case '医疗':
        return 20 + _random.nextInt(300).toDouble();
      default:
        return 10 + _random.nextInt(100).toDouble();
    }
  }

  static double _generateBudgetAmount(String category) {
    switch (category) {
      case '餐饮':
        return 2000;
      case '交通':
        return 800;
      case '购物':
        return 1500;
      case '娱乐':
        return 1000;
      case '居住':
        return 3000;
      case '医疗':
        return 500;
      case '其他':
        return 500;
      default:
        return 0;
    }
  }

  static String? _getIncomeNote(String category) {
    final notes = {
      '工资': ['本月工资', '工资收入', '薪资'],
      '奖金': ['项目奖金', '季度奖金', '年终奖'],
      '投资': ['股票收益', '基金分红', '理财收益'],
      '其他': ['红包', '退款', '兼职'],
    };
    final categoryNotes = notes[category];
    if (categoryNotes != null && _random.nextBool()) {
      return categoryNotes[_random.nextInt(categoryNotes.length)];
    }
    return null;
  }

  static String? _getExpenseNote(String category) {
    final notes = {
      '餐饮': ['午餐', '晚餐', '早餐', '聚餐', '外卖'],
      '交通': ['地铁', '公交', '打车', '加油'],
      '购物': ['超市', '网购', '衣服', '日用品'],
      '娱乐': ['电影', '游戏', 'KTV', '旅游'],
      '居住': ['房租', '水电费', '物业费', '网费'],
      '医疗': ['买药', '挂号费', '体检'],
      '其他': ['捐赠', '罚款', '其他支出'],
    };
    final categoryNotes = notes[category];
    if (categoryNotes != null && _random.nextBool()) {
      return categoryNotes[_random.nextInt(categoryNotes.length)];
    }
    return null;
  }
}

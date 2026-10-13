import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/tag.dart';
import '../models/savings_goal.dart';
import '../models/debt.dart';
import '../models/recurring_transaction.dart';
import '../models/pending_transaction.dart';
import '../utils/decimal_util.dart';
import 'category_service.dart';
import 'account_service.dart';
import 'tag_service.dart';
import 'savings_goal_service.dart';

class DatabaseService {
  static const String _transactionBoxName = 'transactions';
  static const String _budgetBoxName = 'budgets';
  static const String _accountBoxName = 'accounts';
  static const String _tagBoxName = 'tags';
  static const String _savingsGoalBoxName = 'savings_goals';
  static const String _categoryBoxName = 'categories';
  static const String _debtBoxName = 'debts';
  static const String _recurringTransactionBoxName = 'recurring_transactions';
  static const String _locationBoxName = 'locations';
  // WHY: 支付通知自动记账相关 box
  static const String _pendingTransactionBoxName = 'pending_transactions';
  static const String _merchantCategoryMapBoxName = 'merchant_category_map';
  static const String _autoAccountingPrefsBoxName = 'auto_accounting_prefs';
  static late Box<Transaction> _transactionBox;
  static late Box<Budget> _budgetBox;
  static late Box<Account> _accountBox;
  static late Box<Tag> _tagBox;
  static late Box<SavingsGoal> _savingsGoalBox;
  static late Box<Category> _categoryBox;
  static late Box<Debt> _debtBox;
  static late Box<RecurringTransaction> _recurringTransactionBox;
  static late Box<Map<String, dynamic>> _locationBox;
  // WHY: 待确认交易、商户学习表、自动记账偏好
  static late Box<PendingTransaction> _pendingTransactionBox;
  static late Box<String> _merchantCategoryMapBox;
  static late Box<dynamic> _autoAccountingPrefsBox;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BudgetAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AccountAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TagAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SavingsGoalAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(DebtAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(RecurringTransactionAdapter());
    }
    // WHY: 注册支付通知自动记账相关 adapter，typeId 8/9/10
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(PendingTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(PaymentSourceAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(PendingStatusAdapter());
    }
    // WHY: Decimal 类型适配器（typeId 100），将金额序列化为 String 存储，避免浮点误差
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(DecimalAdapter());
    }

    _transactionBox = await Hive.openBox<Transaction>(_transactionBoxName);
    _budgetBox = await Hive.openBox<Budget>(_budgetBoxName);
    _accountBox = await Hive.openBox<Account>(_accountBoxName);
    _tagBox = await Hive.openBox<Tag>(_tagBoxName);
    _savingsGoalBox = await Hive.openBox<SavingsGoal>(_savingsGoalBoxName);
    _categoryBox = await Hive.openBox<Category>(_categoryBoxName);
    _debtBox = await Hive.openBox<Debt>(_debtBoxName);
    _recurringTransactionBox =
        await Hive.openBox<RecurringTransaction>(_recurringTransactionBoxName);
    _locationBox = await Hive.openBox<Map<String, dynamic>>(_locationBoxName);
    // WHY: 打开支付通知自动记账相关 box
    _pendingTransactionBox =
        await Hive.openBox<PendingTransaction>(_pendingTransactionBoxName);
    _merchantCategoryMapBox =
        await Hive.openBox<String>(_merchantCategoryMapBoxName);
    _autoAccountingPrefsBox =
        await Hive.openBox<dynamic>(_autoAccountingPrefsBoxName);

    // 初始化分类服务
    await CategoryService.init();

    // 初始化账户服务
    await AccountService.init();

    // 初始化标签服务
    await TagService.init();

    // 初始化储蓄目标服务
    await SavingsGoalService.init();
  }

  static Box<Transaction> get transactions => _transactionBox;
  static Box<Budget> get budgets => _budgetBox;
  static Box<Account> get accounts => _accountBox;
  static Box<Tag> get tags => _tagBox;
  static Box<SavingsGoal> get savingsGoals => _savingsGoalBox;
  static Box<Category> get categories => _categoryBox;
  static Box<Debt> get debts => _debtBox;
  static Box<RecurringTransaction> get recurringTransactions =>
      _recurringTransactionBox;
  static Box<Map<String, dynamic>> get locations => _locationBox;
  // WHY: 支付通知自动记账相关 box getter
  static Box<PendingTransaction> get pendingTransactions =>
      _pendingTransactionBox;
  static Box<String> get merchantCategoryMap => _merchantCategoryMapBox;
  static Box<dynamic> get autoAccountingPrefs => _autoAccountingPrefsBox;

  static Future<void> addTransaction(Transaction transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  /// 更新交易（编辑模式使用）
  ///
  /// @param transaction 已修改的交易对象，id 必须已存在
  /// @return Future 完成持久化
  static Future<void> updateTransaction(Transaction transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  /// 按 ID 获取交易
  ///
  /// @param id 交易 ID
  /// @return 找到返回 Transaction，否则 null
  static Transaction? getTransactionById(String id) {
    return _transactionBox.get(id);
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactionBox.delete(id);
  }

  static List<Transaction> getAllTransactions() {
    return _transactionBox.values.where((t) => !t.isDeleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<Transaction> getTransactionsInRange(
      DateTime startDate, DateTime endDate) {
    return _transactionBox.values
        .where((t) =>
            !t.isDeleted &&
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> addBudget(Budget budget) async {
    await _budgetBox.put(budget.id, budget);
  }

  static Future<void> updateBudget(Budget budget) async {
    await _budgetBox.put(budget.id, budget);
  }

  static Future<void> deleteBudget(String id) async {
    await _budgetBox.delete(id);
  }

  static List<Budget> getBudgetsForMonth(int year, int month) {
    return _budgetBox.values
        .where((b) => b.year == year && b.month == month)
        .toList();
  }

  static Budget? getBudgetForCategory(String category, int year, int month) {
    try {
      return _budgetBox.values.firstWhere(
        (b) => b.category == category && b.year == year && b.month == month,
      );
    } catch (e) {
      return null;
    }
  }
}

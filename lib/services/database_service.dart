import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'category_service.dart';

class DatabaseService {
  static const String _transactionBoxName = 'transactions';
  static const String _budgetBoxName = 'budgets';
  static late Box<Transaction> _transactionBox;
  static late Box<Budget> _budgetBox;

  static Future<void> init() async {
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(BudgetAdapter());
    Hive.registerAdapter(CategoryAdapter());
    
    _transactionBox = await Hive.openBox<Transaction>(_transactionBoxName);
    _budgetBox = await Hive.openBox<Budget>(_budgetBoxName);
    
    // 初始化分类服务
    await CategoryService.init();
  }

  static Box<Transaction> get transactions => _transactionBox;
  static Box<Budget> get budgets => _budgetBox;

  static Future<void> addTransaction(Transaction transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactionBox.delete(id);
  }

  static List<Transaction> getAllTransactions() {
    return _transactionBox.values.toList()
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
    return _budgetBox.values.firstWhere(
      (b) => b.category == category && b.year == year && b.month == month,
      orElse: () => Budget(
        id: '',
        category: category,
        amount: 0,
        year: year,
        month: month,
      ),
    );
  }
}

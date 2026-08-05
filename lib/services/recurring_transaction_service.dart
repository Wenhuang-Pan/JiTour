import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../utils/uuid_util.dart';

/// 定期交易服务
/// 
/// 提供定期交易的增删改查和自动生成交易功能
class RecurringTransactionService {
  /// 添加定期交易
  /// 
  /// @param recurringTransaction 定期交易对象
  /// @return 添加后的定期交易
  static Future<RecurringTransaction> addRecurringTransaction(
      RecurringTransaction recurringTransaction) async {
    final box = DatabaseService.recurringTransactions;
    await box.put(recurringTransaction.id, recurringTransaction);
    return recurringTransaction;
  }

  /// 更新定期交易
  /// 
  /// @param recurringTransaction 定期交易对象
  /// @return 更新后的定期交易
  static Future<RecurringTransaction> updateRecurringTransaction(
      RecurringTransaction recurringTransaction) async {
    recurringTransaction.updatedAt = DateTime.now();
    final box = DatabaseService.recurringTransactions;
    await box.put(recurringTransaction.id, recurringTransaction);
    return recurringTransaction;
  }

  /// 删除定期交易
  /// 
  /// @param id 定期交易ID
  static Future<void> deleteRecurringTransaction(String id) async {
    final box = DatabaseService.recurringTransactions;
    await box.delete(id);
  }

  /// 获取所有定期交易
  /// 
  /// @param includeDisabled 是否包含已禁用的交易（默认true）
  /// @return 定期交易列表
  static List<RecurringTransaction> getAllRecurringTransactions({
    bool includeDisabled = true,
  }) {
    final box = DatabaseService.recurringTransactions;
    var transactions = box.values.toList();
    
    if (!includeDisabled) {
      transactions = transactions.where((t) => t.isEnabled).toList();
    }
    
    // 按下次执行日期排序
    transactions.sort((a, b) {
      if (a.nextExecutionDate == null) return 1;
      if (b.nextExecutionDate == null) return -1;
      return a.nextExecutionDate!.compareTo(b.nextExecutionDate!);
    });
    
    return transactions;
  }

  /// 获取单个定期交易
  /// 
  /// @param id 定期交易ID
  /// @return 定期交易对象，不存在返回null
  static RecurringTransaction? getRecurringTransaction(String id) {
    final box = DatabaseService.recurringTransactions;
    return box.get(id);
  }

  /// 获取需要执行的定期交易
  /// 
  /// @return 需要执行的定期交易列表
  static List<RecurringTransaction> getPendingRecurringTransactions() {
    final box = DatabaseService.recurringTransactions;
    return box.values
        .where((t) => t.isEnabled && !t.isExpired && t.shouldExecute)
        .toList();
  }

  /// 获取即将到期的定期交易（3天内）
  /// 
  /// @param days 天数（默认3）
  /// @return 即将到期的定期交易列表
  static List<RecurringTransaction> getUpcomingRecurringTransactions({int days = 3}) {
    final box = DatabaseService.recurringTransactions;
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));
    
    return box.values
        .where((t) {
          if (!t.isEnabled) return false;
          if (t.isExpired) return false;
          if (t.nextExecutionDate == null) return false;
          return t.nextExecutionDate!.isBefore(threshold) &&
                 t.nextExecutionDate!.isAfter(now);
        })
        .toList()
      ..sort((a, b) => a.nextExecutionDate!.compareTo(b.nextExecutionDate!));
  }

  /// 执行定期交易（生成普通交易）
  ///
  /// WHY: 添加当天执行次数限制，防止用户同一天内多次点击"立即执行"
  /// 导致生成重复交易记录。通过 lastExecutedDate 判断今天是否已执行。
  ///
  /// @param recurringTransaction 定期交易对象
  /// @return 生成的交易对象，如果当天已执行过则返回 null
  static Future<Transaction?> executeRecurringTransaction(
      RecurringTransaction recurringTransaction) async {
    // 检查今天是否已经执行过
    if (recurringTransaction.lastExecutedDate != null) {
      final lastExecuted = recurringTransaction.lastExecutedDate!;
      final now = DateTime.now();
      if (lastExecuted.year == now.year &&
          lastExecuted.month == now.month &&
          lastExecuted.day == now.day) {
        return null;
      }
    }

    final transaction = Transaction(
      id: UuidUtil.generate(),
      amount: recurringTransaction.amount,
      isIncome: recurringTransaction.isIncome,
      category: recurringTransaction.category,
      subCategory: recurringTransaction.subCategory,
      account: recurringTransaction.account,
      account2: recurringTransaction.account2,
      currency: recurringTransaction.currency,
      date: DateTime.now(),
      note: recurringTransaction.note,
      isReimbursed: false,
      fee: 0.0,
      coupon: 0.0,
    );

    await DatabaseService.addTransaction(transaction);

    // 更新定期交易的执行记录
    recurringTransaction.markAsExecuted();
    await updateRecurringTransaction(recurringTransaction);

    return transaction;
  }

  /// 检查定期交易今天是否已执行
  ///
  /// @param recurringTransaction 定期交易对象
  /// @return 如果今天已执行返回 true，否则返回 false
  static bool isExecutedToday(RecurringTransaction recurringTransaction) {
    if (recurringTransaction.lastExecutedDate == null) return false;
    final last = recurringTransaction.lastExecutedDate!;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  /// 批量执行所有待执行的定期交易
  /// 
  /// @return 生成的交易数量
  static Future<int> executeAllPendingTransactions() async {
    final pending = getPendingRecurringTransactions();
    for (final recurring in pending) {
      await executeRecurringTransaction(recurring);
    }
    return pending.length;
  }

  /// 检查并执行定期交易（在应用启动时调用）
  /// 
  /// @return 生成的交易数量
  static Future<int> checkAndExecute() async {
    // 更新所有定期交易的下次执行日期
    final all = getAllRecurringTransactions();
    for (final recurring in all) {
      if (recurring.nextExecutionDate == null) {
        recurring.updateNextExecutionDate();
        await updateRecurringTransaction(recurring);
      }
    }
    
    // 执行待执行的交易
    return executeAllPendingTransactions();
  }

  /// 获取定期交易统计
  /// 
  /// @return 统计信息Map
  static Map<String, dynamic> getStats() {
    final box = DatabaseService.recurringTransactions;
    final all = box.values.toList();
    final enabled = all.where((t) => t.isEnabled).toList();
    final pending = getPendingRecurringTransactions();
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final t in enabled) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    
    return {
      'totalCount': all.length,
      'enabledCount': enabled.length,
      'pendingCount': pending.length,
      'monthlyIncome': totalIncome,
      'monthlyExpense': totalExpense,
    };
  }

  /// 启用/禁用定期交易
  /// 
  /// @param id 定期交易ID
  /// @param isEnabled 是否启用
  static Future<void> toggleStatus(String id, bool isEnabled) async {
    final box = DatabaseService.recurringTransactions;
    final transaction = box.get(id);
    if (transaction != null) {
      transaction.isEnabled = isEnabled;
      transaction.updatedAt = DateTime.now();
      await box.put(id, transaction);
    }
  }
}

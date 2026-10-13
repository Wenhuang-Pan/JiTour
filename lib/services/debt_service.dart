import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../models/debt.dart';
import '../utils/uuid_util.dart';

/// 负债服务
/// 管理负债数据的增删改查操作
class DebtService {
  /// Hive box 名称
  static const String _boxName = 'debts';

  /// 添加负债
  /// @param debt 负债对象
  static Future<void> addDebt(Debt debt) async {
    final box = await Hive.openBox<Debt>(_boxName);
    await box.put(debt.id, debt);
  }

  /// 更新负债
  /// @param debt 负债对象
  static Future<void> updateDebt(Debt debt) async {
    debt.updatedAt = DateTime.now();
    await debt.save();
  }

  /// 删除负债
  /// @param id 负债ID
  static Future<void> deleteDebt(String id) async {
    final box = await Hive.openBox<Debt>(_boxName);
    await box.delete(id);
  }

  /// 获取所有负债
  /// @return 负债列表，按创建时间倒序排列
  static List<Debt> getAllDebts() {
    final box = Hive.box<Debt>(_boxName);
    final debts = box.values.toList();
    debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return debts;
  }

  /// 获取未还清负债
  /// @return 未还清负债列表
  static List<Debt> getActiveDebts() {
    return getAllDebts().where((d) => !d.isCompleted).toList();
  }

  /// 获取已还清负债
  /// @return 已还清负债列表
  static List<Debt> getCompletedDebts() {
    return getAllDebts().where((d) => d.isCompleted).toList();
  }

  /// 根据ID获取负债
  /// @param id 负债ID
  /// @return 负债对象或null
  static Debt? getDebtById(String id) {
    final box = Hive.box<Debt>(_boxName);
    return box.get(id);
  }

  /// 获取总负债金额
  /// @return 总负债金额
  static Decimal getTotalDebtAmount() {
    return getAllDebts().fold(Decimal.zero, (sum, d) => sum + d.totalAmount);
  }

  /// 获取待还金额
  /// @return 待还金额
  static Decimal getRemainingAmount() {
    return getAllDebts()
        .fold(Decimal.zero, (sum, d) => sum + d.remainingAmount);
  }

  /// @return 已还金额
  static Decimal getPaidAmount() {
    return getAllDebts().fold(Decimal.zero, (sum, d) => sum + d.paidAmount);
  }

  /// 获取负债数量
  /// @return 负债数量
  static int getDebtCount() {
    return getAllDebts().length;
  }

  /// 获取逾期负债数量
  /// @return 逾期负债数量
  static int getOverdueCount() {
    return getAllDebts().where((d) => d.isOverdue).length;
  }

  /// 创建负债（便捷方法）
  /// @param name 负债名称
  /// @param creditor 债权人
  /// @param totalAmount 总金额
  /// @param dueDate 到期日期
  /// @param interestRate 利率
  /// @param note 备注
  /// @param iconName 图标名称
  /// @param colorValue 颜色值
  /// @return 创建的负债对象
  static Debt createDebt({
    required String name,
    required String creditor,
    required Decimal totalAmount,
    required DateTime dueDate,
    double interestRate = 0.0,
    String? note,
    String iconName = 'account_balance',
    int colorValue = 0xFF6366F1,
  }) {
    return Debt(
      id: UuidUtil.generate(),
      name: name,
      creditor: creditor,
      totalAmount: totalAmount,
      paidAmount: Decimal.zero,
      interestRate: interestRate,
      dueDate: dueDate,
      status: 'pending',
      note: note,
      iconName: iconName,
      colorValue: colorValue,
    );
  }

  /// 还款（便捷方法）
  /// @param id 负债ID
  /// @param amount 还款金额
  /// @return 是否还款成功
  static Future<bool> payDebt(String id, Decimal amount) async {
    final debt = getDebtById(id);
    if (debt == null) return false;
    if (amount <= Decimal.zero) return false;

    debt.pay(amount);
    await updateDebt(debt);
    return true;
  }

  /// 获取负债统计信息
  /// @return 统计信息Map
  static Map<String, dynamic> getDebtStats() {
    final debts = getAllDebts();
    final activeDebts = debts.where((d) => !d.isCompleted).toList();
    final completedDebts = debts.where((d) => d.isCompleted).toList();
    final overdueDebts = debts.where((d) => d.isOverdue).toList();

    return {
      'totalCount': debts.length,
      'activeCount': activeDebts.length,
      'completedCount': completedDebts.length,
      'overdueCount': overdueDebts.length,
      'totalAmount': debts.fold(Decimal.zero, (sum, d) => sum + d.totalAmount),
      'remainingAmount': activeDebts.fold(Decimal.zero, (sum, d) => sum + d.remainingAmount),
      'paidAmount': debts.fold(Decimal.zero, (sum, d) => sum + d.paidAmount),
      'overdueAmount': overdueDebts.fold(Decimal.zero, (sum, d) => sum + d.remainingAmount),
    };
  }

  /// 获取即将到期的负债（7天内）
  /// @return 即将到期的负债列表
  static List<Debt> getUpcomingDebts(int days) {
    final now = DateTime.now();
    final deadline = now.add(Duration(days: days));
    return getAllDebts()
        .where((d) =>
            !d.isCompleted &&
            d.dueDate.isAfter(now) &&
            d.dueDate.isBefore(deadline))
        .toList();
  }

  /// 搜索负债
  /// @param query 搜索关键词
  /// @return 匹配的负债列表
  static List<Debt> searchDebts(String query) {
    if (query.isEmpty) return getAllDebts();
    final lowerQuery = query.toLowerCase();
    return getAllDebts()
        .where((d) =>
            d.name.toLowerCase().contains(lowerQuery) ||
            d.creditor.toLowerCase().contains(lowerQuery) ||
            (d.note ?? '').toLowerCase().contains(lowerQuery))
        .toList();
  }
}

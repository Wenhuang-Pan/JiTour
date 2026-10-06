import '../models/pending_transaction.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../utils/uuid_util.dart';
import 'category_inference_service.dart';

/// 待确认交易服务
///
/// 管理支付通知生成的待确认交易 CRUD 操作，
/// 以及转正为正式 [Transaction] 的流程。
class PendingTransactionService {
  PendingTransactionService._();

  /// 添加待确认交易
  ///
  /// @param pending 待确认交易对象
  /// @return 添加后的对象
  static Future<PendingTransaction> add(PendingTransaction pending) async {
    await DatabaseService.pendingTransactions.put(pending.id, pending);
    return pending;
  }

  /// 创建待确认交易
  ///
  /// WHY: 便捷方法，自动生成 ID 和时间戳。
  ///
  /// @param amount 金额
  /// @param source 支付来源
  /// @param rawText 原始通知文本
  /// @param merchant 商户名
  /// @param inferredCategory 推断分类
  /// @param confidence 置信度
  /// @return 创建的待确认交易
  static Future<PendingTransaction> create({
    required double amount,
    required PaymentSource source,
    required String rawText,
    String? merchant,
    String? inferredCategory,
    double confidence = 0.0,
  }) async {
    final pending = PendingTransaction(
      id: UuidUtil.generate(),
      amount: amount,
      source: source,
      paymentTime: DateTime.now(),
      rawText: rawText,
      merchant: merchant,
      inferredCategory: inferredCategory,
      confidence: confidence,
    );
    return add(pending);
  }

  /// 获取所有待确认交易（按时间倒序）
  ///
  /// @param status 可选状态过滤，默认返回全部
  /// @return 待确认交易列表
  static List<PendingTransaction> getAll({PendingStatus? status}) {
    var list = DatabaseService.pendingTransactions.values.toList();
    if (status != null) {
      list = list.where((t) => t.status == status).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 获取待确认状态的交易
  ///
  /// @return 状态为 pending 的交易列表
  static List<PendingTransaction> getPending() {
    return getAll(status: PendingStatus.pending);
  }

  /// 确认待确认交易，转正为正式交易
  ///
  /// WHY: 用户确认后，创建正式 Transaction 并关联 ID，
  /// 同时学习商户-分类映射提升后续推断准确率。
  ///
  /// @param pendingId 待确认交易 ID
  /// @param category 用户最终选择的分类
  /// @param account 账户名
  /// @param note 备注（可选）
  /// @param amount 用户修改后的金额（可选，未传则使用 pending 原金额）
  /// @return 创建的正式交易，失败返回 null
  static Future<Transaction?> confirm(
    String pendingId, {
    required String category,
    required String account,
    String? note,
    double? amount,
  }) async {
    final pending = DatabaseService.pendingTransactions.get(pendingId);
    if (pending == null || pending.status != PendingStatus.pending) {
      return null;
    }

    // WHY: 优先使用用户手动修改后的金额，未传则使用 pending 原金额
    final effectiveAmount = amount ?? pending.amount;

    // 创建正式交易
    final transaction = Transaction(
      id: UuidUtil.generate(),
      amount: effectiveAmount,
      isIncome: false, // WHY: 支付通知默认为支出
      category: category,
      account: account,
      currency: 'CNY',
      date: pending.paymentTime,
      note: note ?? pending.merchant,
      isReimbursed: false,
      fee: 0.0,
      coupon: 0.0,
    );
    await DatabaseService.addTransaction(transaction);

    // WHY: 若用户手动修改了金额，则同步更新 pending 记录，便于审计追溯
    if (amount != null && (amount - pending.amount).abs() > 0.001) {
      pending.amount = amount;
    }

    // 更新待确认状态
    pending.status = PendingStatus.confirmed;
    pending.confirmedTransactionId = transaction.id;
    await DatabaseService.pendingTransactions.put(pending.id, pending);

    // 学习商户-分类映射
    if (pending.merchant != null && pending.merchant!.isNotEmpty) {
      await CategoryInferenceService.learn(pending.merchant!, category);
    }

    return transaction;
  }

  /// 丢弃待确认交易
  ///
  /// @param pendingId 待确认交易 ID
  static Future<void> discard(String pendingId) async {
    final pending = DatabaseService.pendingTransactions.get(pendingId);
    if (pending == null) return;
    pending.status = PendingStatus.discarded;
    await DatabaseService.pendingTransactions.put(pending.id, pending);
  }

  /// 删除待确认交易（物理删除）
  ///
  /// @param pendingId 待确认交易 ID
  static Future<void> delete(String pendingId) async {
    await DatabaseService.pendingTransactions.delete(pendingId);
  }

  /// 清空所有已处理的待确认交易（已确认/已丢弃）
  ///
  /// WHY: 定期清理，避免 box 膨胀。
  ///
  /// @return 清理的数量
  static Future<int> clearProcessed() async {
    final processed = getAll()
        .where((t) => t.status != PendingStatus.pending)
        .toList();
    for (final t in processed) {
      await DatabaseService.pendingTransactions.delete(t.id);
    }
    return processed.length;
  }
}

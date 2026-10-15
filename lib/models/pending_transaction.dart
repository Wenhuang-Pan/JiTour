import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'pending_transaction.g.dart';

/// 支付来源枚举
///
/// 标识待确认交易来自哪个支付渠道。
@HiveType(typeId: 9)
enum PaymentSource {
  /// 支付宝
  @HiveField(0)
  alipay,

  /// 微信支付
  @HiveField(1)
  wechat,
}

/// 待确认交易状态枚举
///
/// WHY: 自动记账本质是"建议"，用户可能确认或丢弃，
/// 独立状态机便于统计准确率和批量管理。
@HiveType(typeId: 10)
enum PendingStatus {
  /// 待确认
  @HiveField(0)
  pending,

  /// 已确认（转正为正式交易）
  @HiveField(1)
  confirmed,

  /// 已丢弃
  @HiveField(2)
  discarded,
}

/// 待确认交易模型
///
/// 当系统监听到支付宝/微信支付通知后，自动创建一条待确认交易。
/// 用户在弹窗中确认或修改后，转正为正式 [Transaction]。
///
/// 持久化方式：Hive box，typeId 为 8。
@HiveType(typeId: 8)
class PendingTransaction extends HiveObject {
  /// 唯一标识
  @HiveField(0)
  String id;

  /// 支付金额
  @HiveField(1)
  Decimal amount;

  /// 商户名称（可能为空，通知解析失败时）
  @HiveField(2)
  String? merchant;

  /// 推断的分类名
  @HiveField(3)
  String? inferredCategory;

  /// 推断置信度（0.0-1.0）
  @HiveField(4)
  double confidence;

  /// 支付来源
  @HiveField(5)
  PaymentSource source;

  /// 支付发生时间
  @HiveField(6)
  DateTime paymentTime;

  /// 原始通知文本（用于调试和重新解析）
  @HiveField(7)
  String rawText;

  /// 当前状态
  @HiveField(8)
  PendingStatus status;

  /// 创建时间
  @HiveField(9)
  DateTime createdAt;

  /// 转正后关联的正式交易 ID
  @HiveField(10)
  String? confirmedTransactionId;

  /// 是否为收入（收款/到账/退款类），默认 false 为支出
  /// WHY: v3.3.0 新增——收支识别补全，历史记录读取时缺省为 false（支出），
  /// 与旧版行为完全一致，无需数据迁移
  @HiveField(11, defaultValue: false)
  bool isIncome;

  /// 构造待确认交易
  ///
  /// @param id 唯一标识
  /// @param amount 支付金额
  /// @param source 支付来源
  /// @param paymentTime 支付时间
  /// @param rawText 原始通知文本
  /// @param merchant 商户名称
  /// @param inferredCategory 推断分类
  /// @param confidence 置信度
  /// @param status 初始状态，默认 pending
  /// @param confirmedTransactionId 转正交易 ID
  /// @param isIncome 是否收入，默认 false
  PendingTransaction({
    required this.id,
    required this.amount,
    required this.source,
    required this.paymentTime,
    required this.rawText,
    this.merchant,
    this.inferredCategory,
    this.confidence = 0.0,
    this.status = PendingStatus.pending,
    this.confirmedTransactionId,
    this.isIncome = false,
  }) : createdAt = DateTime.now();

  /// 获取支付来源显示名
  ///
  /// @return 中文显示名
  String get sourceDisplayName {
    switch (source) {
      case PaymentSource.alipay:
        return '支付宝';
      case PaymentSource.wechat:
        return '微信支付';
    }
  }

  /// 获取状态显示名
  ///
  /// @return 中文显示名
  String get statusDisplayName {
    switch (status) {
      case PendingStatus.pending:
        return '待确认';
      case PendingStatus.confirmed:
        return '已记录';
      case PendingStatus.discarded:
        return '已忽略';
    }
  }
}

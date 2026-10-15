import 'package:decimal/decimal.dart';
import 'pending_transaction.dart';

/// 解析后的支付信息
///
/// WHY: 纯内存数据类，用于在通知解析服务和状态管理之间传递。
/// 不需要持久化，转为 [PendingTransaction] 后即丢弃。
class ParsedPayment {
  /// 支付金额
  final Decimal amount;

  /// 商户名称
  final String? merchant;

  /// 支付来源
  final PaymentSource source;

  /// 原始通知文本
  final String rawText;

  /// 通知时间戳
  final DateTime timestamp;

  /// 是否为收入（收款/到账/退款类），默认 false 为支出
  final bool isIncome;

  /// 构造解析结果
  ///
  /// @param amount 金额
  /// @param source 支付来源
  /// @param rawText 原始文本
  /// @param timestamp 时间戳
  /// @param merchant 商户名
  /// @param isIncome 是否收入，默认 false
  ParsedPayment({
    required this.amount,
    required this.source,
    required this.rawText,
    required this.timestamp,
    this.merchant,
    this.isIncome = false,
  });
}

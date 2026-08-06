import '../models/pending_transaction.dart';
import '../models/parsed_payment.dart';

/// 通知文本解析服务
///
/// WHY: 支付宝/微信通知格式随 App 版本可能变化，
/// 使用多组正则容错匹配，任一命中即返回；全部失败返回 null 由上层丢弃。
class NotificationParserService {
  NotificationParserService._();

  // WHY: 支付宝通知样例「支付宝成功收款1.00元」「你在xxx消费了15.00元」
  //      支持「元/￥」两种符号，金额支持 1-2 位小数
  static final RegExp _alipayAmountPattern =
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:元|￥|¥)');

  // WHY: 支付宝商户名提取：「在XXX消费」「收款方:XXX」「向XXX付款」
  static final RegExp _alipayMerchantPattern =
      RegExp(r'在(.+?)消费|收款方[:：]\s*(.+?)$|向(.+?)付款');

  // WHY: 微信支付通知样例「微信支付收款1.00元」「当前账户金额:100.00元」
  static final RegExp _wechatAmountPattern =
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:元|￥|¥)');

  // WHY: 微信商户名提取：「付款给XXX」「收款方:XXX」
  static final RegExp _wechatMerchantPattern =
      RegExp(r'付款给(.+?)$|收款方[:：]\s*(.+?)$');

  /// 解析通知文本
  ///
  /// @param text 通知正文（title + text 合并）
  /// @param packageName 来源包名
  /// @return 解析结果 [ParsedPayment]，无法解析时返回 null
  static ParsedPayment? parse(String text, String packageName) {
    if (packageName == 'com.eg.android.AlipayGphone') {
      return _parseAlipay(text);
    } else if (packageName == 'com.tencent.mm') {
      return _parseWechat(text);
    }
    return null;
  }

  /// 解析支付宝通知
  ///
  /// @param text 通知文本
  /// @return 解析结果，失败返回 null
  static ParsedPayment? _parseAlipay(String text) {
    final amtMatch = _alipayAmountPattern.firstMatch(text);
    if (amtMatch == null) return null;

    final amount = double.tryParse(amtMatch.group(1) ?? '');
    if (amount == null || amount <= 0) return null;

    final merMatch = _alipayMerchantPattern.firstMatch(text);
    String? merchant;
    if (merMatch != null) {
      // WHY: 三个分组任一命中即可
      merchant = merMatch.group(1) ?? merMatch.group(2) ?? merMatch.group(3);
      merchant = merchant?.trim();
    }

    return ParsedPayment(
      amount: amount,
      merchant: merchant,
      source: PaymentSource.alipay,
      rawText: text,
      timestamp: DateTime.now(),
    );
  }

  /// 解析微信支付通知
  ///
  /// @param text 通知文本
  /// @return 解析结果，失败返回 null
  static ParsedPayment? _parseWechat(String text) {
    final amtMatch = _wechatAmountPattern.firstMatch(text);
    if (amtMatch == null) return null;

    final amount = double.tryParse(amtMatch.group(1) ?? '');
    if (amount == null || amount <= 0) return null;

    final merMatch = _wechatMerchantPattern.firstMatch(text);
    String? merchant;
    if (merMatch != null) {
      merchant = merMatch.group(1) ?? merMatch.group(2);
      merchant = merchant?.trim();
    }

    return ParsedPayment(
      amount: amount,
      merchant: merchant,
      source: PaymentSource.wechat,
      rawText: text,
      timestamp: DateTime.now(),
    );
  }
}

import 'package:decimal/decimal.dart';
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

  // WHY: 收入类关键词——命中即判定为收入而非支出。
  // 注意不能用裸「收款」：支出页面的「收款方」（即商户名标签）会造成误判，
  // 故只匹配明确的成功/到账语义短语
  static const List<String> _incomeKeywords = <String>[
    '成功收款',
    '收款成功',
    '收款到账',
    '转账到账',
    '已到账',
    '收到转账',
    '收到红包',
    '退款成功',
    '退款到账',
  ];

  // WHY: 支付成功页（无障碍通道捕获）主流展示「¥12.50」符号在前形式，
  // 与通知文本的「12.34元」互补，两条正则任一命中即采用
  static final RegExp _amountPrefixPattern =
      RegExp(r'(?:￥|¥)\s*(\d+(?:\.\d{1,2})?)');

  /// 判断文本是否描述收入场景
  ///
  /// @param text 通知或页面拼接文本
  /// @return true 表示收入（收款/到账/退款），false 表示支出
  static bool detectIncome(String text) {
    // O(k)，k 为关键词数量（常量级）
    return _incomeKeywords.any(text.contains);
  }

  /// 从文本中提取金额（符号在前/在后两种形式都尝试）
  ///
  /// @param text 文本
  /// @param suffixPattern 符号在后的正则
  /// @return 解析到的金额，失败返回 null
  static Decimal? _extractAmount(String text, RegExp suffixPattern) {
    final match =
        suffixPattern.firstMatch(text) ?? _amountPrefixPattern.firstMatch(text);
    if (match == null) return null;
    return Decimal.tryParse(match.group(1) ?? '');
  }

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
    final amount = _extractAmount(text, _alipayAmountPattern);
    if (amount == null || amount <= Decimal.zero) return null;

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
      isIncome: detectIncome(text),
    );
  }

  /// 解析微信支付通知
  ///
  /// @param text 通知文本
  /// @return 解析结果，失败返回 null
  static ParsedPayment? _parseWechat(String text) {
    final amount = _extractAmount(text, _wechatAmountPattern);
    if (amount == null || amount <= Decimal.zero) return null;

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
      isIncome: detectIncome(text),
    );
  }
}

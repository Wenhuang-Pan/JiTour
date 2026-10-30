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
  // 「收款方[:：]」模式不能用行尾 $ 锚定：真实通知中商户名后常同行尾随
  // 金额（如「收款方:瑞幸咖啡 20.00元」），. 会吞掉金额。改为前瞻到下一个
  // 空白或行尾，确保只取商户名本身。
  static final RegExp _alipayMerchantPattern =
      RegExp(r'在(.+?)消费|收款方[:：]\s*(.+?)(?=\s|[￥¥]|$)|向(.+?)付款');

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
    '转入',
    '入账',
    '退款成功',
    '退款到账',
  ];

  // WHY: 退款通知文案并不总带「成功/到账」（如「微信支付退款 ￥12.00」
  // 「原路退回」「退款金额」），只靠上面的收入短语会漏判并把退款记成支出
  // （v3.4.2 用户反馈「退款也识别成支付」），故补充退款语义关键词
  static const List<String> _refundKeywords = <String>[
    '退款',
    '退回',
    '退费',
  ];

  // WHY: 退款流程未完成时不能记账成收入，命中即不算收入
  static const List<String> _refundPendingKeywords = <String>[
    '退款失败',
    '申请退款',
    '退款中',
    '退款处理中',
    '待退款',
    '退款申请',
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
    // WHY: 退款申请/退款中等未完成态不能算收入，优先排除
    if (_refundPendingKeywords.any(text.contains)) return false;
    // O(k)，k 为关键词数量（常量级）
    return _incomeKeywords.any(text.contains) ||
        _refundKeywords.any(text.contains);
  }

  /// 判断文本是否为退款到账
  ///
  /// @param text 通知或页面拼接文本
  /// @return true 表示退款已到账，false 表示非退款或退款未完成
  static bool detectRefund(String text) {
    if (_refundPendingKeywords.any(text.contains)) return false;
    return _refundKeywords.any(text.contains);
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
  // 同支付宝，不能用行尾 $ 锚定，否则同行尾随金额会被吞入商户名。
  static final RegExp _wechatMerchantPattern =
      RegExp(r'付款给(.+?)(?=\s|[￥¥]|$)|收款方[:：]\s*(.+?)(?=\s|[￥¥]|$)');

  // WHY: 银行 App 消息提醒通道。银行包名各不相同，无法用前缀统一匹配，
  // 故维护常见银行 App 包名白名单；但银行通知的文本框式与支付宝/微信差异较大，
  // 统一走通用解析（金额 + 收支方向 + 「在XX消费」商户提取）
  static const Set<String> _bankPackages = <String>{
    'cmb.pb', // 招商银行
    'com.icbc', // 工商银行
    'com.ccb.longjiLife', // 建设银行
    'com.android.bankabc', // 农业银行
    'com.chinamworld.bocmbci', // 中国银行
    'com.bankcomm.Bankcomm', // 交通银行
    'com.yitong.mbank.psbc', // 邮储银行
    'com.ecitic.bank.mobile', // 中信银行
    'com.cebbank.mobile.cemb', // 光大银行
    'com.cmbc.cc.mbank', // 民生银行
    'com.pingan.paces.ccms', // 平安银行
    'com.spdbccc.app', // 浦发银行
    'com.cib.xyk', // 兴业银行
    'com.cgbchina.xpt', // 广发银行
    'com.huaxia.mobilebank', // 华夏银行
    'com.bankofbeijing.mobilebanking', // 北京银行
    'com.unionpay', // 云闪付
  };

  /// 银行 App 包名白名单（供原生侧与来源映射共用）
  ///
  /// @return 只读包名集合
  static Set<String> get bankPackages => _bankPackages;

  /// 根据通知来源包名判断支付来源
  ///
  /// @param packageName 来源包名
  /// @return 对应的 [PaymentSource]；未知包名按支付宝处理
  static PaymentSource sourceForPackage(String packageName) {
    if (packageName == 'com.tencent.mm') return PaymentSource.wechat;
    if (_bankPackages.contains(packageName)) return PaymentSource.bank;
    return PaymentSource.alipay;
  }

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
    } else if (_bankPackages.contains(packageName)) {
      return _parseBank(text);
    }
    return null;
  }

  /// 银行通知通用金额正则（「12.34元」「￥12.34」两种写法都由 _extractAmount 兜底）
  static final RegExp _bankAmountPattern =
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:元|￥|¥)');

  /// 银行通知商户正则（只取明确的商户线索：「在XX消费」「商户：XX」）
  ///
  /// WHY: 银行文案常见「于10月23日支出」，若把「于…」也当商户会得到日期，
  /// 故只保留明确的商户表述，其余留空由用户确认
  static final RegExp _bankMerchantPattern =
      RegExp(r'在(.+?)消费|商户[:：]\s*(.+?)(?=\s|[￥¥]|$)|收款方[:：]\s*(.+?)(?=\s|[￥¥]|$)');

  /// 解析银行 App 消息提醒
  ///
  /// @param text 通知文本
  /// @return 解析结果，无法提取金额时返回 null
  static ParsedPayment? _parseBank(String text) {
    final amount = _extractAmount(text, _bankAmountPattern);
    if (amount == null || amount <= Decimal.zero) return null;

    final merMatch = _bankMerchantPattern.firstMatch(text);
    String? merchant;
    if (merMatch != null) {
      merchant = (merMatch.group(1) ?? merMatch.group(2) ?? merMatch.group(3))
          ?.trim();
      if (merchant != null && merchant.isEmpty) merchant = null;
    }

    return ParsedPayment(
      amount: amount,
      merchant: merchant,
      source: PaymentSource.bank,
      rawText: text,
      timestamp: DateTime.now(),
      isIncome: detectIncome(text),
    );
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

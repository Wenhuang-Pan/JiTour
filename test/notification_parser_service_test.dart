import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/models/pending_transaction.dart' show PaymentSource;
import 'package:jitu/services/notification_parser_service.dart';

/// 通知文本解析服务测试
///
/// WHY: 自动记账的金额/商户/收支方向解析依赖正则，历史上有「收款方」
/// 误判收入的缺陷（v3.3.0 修复），此处固化关键行为防回归
void main() {
  group('NotificationParserService.parse 包名分流', () {
    test('支付宝包名走支付宝解析', () {
      final result = NotificationParserService.parse(
          '你在全家便利店消费了15.00元', 'com.eg.android.AlipayGphone');
      expect(result, isNotNull);
      expect(result!.source, PaymentSource.alipay);
    });

    test('微信包名走微信解析', () {
      final result =
          NotificationParserService.parse('微信支付付款给超市30.00元', 'com.tencent.mm');
      expect(result, isNotNull);
      expect(result!.source, PaymentSource.wechat);
    });

    test('未知包名返回 null', () {
      final result = NotificationParserService.parse('消费了10.00元', 'com.other');
      expect(result, isNull);
    });
  });

  group('支付宝解析', () {
    test('支出：在XXX消费 提取金额与商户', () {
      final result = NotificationParserService.parse(
          '你在全家便利店消费了15.00元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('15.00'));
      expect(result.merchant, '全家便利店');
      expect(result.isIncome, isFalse);
    });

    test('支出：向XXX付款 提取商户', () {
      final result = NotificationParserService.parse(
          '向星巴克付款 35.50元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('35.50'));
      expect(result.merchant, '星巴克');
    });

    test('支出：收款方标签不得误判为收入', () {
      // WHY: 「收款方:XXX」是支出页面的商户名标签，历史上曾因裸匹配
      // 「收款」关键词造成误判收入，此处固化防回归。
      final result = NotificationParserService.parse(
          '消费了20.00元 收款方:瑞幸咖啡', 'com.eg.android.AlipayGphone');
      expect(result!.isIncome, isFalse);
      expect(result.merchant, '瑞幸咖啡');
    });

    test('支出：收款方后同行尾随金额不被吞入商户名', () {
      // WHY: 修复前「收款方[:：]」以行尾 $ 锚定，商户名后同行的金额文本
      // 会被一并带入商户名（如「瑞幸咖啡 20.00元」），现已修复。
      final result = NotificationParserService.parse(
          '收款方:瑞幸咖啡 20.00元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('20.00'));
      expect(result.merchant, '瑞幸咖啡');
    });

    test('收入：成功收款 判定为收入', () {
      final result = NotificationParserService.parse(
          '支付宝成功收款100.00元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('100.00'));
      expect(result.isIncome, isTrue);
    });

    test('收入：退款到账 判定为收入', () {
      final result = NotificationParserService.parse(
          '退款到账 8.90元', 'com.eg.android.AlipayGphone');
      expect(result!.isIncome, isTrue);
    });
  });

  group('微信解析', () {
    test('支出：付款给XXX 提取金额与商户', () {
      final result =
          NotificationParserService.parse('¥30.00 付款给楼下超市', 'com.tencent.mm');
      expect(result!.amount, Decimal.parse('30.00'));
      expect(result.merchant, '楼下超市');
      expect(result.isIncome, isFalse);
    });

    test('支出：付款给后同行尾随金额不被吞入商户名', () {
      // WHY: 修复前「付款给」以行尾 $ 锚定，商户名后同行的金额会被吞入，
      // 商户名变成「楼下超市 ¥30.00」，现已修复为前瞻到空白/金额符号/行尾。
      final result =
          NotificationParserService.parse('付款给楼下超市 ¥30.00', 'com.tencent.mm');
      expect(result!.amount, Decimal.parse('30.00'));
      expect(result.merchant, '楼下超市');
    });

    test('支出：付款给后直接接金额符号也能截断', () {
      final result = NotificationParserService.parse(
          '微信支付付款给楼下超市¥30.00', 'com.tencent.mm');
      expect(result!.merchant, '楼下超市');
    });

    test('收入：收款成功 判定为收入', () {
      final result =
          NotificationParserService.parse('微信支付收款成功20.00元', 'com.tencent.mm');
      expect(result!.amount, Decimal.parse('20.00'));
      expect(result.isIncome, isTrue);
    });

    test('收入：收到红包 判定为收入', () {
      final result =
          NotificationParserService.parse('收到红包 66.66元', 'com.tencent.mm');
      expect(result!.isIncome, isTrue);
    });
  });

  group('金额解析边界', () {
    test('符号在前形式（无障碍通道）可解析', () {
      final result =
          NotificationParserService.parse('支付成功 ￥12.50', 'com.tencent.mm');
      expect(result!.amount, Decimal.parse('12.50'));
    });

    test('1 位小数金额可解析', () {
      final result = NotificationParserService.parse(
          '消费了12.5元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('12.5'));
    });

    test('整数金额可解析', () {
      final result = NotificationParserService.parse(
          '消费了3元', 'com.eg.android.AlipayGphone');
      expect(result!.amount, Decimal.parse('3'));
    });

    test('无金额文本返回 null', () {
      final result = NotificationParserService.parse(
          '你的账单已生成', 'com.eg.android.AlipayGphone');
      expect(result, isNull);
    });

    test('金额为零返回 null', () {
      final result = NotificationParserService.parse(
          '消费了0.00元', 'com.eg.android.AlipayGphone');
      expect(result, isNull);
    });
  });

  group('detectIncome 关键词判定', () {
    test('明确收入短语返回 true', () {
      expect(NotificationParserService.detectIncome('转账到账 100元'), isTrue);
      expect(NotificationParserService.detectIncome('退款成功'), isTrue);
    });

    test('含收款方的支出文本返回 false', () {
      // WHY: 「收款方」为支出页商户标签，不得命中收入关键词
      expect(NotificationParserService.detectIncome('收款方:张三 消费了5元'), isFalse);
    });

    test('普通支出文本返回 false', () {
      expect(NotificationParserService.detectIncome('你在便利店消费了10.00元'), isFalse);
    });
  });
}

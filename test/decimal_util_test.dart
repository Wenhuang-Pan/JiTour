// WHY: v3 金额精度改造回归测试，守护旧 double 数据的惰性兼容逻辑
// 若 parseDecimal 行为变更导致旧数据无法正确还原，会造成用户余额错误
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/utils/decimal_util.dart';

void main() {
  test('parseDecimal 兼容旧 double / int / String / Decimal', () {
    // 旧版 Hive 中金额以 double 存储
    expect(parseDecimal(100.05), Decimal.parse('100.05'));
    expect(parseDecimal(0.1 + 0.2) == Decimal.parse('0.3'), isFalse);
    // int 场景
    expect(parseDecimal(2000), Decimal.parse('2000'));
    // 新版 String 场景
    expect(parseDecimal('88.88'), Decimal.parse('88.88'));
    // 已是 Decimal 原样返回
    final d = Decimal.parse('1.23');
    expect(identical(parseDecimal(d), d), isTrue);
    // 异常输入回退零
    expect(parseDecimal(null), Decimal.zero);
    expect(parseDecimal('abc'), Decimal.zero);
  });

  test('旧 double 数据经 Hive 读写后可正确还原为 Decimal', () async {
    final tmpDir = await Directory.systemTemp.createTemp('hive_migrate_');
    Hive.init(tmpDir.path);
    await DatabaseService.init();

    final box = await Hive.openBox<dynamic>('legacy_decimal_test');
    // 模拟旧版本直接写入 double 金额
    await box.put('old_amount', 123.45);
    await box.put('old_int', 100);
    await box.put('old_string', '66.66');

    // WHY: 新版统一通过 parseDecimal 读取历史数据
    expect(parseDecimal(box.get('old_amount')), Decimal.parse('123.45'));
    expect(parseDecimal(box.get('old_int')), Decimal.parse('100'));
    expect(parseDecimal(box.get('old_string')), Decimal.parse('66.66'));

    await box.deleteFromDisk();
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('金额适配器必须使用 parseDecimal 兼容读取（防 build_runner 覆盖回归）', () {
    // WHY: v3.0.0 曾遗漏 4 个适配器的裸 `as Decimal` 强转，旧 double 数据
    // 读取时抛 TypeError，导致启动白屏。重跑 build_runner 会重新生成强转代码，
    // 此测试直接扫描源码做静态守护，一旦回归立即变红
    const adapterFiles = <String>[
      'lib/models/transaction.g.dart',
      'lib/models/account.g.dart',
      'lib/models/debt.g.dart',
      'lib/models/savings_goal.g.dart',
      'lib/models/budget.g.dart',
      'lib/models/recurring_transaction.g.dart',
      'lib/models/pending_transaction.g.dart',
      'lib/models/transaction_template.g.dart',
    ];
    for (final path in adapterFiles) {
      final content = File(path).readAsStringSync();
      expect(
        content.contains('as Decimal'),
        isFalse,
        reason: '$path 存在裸 `as Decimal` 强转，旧 double 数据读取会崩溃',
      );
    }
  });
}

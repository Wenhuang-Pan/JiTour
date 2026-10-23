import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/services/database_service.dart';
// 根据被测服务调整 import

void main() {
  // WHY: 服务层可能通过 MethodChannel 调用原生，必须先初始化 binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XxxService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_xxx_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      // WHY: 清理被测服务依赖的所有 box，防止用例间数据污染
      await DatabaseService.transactions.clear();
      // await DatabaseService.pendingTransactions.clear();
      // await AccountService.box.clear();
    });

    tearDown(() async {
      try {
        await Hive.close();
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    test('描述测试意图', () async {
      // 安排 (Arrange)
      // 执行 (Act)
      // 断言 (Assert) — 金额用 Decimal，禁止 double
    });
  });
}

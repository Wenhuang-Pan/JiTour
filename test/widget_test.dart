import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jitu/main.dart';
import 'package:jitu/providers/auto_accounting_provider.dart';
import 'package:jitu/providers/currency_provider.dart';
import 'package:jitu/providers/reminder_provider.dart';
import 'package:jitu/providers/theme_provider.dart';
import 'package:jitu/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ThemeProvider themeProvider;
  late CurrencyProvider currencyProvider;
  late ReminderProvider reminderProvider;

  setUpAll(() async {
    // WHY: widget 测试运行在 Dart VM，无 path_provider 原生插件，
    // 需手动指定 Hive 存储目录；SharedPreferences 用 mock 初始值替代原生实现
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('jitu_widget_test');
    Hive.init(tempDir.path);
    await DatabaseService.init();

    // WHY: Provider 初始化含 Hive/SharedPreferences 真实 IO，必须放在 setUpAll
    // （普通事件循环 zone）；testWidgets 的测试体运行在 FakeAsync 下，
    // await 真实 IO Future 会永久挂起直至 10 分钟超时
    themeProvider = ThemeProvider();
    await themeProvider.init();

    currencyProvider = CurrencyProvider();
    await currencyProvider.init();

    reminderProvider = ReminderProvider();
    await reminderProvider.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('记途应用启动测试', (WidgetTester tester) async {
    // WHY: AutoAccountingProvider.init 会调用原生 MethodChannel（通知监听/悬浮窗），
    // widget 测试环境无原生实现会抛 MissingPluginException，故仅构造不初始化，
    // 其字段均有安全默认值，不影响界面构建
    final autoAccountingProvider = AutoAccountingProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<CurrencyProvider>.value(
              value: currencyProvider),
          ChangeNotifierProvider<ReminderProvider>.value(
              value: reminderProvider),
          ChangeNotifierProvider<AutoAccountingProvider>.value(
              value: autoAccountingProvider),
        ],
        child: const JituApp(),
      ),
    );
    await tester.pump();

    expect(find.text('记途'), findsWidgets);
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/widgets/ai_config_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiConfigDialog', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_ai_dialog_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      await DatabaseService.aiConfig.clear();
    });

    tearDown(() async {
      try {
        await Hive.close();
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    /// 打开配置弹窗
    ///
    /// @param tester 测试上下文
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiConfigDialog.show(ctx),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('打开后展示服务商/Key/模型/端点四项配置', (WidgetTester tester) async {
      await openDialog(tester);
      expect(find.text('AI 助手配置'), findsOneWidget);
      expect(find.text('服务商'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('模型'), findsOneWidget);
      expect(find.text('端点地址'), findsOneWidget);
      // 默认服务商为智谱
      expect(find.text('智谱 AI'), findsOneWidget);
      // WHY: 布局异常会以 exception 形式暴露，此处断言无渲染异常
      expect(tester.takeException(), isNull);
    });

    testWidgets('模型搜索面板可按关键字过滤', (WidgetTester tester) async {
      await openDialog(tester);
      await tester.tap(find.byTooltip('搜索模型'));
      await tester.pumpAndSettle();

      expect(find.text('搜索或输入模型名'), findsOneWidget);
      final Finder searchField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'glm');
      await tester.pumpAndSettle();

      // WHY: 模型输入框当前值也是 glm-4.7-flash，需限定在底部面板内查找
      final Finder inSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('glm-4.7-flash'),
      );
      expect(inSheet, findsOneWidget);
      expect(find.text('deepseek-chat'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('服务商列表可切换到 DeepSeek 并联动模型与端点', (WidgetTester tester) async {
      await openDialog(tester);
      await tester.tap(find.text('智谱 AI'));
      await tester.pumpAndSettle();

      expect(find.text('DeepSeek'), findsOneWidget);
      expect(find.text('通义千问（阿里云百炼）'), findsOneWidget);
      expect(find.text('Kimi（Moonshot）'), findsOneWidget);

      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();

      // WHY: 切换服务商后模型与端点应联动更新
      expect(find.text('deepseek-chat'), findsOneWidget);
      expect(find.text('https://api.deepseek.com/v1/chat/completions'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

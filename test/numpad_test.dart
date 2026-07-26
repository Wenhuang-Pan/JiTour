import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitu/widgets/numpad.dart';

void main() {
  group('Numpad Widget', () {
    testWidgets('显示数字键盘', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets('数字按钮点击回调', (WidgetTester tester) async {
      String pressedNumber = '';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (number) => pressedNumber = number,
              onDeletePressed: () {},
              onSavePressed: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('5'));
      expect(pressedNumber, '5');

      await tester.tap(find.text('.'));
      expect(pressedNumber, '.');

      await tester.tap(find.text('0'));
      expect(pressedNumber, '0');
    });

    testWidgets('删除按钮点击回调', (WidgetTester tester) async {
      bool deletePressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () => deletePressed = true,
              onSavePressed: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(deletePressed, true);
    });

    testWidgets('保存按钮点击回调', (WidgetTester tester) async {
      bool savePressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () => savePressed = true,
              canSave: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      expect(savePressed, true);
    });

    testWidgets('保存按钮在canSave为false时禁用', (WidgetTester tester) async {
      bool savePressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () => savePressed = true,
              canSave: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      expect(savePressed, false);
    });

    testWidgets('再记按钮点击回调', (WidgetTester tester) async {
      bool saveAndAddPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              onSaveAndAddPressed: () => saveAndAddPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('再记'));
      expect(saveAndAddPressed, true);
    });

    testWidgets('显示备注输入框', (WidgetTester tester) async {
      final noteController = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              noteController: noteController,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('备注...'), findsOneWidget);
    });

    testWidgets('备注输入框可以输入内容', (WidgetTester tester) async {
      final noteController = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              noteController: noteController,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试备注');
      expect(noteController.text, '测试备注');
    });

    testWidgets('显示选项按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              selectedAccountName: '现金',
              timeText: '今天',
              couponText: '5元',
              tagText: '标签1',
              isReimbursed: false,
            ),
          ),
        ),
      );

      expect(find.text('现金'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('报销'), findsOneWidget);
      expect(find.text('5元'), findsOneWidget);
      expect(find.text('标签1'), findsOneWidget);
    });

    testWidgets('报销按钮激活状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              isReimbursed: true,
            ),
          ),
        ),
      );

      expect(find.text('报销'), findsOneWidget);
    });

    testWidgets('选项按钮点击回调', (WidgetTester tester) async {
      bool accountTapped = false;
      bool dateTapped = false;
      bool reimbursedTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Numpad(
              onNumberPressed: (_) {},
              onDeletePressed: () {},
              onSavePressed: () {},
              selectedAccountName: '现金',
              onAccountTap: () => accountTapped = true,
              onDateTap: () => dateTapped = true,
              onReimbursedTap: () => reimbursedTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('现金'));
      expect(accountTapped, true);

      await tester.tap(find.text('今天'));
      expect(dateTapped, true);

      await tester.tap(find.text('报销'));
      expect(reimbursedTapped, true);
    });
  });
}

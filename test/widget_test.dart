import 'package:flutter_test/flutter_test.dart';

import 'package:jitu/main.dart';

void main() {
  testWidgets('记途应用启动测试', (WidgetTester tester) async {
    // 测试应用能否正常启动
    await tester.pumpWidget(const SimpleLedgerApp());

    // 验证应用标题显示
    expect(find.text('记途'), findsWidgets);
  });
}

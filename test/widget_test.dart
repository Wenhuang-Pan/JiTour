import 'package:flutter_test/flutter_test.dart';

import 'package:jitu/main.dart';

void main() {
  testWidgets('记途应用启动测试', (WidgetTester tester) async {
    await tester.pumpWidget(const JituApp(isFirstLaunch: false));

    expect(find.text('记途'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jitu/services/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService', () {
    test('init 无历史记录时默认关闭', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppLockService.init();
      expect(AppLockService.isEnabled, isFalse);
    });

    test('setEnabled 持久化开关状态', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppLockService.init();

      await AppLockService.setEnabled(true);
      expect(AppLockService.isEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_lock_enabled'), isTrue);

      // WHY: 还原关闭状态，避免静态缓存影响同文件后续用例
      await AppLockService.setEnabled(false);
      expect(AppLockService.isEnabled, isFalse);
    });

    test('init 恢复已保存的开启状态', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{'app_lock_enabled': true});
      await AppLockService.init();
      expect(AppLockService.isEnabled, isTrue);

      await AppLockService.setEnabled(false);
    });

    test('插件不可用环境 canAuthenticate 安全降级返回 false', () async {
      // WHY: 单元测试运行在 Dart VM，无 local_auth 原生实现，
      // 会抛 MissingPluginException，服务须捕获并返回 false 而非向上抛出
      expect(await AppLockService.canAuthenticate(), isFalse);
    });

    test('插件不可用环境 authenticate 安全降级返回 false', () async {
      expect(await AppLockService.authenticate(reason: '测试'), isFalse);
    });
  });
}

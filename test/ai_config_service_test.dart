import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jitu/services/ai_config_service.dart';
import 'package:jitu/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiConfigService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_ai_config_');
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

    test('setApiKey 后 getApiKey 返回相同值', () async {
      await AiConfigService.setApiKey('test-api-key-123');
      expect(AiConfigService.getApiKey(), 'test-api-key-123');
      expect(AiConfigService.isConfigured(), isTrue);
    });

    test('clearApiKey 后 getApiKey 返回 null，isConfigured 返回 false', () async {
      await AiConfigService.setApiKey('test-api-key-123');
      await AiConfigService.clearApiKey();
      expect(AiConfigService.getApiKey(), isNull);
      expect(AiConfigService.isConfigured(), isFalse);
    });

    test('未配置时 isConfigured 返回 false', () {
      expect(AiConfigService.isConfigured(), isFalse);
      expect(AiConfigService.getApiKey(), isNull);
    });

    test('空字符串抛 ArgumentError', () async {
      expect(
        () => AiConfigService.setApiKey(''),
        throwsArgumentError,
      );
    });

    test('空白字符串也抛 ArgumentError', () async {
      expect(
        () => AiConfigService.setApiKey('   '),
        throwsArgumentError,
      );
    });

    test('未配置时 getModel 返回默认模型', () {
      expect(AiConfigService.getModel(), AiConfigService.defaultModel);
    });

    test('setModel 后 getModel 返回相同值', () async {
      await AiConfigService.setModel('glm-4-flash');
      expect(AiConfigService.getModel(), 'glm-4-flash');
    });

    test('setModel 自动 trim 首尾空白', () async {
      await AiConfigService.setModel('  glm-4.7-flash  ');
      expect(AiConfigService.getModel(), 'glm-4.7-flash');
    });

    test('setModel 传空白字符串恢复默认模型', () async {
      await AiConfigService.setModel('glm-4-flash');
      expect(AiConfigService.getModel(), 'glm-4-flash');
      await AiConfigService.setModel('   ');
      expect(AiConfigService.getModel(), AiConfigService.defaultModel);
    });
  });
}

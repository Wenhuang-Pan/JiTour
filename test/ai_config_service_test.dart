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

    test('未配置服务商时默认使用智谱，端点与默认模型正确', () {
      expect(AiConfigService.getProviderId(), 'zhipu');
      expect(AiConfigService.getProvider().name, '智谱 AI');
      expect(
        AiConfigService.getBaseUrl(),
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
      expect(AiConfigService.getModel(), 'glm-4.7-flash');
    });

    test('切换服务商后端点与默认模型跟随变化', () async {
      await AiConfigService.setProvider('deepseek');
      expect(AiConfigService.getProviderId(), 'deepseek');
      expect(
        AiConfigService.getBaseUrl(),
        'https://api.deepseek.com/v1/chat/completions',
      );
      expect(AiConfigService.getModel(), 'deepseek-chat');
      expect(AiConfigService.getModelOptions(), contains('deepseek-reasoner'));
    });

    test('切换服务商时清除上一家的自定义端点', () async {
      await AiConfigService.setProvider('zhipu');
      await AiConfigService.setBaseUrl('https://proxy.example.com/v1/chat');
      expect(AiConfigService.getBaseUrl(), 'https://proxy.example.com/v1/chat');

      await AiConfigService.setProvider('qwen');
      // WHY: 切换后不能残留旧自定义端点，否则请求会打到错误地址
      expect(
        AiConfigService.getBaseUrl(),
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      );
    });

    test('自定义端点优先于预设端点', () async {
      await AiConfigService.setProvider('moonshot');
      await AiConfigService.setBaseUrl('https://my-proxy.example.com/v1/chat');
      expect(AiConfigService.getBaseUrl(), 'https://my-proxy.example.com/v1/chat');
    });

    test('setBaseUrl 传空白字符串恢复预设端点', () async {
      await AiConfigService.setProvider('openai');
      await AiConfigService.setBaseUrl('https://proxy.example.com/v1/chat');
      await AiConfigService.setBaseUrl('   ');
      expect(
        AiConfigService.getBaseUrl(),
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('未知服务商 ID 回落为自定义预设', () async {
      await AiConfigService.setProvider('unknown-provider');
      expect(AiConfigService.getProvider().id, 'custom');
      expect(AiConfigService.getModelOptions(), isEmpty);
      // WHY: 自定义服务商无默认模型，回落兜底默认模型避免空串
      expect(AiConfigService.getModel(), AiConfigService.defaultModel);
    });

    test('内置服务商预设共六项且 id 唯一', () {
      expect(AiConfigService.presets.length, 6);
      final List<String> ids =
          AiConfigService.presets.map((AiProviderPreset p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}

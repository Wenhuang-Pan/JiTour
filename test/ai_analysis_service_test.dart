import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitu/services/ai_analysis_service.dart';
import 'package:jitu/services/ai_config_service.dart';
import 'package:jitu/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiAnalysisService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_ai_analysis_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      await DatabaseService.aiConfig.clear();
      await DatabaseService.transactions.clear();
    });

    tearDown(() async {
      try {
        await Hive.close();
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    test('未配置 Key 时抛出 notConfigured 异常', () async {
      expect(
        () => AiAnalysisService.analyze(),
        throwsA(isA<AiAnalysisException>().having(
          (e) => e.type,
          'type',
          AiAnalysisError.notConfigured,
        )),
      );
    });

    test('成功响应时返回 AI 文本', () async {
      await AiConfigService.setApiKey('valid-key');
      final mockClient = MockClient((request) async {
        // WHY: 验证请求格式正确
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer valid-key');
        expect(request.headers['Content-Type'], 'application/json');
        return http.Response(
          '{"choices":[{"message":{"content":"AI result text"}}]}',
          200,
        );
      });

      final result = await AiAnalysisService.analyze(client: mockClient);
      expect(result, 'AI result text');
    });

    test('401 响应时抛出 invalidApiKey 异常', () async {
      await AiConfigService.setApiKey('invalid-key');
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      expect(
        () => AiAnalysisService.analyze(client: mockClient),
        throwsA(isA<AiAnalysisException>().having(
          (e) => e.type,
          'type',
          AiAnalysisError.invalidApiKey,
        )),
      );
    });

    test('5xx 响应时抛出 serverError 异常', () async {
      await AiConfigService.setApiKey('valid-key');
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      expect(
        () => AiAnalysisService.analyze(client: mockClient),
        throwsA(isA<AiAnalysisException>().having(
          (e) => e.type,
          'type',
          AiAnalysisError.serverError,
        )),
      );
    });

    test('发送的数据不含商户名或账户名', () async {
      await AiConfigService.setApiKey('valid-key');
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          json.encode({
            'choices': [
              {
                'message': {'content': 'ok'}
              }
            ]
          }),
          200,
        );
      });

      await AiAnalysisService.analyze(client: mockClient);

      // WHY: 验证发送的 Prompt 中不含商户名、账户名等敏感字段
      expect(capturedBody, isNotNull);
      expect(capturedBody!.contains('merchant'), isFalse);
      expect(capturedBody!.contains('account'), isFalse);
    });

    test('不同模板生成不同的 Prompt', () async {
      await AiConfigService.setApiKey('valid-key');
      final bodies = <String>[];
      final mockClient = MockClient((request) async {
        bodies.add(request.body);
        return http.Response(
          json.encode({
            'choices': [
              {
                'message': {'content': 'ok'}
              }
            ]
          }),
          200,
        );
      });

      await AiAnalysisService.analyze(
        template: AnalysisTemplate.expenseStructure,
        client: mockClient,
      );
      await AiAnalysisService.analyze(
        template: AnalysisTemplate.savingsAdvice,
        client: mockClient,
      );

      expect(bodies.length, 2);
      expect(bodies[0] != bodies[1], isTrue);
    });
  });
}

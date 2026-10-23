import 'package:flutter/foundation.dart' show debugPrint;
import 'database_service.dart';

/// AI 助手配置服务
///
/// WHY: 管理智谱 AI API Key 的读写，不硬编码密钥，
/// 由用户在设置页自行配置。Key 存储在 Hive 独立 box 中。
class AiConfigService {
  AiConfigService._();

  /// API Key 在 Hive box 中的存储键名
  static const String _apiKeyField = 'api_key';

  /// 获取已配置的 API Key。
  ///
  /// @return API Key 字符串；未配置返回 null。
  static String? getApiKey() {
    try {
      return DatabaseService.aiConfig.get(_apiKeyField);
    } catch (e) {
      // WHY: 读取失败时记录日志并返回 null，避免阻断 UI 流程
      debugPrint('[AiConfig] getApiKey 异常: $e');
      return null;
    }
  }

  /// 保存 API Key。
  ///
  /// @param apiKey 智谱开放平台的 API Key。
  /// @return Future 完成持久化。
  /// @throws ArgumentError 当 apiKey 为空字符串时抛出。
  static Future<void> setApiKey(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API Key 不能为空');
    }
    try {
      await DatabaseService.aiConfig.put(_apiKeyField, apiKey.trim());
      debugPrint('[AiConfig] setApiKey 成功');
    } catch (e) {
      // WHY: 保存失败需抛出，让上层提示用户，禁止静默失败
      debugPrint('[AiConfig] setApiKey 失败: $e');
      rethrow;
    }
  }

  /// 清除已保存的 API Key。
  ///
  /// @return Future 完成删除。
  static Future<void> clearApiKey() async {
    try {
      await DatabaseService.aiConfig.delete(_apiKeyField);
      debugPrint('[AiConfig] clearApiKey 成功');
    } catch (e) {
      debugPrint('[AiConfig] clearApiKey 失败: $e');
      rethrow;
    }
  }

  /// 是否已配置 API Key。
  ///
  /// @return true 表示已配置非空 Key；false 表示未配置。
  static bool isConfigured() {
    final key = getApiKey();
    return key != null && key.isNotEmpty;
  }
}

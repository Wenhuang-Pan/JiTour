import 'package:flutter/foundation.dart' show debugPrint;
import 'database_service.dart';

/// AI 助手配置服务
///
/// WHY: 管理智谱 AI API Key 与模型名的读写，不硬编码密钥，
/// 由用户在设置页自行配置。配置存储在 Hive 独立 box 中。
/// 模型名可配置的原因：智谱免费模型持续迭代（如 glm-4-flash →
/// glm-4.7-flash），模型名开放配置后无需发版即可跟进升级。
class AiConfigService {
  AiConfigService._();

  /// API Key 在 Hive box 中的存储键名
  static const String _apiKeyField = 'api_key';

  /// 模型名在 Hive box 中的存储键名
  static const String _modelField = 'model';

  /// 默认模型名（智谱当前免费模型）
  static const String defaultModel = 'glm-4.7-flash';

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

  /// 获取当前使用的模型名。
  ///
  /// WHY: 模型名可配置，智谱免费模型升级时用户改配置即可，无需 app 发版。
  ///
  /// @return 已配置的模型名；未配置或配置为空时返回默认模型 [defaultModel]。
  static String getModel() {
    try {
      final stored = DatabaseService.aiConfig.get(_modelField);
      if (stored == null || stored.trim().isEmpty) {
        return defaultModel;
      }
      return stored.trim();
    } catch (e) {
      debugPrint('[AiConfig] getModel 异常: $e');
      return defaultModel;
    }
  }

  /// 保存模型名。
  ///
  /// @param model 智谱模型名（如 glm-4.7-flash）。空白字符串表示恢复默认。
  /// @return Future 完成持久化。空白输入会清除已存配置（回到默认模型）。
  static Future<void> setModel(String model) async {
    final trimmed = model.trim();
    try {
      if (trimmed.isEmpty) {
        // WHY: 空输入语义为「恢复默认」，清除已存配置
        await DatabaseService.aiConfig.delete(_modelField);
        debugPrint('[AiConfig] setModel 清除配置，恢复默认');
      } else {
        await DatabaseService.aiConfig.put(_modelField, trimmed);
        debugPrint('[AiConfig] setModel 成功: $trimmed');
      }
    } catch (e) {
      debugPrint('[AiConfig] setModel 失败: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart' show debugPrint;
import 'database_service.dart';

/// AI 服务商预设
///
/// WHY: 各家大模型均提供 OpenAI 兼容的 chat/completions 接口，
/// 差异仅在端点地址与模型名。把服务商做成预设 + 可自定义端点，
/// 用户可在智谱 / DeepSeek / 通义 / Kimi / OpenAI 之间自由切换。
class AiProviderPreset {
  /// 服务商标识（持久化用）
  final String id;

  /// 服务商展示名称
  final String name;

  /// OpenAI 兼容的 chat/completions 端点
  final String baseUrl;

  /// 内置可选模型列表
  final List<String> models;

  /// 该服务商默认模型
  final String defaultModel;

  /// 构造服务商预设
  ///
  /// @param id 服务商标识
  /// @param name 展示名称
  /// @param baseUrl 端点地址
  /// @param models 可选模型列表
  /// @param defaultModel 默认模型
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.models,
    required this.defaultModel,
  });
}

/// AI 助手配置服务
///
/// WHY: 管理 API Key、服务商、端点与模型名的读写，不硬编码密钥。
/// 模型名与服务商均可配置：新模型上线或更换厂商时用户改配置即可，
/// 无需 app 发版。
class AiConfigService {
  AiConfigService._();

  /// API Key 在 Hive box 中的存储键名
  static const String _apiKeyField = 'api_key';

  /// 模型名在 Hive box 中的存储键名
  static const String _modelField = 'model';

  /// 服务商 ID 在 Hive box 中的存储键名
  static const String _providerField = 'provider_id';

  /// 自定义端点地址在 Hive box 中的存储键名
  static const String _baseUrlField = 'base_url';

  /// 默认模型名（智谱当前免费模型）
  static const String defaultModel = 'glm-4.7-flash';

  /// 自定义服务商（用户手填端点地址）
  static const AiProviderPreset customPreset = AiProviderPreset(
    id: 'custom',
    name: '自定义（OpenAI 兼容）',
    baseUrl: '',
    models: <String>[],
    defaultModel: '',
  );

  /// 内置服务商预设列表
  static const List<AiProviderPreset> presets = <AiProviderPreset>[
    AiProviderPreset(
      id: 'zhipu',
      name: '智谱 AI',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      models: <String>[
        'glm-4.7-flash',
        'glm-4.6-flash',
        'glm-4-flash',
        'glm-4-flash-250414',
        'glm-4-air',
        'glm-4-plus',
      ],
      defaultModel: 'glm-4.7-flash',
    ),
    AiProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1/chat/completions',
      models: <String>[
        'deepseek-chat',
        'deepseek-reasoner',
      ],
      defaultModel: 'deepseek-chat',
    ),
    AiProviderPreset(
      id: 'qwen',
      name: '通义千问（阿里云百炼）',
      baseUrl:
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      models: <String>[
        'qwen-flash',
        'qwen-turbo',
        'qwen-plus',
        'qwen-max',
        'qwen3-max',
      ],
      defaultModel: 'qwen-flash',
    ),
    AiProviderPreset(
      id: 'moonshot',
      name: 'Kimi（Moonshot）',
      baseUrl: 'https://api.moonshot.cn/v1/chat/completions',
      models: <String>[
        'kimi-k2-0905-preview',
        'kimi-k2-turbo-preview',
        'moonshot-v1-8k',
        'moonshot-v1-32k',
        'moonshot-v1-128k',
      ],
      defaultModel: 'kimi-k2-turbo-preview',
    ),
    AiProviderPreset(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      models: <String>[
        'gpt-4o-mini',
        'gpt-4o',
        'gpt-5-mini',
        'o4-mini',
      ],
      defaultModel: 'gpt-4o-mini',
    ),
    customPreset,
  ];

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
  /// @param apiKey 服务商的 API Key。
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

  /// 获取当前服务商标识。
  ///
  /// @return 服务商 ID；未配置返回 'zhipu'。
  static String getProviderId() {
    try {
      final stored = DatabaseService.aiConfig.get(_providerField);
      if (stored == null || stored.trim().isEmpty) return 'zhipu';
      return stored.trim();
    } catch (e) {
      debugPrint('[AiConfig] getProviderId 异常: $e');
      return 'zhipu';
    }
  }

  /// 获取当前服务商预设。
  ///
  /// @return 匹配的服务商预设；未匹配到返回 [customPreset]。
  static AiProviderPreset getProvider() {
    final id = getProviderId();
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return customPreset;
  }

  /// 切换服务商。
  ///
  /// WHY: 切换时必须清掉已保存的端点地址，否则会残留上一家服务商的
  /// 自定义端点，导致请求打到错误的地址。
  ///
  /// @param providerId 服务商标识。
  /// @return Future 完成持久化。
  static Future<void> setProvider(String providerId) async {
    try {
      await DatabaseService.aiConfig.put(_providerField, providerId.trim());
      await DatabaseService.aiConfig.delete(_baseUrlField);
      debugPrint('[AiConfig] setProvider 成功: $providerId');
    } catch (e) {
      debugPrint('[AiConfig] setProvider 失败: $e');
      rethrow;
    }
  }

  /// 获取实际使用的端点地址。
  ///
  /// @return 用户自定义端点；未自定义时返回当前服务商预设端点。
  static String getBaseUrl() {
    try {
      final stored = DatabaseService.aiConfig.get(_baseUrlField);
      if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    } catch (e) {
      debugPrint('[AiConfig] getBaseUrl 异常: $e');
    }
    return getProvider().baseUrl;
  }

  /// 保存自定义端点地址。
  ///
  /// @param baseUrl OpenAI 兼容的 chat/completions 端点。留空表示用预设端点。
  /// @return Future 完成持久化。
  static Future<void> setBaseUrl(String baseUrl) async {
    final trimmed = baseUrl.trim();
    try {
      if (trimmed.isEmpty) {
        await DatabaseService.aiConfig.delete(_baseUrlField);
      } else {
        await DatabaseService.aiConfig.put(_baseUrlField, trimmed);
      }
      debugPrint('[AiConfig] setBaseUrl: $trimmed');
    } catch (e) {
      debugPrint('[AiConfig] setBaseUrl 失败: $e');
      rethrow;
    }
  }

  /// 获取当前服务商的内置模型候选列表。
  ///
  /// @return 模型名列表；自定义服务商返回空列表。
  static List<String> getModelOptions() => getProvider().models;

  /// 获取当前使用的模型名。
  ///
  /// WHY: 模型名可配置，新模型上线时用户改配置即可，无需 app 发版。
  ///
  /// @return 已配置的模型名；未配置时返回当前服务商的默认模型。
  static String getModel() {
    try {
      final stored = DatabaseService.aiConfig.get(_modelField);
      if (stored != null && stored.trim().isNotEmpty) {
        return stored.trim();
      }
    } catch (e) {
      debugPrint('[AiConfig] getModel 异常: $e');
    }
    final providerDefault = getProvider().defaultModel;
    return providerDefault.isEmpty ? defaultModel : providerDefault;
  }

  /// 保存模型名。
  ///
  /// @param model 模型名（如 glm-4.7-flash）。空白字符串表示恢复服务商默认。
  /// @return Future 完成持久化。空白输入会清除已存配置。
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

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:decimal/decimal.dart';
import 'ai_config_service.dart';
import 'database_service.dart';
import 'stats_service.dart';

/// AI 分析异常类型
enum AiAnalysisError {
  /// 未配置 API Key
  notConfigured,

  /// API Key 无效（401）
  invalidApiKey,

  /// 网络请求失败
  networkError,

  /// 服务端错误（5xx）
  serverError,

  /// 触发服务端频率限制（429）
  rateLimited,

  /// 请求超时
  timeout,

  /// 响应解析失败
  parseError,
}

/// 分析模板类型
enum AnalysisTemplate {
  /// 消费结构分析
  expenseStructure,

  /// 异常支出提醒
  abnormalExpense,

  /// 储蓄优化建议
  savingsAdvice,
}

/// AI 分析异常
class AiAnalysisException implements Exception {
  /// 异常类型
  final AiAnalysisError type;

  /// 异常描述
  final String message;

  /// 构造 AI 分析异常
  ///
  /// @param type 异常类型
  /// @param message 异常描述
  const AiAnalysisException(this.type, this.message);

  @override
  String toString() => 'AiAnalysisException($type): $message';
}

/// 账单 AI 分析服务
///
/// WHY: 将脱敏的账单汇总数据发送给智谱 GLM-4-Flash，
/// 返回消费结构分析、异常支出提醒、储蓄建议等自然语言解读。
/// 数据仅包含分类维度汇总，不含商户名/账户名等敏感信息。
class AiAnalysisService {
  AiAnalysisService._();

  /// 智谱 API 端点（OpenAI 兼容格式）
  ///
  /// WHY: 端点从配置读取，支持切换到 DeepSeek / 通义 / Kimi / OpenAI
  /// 等任意 OpenAI 兼容服务商；自定义端点优先。
  static String get _apiEndpoint => AiConfigService.getBaseUrl();

  /// 使用的模型名称
  ///
  /// WHY: 从 AiConfigService 运行时读取（默认 glm-4.7-flash），
  /// 智谱免费模型升级时用户改配置即可，无需发版。
  static String get _model => AiConfigService.getModel();

  /// 请求超时时间
  static const Duration _timeout = Duration(seconds: 30);

  /// 执行账单 AI 分析。
  ///
  /// WHY: 主入口方法，完成「取数 → 脱敏聚合 → 构造 Prompt → 调用 API → 解析结果」全流程。
  ///
  /// @param template 分析模板类型。
  /// @param days 分析天数（默认 30 天）。
  /// @param client 可选的 http.Client，用于测试时注入 mock。
  /// @return AI 分析的文本结果。
  /// @throws AiAnalysisException 未配置 Key、网络失败、Key 无效等场景。
  static Future<String> analyze({
    AnalysisTemplate template = AnalysisTemplate.expenseStructure,
    int days = 30,
    http.Client? client,
  }) async {
    // 1. 检查 API Key 是否配置
    final apiKey = AiConfigService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiAnalysisException(
        AiAnalysisError.notConfigured,
        '未配置 API Key，请先在设置中配置 AI 服务商的 API Key',
      );
    }

    // 2. 获取并脱敏账单数据
    final summary = _buildBillSummary(days);

    // 3. 构造 Prompt
    final prompt = _buildPrompt(template, summary);

    // 4. 调用 API
    final useClient = client ?? http.Client();
    try {
      return await _callApi(apiKey, prompt, useClient);
    } finally {
      // WHY: 若未注入外部 client，用完即关，避免连接泄漏
      if (client == null) useClient.close();
    }
  }

  /// 构建脱敏的账单汇总数据。
  ///
  /// WHY: 仅聚合分类维度的金额统计，不包含商户名、账户名等敏感信息。
  /// 时间复杂度：O(n)，n 为交易条数。
  ///
  /// @param days 统计天数。
  /// @return 脱敏的汇总数据 Map。
  static Map<String, Object> _buildBillSummary(int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final transactions = DatabaseService.getTransactionsInRange(startDate, now);

    final expenseTotal = StatsService.calculateTotal(transactions, false);
    final incomeTotal = StatsService.calculateTotal(transactions, true);
    final Map<String, Decimal> expenseByCategory =
        StatsService.calculateCategoryStats(transactions, false);
    final Map<String, Decimal> incomeByCategory =
        StatsService.calculateCategoryStats(transactions, true);

    // WHY: 计算最大单笔支出与日均支出
    Decimal maxExpense = Decimal.zero;
    for (final t in transactions) {
      if (!t.isIncome && t.amount > maxExpense) {
        maxExpense = t.amount;
      }
    }
    // WHY: 用 if-else 而非三元，避免 Dart 对 Decimal 运算符返回类型推断为 Object
    Decimal dailyAvg;
    if (days > 0) {
      // WHY: Decimal 的 ~/ 返回 BigInt，再转回 Decimal；日均取整足够分析用
      dailyAvg = Decimal.fromBigInt(expenseTotal ~/ Decimal.fromInt(days));
    } else {
      dailyAvg = Decimal.zero;
    }

    return <String, Object>{
      'period': '近$days天',
      'total_income': incomeTotal.toStringAsFixed(2),
      'total_expense': expenseTotal.toStringAsFixed(2),
      'expense_by_category': expenseByCategory.map<String, String>(
        (String k, Decimal v) => MapEntry(k, v.toStringAsFixed(2)),
      ),
      'income_by_category': incomeByCategory.map<String, String>(
        (String k, Decimal v) => MapEntry(k, v.toStringAsFixed(2)),
      ),
      'max_single_expense': maxExpense.toStringAsFixed(2),
      'daily_avg_expense': dailyAvg.toStringAsFixed(2),
      'transaction_count': transactions.length,
    };
  }

  /// 构造发送给 LLM 的 Prompt。
  ///
  /// @param template 分析模板类型。
  /// @param summary 脱敏的账单汇总数据。
  /// @return 完整的 Prompt 文本。
  static String _buildPrompt(
    AnalysisTemplate template,
    Map<String, Object> summary,
  ) {
    const systemPrompt = '你是一个专业的个人理财分析师。'
        '用户会提供脱敏后的账单汇总数据，请用中文给出简洁、有洞察力的分析建议。'
        '注意：数据不包含具体商户和账户信息，请勿追问。';

    final templateInstruction = switch (template) {
      AnalysisTemplate.expenseStructure => '请分析我的消费结构，指出各类支出占比是否合理，并给出优化建议。',
      AnalysisTemplate.abnormalExpense =>
        '请检查是否存在异常支出（如单笔过大、某类别占比异常偏高），并提醒我注意。',
      AnalysisTemplate.savingsAdvice => '请根据我的收支情况，给出可执行的储蓄和理财建议。',
    };

    final dataJson = const JsonEncoder.withIndent('  ').convert(summary);

    return '$systemPrompt\n\n'
        '用户请求：$templateInstruction\n\n'
        '账单数据（已脱敏）：\n$dataJson';
  }

  /// 单次请求的最大尝试次数（含首次）。
  ///
  /// WHY: 大模型服务在并发或高频调用时会返回 429 / 5xx，直接报错会让用户
  /// 反复手动重试；指数退避重试可显著提升实际成功率。
  static const int _maxAttempts = 3;

  /// 重试的基础退避时长（第 n 次重试等待 n * 1.5s）。
  static const Duration _retryBaseDelay = Duration(milliseconds: 1500);

  /// 调用 AI 接口，对可重试错误做指数退避重试。
  ///
  /// @param apiKey API Key。
  /// @param prompt 完整 Prompt。
  /// @param client http.Client 实例。
  /// @return AI 返回的文本内容。
  /// @throws AiAnalysisException 网络/Key/解析等异常。
  static Future<String> _callApi(
    String apiKey,
    String prompt,
    http.Client client,
  ) async {
    // O(n)，n 为最大尝试次数（固定 3），仅在失败路径产生额外等待
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      final bool lastAttempt = attempt == _maxAttempts;
      try {
        return await _requestOnce(apiKey, prompt, client);
      } on AiAnalysisException catch (e) {
        // WHY: 仅频率限制/服务端错误/网络/超时可重试；
        // Key 无效、参数错误等 4xx 与解析错误重试也不会成功，直接抛出
        final bool retryable = e.type == AiAnalysisError.rateLimited ||
            e.type == AiAnalysisError.serverError ||
            e.type == AiAnalysisError.networkError ||
            e.type == AiAnalysisError.timeout;
        if (!retryable || lastAttempt) rethrow;
        debugPrint(
          '[AiAnalysis] 第 $attempt 次请求失败（${e.type}），即将退避重试',
        );
        await _waitBeforeRetry(attempt);
      }
    }
    // 理论不可达：循环内所有分支均已 return 或 throw
    throw const AiAnalysisException(
      AiAnalysisError.networkError,
      '请求失败，请稍后重试',
    );
  }

  /// 按尝试次数线性退避等待。
  ///
  /// @param attempt 已失败的尝试次数（从 1 开始）。
  /// @return 等待完成的 Future。
  static Future<void> _waitBeforeRetry(int attempt) {
    // WHY: 首次失败等 1.5s、第二次等 3s，给服务端频率窗口留出恢复时间
    return Future<void>.delayed(_retryBaseDelay * attempt);
  }

  /// 执行一次 AI 请求（不含重试）。
  ///
  /// @param apiKey API Key。
  /// @param prompt 完整 Prompt。
  /// @param client http.Client 实例。
  /// @return AI 返回的文本内容。
  /// @throws AiAnalysisException 网络/Key/解析等异常。
  static Future<String> _requestOnce(
    String apiKey,
    String prompt,
    http.Client client,
  ) async {
    try {
      final response = await client
          .post(
            Uri.parse(_apiEndpoint),
            headers: <String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode(<String, Object>{
              'model': _model,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        throw const AiAnalysisException(
          AiAnalysisError.invalidApiKey,
          'API Key 无效，请检查当前服务商的 API Key 是否正确',
        );
      }
      if (response.statusCode == 429) {
        // WHY: 429 是频率限制，属于可重试错误，由外层 _callApi 负责退避重试
        throw const AiAnalysisException(
          AiAnalysisError.rateLimited,
          '请求过于频繁，请稍等片刻再试',
        );
      }
      if (response.statusCode >= 500) {
        throw AiAnalysisException(
          AiAnalysisError.serverError,
          '服务端错误 (${response.statusCode})，请稍后重试',
        );
      }
      if (response.statusCode != 200) {
        throw AiAnalysisException(
          AiAnalysisError.networkError,
          '请求失败 (${response.statusCode})',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const AiAnalysisException(
          AiAnalysisError.parseError,
          'AI 返回内容为空',
        );
      }
      final content = (choices.first as Map<String, dynamic>)['message']
          ['content'] as String?;
      if (content == null || content.isEmpty) {
        throw const AiAnalysisException(
          AiAnalysisError.parseError,
          'AI 返回内容解析失败',
        );
      }
      return content;
    } on AiAnalysisException {
      rethrow;
    } on http.ClientException catch (e) {
      debugPrint('[AiAnalysis] 网络异常: $e');
      throw const AiAnalysisException(
        AiAnalysisError.networkError,
        '网络连接失败，请检查网络后重试',
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const AiAnalysisException(
          AiAnalysisError.timeout,
          '请求超时，请稍后重试',
        );
      }
      debugPrint('[AiAnalysis] 未知异常: $e');
      throw AiAnalysisException(
        AiAnalysisError.parseError,
        '解析响应失败: ${e.toString()}',
      );
    }
  }
}

import 'package:flutter/material.dart';
import '../services/ai_analysis_service.dart';
import '../theme/app_theme.dart';

/// AI 账单分析页面
///
/// WHY: 提供预设分析模板，用户点击后调用 AiAnalysisService 获取
/// 智谱 GLM-4-Flash 的分析结果，以自然语言展示。
class AiAnalysisScreen extends StatefulWidget {
  /// 构造 AI 分析页
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  /// 当前选中的分析模板
  AnalysisTemplate? _selectedTemplate;

  /// 分析结果文本
  String? _result;

  /// 是否正在加载
  bool _isLoading = false;

  /// 错误信息
  String? _error;

  /// 预设分析模板列表
  static const List<_TemplateDef> _templates = [
    _TemplateDef(
      template: AnalysisTemplate.expenseStructure,
      title: '消费结构分析',
      desc: '分析各类支出占比，判断是否合理',
      icon: Icons.pie_chart_rounded,
    ),
    _TemplateDef(
      template: AnalysisTemplate.abnormalExpense,
      title: '异常支出提醒',
      desc: '检查单笔过大或占比异常的支出',
      icon: Icons.warning_amber_rounded,
    ),
    _TemplateDef(
      template: AnalysisTemplate.savingsAdvice,
      title: '储蓄优化建议',
      desc: '根据收支情况给出储蓄建议',
      icon: Icons.savings_rounded,
    ),
  ];

  /// 执行 AI 分析。
  ///
  /// @param template 选中的分析模板。
  Future<void> _runAnalysis(AnalysisTemplate template) async {
    setState(() {
      _selectedTemplate = template;
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final text = await AiAnalysisService.analyze(template: template);
      if (mounted) {
        setState(() {
          _result = text;
          _isLoading = false;
        });
      }
    } on AiAnalysisException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      // WHY: 兜底捕获未预期异常，禁止静默失败
      if (mounted) {
        setState(() {
          _error = '分析失败: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 账单分析'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // WHY: 隐私提示，告知用户数据已脱敏
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 20,
                    color: AppTheme.getPrimaryColor(context),
                  ),
                  const SizedBox(width: AppTheme.spaceSmall),
                  const Expanded(
                    child: Text(
                      '仅发送分类汇总数据，不包含商户名、账户名等敏感信息',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),

            // 模板卡片列表
            ..._templates.map((t) => _buildTemplateCard(context, t)),

            if (_isLoading) ...[
              const SizedBox(height: AppTheme.spaceLarge),
              _buildLoading(context),
            ],

            if (_error != null) ...[
              const SizedBox(height: AppTheme.spaceLarge),
              _buildError(context, _error!),
            ],

            if (_result != null) ...[
              const SizedBox(height: AppTheme.spaceLarge),
              _buildResult(context, _result!),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建分析模板卡片。
  ///
  /// @param context 构建上下文。
  /// @param def 模板定义。
  /// @return 模板卡片 Widget。
  Widget _buildTemplateCard(BuildContext context, _TemplateDef def) {
    final isSelected = _selectedTemplate == def.template;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
      child: Material(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: _isLoading ? null : () => _runAnalysis(def.template),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    def.icon,
                    color: AppTheme.getPrimaryColor(context),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        def.desc,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.getPrimaryColor(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建加载状态。
  ///
  /// @param context 构建上下文。
  /// @return 加载 Widget。
  Widget _buildLoading(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.getPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            'AI 正在分析您的账单...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误提示。
  ///
  /// @param context 构建上下文。
  /// @param message 错误信息。
  /// @return 错误 Widget。
  Widget _buildError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分析结果展示。
  ///
  /// @param context 构建上下文。
  /// @param result 分析结果文本。
  /// @return 结果展示 Widget。
  Widget _buildResult(BuildContext context, String result) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.getPrimaryColor(context),
                size: 20,
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Text(
                '分析结果',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          SelectableText(
            result,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分析模板定义
class _TemplateDef {
  /// 模板类型
  final AnalysisTemplate template;

  /// 模板标题
  final String title;

  /// 模板描述
  final String desc;

  /// 模板图标
  final IconData icon;

  /// 构造模板定义
  ///
  /// @param template 模板类型。
  /// @param title 标题。
  /// @param desc 描述。
  /// @param icon 图标。
  const _TemplateDef({
    required this.template,
    required this.title,
    required this.desc,
    required this.icon,
  });
}

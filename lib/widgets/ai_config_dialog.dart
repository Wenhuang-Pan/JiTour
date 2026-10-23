import 'package:flutter/material.dart';
import '../services/ai_config_service.dart';
import '../theme/app_theme.dart';

/// AI 助手配置弹窗
///
/// WHY: 各家大模型均提供 OpenAI 兼容接口，把服务商、端点、模型名
/// 全部做成可配置项，用户可在智谱 / DeepSeek / 通义 / Kimi / OpenAI
/// 之间自由切换，新模型上线也无需等待 app 发版。
class AiConfigDialog extends StatefulWidget {
  /// 构造 AI 配置弹窗
  const AiConfigDialog({super.key});

  /// 打开 AI 配置弹窗
  ///
  /// @param context 构建上下文
  /// @return true 表示用户已保存配置；null 表示取消
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => const AiConfigDialog(),
    );
  }

  @override
  State<AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<AiConfigDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;

  /// 当前选中的服务商
  late AiProviderPreset _provider;

  /// API Key 是否掩码显示
  bool _obscureKey = true;

  /// 是否正在保存（防重复提交）
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _provider = AiConfigService.getProvider();
    _apiKeyController = TextEditingController(
      text: AiConfigService.getApiKey() ?? '',
    );
    _modelController = TextEditingController(
      text: AiConfigService.getModel(),
    );
    _baseUrlController = TextEditingController(
      text: AiConfigService.getBaseUrl(),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  /// 选择服务商
  ///
  /// WHY: 切换服务商后端点和模型需同步跟随，避免残留上一家的配置。
  Future<void> _pickProvider() async {
    final picked = await showModalBottomSheet<AiProviderPreset>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: AiConfigService.presets.map((AiProviderPreset p) {
              final bool selected = p.id == _provider.id;
              return ListTile(
                title: Text(p.name),
                subtitle: Text(
                  p.baseUrl.isEmpty ? '需手动填写端点地址' : p.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: AppTheme.getPrimaryColor(ctx),
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, p),
              );
            }).toList(),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    if (picked.id == _provider.id) return;

    setState(() {
      _provider = picked;
      _baseUrlController.text = picked.baseUrl;
      // WHY: 当前模型若不在新服务商候选内，自动回落到新服务商默认模型
      final current = _modelController.text.trim();
      if (!picked.models.contains(current)) {
        _modelController.text = picked.defaultModel;
      }
    });
  }

  /// 搜索并选择模型
  Future<void> _pickModel() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return _ModelPickerSheet(
          models: _provider.models,
          current: _modelController.text.trim(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _modelController.text = picked);
  }

  /// 保存配置
  Future<void> _save() async {
    final String key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showTip('API Key 不能为空');
      return;
    }
    final String baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      _showTip('端点地址不能为空');
      return;
    }
    final String model = _modelController.text.trim();
    if (model.isEmpty) {
      _showTip('模型名不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      await AiConfigService.setProvider(_provider.id);
      await AiConfigService.setApiKey(key);
      // WHY: 端点与预设一致时清除自定义值，保持配置最简
      await AiConfigService.setBaseUrl(
        baseUrl == _provider.baseUrl ? '' : baseUrl,
      );
      await AiConfigService.setModel(model);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showTip('保存失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 显示操作提示
  ///
  /// @param message 提示文案
  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 清除已保存的 API Key
  Future<void> _clear() async {
    try {
      await AiConfigService.clearApiKey();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showTip('清除失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasKey = AiConfigService.isConfigured();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLarge,
                AppTheme.spaceMedium,
                AppTheme.spaceSmall,
                AppTheme.spaceMedium,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI 助手配置',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('服务商'),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    _buildPickerRow(
                      icon: Icons.dns_rounded,
                      text: _provider.name,
                      subtitle: '点击切换服务商',
                      onTap: _pickProvider,
                    ),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildLabel('API Key'),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '粘贴服务商控制台的 API Key',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildLabel('模型'),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    TextField(
                      controller: _modelController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '可搜索选择或直接输入模型名',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded),
                          tooltip: '搜索模型',
                          onPressed: _pickModel,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      '可直接输入任意模型名，新模型上线无需更新 app',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildLabel('端点地址'),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'https://.../chat/completions',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      '切换服务商会自动填入官方端点；使用代理时改为代理地址',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMedium),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceSmall),
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimaryColor(context)
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppTheme.getPrimaryColor(context),
                          ),
                          const SizedBox(width: AppTheme.spaceXSmall),
                          Expanded(
                            child: Text(
                              'API Key 仅保存在本机，不会上传到任何服务器。'
                              '账单分析只发送分类汇总数据，不含商户名和账户名。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // 操作栏
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              child: Row(
                children: [
                  if (hasKey)
                    TextButton(
                      onPressed: _saving ? null : _clear,
                      child: const Text('清除 Key'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建字段标题
  ///
  /// @param text 标题文本
  /// @return 标题 Widget
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  /// 构建可点击的选择行
  ///
  /// @param icon 左侧图标
  /// @param text 主文本
  /// @param subtitle 副文本
  /// @param onTap 点击回调
  /// @return 选择行 Widget
  Widget _buildPickerRow({
    required IconData icon,
    required String text,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSmall,
          vertical: AppTheme.spaceSmall,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.getPrimaryColor(context)),
            const SizedBox(width: AppTheme.spaceSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 模型搜索选择面板
///
/// WHY: 服务商内置模型可能较多，提供搜索过滤 + 自由输入两种方式，
/// 兼顾「快速选常用模型」与「跟进最新模型」。
class _ModelPickerSheet extends StatefulWidget {
  /// 可选模型列表
  final List<String> models;

  /// 当前已选模型
  final String current;

  const _ModelPickerSheet({
    required this.models,
    required this.current,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String keyword = _searchController.text.trim();
    final String lower = keyword.toLowerCase();
    final List<String> filtered = widget.models
        .where((String m) => lower.isEmpty || m.toLowerCase().contains(lower))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索或输入模型名',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 300,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.models.isEmpty
                            ? '该服务商未内置模型，请直接输入模型名'
                            : '未找到匹配模型',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext ctx, int index) {
                        final String model = filtered[index];
                        final bool selected = model == widget.current;
                        return ListTile(
                          dense: true,
                          title: Text(model),
                          trailing: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.getPrimaryColor(ctx),
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, model),
                        );
                      },
                    ),
            ),
            if (keyword.isNotEmpty && !filtered.contains(keyword))
              ListTile(
                dense: true,
                leading: const Icon(Icons.add_rounded, size: 18),
                title: Text('使用「$keyword」'),
                onTap: () => Navigator.pop(context, keyword),
              ),
          ],
        ),
      ),
    );
  }
}

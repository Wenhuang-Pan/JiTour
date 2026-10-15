import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:decimal/decimal.dart';
import '../theme/app_theme.dart';
import '../models/transaction_template.dart';
import '../models/tag.dart';
import '../services/database_service.dart';
import '../services/template_service.dart';
import '../services/tag_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../utils/icon_library.dart';

/// 账单模板管理页面
///
/// 展示所有模板，支持新建、编辑、删除；模板在记账页用于一键填充表单。
class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单模板'),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactionTemplates.listenable(),
        builder: (context, Box<TransactionTemplate> box, _) {
          final templates = TemplateService.getAllTemplates();

          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXXXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimaryColor(context)
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bookmark_border_rounded,
                        size: 40,
                        color: AppTheme.getPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXXLarge),
                    Text(
                      '暂无模板',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '将常用交易存为模板，记账时一键填充',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.neutral400,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            itemCount: templates.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppTheme.spaceSmall),
            itemBuilder: (context, index) =>
                _buildTemplateCard(context, templates[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTemplateEditor(context, null),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  /// 构建单个模板卡片
  Widget _buildTemplateCard(
      BuildContext context, TransactionTemplate template) {
    // WHY: 删除按钮需二次确认，直接调用类内方法
    return _buildTemplateCardContent(context, template);
  }

  /// 构建单个模板卡片
  Widget _buildTemplateCardContent(
      BuildContext context, TransactionTemplate template) {
    final category = template.isIncome
        ? CategoryService.getIncomeCategories()
            .where((c) => c.name == template.category)
            .firstOrNull
        : CategoryService.getExpenseCategories()
            .where((c) => c.name == template.category)
            .firstOrNull;
    final iconColor = template.isIncome
        ? AppTheme.successColor
        : AppTheme.getPrimaryColor(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              category != null
                  ? _getIconData(category.iconName)
                  : Icons.bookmark_rounded,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.category} · ${template.account}'
                  '${template.note != null ? ' · ${template.note}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          Text(
            template.amountText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: template.isIncome
                      ? AppTheme.successColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppTheme.neutral400,
            tooltip: '编辑',
            onPressed: () => _showTemplateEditor(context, template),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppTheme.errorColor,
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, template),
          ),
        ],
      ),
    );
  }

  /// 删除二次确认
  Future<void> _confirmDelete(
      BuildContext context, TransactionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('删除模板'),
        content: Text('确定要删除模板"${template.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TemplateService.deleteTemplate(template.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除模板"${template.name}"')),
    );
  }

  /// 打开模板编辑器（新建或编辑）
  Future<void> _showTemplateEditor(
      BuildContext context, TransactionTemplate? template) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateEditorSheet(template: template),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(template == null ? '模板已创建' : '模板已更新')),
      );
    }
  }

  IconData _getIconData(String iconName) {
    try {
      return IconLibrary.getIconByName(iconName);
    } catch (e) {
      return Icons.category;
    }
  }
}

/// 模板编辑器底部弹层（新建/编辑共用）
class _TemplateEditorSheet extends StatefulWidget {
  /// 编辑模式传入的模板，新建模式为 null
  final TransactionTemplate? template;

  const _TemplateEditorSheet({this.template});

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late bool _isIncome;
  String? _selectedCategory;
  String? _selectedAccount;
  final List<Tag> _selectedTags = [];

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _amountController = TextEditingController(
      text: template?.amount?.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(text: template?.note ?? '');
    _isIncome = template?.isIncome ?? false;
    _selectedCategory = template?.category;
    _selectedAccount = template?.account;
    if (template != null) {
      for (final tagId in template.tagIds) {
        final tag = TagService.getTagById(tagId);
        if (tag != null) _selectedTags.add(tag);
      }
    }
    // WHY: 分类/账户默认为空引导用户选择，未选时保存会给出校验提示
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome
        ? CategoryService.getIncomeCategories()
        : CategoryService.getExpenseCategories();
    final accounts = AccountService.getActiveAccounts();
    final allTags = TagService.getActiveTags();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spaceLarge,
        right: AppTheme.spaceLarge,
        top: AppTheme.spaceLarge,
        // WHY: 键盘弹出时底部预留高度，保证输入框不被遮挡
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLarge,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Text(
              _isEditing ? '编辑模板' : '新建模板',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 模板名称
            TextField(
              controller: _nameController,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '模板名称',
                hintText: '如：每日咖啡',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 收支类型切换
            Row(
              children: [
                Expanded(child: _buildTypeButton(false, '支出')),
                const SizedBox(width: AppTheme.spaceSmall),
                Expanded(child: _buildTypeButton(true, '收入')),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 金额（可选）
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额（可选）',
                hintText: '留空则使用时手动输入',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 分类选择
            _buildDropdown(
              label: '分类',
              value: _selectedCategory,
              items: categories.map((c) => c.name).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 账户选择
            _buildDropdown(
              label: '账户',
              value: _selectedAccount,
              items: accounts.map((a) => a.name).toList(),
              onChanged: (v) => setState(() => _selectedAccount = v),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 备注（可选）
            TextField(
              controller: _noteController,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 标签选择
            if (allTags.isNotEmpty) ...[
              Text(
                '标签（可选）',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Wrap(
                spacing: AppTheme.spaceSmall,
                runSpacing: AppTheme.spaceSmall,
                children: allTags.map((tag) {
                  final isSelected = _selectedTags.any((t) => t.id == tag.id);
                  final tagColor = Color(tag.colorValue);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.removeWhere((t) => t.id == tag.id);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMedium,
                        vertical: AppTheme.spaceSmall,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tagColor
                            : tagColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: tagColor,
                          width: isSelected ? 0 : 1,
                        ),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : tagColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spaceLarge),
            ],

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(
                  _isEditing ? '保存修改' : '创建模板',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
          ],
        ),
      ),
    );
  }

  /// 构建收支类型切换按钮
  Widget _buildTypeButton(bool isIncome, String label) {
    final selected = _isIncome == isIncome;
    final color = isIncome ? AppTheme.successColor : AppTheme.errorColor;
    return GestureDetector(
      onTap: () => setState(() {
        _isIncome = isIncome;
        // WHY: 切换收支类型后原分类可能不存在于新列表，重置待用户重新选择
        _selectedCategory = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.10)
              : AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 构建下拉选择框
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// 校验并保存模板
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showTopLevelError(context, '请输入模板名称');
      return;
    }
    if (TemplateService.templateNameExists(name,
        excludeId: widget.template?.id)) {
      _showTopLevelError(context, '模板名称已存在');
      return;
    }

    Decimal? amount;
    final amountText = _amountController.text.trim();
    if (amountText.isNotEmpty) {
      amount = Decimal.tryParse(amountText);
      if (amount == null || amount < Decimal.zero) {
        _showTopLevelError(context, '请输入正确的金额');
        return;
      }
    }

    if (_selectedCategory == null) {
      _showTopLevelError(context, '请选择分类');
      return;
    }
    if (_selectedAccount == null) {
      _showTopLevelError(context, '请选择账户');
      return;
    }

    final note = _noteController.text.trim();
    final tagIds = _selectedTags.map((t) => t.id).toList();

    try {
      if (_isEditing) {
        final template = widget.template!;
        template.name = name;
        template.isIncome = _isIncome;
        template.amount = amount;
        template.category = _selectedCategory!;
        template.account = _selectedAccount!;
        template.note = note.isEmpty ? null : note;
        template.setTagIds(tagIds);
        await TemplateService.updateTemplate(template);
      } else {
        await TemplateService.createTemplate(
          name: name,
          isIncome: _isIncome,
          category: _selectedCategory!,
          account: _selectedAccount!,
          amount: amount,
          note: note.isEmpty ? null : note,
          tagIds: tagIds,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showTopLevelError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 展示错误提示
  void _showTopLevelError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

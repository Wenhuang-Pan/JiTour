import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../models/tag.dart';
import '../models/transaction.dart';
import '../services/tag_service.dart';
import '../services/database_service.dart';
import '../utils/icon_library.dart';

class TagsManagementScreen extends StatefulWidget {
  const TagsManagementScreen({super.key});

  @override
  State<TagsManagementScreen> createState() => _TagsManagementScreenState();
}

class _TagsManagementScreenState extends State<TagsManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final tags = TagService.getAllTags();
    final activeTags = tags.where((tag) => tag.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final inactiveTags = tags.where((tag) => !tag.isActive).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final bool isEmpty = tags.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        elevation: 0,
      ),
      // WHY: 监听交易 box，账单增删或标签变更后使用笔数实时刷新
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          final usageCounts = TagService.getTagUsageCounts();
          if (isEmpty) return _buildEmptyState(context);

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            children: [
              ...activeTags.map((tag) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                    child: _buildTagCard(
                      context,
                      tag,
                      usageCounts[tag.id] ?? 0,
                    ),
                  )),
              if (inactiveTags.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceMedium),
                _buildInactiveHeader(context, inactiveTags.length),
                const SizedBox(height: AppTheme.spaceSmall),
                ...inactiveTags.map((tag) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                      child: _buildInactiveTagCard(
                        context,
                        tag,
                        usageCounts[tag.id] ?? 0,
                      ),
                    )),
              ],
              const SizedBox(height: AppTheme.spaceXXXLarge),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  /// 构建已停用分区标题
  Widget _buildInactiveHeader(BuildContext context, int count) {
    return Row(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 16,
          color: AppTheme.neutral500,
        ),
        const SizedBox(width: AppTheme.spaceXSmall),
        Text(
          '已停用（$count）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral600,
              ),
        ),
        const SizedBox(width: AppTheme.spaceSmall),
        const Expanded(
          child: Text(
            '停用后历史账单保留，可随时恢复',
            style: TextStyle(
              color: AppTheme.neutral400,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: AppTheme.neutral400,
              size: 40,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '暂无标签',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.neutral600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          const Text(
            '点击下方按钮添加标签',
            style: TextStyle(
              color: AppTheme.neutral500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(BuildContext context, Tag tag, int usageCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutral900.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(tag.colorValue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Icon(
            IconLibrary.getIconByName(tag.iconName),
            color: Color(tag.colorValue),
            size: 24,
          ),
        ),
        title: Text(
          tag.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            usageCount > 0 ? '$usageCount 笔账单使用' : '暂无账单使用',
            style: TextStyle(
              color: usageCount > 0 ? AppTheme.neutral500 : AppTheme.neutral400,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              color: AppTheme.primaryColor,
              onPressed: () => _showEditTagDialog(context, tag),
            ),
            IconButton(
              icon: const Icon(Icons.block_rounded),
              color: AppTheme.neutral500,
              tooltip: '停用',
              onPressed: () =>
                  _showDisableConfirmDialog(context, tag, usageCount),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建已停用标签卡片（置灰，可恢复或永久删除）
  Widget _buildInactiveTagCard(BuildContext context, Tag tag, int usageCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.neutral200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceXSmall,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.neutral200,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Icon(
            IconLibrary.getIconByName(tag.iconName),
            color: AppTheme.neutral400,
            size: 22,
          ),
        ),
        title: Text(
          tag.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral500,
                decoration: TextDecoration.lineThrough,
              ),
        ),
        subtitle: Text(
          usageCount > 0 ? '$usageCount 笔历史账单' : '暂无账单使用',
          style: const TextStyle(
            color: AppTheme.neutral400,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              color: AppTheme.primaryColor,
              tooltip: '恢复',
              onPressed: () => _restoreTag(context, tag),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded),
              color: AppTheme.errorColor,
              tooltip: '永久删除',
              onPressed: () =>
                  _showPermanentDeleteConfirmDialog(context, tag, usageCount),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedIconName = 'local_offer_rounded';
    Color selectedColor = AppTheme.primaryColor;
    final icons = TagService.getDefaultIcons();
    final colors = TagService.getDefaultColors();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('添加标签'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称输入
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '标签名称',
                      labelStyle: const TextStyle(color: AppTheme.neutral600),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),

                  // 图标选择
                  Text(
                    '图标',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Wrap(
                    spacing: AppTheme.spaceSmall,
                    runSpacing: AppTheme.spaceSmall,
                    children: icons.map((icon) {
                      final iconName = IconLibrary.getIconName(icon);
                      final isSelected = iconName == selectedIconName;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedIconName = iconName;
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : AppTheme.neutral50,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.neutral200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.neutral500,
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),

                  // 颜色选择
                  Text(
                    '颜色',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Wrap(
                    spacing: AppTheme.spaceSmall,
                    runSpacing: AppTheme.spaceSmall,
                    children: colors.map((color) {
                      final isSelected = color.value == selectedColor.value;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.neutral900
                                  : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入标签名称')),
                    );
                    return;
                  }

                  try {
                    await TagService.createTag(
                      name: name,
                      iconName: selectedIconName,
                      colorValue: selectedColor.value,
                    );
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('标签添加成功'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('添加失败: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTagDialog(BuildContext context, Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    String selectedIconName = tag.iconName;
    Color selectedColor = Color(tag.colorValue);
    final icons = TagService.getDefaultIcons();
    final colors = TagService.getDefaultColors();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('编辑标签'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称输入
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '标签名称',
                      labelStyle: const TextStyle(color: AppTheme.neutral600),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),

                  // 图标选择
                  Text(
                    '图标',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Wrap(
                    spacing: AppTheme.spaceSmall,
                    runSpacing: AppTheme.spaceSmall,
                    children: icons.map((icon) {
                      final iconName = IconLibrary.getIconName(icon);
                      final isSelected = iconName == selectedIconName;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedIconName = iconName;
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withValues(alpha: 0.1)
                                : AppTheme.neutral50,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? selectedColor
                                  : AppTheme.neutral200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? selectedColor
                                : AppTheme.neutral500,
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),

                  // 颜色选择
                  Text(
                    '颜色',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Wrap(
                    spacing: AppTheme.spaceSmall,
                    runSpacing: AppTheme.spaceSmall,
                    children: colors.map((color) {
                      final isSelected = color.value == selectedColor.value;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.neutral900
                                  : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入标签名称')),
                    );
                    return;
                  }

                  try {
                    final updatedTag = tag.copyWith(
                      name: name,
                      iconName: selectedIconName,
                      colorValue: selectedColor.value,
                    );
                    await TagService.updateTag(updatedTag);
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('标签更新成功'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('更新失败: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 停用标签确认（软删除）
  void _showDisableConfirmDialog(
      BuildContext context, Tag tag, int usageCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(tag.colorValue).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                IconLibrary.getIconByName(tag.iconName),
                color: Color(tag.colorValue),
                size: 16,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            const Text('停用标签'),
          ],
        ),
        content: Text(
          usageCount > 0
              ? '「${tag.name}」正被 $usageCount 笔账单使用。\n\n停用后记账时不能再选择该标签，历史账单与统计数据都会保留，之后可在下方"已停用"中恢复。'
              : '确定要停用「${tag.name}」标签吗？\n\n停用后记账时不能再选择，之后可在"已停用"中恢复。',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              // WHY: await 前捕获 navigator/messenger，避免异步间隙后 context 失活
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await TagService.deleteTag(tag.id);
              if (!mounted) return;
              navigator.pop();
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('标签已停用，可在下方已停用区恢复'),
                  backgroundColor: AppTheme.neutral700,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neutral700,
              foregroundColor: Colors.white,
            ),
            child: const Text('停用'),
          ),
        ],
      ),
    );
  }

  /// 恢复已停用标签
  Future<void> _restoreTag(BuildContext context, Tag tag) async {
    // WHY: 避免恢复后与现有活跃标签重名，破坏同名唯一约束
    if (TagService.tagNameExists(tag.name, excludeId: tag.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('恢复失败：已存在同名标签「${tag.name}」，请先在编辑中改名'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    tag.restore();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('标签已恢复'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  /// 永久删除确认（二次确认；不可恢复）
  void _showPermanentDeleteConfirmDialog(
      BuildContext context, Tag tag, int usageCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppTheme.errorColor,
                size: 16,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            const Text('永久删除标签'),
          ],
        ),
        content: Text(
          usageCount > 0
              ? '「${tag.name}」关联着 $usageCount 笔历史账单。永久删除后无法恢复，这些账单将不再显示该标签，也无法再按它统计（账单本身不会被删除）。\n\n确定永久删除吗？'
              : '永久删除「${tag.name}」后无法恢复，确定继续吗？',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              // WHY: await 前捕获 navigator/messenger，避免异步间隙后 context 失活
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await TagService.permanentDeleteTag(tag.id);
              if (!mounted) return;
              navigator.pop();
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('标签已永久删除'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
  }
}

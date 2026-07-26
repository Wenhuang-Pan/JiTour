import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';
import '../utils/icon_library.dart';

class TagsManagementScreen extends StatefulWidget {
  const TagsManagementScreen({super.key});

  @override
  State<TagsManagementScreen> createState() => _TagsManagementScreenState();
}

class _TagsManagementScreenState extends State<TagsManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final tags = TagService.getActiveTags();

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        elevation: 0,
      ),
      body: tags.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                  child: _buildTagCard(context, tag),
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
            child: Icon(
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
          Text(
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

  Widget _buildTagCard(BuildContext context, Tag tag) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutral900.withOpacity(0.05),
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
            color: Color(tag.colorValue).withOpacity(0.1),
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
        subtitle: Text(
          '排序: ${tag.sortOrder}',
          style: TextStyle(
            color: AppTheme.neutral500,
            fontSize: 12,
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
              icon: const Icon(Icons.delete_rounded),
              color: AppTheme.errorColor,
              onPressed: () => _showDeleteConfirmDialog(context, tag),
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
                      labelStyle: TextStyle(color: AppTheme.neutral600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.neutral50,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
                      labelStyle: TextStyle(color: AppTheme.neutral600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withOpacity(0.1)
                                : AppTheme.neutral50,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected ? selectedColor : AppTheme.neutral200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? selectedColor : AppTheme.neutral500,
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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

  void _showDeleteConfirmDialog(BuildContext context, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(tag.colorValue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                IconLibrary.getIconByName(tag.iconName),
                color: Color(tag.colorValue),
                size: 16,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            const Text('删除标签'),
          ],
        ),
        content: Text('确定要删除「${tag.name}」标签吗？'),
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
              await TagService.deleteTag(tag.id);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('标签已删除'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../utils/icon_library.dart';
import '../theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CategoryList(isIncome: true),
                _CategoryList(isIncome: false),
              ],
            ),
          ),
        ],
      ),
      // WHY: 移除FAB，改为header中的按钮，避免遮挡分类列表
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXLarge),
          bottomRight: Radius.circular(AppTheme.radiusXLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                // WHY: 用Flexible防止窄屏标题溢出
                const Flexible(
                  child: Text(
                    '分类管理',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                // WHY: 添加分类按钮放在header右上角，避免遮挡列表
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  child: InkWell(
                    onTap: () => _showAddCategoryDialog(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMedium,
                        vertical: AppTheme.spaceSmall,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spaceXSmall),
                          Text(
                            '添加',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              '自定义您的收入和支出分类',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          children: [
            Expanded(
              child:
                  _buildTabButton(context, '收入分类', _tabController.index == 0),
            ),
            const SizedBox(width: 4),
            Expanded(
              child:
                  _buildTabButton(context, '支出分类', _tabController.index == 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(
            isSelected ? _tabController.index : (label == '收入分类' ? 0 : 1));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.getCardColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppTheme.primaryColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        isIncome: _tabController.index == 0,
        onSave: (category) async {
          await CategoryService.addCategory(category);
          setState(() {});
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final bool isIncome;

  const _CategoryList({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseService.categories.listenable(),
      builder: (context, Box<Category> box, _) {
        final categories = isIncome
            ? CategoryService.getIncomeCategories()
            : CategoryService.getExpenseCategories();

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    size: 60,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                Text(
                  '暂无${isIncome ? "收入" : "支出"}分类',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Text(
                  '点击下方按钮添加您的第一个分类',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          itemCount: categories.length,
          // WHY: 长按整卡拖动排序（buildDefaultDragHandles 默认开启），
          // 拖动结果立即持久化到 Hive，ValueListenableBuilder 监听变更后自动重建
          onReorder: (oldIndex, newIndex) =>
              CategoryService.reorderCategories(isIncome, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryCard(
              key: ValueKey(category.id),
              category: category,
              onTap: () => _showEditCategoryDialog(context, category),
              onDelete: () => _showDeleteConfirmDialog(context, category),
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        isIncome: category.isIncome,
        existingCategory: category,
        onSave: (updatedCategory) async {
          await CategoryService.updateCategory(updatedCategory);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('确认删除'),
        content: Text('确定要删除"${category.name}"分类吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await CategoryService.deleteCategory(category.id);
              // WHY: 删除是异步操作，弹窗可能已被关闭，pop 前须校验 context 有效性
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconData(category.iconName);
    final color = Color(int.parse(category.color.replaceFirst('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    iconData,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        category.isIncome ? '收入分类' : '支出分类',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorColor,
                  ),
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    return IconLibrary.getIconByName(iconName);
  }
}

class _CategoryDialog extends StatefulWidget {
  final bool isIncome;
  final Category? existingCategory;
  final Function(Category) onSave;

  const _CategoryDialog({
    required this.isIncome,
    this.existingCategory,
    required this.onSave,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late IconData _selectedIcon;
  late String _selectedIconName;
  late Color _selectedColor;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 预设颜色列表
  final List<Color> _colors = [
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
    const Color(0xFF06B6D4),
    const Color(0xFF3B82F6),
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF78350F),
    const Color(0xFF6B7280),
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingCategory != null) {
      _selectedIcon =
          IconLibrary.getIconByName(widget.existingCategory!.iconName);
      _selectedIconName = widget.existingCategory!.iconName;
      _selectedColor = Color(
          int.parse(widget.existingCategory!.color.replaceFirst('#', '0xFF')));
      _nameController.text = widget.existingCategory!.name;
    } else {
      _selectedIcon = widget.isIncome
          ? IconLibrary.getDefaultIncomeIcon()
          : IconLibrary.getDefaultExpenseIcon();
      _selectedIconName = widget.isIncome
          ? IconLibrary.getDefaultIncomeCategory()
          : IconLibrary.getDefaultExpenseCategory();
      _selectedColor =
          widget.isIncome ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
      _nameController.text = _selectedIconName;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMedium,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 600 ? 560 : screenWidth - 32,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildIconSelector(),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildColorSelector(),
                    const SizedBox(height: AppTheme.spaceLarge),
                    _buildPreview(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXLarge),
          topRight: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              widget.existingCategory == null
                  ? Icons.add_rounded
                  : Icons.edit_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Text(
            widget.existingCategory == null ? '添加分类' : '编辑分类',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类名称输入框
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类名称',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextField(
          controller: _nameController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '输入分类名称',
            prefixIcon: Icon(_selectedIcon, color: _selectedColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
          onChanged: (value) {
            // WHY: 用户手动修改名称时，仅更新显示名称，不影响 iconName
            setState(() {});
          },
        ),
      ],
    );
  }

  /// 构建图标选择器
  Widget _buildIconSelector() {
    final allIcons = IconLibrary.getIconsByType(widget.isIncome);
    final allCategoryNames =
        IconLibrary.getCategoryNamesByType(widget.isIncome);

    // 根据搜索关键词过滤
    final filteredIndices = <int>[];
    if (_searchQuery.isEmpty) {
      filteredIndices.addAll(List.generate(allIcons.length, (i) => i));
    } else {
      for (int i = 0; i < allCategoryNames.length; i++) {
        if (allCategoryNames[i]
            .toLowerCase()
            .contains(_searchQuery.toLowerCase())) {
          filteredIndices.add(i);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择图标',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '搜索分类...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: AppTheme.getSecondaryBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.getDividerColor(context)),
          ),
          child: filteredIndices.isEmpty && _searchQuery.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMedium),
                    child: Text(
                      '未找到匹配的分类',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: AppTheme.spaceSmall,
                    mainAxisSpacing: AppTheme.spaceSmall,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredIndices.length,
                  itemBuilder: (context, index) {
                    final originalIndex = filteredIndices[index];
                    final icon = allIcons[originalIndex];
                    final categoryName = allCategoryNames[originalIndex];
                    final isSelected = categoryName == _selectedIconName;

                    return InkWell(
                      onTap: () => setState(() {
                        _selectedIcon = icon;
                        _selectedIconName = categoryName;
                        // WHY: 如果用户尚未手动修改名称，同步更新名称字段
                        if (_nameController.text.isEmpty ||
                            _nameController.text ==
                                IconLibrary.getDefaultIncomeCategory() ||
                            _nameController.text ==
                                IconLibrary.getDefaultExpenseCategory()) {
                          _nameController.text = categoryName;
                        }
                      }),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.15)
                              : AppTheme.getCardColor(context),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: isSelected
                                ? _selectedColor
                                : AppTheme.getDividerColor(context),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? _selectedColor
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 26,
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                categoryName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? _selectedColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 构建颜色选择器
  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择颜色',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Wrap(
          spacing: AppTheme.spaceMedium,
          runSpacing: AppTheme.spaceMedium,
          children: _colors.map((color) {
            final isSelected = color.toARGB32() == _selectedColor.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 44 : 36,
                height: isSelected ? 44 : 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
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
    );
  }

  /// 构建预览效果
  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预览效果',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.getDividerColor(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  _selectedIcon,
                  color: _selectedColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isEmpty
                          ? '分类名称'
                          : _nameController.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      widget.isIncome ? '收入分类' : '支出分类',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建底部操作按钮
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.getDividerColor(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: SizedBox(
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saveCategory,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: const Center(
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存分类
  void _saveCategory() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分类名称')),
      );
      return;
    }

    if (CategoryService.isCategoryNameExists(
      name,
      widget.isIncome,
      excludeId: widget.existingCategory?.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该分类已存在')),
      );
      return;
    }

    final colorHex =
        '#${_selectedColor.toARGB32().toRadixString(16).substring(2)}';

    final category = widget.existingCategory != null
        ? widget.existingCategory!.copyWith(
            name: name,
            iconName: _selectedIconName,
            color: colorHex,
          )
        : (widget.isIncome
            ? Category.createIncome(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                iconName: _selectedIconName,
                color: colorHex,
              )
            : Category.createExpense(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                iconName: _selectedIconName,
                color: colorHex,
              ));

    widget.onSave(category);
    Navigator.pop(context);
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/icon_library.dart';
import '../theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
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
      backgroundColor: AppTheme.neutral50,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
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
      floatingActionButton: _buildFloatingActionButton(),
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
            color: AppTheme.primaryColor.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                const Text(
                  '分类管理',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              '自定义您的收入和支出分类',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.neutral500,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        tabs: const [
          Tab(text: '收入分类'),
          Tab(text: '支出分类'),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddCategoryDialog(),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: AppTheme.spaceSmall),
                Text(
                  '添加分类',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Icon(
                Icons.category_outlined,
                size: 60,
                color: AppTheme.neutral400,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Text(
              '暂无${isIncome ? "收入" : "支出"}分类',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral600,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              '点击下方按钮添加您的第一个分类',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.neutral500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onTap: () => _showEditCategoryDialog(context, category),
          onDelete: () => _showDeleteConfirmDialog(context, category),
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
        color: Colors.white,
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
                    color: color.withOpacity(0.1),
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
                              color: AppTheme.neutral500,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
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
  bool _isCustomCategory = false;
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<Color> _colors = [
    const Color(0xFFEF4444), // 红色
    const Color(0xFFF97316), // 橙色
    const Color(0xFFF59E0B), // 琥珀色
    const Color(0xFF10B981), // 绿色
    const Color(0xFF06B6D4), // 青色
    const Color(0xFF3B82F6), // 蓝色
    const Color(0xFF6366F1), // 靛蓝色
    const Color(0xFF8B5CF6), // 紫色
    const Color(0xFFEC4899), // 粉色
    const Color(0xFF78350F), // 棕色
    const Color(0xFF6B7280), // 灰色
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.existingCategory != null) {
      _selectedIcon = IconLibrary.getIconByName(widget.existingCategory!.iconName);
      _selectedIconName = widget.existingCategory!.iconName;
      _selectedColor = Color(int.parse(widget.existingCategory!.color.replaceFirst('#', '0xFF')));
    } else {
      _selectedIcon = widget.isIncome 
          ? IconLibrary.getDefaultIncomeIcon() 
          : IconLibrary.getDefaultExpenseIcon();
      _selectedIconName = widget.isIncome 
          ? IconLibrary.getDefaultIncomeCategory() 
          : IconLibrary.getDefaultExpenseCategory();
      _selectedColor = widget.isIncome ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXLarge),
          topRight: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              widget.existingCategory == null ? Icons.add_rounded : Icons.edit_rounded,
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

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类名称',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral800,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        _isCustomCategory
            ? TextField(
                controller: _customNameController,
                decoration: InputDecoration(
                  hintText: '输入自定义分类名称',
                  prefixIcon: Icon(_selectedIcon, color: _selectedColor, size: 20),
                  filled: true,
                  fillColor: AppTheme.neutral50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(AppTheme.spaceMedium),
                decoration: BoxDecoration(
                  color: AppTheme.neutral50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.neutral200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedIcon,
                      color: _selectedColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Text(
                      _selectedIconName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutral800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '点击图标选择',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutral400,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildIconSelector() {
    final allIcons = IconLibrary.getIconsByType(widget.isIncome);
    final allCategoryNames = IconLibrary.getCategoryNamesByType(widget.isIncome);

    // 根据搜索关键词过滤
    final filteredIndices = <int>[];
    if (_searchQuery.isEmpty) {
      filteredIndices.addAll(List.generate(allIcons.length, (i) => i));
    } else {
      for (int i = 0; i < allCategoryNames.length; i++) {
        if (allCategoryNames[i].toLowerCase().contains(_searchQuery.toLowerCase())) {
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
            color: AppTheme.neutral800,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        // 搜索框
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
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
            filled: true,
            fillColor: AppTheme.neutral50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium, vertical: AppTheme.spaceSmall),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: AppTheme.neutral50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: filteredIndices.isEmpty && _searchQuery.isNotEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spaceMedium),
                    child: Text(
                      '未找到匹配的分类',
                      style: TextStyle(color: AppTheme.neutral400),
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
                  itemCount: filteredIndices.length + (_searchQuery.isEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 最后一项是"自定义分类"
                    if (_searchQuery.isEmpty && index == filteredIndices.length) {
                      final isSelected = _isCustomCategory;
                      return InkWell(
                        onTap: () => setState(() {
                          _isCustomCategory = true;
                          _selectedIcon = Icons.edit;
                          _selectedIconName = '自定义';
                          _customNameController.text = '';
                        }),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? _selectedColor.withOpacity(0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSelected ? _selectedColor : AppTheme.neutral200,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _selectedColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: isSelected ? _selectedColor : AppTheme.neutral600,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  '自定义',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? _selectedColor : AppTheme.neutral600,
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
                    }

                    final originalIndex = filteredIndices[index];
                    final icon = allIcons[originalIndex];
                    final categoryName = allCategoryNames[originalIndex];
                    final isSelected = categoryName == _selectedIconName && !_isCustomCategory;

                    return InkWell(
                      onTap: () => setState(() {
                        _isCustomCategory = false;
                        _selectedIcon = icon;
                        _selectedIconName = categoryName;
                      }),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? _selectedColor.withOpacity(0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: isSelected ? _selectedColor : AppTheme.neutral200,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _selectedColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? _selectedColor : AppTheme.neutral600,
                              size: 26,
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                categoryName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? _selectedColor : AppTheme.neutral600,
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

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择颜色',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral800,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: AppTheme.neutral50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: Column(
            children: [
              // 第一行颜色
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _colors.take(10).map((color) {
                  final isSelected = color.value == _selectedColor.value;
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
                          color: isSelected ? AppTheme.neutral800 : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
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
              const SizedBox(height: AppTheme.spaceMedium),
              // 第二行颜色
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _colors.skip(10).take(10).map((color) {
                  final isSelected = color.value == _selectedColor.value;
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
                          color: isSelected ? AppTheme.neutral800 : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
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
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预览效果',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral800,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.neutral200),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.1),
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
                      _isCustomCategory
                          ? (_customNameController.text.isEmpty ? '自定义分类' : _customNameController.text)
                          : _selectedIconName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      widget.isIncome ? '收入分类' : '支出分类',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
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

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.neutral200,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: const Center(
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Container(
              height: 48,
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
        ],
      ),
    );
  }

  void _saveCategory() {
    final name = _isCustomCategory ? _customNameController.text.trim() : _selectedIconName;

    if (_isCustomCategory && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入自定义分类名称')),
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

    final category = widget.existingCategory != null
        ? widget.existingCategory!.copyWith(
            name: name,
            iconName: name,
            color: '#${_selectedColor.value.toRadixString(16).substring(2)}',
          )
        : (widget.isIncome
            ? Category.createIncome(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                iconName: name,
                color: '#${_selectedColor.value.toRadixString(16).substring(2)}',
              )
            : Category.createExpense(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                iconName: name,
                color: '#${_selectedColor.value.toRadixString(16).substring(2)}',
              ));

    widget.onSave(category);
    Navigator.pop(context);
  }
}

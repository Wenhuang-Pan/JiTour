import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_inference_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

/// 日志统一前缀，与 CategoryInferenceService 保持一致，便于控制台过滤
const String _logTag = '[MerchantRule]';

/// 商户规则编辑器页面
///
/// 用于管理「商户名 → 分类」的映射规则。支付通知自动记账时会优先套用
/// 这些规则，提升分类准确率。支持新增、编辑、删除、搜索规则。
///
/// WHY: 用户在自动记账弹窗中确认的分类会通过 [CategoryInferenceService.learn]
/// 自动学习，本页面提供统一的可视化管理入口，便于批量维护与纠错。
class MerchantRuleEditorScreen extends StatefulWidget {
  /// 构造商户规则编辑器页面
  ///
  /// @param key 用于控件标识的可选键
  const MerchantRuleEditorScreen({super.key});

  @override
  State<MerchantRuleEditorScreen> createState() =>
      _MerchantRuleEditorScreenState();
}

class _MerchantRuleEditorScreenState extends State<MerchantRuleEditorScreen> {
  /// 商户名 → 分类名 的映射
  Map<String, String> _rules = <String, String>{};

  /// 可选支出分类列表
  List<Category> _expenseCategories = <Category>[];

  /// 加载状态
  bool _isLoading = true;

  /// 搜索关键字（null 或空字符串表示无搜索）
  String? _searchKeyword;

  /// 搜索框控制器
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载商户规则与支出分类数据
  ///
  /// WHY: 同步获取学习表与支出分类，数据量小无需异步等待，
  /// 但保留 _isLoading 状态以统一空状态/错误态展示入口。
  Future<void> _loadData() async {
    debugPrint('$_logTag _loadData 开始');
    setState(() {
      _isLoading = true;
    });
    _rules = CategoryInferenceService.getAllLearned();
    _expenseCategories = CategoryService.getExpenseCategories();
    debugPrint(
        '$_logTag _loadData 完成: 规则数=${_rules.length}, 分类数=${_expenseCategories.length}');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 过滤并排序规则列表
  ///
  /// 若搜索关键字为空返回全部 entries（按 key 字母升序排序），
  /// 否则返回 key 或 value 包含关键字（不区分大小写）的 entries。
  ///
  /// @return 过滤后的 entries 列表
  /// 算法复杂度: O(n log n)，n 为规则总数，主要来自排序。
  List<MapEntry<String, String>> _filterRules() {
    final entries = _rules.entries.toList();
    if (_searchKeyword == null || _searchKeyword!.isEmpty) {
      entries.sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
          a.key.compareTo(b.key));
      return entries;
    }
    final keyword = _searchKeyword!.toLowerCase();
    final filtered = entries.where((MapEntry<String, String> e) {
      return e.key.toLowerCase().contains(keyword) ||
          e.value.toLowerCase().contains(keyword);
    }).toList();
    filtered.sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
        a.key.compareTo(b.key));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商户规则'),
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加规则',
            onPressed: () => _showEditSheet(null),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildSearchBar(),
          const SizedBox(height: AppTheme.spaceSmall),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  /// 构建搜索框
  ///
  /// @return 搜索框 Container
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: '搜索商户名或分类',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.neutral400,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMedium,
            vertical: AppTheme.spaceMedium,
          ),
        ),
        // WHY: 列表数据量小，直接 setState 即可，无需防抖。
        onChanged: (String value) =>
            setState(() => _searchKeyword = value.trim()),
      ),
    );
  }

  /// 构建规则列表
  ///
  /// @return 列表 Widget（含加载态、空态、搜索无结果态）
  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<MapEntry<String, String>> entries = _filterRules();
    if (entries.isEmpty) {
      if (_rules.isEmpty) {
        return _buildEmptyState();
      }
      return _buildNoSearchResult();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium),
      itemCount: entries.length,
      itemBuilder: (BuildContext ctx, int i) => _buildRuleCard(entries[i]),
    );
  }

  /// 构建无任何规则时的空状态
  ///
  /// @return 空状态 Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.rule_rounded, size: 64, color: AppTheme.neutral400),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '暂无规则',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '添加商户规则后，支付通知自动记账会优先套用这些规则',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          ElevatedButton(
            onPressed: () => _showEditSheet(null),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getPrimaryColor(context),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXLarge,
                vertical: AppTheme.spaceMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Text(
              '添加规则',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索无结果状态
  ///
  /// @return 搜索无结果 Widget
  Widget _buildNoSearchResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.search_off_rounded,
              size: 64, color: AppTheme.neutral400),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '未找到匹配的规则',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建单条规则卡片
  ///
  /// @param entry 商户名 → 分类名 的映射条目
  /// @return 规则卡片 Widget
  Widget _buildRuleCard(MapEntry<String, String> entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: InkWell(
        onTap: () => _showEditSheet(entry),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          child: Row(
            children: <Widget>[
              // 左侧：商户名 + 分类标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSmall,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimaryColor(context)
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: AppTheme.getPrimaryColor(context),
                          fontSize: AppTheme.textLabelMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧：编辑 + 删除按钮
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppTheme.neutral400),
                onPressed: () => _showEditSheet(entry),
                tooltip: '编辑',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => _confirmDelete(entry.key),
                tooltip: '删除',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示添加/编辑规则的底部 Sheet
  ///
  /// @param entry 编辑时传入原条目，新增时传入 null
  Future<void> _showEditSheet(MapEntry<String, String>? entry) async {
    final bool isAdd = entry == null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXXLarge),
          bottom: Radius.circular(AppTheme.radiusXXLarge),
        ),
      ),
      builder: (BuildContext ctx) => _EditRuleSheet(
        merchant: entry?.key,
        categoryName: entry?.value,
        expenseCategories: _expenseCategories,
        isAdd: isAdd,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  /// 删除规则二次确认对话框
  ///
  /// WHY: 项目规范要求删除操作必须二次确认，避免误触丢失数据。
  ///
  /// @param merchant 待删除的商户名
  Future<void> _confirmDelete(String merchant) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定删除商户 "$merchant" 的规则吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    debugPrint('$_logTag _confirmDelete 用户已确认删除: merchant="$merchant"');
    try {
      await CategoryInferenceService.forget(merchant);
      debugPrint('$_logTag _confirmDelete 删除成功，开始刷新列表');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已删除'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // WHY: 删除失败需给出友好提示，禁止静默失败。
      debugPrint(
          '$_logTag _confirmDelete 删除失败: merchant="$merchant", error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除失败，请重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 商户规则编辑底部 Sheet
///
/// 提供商户名输入与分类选择，用于新增或编辑一条商户规则。
///
/// WHY: 编辑时不允许修改商户名，因为它是 Hive box 的 key，
/// 改商户名等同于新增规则，应通过「删除旧规则 + 添加新规则」实现。
class _EditRuleSheet extends StatefulWidget {
  /// 编辑时传入原商户名，添加时为 null
  final String? merchant;

  /// 编辑时传入原分类名，添加时为 null
  final String? categoryName;

  /// 可选支出分类列表
  final List<Category> expenseCategories;

  /// 是否为新增模式
  final bool isAdd;

  /// 保存成功后的回调
  final VoidCallback onSaved;

  /// 构造编辑 Sheet
  ///
  /// @param merchant 原商户名
  /// @param categoryName 原分类名
  /// @param expenseCategories 可选支出分类
  /// @param isAdd 是否新增
  /// @param onSaved 保存成功回调
  const _EditRuleSheet({
    required this.merchant,
    required this.categoryName,
    required this.expenseCategories,
    required this.isAdd,
    required this.onSaved,
  });

  @override
  State<_EditRuleSheet> createState() => _EditRuleSheetState();
}

class _EditRuleSheetState extends State<_EditRuleSheet> {
  /// 商户名输入控制器
  late final TextEditingController _merchantController;

  /// 当前选中的分类名
  String? _selectedCategory;

  /// 商户名输入框是否可编辑
  late final bool _merchantEnabled;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.merchant ?? '');
    _selectedCategory = widget.categoryName;
    // WHY: 编辑时不允许修改商户名，因为它是 Hive box 的 key。
    _merchantEnabled = widget.isAdd;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  /// 构建分类选择 chip 列表
  ///
  /// @return chip Widget 列表，无分类时返回提示文本
  List<Widget> _buildCategoryChips() {
    if (widget.expenseCategories.isEmpty) {
      return <Widget>[
        Text(
          '暂无分类，请先在分类管理中创建',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.errorColor,
              ),
        ),
      ];
    }
    return widget.expenseCategories
        .map((Category category) => _buildCategoryChip(
              name: category.name,
              isSelected: _selectedCategory == category.name,
              onTap: () => setState(() => _selectedCategory = category.name),
            ))
        .toList();
  }

  /// 构建单个分类 chip
  ///
  /// @param name 分类名
  /// @param isSelected 是否选中
  /// @param onTap 点击回调
  /// @return chip Widget
  Widget _buildCategoryChip({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryGradient = AppTheme.getPrimaryGradient(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMedium,
            vertical: AppTheme.spaceSmall + 2,
          ),
          decoration: BoxDecoration(
            gradient: isSelected ? primaryGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppTheme.neutral700 : AppTheme.neutral100),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: AppTheme.textBodyMedium,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.neutral100 : AppTheme.neutral700),
            ),
          ),
        ),
      ),
    );
  }

  /// 提交保存规则
  ///
  /// 校验商户名与分类，调用 [CategoryInferenceService.learn] 写入。
  Future<void> _submit() async {
    final String merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      debugPrint('$_logTag _submit 校验失败: 商户名为空');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入商户名'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      debugPrint('$_logTag _submit 校验失败: 未选择分类, merchant="$merchant"');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择分类'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    debugPrint(
        '$_logTag _submit 校验通过: merchant="$merchant", category="$_selectedCategory", isAdd=${widget.isAdd}');
    try {
      await CategoryInferenceService.learn(merchant, _selectedCategory!);
      debugPrint('$_logTag _submit 保存成功，触发 onSaved 回调刷新列表');
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAdd ? '已添加' : '已保存'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // WHY: 保存失败是关键节点，记录商户名、分类、错误信息三要素，便于排查
      debugPrint(
          '$_logTag _submit 保存失败: merchant="$merchant", category="$_selectedCategory", isAdd=${widget.isAdd}, error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXXLarge),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceXLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 拖动手柄
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
                // 标题
                Text(
                  widget.isAdd ? '添加规则' : '编辑规则',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                // 商户名输入
                Text(
                  '商户名',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                TextFormField(
                  controller: _merchantController,
                  enabled: _merchantEnabled,
                  decoration: InputDecoration(
                    hintText: '如：美团外卖',
                    filled: true,
                    fillColor:
                        isDark ? AppTheme.neutral700 : AppTheme.neutral100,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(
                        color: AppTheme.getPrimaryColor(context),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMedium,
                      vertical: AppTheme.spaceMedium,
                    ),
                  ),
                  style: const TextStyle(fontSize: AppTheme.textBodyMedium),
                ),
                // WHY: 编辑时不允许修改商户名，因为它是 Hive box 的 key，
                // 改商户名等同于新增规则，应通过"删除旧规则+添加新规则"实现。
                if (!_merchantEnabled) ...<Widget>[
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Text(
                    '商户名不可修改，如需更改请删除后重新添加',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLarge),
                // 分类选择
                Text(
                  '分类',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Wrap(
                  spacing: AppTheme.spaceSmall,
                  runSpacing: AppTheme.spaceSmall,
                  children: _buildCategoryChips(),
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                // 操作按钮
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.neutral600,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceLarge),
                        ),
                        child: Text(
                          '取消',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.getPrimaryColor(context),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceLarge),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLarge),
                          ),
                        ),
                        child: Text(
                          widget.isAdd ? '添加' : '保存',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

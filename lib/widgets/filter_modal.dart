import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/filter_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';

/// 筛选模态框组件
///
/// 提供多维度筛选功能，支持按分类、账户、日期、金额、收支类型等筛选交易。
class FilterModal extends StatefulWidget {
  /// 当前筛选条件
  final FilterConditions initialConditions;

  /// 筛选确认回调
  final void Function(FilterConditions) onApply;

  /// 清除筛选回调
  final VoidCallback onClear;

  const FilterModal({
    super.key,
    required this.initialConditions,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late FilterConditions _conditions;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    _conditions = widget.initialConditions.copyWith();
    _minAmountController = TextEditingController(
      text: _conditions.minAmount != null
          ? _conditions.minAmount!.toString()
          : '',
    );
    _maxAmountController = TextEditingController(
      text: _conditions.maxAmount != null
          ? _conditions.maxAmount!.toString()
          : '',
    );
    _keywordController = TextEditingController(
      text: _conditions.keyword ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKeywordSection(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildTypeSection(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildCategorySection(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildAccountSection(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildDateSection(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildAmountSection(),
                  const SizedBox(height: AppTheme.spaceXXLarge),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          Text(
            '筛选',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onClear,
            child: const Text('清除'),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 构建关键词搜索
  Widget _buildKeywordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextField(
          controller: _keywordController,
          onChanged: (value) => _conditions.keyword = value,
          decoration: const InputDecoration(
            hintText: '搜索备注、分类或账户',
            prefixIcon: Icon(Icons.search_rounded),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMedium,
              vertical: AppTheme.spaceMedium,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建收支类型筛选
  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '收支类型',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Row(
          children: [
            _buildTypeChip('全部', null),
            const SizedBox(width: AppTheme.spaceSmall),
            _buildTypeChip('收入', true),
            const SizedBox(width: AppTheme.spaceSmall),
            _buildTypeChip('支出', false),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, bool? isIncome) {
    final isSelected = _conditions.isIncome == isIncome;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected
          ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.10)
          : AppTheme.getSecondaryBackground(context),
      labelStyle: TextStyle(
        color: isSelected
            ? AppTheme.getPrimaryColor(context)
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      onPressed: () {
        setState(() {
          _conditions.isIncome = isSelected ? null : isIncome;
        });
      },
    );
  }

  /// 构建分类筛选
  Widget _buildCategorySection() {
    final categories = [
      ...CategoryService.getIncomeCategories(),
      ...CategoryService.getExpenseCategories(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '分类',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            if (_conditions.category != null)
              Text(
                '(已选)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral400,
                    ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _conditions.category == category.name;
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spaceSmall),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: isSelected,
                  selectedColor:
                      Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                          .withValues(alpha: 0.10),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Color(
                            int.parse(category.color.replaceFirst('#', '0xFF')))
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _conditions.category = selected ? category.name : null;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建账户筛选
  Widget _buildAccountSection() {
    final accounts = AccountService.getAllAccounts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '账户',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            if (_conditions.account != null)
              Text(
                '(已选)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral400,
                    ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              final isSelected = _conditions.account == account.name;
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spaceSmall),
                child: ChoiceChip(
                  label: Text(account.name),
                  selected: isSelected,
                  selectedColor:
                      AppTheme.getPrimaryColor(context).withValues(alpha: 0.10),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _conditions.account = selected ? account.name : null;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建日期筛选
  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '日期范围',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Row(
          children: [
            _buildDateButton('今天', 'today'),
            const SizedBox(width: AppTheme.spaceSmall),
            _buildDateButton('昨天', 'yesterday'),
            const SizedBox(width: AppTheme.spaceSmall),
            _buildDateButton('本周', 'week'),
            const SizedBox(width: AppTheme.spaceSmall),
            _buildDateButton('本月', 'month'),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        Row(
          children: [
            Expanded(
              child: _buildDatePickerField(
                '开始日期',
                _conditions.startDate,
                (date) => _conditions.startDate = date,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            Expanded(
              child: _buildDatePickerField(
                '结束日期',
                _conditions.endDate,
                (date) => _conditions.endDate = date,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateButton(String label, String type) {
    return ElevatedButton(
      onPressed: () {
        final range = FilterService.getDateRange(type);
        setState(() {
          _conditions.startDate = range['start'];
          _conditions.endDate = range['end'];
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.getSecondaryBackground(context),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        textStyle: const TextStyle(fontSize: AppTheme.textBodySmall),
      ),
      child: Text(label),
    );
  }

  Widget _buildDatePickerField(
    String label,
    DateTime? date,
    void Function(DateTime?) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final result = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (result != null) {
          setState(() => onChanged(result));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceMedium,
        ),
        decoration: BoxDecoration(
          color: AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Text(
              date != null ? DateFormat('MM/dd').format(date) : label,
              style: TextStyle(
                color: date != null
                    ? Theme.of(context).colorScheme.onSurface
                    : AppTheme.neutral400,
              ),
            ),
            const Spacer(),
            const Icon(Icons.calendar_month_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  /// 构建金额筛选
  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '金额范围',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  _conditions.minAmount = double.tryParse(value);
                },
                decoration: const InputDecoration(
                  hintText: '最低金额',
                  prefixText: '¥',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: AppTheme.spaceMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            const Text('至'),
            const SizedBox(width: AppTheme.spaceSmall),
            Expanded(
              child: TextField(
                controller: _maxAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  _conditions.maxAmount = double.tryParse(value);
                },
                decoration: const InputDecoration(
                  hintText: '最高金额',
                  prefixText: '¥',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: AppTheme.spaceMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建底部操作栏
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: widget.onClear,
              child: const Text('重置'),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_conditions);
                Navigator.pop(context);
              },
              child: const Text('确认筛选'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示筛选模态框
///
/// @param context 上下文
/// @param conditions 当前筛选条件
/// @param onApply 筛选确认回调
/// @param onClear 清除筛选回调
void showFilterModal(
  BuildContext context, {
  required FilterConditions conditions,
  required void Function(FilterConditions) onApply,
  required VoidCallback onClear,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
    ),
    builder: (_) => FilterModal(
      initialConditions: conditions,
      onApply: onApply,
      onClear: onClear,
    ),
  );
}

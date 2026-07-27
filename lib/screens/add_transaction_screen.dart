import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/tag.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../services/tag_service.dart';
import '../utils/icon_library.dart';
import '../utils/uuid_util.dart';
import '../widgets/numpad.dart';

/// 快捷日期选项数据类
class QuickDateOption {
  final String label;
  final DateTime date;

  const QuickDateOption(this.label, this.date);
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  int _currentTab = 0;
  Category? _selectedCategory;
  Account? _selectedAccount;
  List<Tag> _selectedTags = [];
  String _amountText = '0.0';
  DateTime _selectedDate = DateTime.now();
  bool _isReimbursed = false;
  double _couponAmount = 0.0;
  double _feeAmount = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = AccountService.getActiveAccounts();
      if (accounts.isNotEmpty) {
        setState(() {
          _selectedAccount = accounts.first;
        });
      }
      _updateDefaultCategory();
    });
  }

  void _updateDefaultCategory() {
    final categories = _currentTab == 0
        ? CategoryService.getExpenseCategories()
        : CategoryService.getIncomeCategories();
    setState(() {
      _selectedCategory = categories.firstOrNull;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildAmountSection(),
                _buildCategoryGrid(),
              ],
            ),
          ),
          Numpad(
            onNumberPressed: _onNumberPressed,
            onDeletePressed: _onDeletePressed,
            onSavePressed: _saveTransaction,
            onSaveAndAddPressed: _saveAndAddTransaction,
            canSave: _canSave,
            noteController: _noteController,
            selectedAccountName: _selectedAccount?.name,
            onAccountTap: _showAccountPicker,
            onDateTap: _selectDate,
            timeText: _formatDateTimeText(_selectedDate),
            onReimbursedTap: () =>
                setState(() => _isReimbursed = !_isReimbursed),
            isReimbursed: _isReimbursed,
            onCouponTap: _showCouponDialog,
            couponText: _couponAmount > 0
                ? '-¥${_couponAmount.toStringAsFixed(0)}'
                : null,
            onTagTap: _showTagPicker,
            tagText:
                _selectedTags.isNotEmpty ? '${_selectedTags.length}个' : null,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: const SizedBox.shrink(),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_rounded),
          onPressed: () {},
          tooltip: '更多',
        ),
      ],
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildAmountSection() {
    final isIncome = _currentTab == 1;
    final isTransfer = _currentTab == 2;
    final color = isIncome
        ? AppTheme.successColor
        : (isTransfer
            ? AppTheme.getPrimaryColor(context)
            : AppTheme.neutral900);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            children: [
              _buildTabButton('支出', 0),
              _buildTabButton('收入', 1),
              _buildTabButton('转账', 2),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXLarge),
          Row(
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _amountText,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = index;
          });
          _updateDefaultCategory();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textBodyLarge,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppTheme.getPrimaryColor(context)
                  : AppTheme.neutral400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = _currentTab == 0
        ? CategoryService.getExpenseCategories()
        : CategoryService.getIncomeCategories();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
      margin: const EdgeInsets.only(top: AppTheme.spaceXLarge),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppTheme.spaceXLarge,
          crossAxisSpacing: AppTheme.spaceMedium,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory?.id == category.id;
          final categoryColor =
              Color(int.parse(category.color.replaceFirst('#', '0xFF')));
          return InkWell(
            onTap: () {
              setState(() => _selectedCategory = category);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryColor
                        : categoryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: isSelected ? categoryColor : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Icon(
                    _getIconData(category.iconName),
                    color: isSelected ? Colors.white : categoryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? categoryColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAccountPicker() {
    final accounts = AccountService.getActiveAccounts();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              '选择账户',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isSelected = _selectedAccount?.id == account.id;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedAccount = account);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMedium),
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(account.colorValue).withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Icon(
                            IconLibrary.getIconByName(account.iconName),
                            color: Color(account.colorValue),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMedium),
                        Expanded(
                          child: Text(
                            account.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '¥${account.currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          const SizedBox(width: AppTheme.spaceSmall),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.getPrimaryColor(context),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCouponDialog() {
    final couponController = TextEditingController(
      text: _couponAmount > 0 ? _couponAmount.toString() : '',
    );
    final feeController = TextEditingController(
      text: _feeAmount > 0 ? _feeAmount.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.percent_rounded,
                color: AppTheme.getPrimaryColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('优惠/手续费'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: couponController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '优惠券金额',
                prefixText: '-¥',
              ),
              onChanged: (value) {
                setState(() => _couponAmount = double.tryParse(value) ?? 0);
              },
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '手续费',
                prefixText: '+¥',
              ),
              onChanged: (value) {
                setState(() => _feeAmount = double.tryParse(value) ?? 0);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showTagPicker() {
    final allTags = TagService.getActiveTags();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  '选择标签',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceXSmall),
                Text(
                  '可多选标签为交易分类',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: AppTheme.textBodySmall,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                Wrap(
                  spacing: AppTheme.spaceSmall,
                  runSpacing: AppTheme.spaceSmall,
                  children: allTags.map((tag) {
                    final isSelected = _selectedTags.any((t) => t.id == tag.id);
                    final tagColor = Color(tag.colorValue);
                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            _selectedTags.removeWhere((t) => t.id == tag.id);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                        setState(() {});
                      },
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconLibrary.getIconByName(tag.iconName),
                              color: isSelected ? Colors.white : tagColor,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.spaceSmall),
                            Text(
                              tag.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : tagColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getIconData(String iconName) {
    try {
      return IconLibrary.getIconByName(iconName);
    } catch (e) {
      return Icons.category;
    }
  }

  void _onNumberPressed(String text) {
    setState(() {
      if (text == '.') {
        if (!_amountText.contains('.')) {
          _amountText += '.';
        }
      } else if (text == '-') {
      } else if (text == '+') {
      } else {
        if (_amountText == '0' || _amountText == '0.0') {
          _amountText = text;
        } else {
          final parts = _amountText.split('.');
          if (parts.length > 1 && parts[1].length >= 2) {
            return;
          }
          _amountText += text;
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (_amountText.length > 1) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      } else {
        _amountText = '0.0';
      }
    });
  }

  String _formatDateTimeText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBeforeYesterday = today.subtract(const Duration(days: 2));
    final tomorrow = today.add(const Duration(days: 1));

    final dateOnly = DateTime(date.year, date.month, date.day);
    final timeText = DateFormat('HH:mm').format(date);

    if (dateOnly == today) {
      return '今天 $timeText';
    } else if (dateOnly == yesterday) {
      return '昨天 $timeText';
    } else if (dateOnly == dayBeforeYesterday) {
      return '前天 $timeText';
    } else if (dateOnly == tomorrow) {
      return '明天 $timeText';
    } else {
      return '${DateFormat('M/d').format(date)} $timeText';
    }
  }

  bool get _canSave {
    final amount = double.tryParse(_amountText);
    return amount != null && amount > 0 && _selectedCategory != null;
  }

  Future<void> _selectDate() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => _buildDateTimePicker(context),
    );
  }

  Widget _buildDateTimePicker(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final dayBeforeYesterday = today.subtract(const Duration(days: 2));
        final tomorrow = today.add(const Duration(days: 1));

        final quickDates = [
          QuickDateOption('前天', dayBeforeYesterday),
          QuickDateOption('昨天', yesterday),
          QuickDateOption('今天', today),
          QuickDateOption('明天', tomorrow),
        ];

        return Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                '选择日期时间',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceMedium),

              // 快捷日期按钮
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: quickDates.length,
                  itemBuilder: (context, index) {
                    final item = quickDates[index];
                    final isSelected = DateTime(_selectedDate.year,
                            _selectedDate.month, _selectedDate.day) ==
                        item.date;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: AppTheme.spaceSmall),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMedium,
                          ),
                          backgroundColor: isSelected
                              ? AppTheme.getPrimaryColor(context)
                              : AppTheme.getSecondaryBackground(context),
                          foregroundColor: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            _selectedDate = DateTime(
                              item.date.year,
                              item.date.month,
                              item.date.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                            );
                          });
                          setState(() {});
                        },
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 日期选择器
              Container(
                color: isDark ? AppTheme.neutral800 : Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  onDateChanged: (date) {
                    setModalState(() {
                      _selectedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        _selectedDate.hour,
                        _selectedDate.minute,
                      );
                    });
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 时间选择器
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.getSecondaryBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: DropdownButtonFormField<int>(
                        value: _selectedDate.hour,
                        decoration: const InputDecoration(
                          labelText: '小时',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMedium,
                            vertical: AppTheme.spaceSmall,
                          ),
                          border: InputBorder.none,
                        ),
                        items: List.generate(24, (index) => index)
                            .map((hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text(
                                      '${hour.toString().padLeft(2, '0')}:00'),
                                ))
                            .toList(),
                        onChanged: (hour) {
                          if (hour != null) {
                            setModalState(() {
                              _selectedDate = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                hour,
                                _selectedDate.minute,
                              );
                            });
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSmall),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.getSecondaryBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: DropdownButtonFormField<int>(
                        value: _selectedDate.minute,
                        decoration: const InputDecoration(
                          labelText: '分钟',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMedium,
                            vertical: AppTheme.spaceSmall,
                          ),
                          border: InputBorder.none,
                        ),
                        items: [0, 15, 30, 45]
                            .map((minute) => DropdownMenuItem(
                                  value: minute,
                                  child: Text(
                                      ':${minute.toString().padLeft(2, '0')}'),
                                ))
                            .toList(),
                        onChanged: (minute) {
                          if (minute != null) {
                            setModalState(() {
                              _selectedDate = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                _selectedDate.hour,
                                minute,
                              );
                            });
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 当前选中时间显示
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMedium),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '当前选择',
                      style: TextStyle(
                        fontSize: AppTheme.textBodyMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy年M月d日 HH:mm', 'zh_CN')
                          .format(_selectedDate),
                      style: TextStyle(
                        fontSize: AppTheme.textBodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXLarge),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '确定',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    if (!_canSave) return;
    await _doSaveTransaction(false);
  }

  Future<void> _saveAndAddTransaction() async {
    if (!_canSave) return;
    await _doSaveTransaction(true);
  }

  Future<void> _doSaveTransaction(bool keepOpen) async {
    final amount = double.parse(_amountText);
    final isIncome = _currentTab == 1;

    final transaction = Transaction(
      id: UuidUtil.generate(),
      amount: amount,
      isIncome: isIncome,
      category: _selectedCategory!.name,
      account: _selectedAccount?.name ?? '默认账户',
      date: _selectedDate,
      note: _noteController.text,
      tags: _selectedTags.map((t) => t.id).join(','),
      isReimbursed: _isReimbursed,
      fee: _feeAmount,
      coupon: _couponAmount,
    );

    DatabaseService.addTransaction(transaction);

    if (_selectedAccount != null) {
      final account = AccountService.getAccountById(_selectedAccount!.id);
      if (account != null) {
        if (isIncome) {
          account.currentBalance += amount;
        } else {
          account.currentBalance -= amount;
        }
        await AccountService.updateAccount(account);
      }
    }

    if (mounted) {
      if (keepOpen) {
        setState(() {
          _amountText = '0.0';
          _noteController.clear();
          _isReimbursed = false;
          _couponAmount = 0.0;
          _feeAmount = 0.0;
        });
      } else {
        Navigator.pop(context);
      }
    }
  }
}

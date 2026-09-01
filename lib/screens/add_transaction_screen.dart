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
import '../widgets/location_picker_modal.dart';
import 'photo_capture_screen.dart';

/// 快捷日期选项数据类
class QuickDateOption {
  final String label;
  final DateTime date;

  const QuickDateOption(this.label, this.date);
}

class AddTransactionScreen extends StatefulWidget {
  /// 编辑模式时传入的待编辑交易，新增模式为 null
  final Transaction? editingTransaction;

  const AddTransactionScreen({super.key, this.editingTransaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _noteController = TextEditingController();

  int _currentTab = 0;
  Category? _selectedCategory;
  Account? _selectedAccount;
  final List<Tag> _selectedTags = [];
  String _amountText = '0.0';
  DateTime _selectedDate = DateTime.now();
  bool _isReimbursed = false;
  double _couponAmount = 0.0;
  double _feeAmount = 0.0;

  // 位置信息
  String? _selectedLocationName;
  double? _selectedLatitude;
  double? _selectedLongitude;

  /// 编辑模式下的原交易 ID，新增模式为 null
  String? _editingId;

  /// 是否处于编辑模式
  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editingTransaction != null) {
        _populateFromTransaction(widget.editingTransaction!);
      } else {
        final accounts = AccountService.getActiveAccounts();
        if (accounts.isNotEmpty) {
          setState(() {
            _selectedAccount = accounts.first;
          });
        }
        _updateDefaultCategory();
      }
    });
  }

  /// 从已有交易填充表单字段（编辑模式）
  ///
  /// @param transaction 待编辑的交易
  void _populateFromTransaction(Transaction transaction) {
    _editingId = transaction.id;
    _currentTab = transaction.isIncome ? 1 : 0;
    _amountText = transaction.amount.toStringAsFixed(2);
    _selectedDate = transaction.date;
    _isReimbursed = transaction.isReimbursed;
    _couponAmount = transaction.coupon;
    _feeAmount = transaction.fee;
    _selectedLocationName = transaction.locationName;
    _selectedLatitude = transaction.latitude;
    _selectedLongitude = transaction.longitude;
    _noteController.text = transaction.note ?? '';

    // WHY: 编辑模式下，回填用户输入的"原价"金额
    // 由于 amount 字段已扣除优惠，需反向加回 coupon 并减去 fee，得到原输入金额
    if (!transaction.isIncome &&
        (transaction.coupon > 0 || transaction.fee > 0)) {
      final originalAmount =
          transaction.amount + transaction.coupon - transaction.fee;
      _amountText = originalAmount.toStringAsFixed(2);
    }

    // 匹配账户
    final accounts = AccountService.getActiveAccounts();
    final matchedAccount =
        accounts.where((a) => a.name == transaction.account).firstOrNull;
    if (matchedAccount != null) {
      _selectedAccount = matchedAccount;
    } else if (accounts.isNotEmpty) {
      _selectedAccount = accounts.first;
    }

    // 匹配分类
    final categories = _currentTab == 0
        ? CategoryService.getExpenseCategories()
        : CategoryService.getIncomeCategories();
    _selectedCategory =
        categories.where((c) => c.name == transaction.category).firstOrNull;

    // 匹配标签
    _selectedTags.clear();
    for (final tagId in transaction.tagIds) {
      final tag = TagService.getTagById(tagId);
      if (tag != null) {
        _selectedTags.add(tag);
      }
    }

    setState(() {});
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
            onSaveAndAddPressed: _isEditing ? null : _saveAndAddTransaction,
            saveButtonText: _isEditing ? '保存修改' : null,
            canSave: _canSave,
            noteController: _noteController,
            selectedAccountName: _selectedAccount?.name,
            onAccountTap: _showAccountPicker,
            onDateTap: _selectDate,
            timeText: _formatDateTimeText(_selectedDate),
            onReimbursedTap: () =>
                setState(() => _isReimbursed = !_isReimbursed),
            isReimbursed: _isReimbursed,
            onTagTap: _showTagPicker,
            tagText:
                _selectedTags.isNotEmpty ? '${_selectedTags.length}个标签' : '标签',
            onCouponTap: _showCouponDialog,
            couponText: _couponAmount > 0
                ? '优惠 ¥${_couponAmount.toStringAsFixed(2)}'
                : '优惠',
            onLocationTap: _showLocationPicker,
            locationText: _selectedLocationName ?? '位置',
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
      title: Text(
        _isEditing ? '编辑账单' : '',
        style: TextStyle(
          fontSize: AppTheme.textBodyLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: _isEditing
          ? const []
          : [
              IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: AppTheme.neutral500,
                ),
                onPressed: _startVoiceRecognition,
                tooltip: '文本记账',
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PhotoCaptureScreen(),
                    ),
                  );
                },
                tooltip: '拍照记账',
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            children: [
              _buildTabButton('支出', 0),
              _buildTabButton('收入', 1),
              _buildTabButton('转账', 2),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // WHY: 当输入含 +/- 时，实时计算表达式结果并显示，
                  // 让用户看到"50+30"的运算过程和最终金额
                  _amountText.contains(RegExp(r'[+-]'))
                      ? _evaluateExpression(_amountText)
                      : _amountText,
                  style: TextStyle(
                    fontSize: 48,
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium),
      margin: const EdgeInsets.only(top: AppTheme.spaceLarge),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 6,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryColor
                        : categoryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: isSelected ? categoryColor : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Icon(
                    _getIconData(category.iconName),
                    color: isSelected ? Colors.white : categoryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          ? AppTheme.getPrimaryColor(context)
                              .withValues(alpha: 0.12)
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
                            color: Color(account.colorValue)
                                .withValues(alpha: 0.12),
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
                color:
                    AppTheme.getPrimaryColor(context).withValues(alpha: 0.12),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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

  /// 显示更多选项菜单
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => Container(
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
              '更多选项',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceXLarge),
            _buildMoreOptionItem(
              Icons.local_offer_rounded,
              '标签',
              _selectedTags.isNotEmpty ? '已选${_selectedTags.length}个' : '添加标签',
              () {
                Navigator.pop(context);
                _showTagPicker();
              },
            ),
            const SizedBox(height: 4),
            _buildMoreOptionItem(
              Icons.percent_rounded,
              '优惠/手续费',
              _couponAmount > 0 || _feeAmount > 0
                  ? '优惠${_couponAmount}元 手续费${_feeAmount}元'
                  : '添加优惠或手续费',
              () {
                Navigator.pop(context);
                _showCouponDialog();
              },
            ),
            const SizedBox(height: 4),
            _buildMoreOptionItem(
              Icons.location_on_rounded,
              '位置',
              _selectedLocationName ?? '添加位置',
              () {
                Navigator.pop(context);
                _showLocationPicker();
              },
            ),
            const SizedBox(height: AppTheme.spaceXLarge),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceLarge,
        ),
        decoration: BoxDecoration(
          color: AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    AppTheme.getPrimaryColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon,
                  color: AppTheme.getPrimaryColor(context), size: 20),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppTheme.textBodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.neutral400),
          ],
        ),
      ),
    );
  }

  /// 显示位置选择器
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXLarge),
            ),
          ),
          child: const LocationPickerModal(),
        );
      },
    ).then((location) {
      if (location != null) {
        setState(() {
          _selectedLocationName = location['name'];
          _selectedLatitude = location['latitude'];
          _selectedLongitude = location['longitude'];
        });
      }
    });
  }

  /// 处理数字键盘输入
  ///
  /// 支持数字、小数点、加减运算符（+/-）的输入。
  /// +/- 会被解析为表达式并实时计算结果，例如 "50+30" 输入后会显示 80。
  ///
  /// @param text 用户按下的键值（'0'-'9'、'.'、'+'、'-'）
  void _onNumberPressed(String text) {
    setState(() {
      if (text == '.') {
        // WHY: 每个操作数只允许一个小数点，避免出现 "5.5.5" 非法格式
        final lastNumber = _amountText.split(RegExp(r'[+-]')).last;
        if (!lastNumber.contains('.')) {
          _amountText += '.';
        }
      } else if (text == '-' || text == '+') {
        // WHY: 支持加减表达式，如"50+30+20"，便于快速合并多笔金额
        // 不允许连续两个运算符，且不能以运算符开头
        if (_amountText.isEmpty ||
            _amountText == '0' ||
            _amountText.endsWith('+') ||
            _amountText.endsWith('-') ||
            _amountText.endsWith('.')) {
          return;
        }
        _amountText += text;
      } else {
        if (_amountText == '0' || _amountText == '0.0') {
          _amountText = text;
        } else {
          // WHY: 限制小数点后最多2位，符合金融场景精度要求
          final lastNumber = _amountText.split(RegExp(r'[+-]')).last;
          final parts = lastNumber.split('.');
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

  /// 打开文本记账对话框
  ///
  /// 用户手动输入或粘贴记账文本，点击"智能识别"按钮解析金额/分类/备注，
  /// 确认后自动填入表单。取代了原有的语音录音方案，避免平台兼容性问题。
  ///
  /// @return Future<void> 无返回值
  Future<void> _startVoiceRecognition() async {
    final TextEditingController textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // WHY: 实时解析预览，让用户在输入时即可看到识别结果
          final parsed = _parseVoiceText(textController.text);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor),
                SizedBox(width: AppTheme.spaceSmall),
                Text('文本记账'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: '输入或粘贴记账文本',
                      hintText: '例如：餐饮50元、交通打车30元',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  const Text(
                    '示例：餐饮50元、交通打车30元、购物买衣服200元、工资收入5000元',
                    style: TextStyle(fontSize: 11, color: AppTheme.neutral500),
                  ),
                  if (textController.text.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceMedium),
                    const Divider(height: 1),
                    const SizedBox(height: AppTheme.spaceMedium),
                    Text(
                      '解析预览：',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.neutral600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    _buildParsedResultItem('金额', parsed['amount'] ?? '未识别'),
                    _buildParsedResultItem('分类', parsed['category'] ?? '未识别'),
                    _buildParsedResultItem('备注', parsed['note'] ?? '未识别'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: textController.text.isEmpty
                    ? null
                    : () {
                        final result = _parseVoiceText(textController.text);
                        Navigator.pop(context);
                        _applyVoiceRecognitionResult(result);
                      },
                child: const Text('确认记账'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParsedResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.neutral500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    value == '未识别' ? AppTheme.neutral400 : AppTheme.neutral800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseVoiceText(String text) {
    final result = <String, String>{};
    String processedText = text;

    // ========== 1. 金额识别（增强版，支持多种模式） ==========
    // 模式1: ¥/￥ 符号 + 数字
    // 模式2: 数字 + 元/块/块钱
    // 模式3: 中文大写数字（壹佰、伍拾等）
    // 模式4: 英文数字（1 hundred = 100）
    // 模式5: 小票常见格式（合计/总计/金额/实付 + 数字）
    // 模式6: 银行卡消费短信格式（消费/支出/存入 + 金额）
    final List<Pattern> amountPatterns = [
      // ¥100, ￥100.50, ¥ 1,234.56
      RegExp(r'[¥￥]\s*([\d,]+\.?\d{0,2})'),
      // 100元, 50.50块, 99块钱, 1234.5元
      RegExp(r'([\d,]+\.?\d{0,2})\s*[元块]'),
      // 合计:100, 总计 200.50, 金额 ￥300
      RegExp(
          r'(?:合计|总计|共计|应收|实收|实付|应付|金额|消费|支出|存入|收款)[^¥￥\d]{0,5}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      // 银行卡消费：100.00
      RegExp(r'消费[^¥￥\d]{0,10}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      RegExp(r'支出[^¥￥\d]{0,10}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      // 小票底部金额
      RegExp(r'总[^¥￥\d]{0,3}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
    ];

    String foundAmount = '';
    for (final pattern in amountPatterns) {
      final match = RegExp(pattern.toString()).firstMatch(processedText);
      if (match != null) {
        final amountRaw = match.group(1) ?? '';
        if (amountRaw.isNotEmpty) {
          foundAmount = amountRaw.replaceAll(',', '');
          // 验证金额有效性
          final value = double.tryParse(foundAmount);
          if (value != null && value > 0 && value < 100000000) {
            break;
          }
        }
      }
    }

    // 如果还是没找到，尝试找字符串中出现的第一个有效数字（通常小票金额在下方）
    if (foundAmount.isEmpty) {
      final allNumbers = RegExp(r'[\d,]+\.\d{1,2}').allMatches(processedText);
      double maxAmount = 0;
      for (final match in allNumbers) {
        final numStr = match.group(0)?.replaceAll(',', '') ?? '';
        final value = double.tryParse(numStr);
        if (value != null && value > maxAmount && value < 1000000) {
          maxAmount = value;
        }
      }
      if (maxAmount > 0) {
        // 找最大的有两位小数的数字（通常是总金额）
        foundAmount = maxAmount
            .toStringAsFixed(maxAmount.truncateToDouble() == maxAmount ? 0 : 2);
      }
    }

    // 最后兜底：找任何数字
    if (foundAmount.isEmpty) {
      final anyNumber = RegExp(r'[\d,]+\.?\d*').firstMatch(processedText);
      if (anyNumber != null) {
        final numStr = anyNumber.group(0)?.replaceAll(',', '') ?? '';
        final value = double.tryParse(numStr);
        if (value != null && value > 0 && value < 100000000) {
          foundAmount = numStr;
        }
      }
    }

    if (foundAmount.isNotEmpty) {
      result['amount'] = foundAmount;
    }

    // ========== 2. 分类识别（增强版） ==========
    final expenseCategories = CategoryService.getExpenseCategories();
    final incomeCategories = CategoryService.getIncomeCategories();

    // 分类关键词映射表（比直接匹配更灵活）
    final Map<String, List<String>> categoryKeywords = {
      '餐饮': [
        '餐',
        '饭',
        '吃',
        '喝',
        '美食',
        '餐厅',
        '饭店',
        '外卖',
        '早茶',
        '午餐',
        '晚餐',
        '早餐',
        '夜宵'
      ],
      '交通': [
        '车',
        '交通',
        '油',
        '打车',
        '出租',
        '滴滴',
        '地铁',
        '公交',
        '火车',
        '高铁',
        '机票',
        '加油',
        '停车',
        '高速'
      ],
      '购物': ['购物', '买', '超市', '商场', '淘宝', '京东', '网购', '快递', '便利店'],
      '娱乐': ['娱乐', '玩', '电影', '游戏', 'KTV', '旅游', '景区', '门票', '健身', '运动'],
      '居家': ['水电', '房租', '物业', '燃气', '网络', '电话', '手机', '家电', '家具', '维修'],
      '医疗': ['医院', '看病', '药', '体检', '挂号', '医疗', '诊所'],
      '教育': ['书', '学习', '课程', '培训', '学费', '考试', '教育'],
      '通讯': ['话费', '充值', '流量', '宽带'],
      '人情': ['红包', '送礼', '份子', '礼物'],
      '投资': ['股票', '基金', '理财', '投资'],
      '工资': ['工资', '收入', '奖金', '薪资', '月薪', '年薪'],
      '奖金': ['奖金', '提成', '奖励', '分红'],
      '红包': ['红包', '转账收入', '收款'],
      '兼职': ['兼职', '外快', '副业'],
      '投资收益': ['利息', '分红', '收益'],
    };

    String matchedCategory = '';

    // 先精确匹配分类名
    final allCategories = [...expenseCategories, ...incomeCategories];
    for (final category in allCategories) {
      if (processedText.contains(category.name)) {
        matchedCategory = category.name;
        break;
      }
    }

    // 再用关键词匹配
    if (matchedCategory.isEmpty) {
      for (final entry in categoryKeywords.entries) {
        for (final keyword in entry.value) {
          if (processedText.contains(keyword)) {
            // 检查这个分类是否存在
            final exists = allCategories.any((c) => c.name == entry.key);
            if (exists) {
              matchedCategory = entry.key;
              break;
            }
          }
        }
        if (matchedCategory.isNotEmpty) break;
      }
    }

    // 根据关键词判断是收入还是支出
    if (matchedCategory.isEmpty) {
      final incomeKeywords = [
        '收入',
        '工资',
        '奖金',
        '红包',
        '收款',
        '存入',
        '到账',
        '转账',
        '报销'
      ];
      final expenseKeywords = ['消费', '支出', '支付', '付款', '花费', '花了'];

      bool isIncome = false;
      for (final kw in incomeKeywords) {
        if (processedText.contains(kw)) {
          isIncome = true;
          break;
        }
      }
      if (!isIncome) {
        for (final kw in expenseKeywords) {
          if (processedText.contains(kw)) {
            isIncome = false;
            break;
          }
        }
      }

      if (isIncome && incomeCategories.isNotEmpty) {
        matchedCategory = incomeCategories.first.name;
      } else if (expenseCategories.isNotEmpty) {
        matchedCategory = expenseCategories.first.name;
      }
    }

    result['category'] = matchedCategory;

    // ========== 3. 备注提取（增强版） ==========
    // 移除已识别的分类关键词和金额，剩下的就是备注
    String noteText = processedText;

    // 移除金额相关字符
    noteText = noteText.replaceAll(RegExp(r'[¥￥]'), '');
    noteText = noteText.replaceAll(RegExp(r'[\d,]+\.?\d*'), '');
    noteText = noteText.replaceAll(RegExp(r'[元块角分整]'), '');

    // 移除常见的小票/消费关键词
    final noteRemoveKeywords = [
      '合计',
      '总计',
      '共计',
      '应收',
      '实收',
      '实付',
      '应付',
      '金额',
      '消费',
      '支出',
      '存入',
      '收款',
      '付款',
      '支付',
      '花费',
      '花了',
      '小票',
      '发票',
      '收据',
      '单号',
      '编号',
      '时间',
      '日期',
      '欢迎光临',
      '谢谢惠顾',
    ];
    for (final kw in noteRemoveKeywords) {
      noteText = noteText.replaceAll(kw, '');
    }

    // 移除已识别的分类关键词
    if (matchedCategory.isNotEmpty) {
      noteText = noteText.replaceAll(matchedCategory, '');
      final keywords = categoryKeywords[matchedCategory] ?? [];
      for (final kw in keywords) {
        noteText = noteText.replaceAll(kw, '');
      }
    }

    // 清理空格和特殊字符
    noteText = noteText.replaceAll(RegExp(r'\s+'), ' ').trim();
    noteText = noteText
        .replaceAll(
            RegExp(r'[，。！？、；：""' '【】《》（）()\[\]{}<>/\\|@#\$%^&*\-_=+`~]+'), ' ')
        .trim();

    // 如果备注太长，截断
    if (noteText.length > 50) {
      noteText = noteText.substring(0, 50);
    }

    if (noteText.isNotEmpty && noteText.length >= 2) {
      result['note'] = noteText;
    }

    return result;
  }

  void _applyVoiceRecognitionResult(Map<String, String> parsed) {
    if (parsed['amount']?.isNotEmpty == true) {
      setState(() {
        _amountText = parsed['amount']!;
      });
    }

    if (parsed['category']?.isNotEmpty == true) {
      final categories = _currentTab == 0
          ? CategoryService.getExpenseCategories()
          : CategoryService.getIncomeCategories();
      final matchedCategory = categories.firstWhere(
        (c) => c.name == parsed['category'],
        orElse: () => categories.first,
      );
      setState(() {
        _selectedCategory = matchedCategory;
        if (matchedCategory.isIncome) {
          _currentTab = 1;
        } else {
          _currentTab = 0;
        }
      });
    }

    if (parsed['note']?.isNotEmpty == true && _noteController.text.isEmpty) {
      _noteController.text = parsed['note']!;
    }

    // 移除全局 SnackBar，改为极短的提示（避免遮挡）
    final hasAmount = parsed['amount']?.isNotEmpty == true;
    final hasCategory = parsed['category']?.isNotEmpty == true;
    if (hasAmount || hasCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasAmount
                ? '已填入：¥${parsed['amount']}${hasCategory ? ' · ${parsed['category']}' : ''}'
                : '已填入分类：${parsed['category']}',
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
        ),
      );
    }
  }

  /// 计算金额表达式的最终值
  ///
  /// 支持加减运算，如 "50+30+20" → "100"，"100-25.5" → "74.5"。
  /// 用于实时显示表达式结果和保存时取最终金额。
  ///
  /// @param expression 金额表达式字符串
  /// @return String 格式化后的结果字符串；无法解析时返回原表达式
  String _evaluateExpression(String expression) {
    try {
      // WHY: 使用正则按 +/- 分割，再按顺序累加，避免引入 eval 类库
      final tokens = expression.split(RegExp(r'(?=[+-])'));
      double result = 0;
      bool first = true;
      for (final token in tokens) {
        if (token.isEmpty) continue;
        if (token == '+' || token == '-') continue;
        final value = double.tryParse(token);
        if (value == null) return expression; // 解析失败，返回原文本
        if (first) {
          result = value;
          first = false;
        } else if (token.startsWith('+')) {
          result += value;
        } else if (token.startsWith('-')) {
          result -= value;
        } else {
          result += value;
        }
      }
      // WHY: 整数时不显示小数点，提升可读性
      return result == result.toInt()
          ? result.toInt().toString()
          : result.toStringAsFixed(2);
    } catch (_) {
      return expression;
    }
  }

  /// 获取最终金额数值（解析表达式）
  /// @return double 金额值；解析失败返回 0
  double get _finalAmount {
    final text = _amountText.contains(RegExp(r'[+-]'))
        ? _evaluateExpression(_amountText)
        : _amountText;
    return double.tryParse(text) ?? 0;
  }

  bool get _canSave {
    final amount = _finalAmount;
    return amount > 0 && _selectedCategory != null;
  }

  Future<void> _selectDate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => _buildDateTimePicker(context),
    );
  }

  Widget _buildDateTimePicker(BuildContext context) {
    DateTime tempDate = _selectedDate;
    return StatefulBuilder(
      builder: (context, setModalState) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final dayBeforeYesterday = today.subtract(const Duration(days: 2));
        final tomorrow = today.add(const Duration(days: 1));

        final quickDates = [
          ('前天', dayBeforeYesterday),
          ('昨天', yesterday),
          ('今天', today),
          ('明天', tomorrow),
        ];

        // 生成前后可选的日期卡片（约30天范围）
        final List<DateTime> dayCards = List.generate(40, (i) {
          return today.add(Duration(days: i - 20));
        })
            .where((d) =>
                d.isAfter(DateTime(2019, 12, 31)) &&
                d.isBefore(DateTime.now().add(const Duration(days: 31))))
            .toList();

        final initialDayIndex = dayCards.indexWhere((d) =>
            DateTime(d.year, d.month, d.day) ==
            DateTime(tempDate.year, tempDate.month, tempDate.day));

        final dayScrollController = ScrollController(
          initialScrollOffset:
              (initialDayIndex < 0 ? 20 : initialDayIndex) * 56.0,
        );
        final hourController = FixedExtentScrollController(
          initialItem: tempDate.hour,
        );
        final minuteController = FixedExtentScrollController(
          initialItem: tempDate.minute,
        );

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLarge,
              AppTheme.spaceSmall,
              AppTheme.spaceLarge,
              AppTheme.spaceLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.neutral300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Text(
                  '选择日期时间',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),

                // 快捷日期按钮
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickDates.length,
                    itemBuilder: (context, index) {
                      final (label, date) = quickDates[index];
                      final isSelected = DateTime(
                              tempDate.year, tempDate.month, tempDate.day) ==
                          date;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            backgroundColor: isSelected
                                ? AppTheme.getPrimaryColor(context)
                                : AppTheme.getSecondaryBackground(context),
                            foregroundColor: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            final idx = dayCards.indexWhere((d) =>
                                DateTime(d.year, d.month, d.day) ==
                                DateTime(date.year, date.month, date.day));
                            if (idx >= 0) {
                              dayScrollController.animateTo(
                                idx * 56.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                            setModalState(() {
                              tempDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                tempDate.hour,
                                tempDate.minute,
                              );
                            });
                          },
                          child: Text(label),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),

                // 当前选中时间（实时预览）
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: AppTheme.spaceSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '已选时间',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.neutral600,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy年M月d日 HH:mm', 'zh_CN').format(tempDate),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),

                // ========== 日期：横向卡片（日/月/周） ==========
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: dayScrollController,
                    itemCount: dayCards.length,
                    itemBuilder: (context, index) {
                      final day = dayCards[index];
                      final isSelected = DateTime(
                              tempDate.year, tempDate.month, tempDate.day) ==
                          DateTime(day.year, day.month, day.day);
                      final isWeekend = day.weekday == DateTime.saturday ||
                          day.weekday == DateTime.sunday;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            tempDate = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              tempDate.hour,
                              tempDate.minute,
                            );
                          });
                        },
                        child: Container(
                          width: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.getPrimaryColor(context)
                                : AppTheme.getSecondaryBackground(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMM', 'zh_CN').format(day),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : AppTheme.neutral500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                day.day.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  color: isSelected
                                      ? Colors.white
                                      : isWeekend
                                          ? AppTheme.errorColor
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                [
                                  '一',
                                  '二',
                                  '三',
                                  '四',
                                  '五',
                                  '六',
                                  '日'
                                ][day.weekday - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : AppTheme.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),

                // ========== 时间：小时 + 分钟 滚轮 ==========
                Row(
                  children: [
                    const Text(
                      '  时间',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutral600,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 126,
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 小时
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          itemExtent: 34,
                          perspective: 0.002,
                          diameterRatio: 1.8,
                          squeeze: 0.85,
                          overAndUnderCenterOpacity: 0.3,
                          controller: hourController,
                          onSelectedItemChanged: (index) {
                            setModalState(() {
                              tempDate = DateTime(
                                tempDate.year,
                                tempDate.month,
                                tempDate.day,
                                index,
                                tempDate.minute,
                              );
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 24,
                            builder: (context, index) {
                              final isCenter = index == tempDate.hour;
                              return Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: isCenter
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isCenter
                                        ? AppTheme.getPrimaryColor(context)
                                        : AppTheme.neutral500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Text(
                        ':',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutral400,
                        ),
                      ),
                      // 分钟
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          itemExtent: 34,
                          perspective: 0.002,
                          diameterRatio: 1.8,
                          squeeze: 0.85,
                          overAndUnderCenterOpacity: 0.3,
                          controller: minuteController,
                          onSelectedItemChanged: (index) {
                            setModalState(() {
                              tempDate = DateTime(
                                tempDate.year,
                                tempDate.month,
                                tempDate.day,
                                tempDate.hour,
                                index,
                              );
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 60,
                            builder: (context, index) {
                              final isCenter = index == tempDate.minute;
                              return Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: isCenter
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isCenter
                                        ? AppTheme.getPrimaryColor(context)
                                        : AppTheme.neutral500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),

                // 取消/确定按钮
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = tempDate;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.getPrimaryColor(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          child: const Text(
                            '确定',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMedium),
              ],
            ),
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
    // WHY: 保存时使用 _finalAmount 解析表达式，确保 "50+30" 存为 80
    final rawAmount = _finalAmount;
    final isIncome = _currentTab == 1;

    // WHY: 用户输入的金额为"原价"，实际入账金额需扣除优惠并加上手续费
    // 例如原价 100、优惠 10、手续费 0，则 amount 字段存 90，
    // coupon/fee 字段保留作为元信息，主界面显示 ¥90 + "优惠 ¥10" 注释
    final effectiveAmount = isIncome
        ? rawAmount
        : (rawAmount - _couponAmount + _feeAmount).clamp(0.0, double.infinity);

    final transaction = Transaction(
      id: _editingId ?? UuidUtil.generate(),
      amount: effectiveAmount,
      isIncome: isIncome,
      category: _selectedCategory!.name,
      account: _selectedAccount?.name ?? '默认账户',
      date: _selectedDate,
      note: _noteController.text,
      tags: _selectedTags.map((t) => t.id).join(','),
      isReimbursed: _isReimbursed,
      fee: _feeAmount,
      coupon: _couponAmount,
      locationName: _selectedLocationName,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );

    if (_editingId != null) {
      // 编辑模式：先回滚原账户余额，再应用新金额
      final oldTransaction = DatabaseService.getTransactionById(_editingId!);
      if (oldTransaction != null) {
        final oldAccount =
            AccountService.getAccountByName(oldTransaction.account);
        if (oldAccount != null) {
          if (oldTransaction.isIncome) {
            oldAccount.currentBalance -= oldTransaction.amount;
          } else {
            oldAccount.currentBalance += oldTransaction.amount;
          }
          await AccountService.updateAccount(oldAccount);
        }
      }
      await DatabaseService.updateTransaction(transaction);
    } else {
      await DatabaseService.addTransaction(transaction);
    }

    if (_selectedAccount != null) {
      final account = AccountService.getAccountById(_selectedAccount!.id);
      if (account != null) {
        if (isIncome) {
          account.currentBalance += effectiveAmount;
        } else {
          account.currentBalance -= effectiveAmount;
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

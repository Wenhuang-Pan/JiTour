import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../utils/icon_library.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _uuid = const Uuid();

  bool _isIncome = false;
  Category? _selectedCategory;
  String _selectedAccount = '现金';
  String _amountText = '0.00';
  DateTime _selectedDate = DateTime.now();

  final List<String> _accounts = ['现金', '银行卡', '支付宝', '微信'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildAmountDisplay(),
                  const SizedBox(height: AppTheme.spaceXLarge),
                  _buildDateSelector(),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildCategorySelector(),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildAccountSelector(),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildNoteField(),
                ],
              ),
            ),
          ),
          _buildNumberPad(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              label: '支出',
              isSelected: !_isIncome,
              color: AppTheme.errorColor,
              onTap: () {
                setState(() {
                  _isIncome = false;
                  _selectedCategory = CategoryService.getExpenseCategories().firstOrNull;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTypeButton(
              label: '收入',
              isSelected: _isIncome,
              color: AppTheme.successColor,
              onTap: () {
                setState(() {
                  _isIncome = true;
                  _selectedCategory = CategoryService.getIncomeCategories().firstOrNull;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.neutral600,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        gradient: _isIncome ? AppTheme.successGradient : AppTheme.warningGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: (_isIncome ? AppTheme.successColor : AppTheme.warningColor).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                child: Icon(
                  _isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Text(
                _isIncome ? '收入金额' : '支出金额',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '¥ $_amountText',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: AppTheme.neutral50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Text(
              DateFormat('yyyy年M月d日').format(_selectedDate),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return InkWell(
      onTap: _showCategoryPicker,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: AppTheme.neutral50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _selectedCategory != null
                    ? Color(int.parse(_selectedCategory!.color.replaceFirst('#', '0xFF')))
                        .withOpacity(0.1)
                    : AppTheme.neutral200,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                _selectedCategory != null
                    ? _getIconData(_selectedCategory!.iconName)
                    : Icons.category_rounded,
                color: _selectedCategory != null
                    ? Color(int.parse(_selectedCategory!.color.replaceFirst('#', '0xFF')))
                    : AppTheme.neutral400,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分类',
                    style: TextStyle(
                      color: AppTheme.neutral500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedCategory?.name ?? '请选择分类',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    final categories = _isIncome
        ? CategoryService.getIncomeCategories()
        : CategoryService.getExpenseCategories();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isIncome ? '选择收入分类' : '选择支出分类',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppTheme.spaceMedium,
                crossAxisSpacing: AppTheme.spaceMedium,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategory?.id == category.id;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                              : Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: isSelected
                                ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getIconData(category.iconName),
                          color: isSelected ? Colors.white : Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSmall),
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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

  Widget _buildAccountSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedAccount,
          decoration: InputDecoration(
            labelText: '账户',
            labelStyle: TextStyle(
              color: AppTheme.neutral600,
              fontSize: 14,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMedium,
              vertical: AppTheme.spaceSmall,
            ),
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            color: AppTheme.neutral400,
          ),
          items: _accounts
              .map((account) => DropdownMenuItem(
                    value: account,
                    child: Text(
                      account,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedAccount = value!);
          },
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: TextFormField(
        controller: _noteController,
        decoration: InputDecoration(
          labelText: '备注',
          labelStyle: TextStyle(
            color: AppTheme.neutral600,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
          hintText: '添加备注信息...',
          hintStyle: TextStyle(
            color: AppTheme.neutral400,
          ),
        ),
        maxLines: 3,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutral900.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMedium,
                vertical: AppTheme.spaceSmall,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildNumberButton('1'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('2'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('3'),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Row(
                    children: [
                      _buildNumberButton('4'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('5'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('6'),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Row(
                    children: [
                      _buildNumberButton('7'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('8'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('9'),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Row(
                    children: [
                      _buildNumberButton('.'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildNumberButton('0'),
                      const SizedBox(width: AppTheme.spaceSmall),
                      _buildDeleteButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String text) {
    return Expanded(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.neutral100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNumberPressed(text),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onDeletePressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Center(
              child: Icon(
                Icons.backspace_rounded,
                size: 28,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String text) {
    setState(() {
      if (text == '.') {
        if (!_amountText.contains('.')) {
          _amountText += '.';
        }
      } else {
        if (_amountText == '0.00') {
          _amountText = text;
        } else {
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
        _amountText = '0.00';
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.neutral900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _saveTransaction() {
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的金额'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择分类'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isIncome) {
      final willExceed = _checkBudgetWarning(amount);
      if (willExceed) {
        _showOverBudgetWarning(amount);
        return;
      }
    }

    final transaction = Transaction(
      id: _uuid.v4(),
      amount: amount,
      isIncome: _isIncome,
      category: _selectedCategory!.name,
      account: _selectedAccount,
      date: _selectedDate,
      note: _noteController.text,
    );

    DatabaseService.addTransaction(transaction);
    Navigator.pop(context);
  }

  bool _checkBudgetWarning(double amount) {
    final budgets = DatabaseService.budgets.values
        .where((b) =>
            b.category == _selectedCategory!.name &&
            b.year == _selectedDate.year &&
            b.month == _selectedDate.month &&
            b.amount > 0)
        .toList();

    if (budgets.isEmpty) return false;

    final budget = budgets.first;

    final spent = DatabaseService.transactions.values
        .where((t) =>
            !t.isIncome &&
            t.category == _selectedCategory!.name &&
            t.date.year == _selectedDate.year &&
            t.date.month == _selectedDate.month)
        .fold(0.0, (sum, t) => sum + t.amount);

    return spent + amount > budget.amount;
  }

  void _showOverBudgetWarning(double amount) {
    final budgets = DatabaseService.budgets.values
        .where((b) =>
            b.category == _selectedCategory!.name &&
            b.year == _selectedDate.year &&
            b.month == _selectedDate.month)
        .toList();

    if (budgets.isEmpty) return;

    final budget = budgets.first;

    final spent = DatabaseService.transactions.values
        .where((t) =>
            !t.isIncome &&
            t.category == _selectedCategory!.name &&
            t.date.year == _selectedDate.year &&
            t.date.month == _selectedDate.month)
        .fold(0.0, (sum, t) => sum + t.amount);

    final remaining = budget.amount - spent;
    final overAmount = amount - remaining;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: AppTheme.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('预算超支警告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您的「${_selectedCategory!.name}」分类预算为 ¥${budget.amount.toStringAsFixed(2)}'),
            const SizedBox(height: AppTheme.spaceSmall),
            Text('本月已支出：¥${spent.toStringAsFixed(2)}'),
            const SizedBox(height: AppTheme.spaceSmall),
            Text('本次支出：¥${amount.toStringAsFixed(2)}'),
            const SizedBox(height: AppTheme.spaceSmall),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Text(
                    '超支金额：¥${overAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            onPressed: () {
              Navigator.pop(context);
              final transaction = Transaction(
                id: _uuid.v4(),
                amount: amount,
                isIncome: _isIncome,
                category: _selectedCategory!.name,
                account: _selectedAccount,
                date: _selectedDate,
                note: _noteController.text,
              );
              DatabaseService.addTransaction(transaction);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('继续记账'),
          ),
        ],
      ),
    );
  }
}

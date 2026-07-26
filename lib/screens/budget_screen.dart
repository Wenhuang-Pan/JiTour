import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../services/database_service.dart';
import '../services/savings_goal_service.dart';
import '../services/account_service.dart';
import '../utils/icon_library.dart';
import '../services/category_service.dart';
import '../utils/uuid_util.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _selectedMonth = DateTime.now();
  int _selectedTab = 1; // 0=分类预算，1=总预算，2=储蓄

  List<String> get _expenseCategories {
    return CategoryService.getExpenseCategories().map((c) => c.name).toList();
  }

  bool get _isTotalBudgetMode => _selectedTab == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.budgets.listenable(),
        builder: (context, Box<Budget> budgetBox, _) {
          final budgets = budgetBox.values
              .where((b) =>
                  b.year == _selectedMonth.year &&
                  b.month == _selectedMonth.month)
              .toList();

          final transactions = DatabaseService.transactions.values
              .where((t) =>
                  !t.isIncome &&
                  t.date.year == _selectedMonth.year &&
                  t.date.month == _selectedMonth.month)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMonthSelector(),
                const SizedBox(height: AppTheme.spaceLarge),
                _buildBudgetModeSelector(),
                const SizedBox(height: AppTheme.spaceLarge),
                if (_selectedTab == 1)
                  _buildTotalBudgetCard(budgets, transactions)
                else if (_selectedTab == 2)
                  _buildSavingsSection()
                else ...[
                  _buildCategoryBudgetOverview(budgets, transactions),
                  const SizedBox(height: AppTheme.spaceLarge),
                  _buildSectionTitle(context, '分类预算', '点击分类设置预算'),
                  const SizedBox(height: AppTheme.spaceMedium),
                  ..._expenseCategories.map((category) {
                    final budget = budgets.firstWhere(
                      (b) => b.category == category,
                      orElse: () => Budget(
                        id: '',
                        category: category,
                        amount: 0,
                        year: _selectedMonth.year,
                        month: _selectedMonth.month,
                      ),
                    );
                    final spent = transactions
                        .where((t) => t.category == category)
                        .fold(0.0, (sum, t) => sum + t.amount);
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                      child: _buildBudgetItem(context, category, budget, spent),
                    );
                  }),
                ],
                const SizedBox(height: AppTheme.spaceXXXLarge),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? AppTheme.getCardColor(context)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: _selectedTab == 0 ? AppTheme.cardShadow : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_rounded,
                      size: 16,
                      color: _selectedTab == 0
                          ? AppTheme.primaryColor
                          : AppTheme.neutral500,
                    ),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    Text(
                      '分类预算',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == 0
                            ? AppTheme.primaryColor
                            : AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? AppTheme.getCardColor(context)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: _selectedTab == 1 ? AppTheme.cardShadow : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: _selectedTab == 1
                          ? AppTheme.primaryColor
                          : AppTheme.neutral500,
                    ),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    Text(
                      '总预算',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == 1
                            ? AppTheme.primaryColor
                            : AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: _selectedTab == 2
                      ? AppTheme.getCardColor(context)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: _selectedTab == 2 ? AppTheme.cardShadow : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      size: 16,
                      color: _selectedTab == 2
                          ? AppTheme.primaryColor
                          : AppTheme.neutral500,
                    ),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    Text(
                      '储蓄',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 2
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == 2
                            ? AppTheme.primaryColor
                            : AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Text(
                DateFormat('yyyy年MM月').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMonthButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMedium,
                  vertical: AppTheme.spaceXSmall,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMonth = DateTime.now();
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '本月',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              _buildMonthButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetOverview(
      List<Budget> budgets, List<Transaction> transactions) {
    final totalBudget = budgets.fold(0.0, (sum, b) => sum + b.amount);
    final totalSpent = transactions.fold(0.0, (sum, t) => sum + t.amount);
    final remaining = totalBudget - totalSpent;
    final progress = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;
    final isOverBudget = progress > 100;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              const Text(
                '分类预算总览',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showTotalBudgetTip,
                child: Icon(
                  Icons.help_outline_rounded,
                  color: AppTheme.neutral400,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '预算',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${totalBudget.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '已支出',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${totalSpent.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '进度',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOverBudget
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 100 ? 1.0 : progress / 100,
                  backgroundColor: AppTheme.getSecondaryBackground(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBudgetCard(
      List<Budget> budgets, List<Transaction> transactions) {
    // 获取总预算（使用特殊的 "__TOTAL__" 分类名存储）
    final totalBudget = budgets
        .where((b) => b.category == '__TOTAL__')
        .fold(0.0, (sum, b) => sum + b.amount);

    final totalSpent = transactions.fold(0.0, (sum, t) => sum + t.amount);
    final remaining = totalBudget - totalSpent;
    final progress = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;
    final isOverBudget = progress > 100;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              const Text(
                '月度总预算',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showTotalBudgetDialog(budgets),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: AppTheme.spaceXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '设置',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          // 预算金额显示
          GestureDetector(
            onTap: () => _showTotalBudgetDialog(budgets),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                gradient: totalBudget > 0 ? AppTheme.primaryGradient : null,
                color: totalBudget > 0
                    ? null
                    : AppTheme.getSecondaryBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Column(
                children: [
                  Text(
                    totalBudget > 0
                        ? '¥${totalBudget.toStringAsFixed(2)}'
                        : '¥0.00',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: totalBudget > 0
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: -1,
                    ),
                  ),
                  if (totalBudget <= 0)
                    Text(
                      '点击设置总预算',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          // 支出进度
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已支出',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${totalSpent.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '剩余',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${remaining.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: remaining >= 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          // 进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '使用进度',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    totalBudget > 0 ? '${progress.toStringAsFixed(1)}%' : '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOverBudget
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalBudget > 0
                      ? (progress > 100 ? 1.0 : progress / 100)
                      : 0,
                  backgroundColor: AppTheme.getSecondaryBackground(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                  minHeight: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          // 提示信息
          if (totalBudget > 0)
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color:
                    (isOverBudget ? AppTheme.errorColor : AppTheme.successColor)
                        .withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: (isOverBudget
                          ? AppTheme.errorColor
                          : AppTheme.successColor)
                      .withOpacity(0.20),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverBudget
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: isOverBudget
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  Expanded(
                    child: Text(
                      isOverBudget
                          ? '已超出预算 ¥${remaining.abs().toStringAsFixed(2)}，请注意控制支出'
                          : '预算充足，还可以花费 ¥${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverBudget
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, String subtitle) {
    return Row(
      children: [
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetItem(
      BuildContext context, String category, Budget budget, double spent) {
    final progress = budget.amount > 0 ? (spent / budget.amount) * 100 : 0;
    final isOverBudget = progress > 100;
    final remaining = budget.amount - spent;
    final categoryColor = _getCategoryColor(category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBudgetDialog(category, budget),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Center(
                        child: Icon(
                          IconLibrary.getIconByName(category),
                          size: 20,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '预算 ¥${budget.amount.toStringAsFixed(0)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.neutral500,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${spent.toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isOverBudget
                                        ? AppTheme.errorColor
                                        : categoryColor,
                                  ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceXSmall,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isOverBudget
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor)
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Text(
                            '${progress.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isOverBudget
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress > 100 ? 1.0 : progress / 100,
                    backgroundColor: categoryColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverBudget ? AppTheme.errorColor : categoryColor,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      '餐饮': AppTheme.warningColor,
      '交通': AppTheme.primaryColor,
      '购物': const Color(0xFF9333EA),
      '娱乐': const Color(0xFFEC4899),
      '居住': const Color(0xFF78350F),
      '医疗': AppTheme.errorColor,
      '其他': AppTheme.neutral600,
    };
    return colors[category] ?? AppTheme.neutral600;
  }

  void _showTotalBudgetTip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            const Text('分类预算说明'),
          ],
        ),
        content: const Text(
          '分类预算模式下，您需要为每个支出分类单独设置预算金额。\n\n系统会自动汇总所有分类预算，作为总预算参考。\n\n如需使用总预算模式，请点击上方的"总预算"切换。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showTotalBudgetDialog(List<Budget> budgets) {
    final existingTotal =
        budgets.where((b) => b.category == '__TOTAL__').firstOrNull;
    final controller = TextEditingController(
      text:
          existingTotal != null ? existingTotal.amount.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: AppTheme.spaceSmall),
            Text('设置总预算'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置本月的总支出预算上限',
              style: TextStyle(
                color: AppTheme.neutral600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '预算金额',
                hintText: '请输入金额',
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  color: AppTheme.neutral800,
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (existingTotal != null)
            TextButton(
              onPressed: () async {
                await DatabaseService.deleteBudget(existingTotal.id);
                if (mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
              child: const Text('删除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              if (existingTotal != null) {
                existingTotal.amount = amount;
                await DatabaseService.updateBudget(existingTotal);
              } else {
                final budget = Budget(
                  id: UuidUtil.generate(),
                  category: '__TOTAL__',
                  amount: amount,
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                );
                await DatabaseService.addBudget(budget);
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(String category, Budget budget) {
    final controller = TextEditingController(
        text: budget.amount > 0 ? budget.amount.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Center(
                child: Icon(
                  IconLibrary.getIconByName(category),
                  size: 18,
                  color: _getCategoryColor(category),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            Text(category),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置本月该分类的预算上限',
              style: TextStyle(
                color: AppTheme.neutral600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '预算金额',
                hintText: '请输入金额',
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  color: AppTheme.neutral800,
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (budget.id.isNotEmpty)
            TextButton(
              onPressed: () async {
                await DatabaseService.deleteBudget(budget.id);
                if (mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
              child: const Text('删除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              if (budget.id.isNotEmpty) {
                budget.amount = amount;
                await DatabaseService.updateBudget(budget);
              } else {
                final newBudget = Budget(
                  id: UuidUtil.generate(),
                  category: category,
                  amount: amount,
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                );
                await DatabaseService.addBudget(newBudget);
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  // 储蓄部分
  Widget _buildSavingsSection() {
    final goals = SavingsGoalService.getActiveGoals();
    final totalBalance = AccountService.getTotalBalance();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 账户总余额卡片
        _buildBalanceCard(totalBalance),
        const SizedBox(height: AppTheme.spaceLarge),
        // 储蓄目标总览
        _buildSavingsOverviewCard(goals),
        const SizedBox(height: AppTheme.spaceLarge),
        // 储蓄目标列表
        _buildSectionTitle(context, '储蓄目标', '点击目标进行操作'),
        const SizedBox(height: AppTheme.spaceMedium),
        if (goals.isEmpty)
          _buildEmptySavingsState()
        else
          ...goals.map((goal) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                child: _buildSavingsGoalCard(goal),
              )),
        const SizedBox(height: AppTheme.spaceMedium),
        // 添加储蓄目标按钮
        Center(
          child: TextButton.icon(
            onPressed: () => _showAddSavingsGoalDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建新目标'),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXXXLarge),
      ],
    );
  }

  Widget _buildBalanceCard(double totalBalance) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              const Text(
                '账户总余额',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '¥${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsOverviewCard(List<SavingsGoal> goals) {
    final totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final progress = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.savings_rounded,
                  color: AppTheme.successColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              const Text(
                '储蓄总览',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已存金额',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${totalSaved.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '目标总额',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${totalTarget.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '总进度',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: progress >= 100
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 100 ? 1.0 : progress / 100,
                  backgroundColor: AppTheme.neutral200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 100
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySavingsState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            child: Icon(
              Icons.savings_outlined,
              color: AppTheme.neutral400,
              size: 32,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '暂无储蓄目标',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.neutral600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '创建第一个储蓄目标，开始存钱吧',
            style: TextStyle(
              color: AppTheme.neutral500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(SavingsGoal goal) {
    final color = Color(goal.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSavingsGoalDetailDialog(goal),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        IconLibrary.getIconByName(goal.iconName),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (goal.description != null)
                            Text(
                              goal.description!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.neutral500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${goal.currentAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        Text(
                          '/ ¥${goal.targetAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progressPercent / 100,
                    backgroundColor: AppTheme.neutral100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${goal.progressPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (goal.targetDate != null)
                      Text(
                        goal.isOverdue ? '已逾期' : '剩余${goal.daysToTargetDate}天',
                        style: TextStyle(
                          fontSize: 11,
                          color: goal.isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.neutral500,
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

  void _showSavingsGoalDetailDialog(SavingsGoal goal) {
    final amountController = TextEditingController();
    final accounts = AccountService.getAllAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spaceLarge,
              right: AppTheme.spaceLarge,
              top: AppTheme.spaceLarge,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppTheme.spaceLarge,
            ),
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
                const SizedBox(height: AppTheme.spaceMedium),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(goal.colorValue).withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Icon(
                        IconLibrary.getIconByName(goal.iconName),
                        color: Color(goal.colorValue),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '目标: ¥${goal.targetAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.neutral500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                // 存入金额
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, color: AppTheme.successColor),
                      const SizedBox(width: AppTheme.spaceSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '已存金额',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.neutral600,
                              ),
                            ),
                            Text(
                              '¥${goal.currentAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${goal.progressPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                // 选择账户
                if (accounts.isNotEmpty) ...[
                  Text(
                    '从账户转入',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Builder(
                    builder: (context) {
                      final selectedAccountId =
                          goal.accountId ?? accounts.first.id;
                      final selectedAccount =
                          AccountService.getAccountById(selectedAccountId);
                      final accountBalance =
                          selectedAccount?.currentBalance ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMedium),
                        decoration: BoxDecoration(
                          color: AppTheme.neutral100,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedAccountId,
                            items: accounts.map((account) {
                              return DropdownMenuItem(
                                value: account.id,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(account.name),
                                    Text(
                                      '¥${account.currentBalance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppTheme.neutral500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  goal.accountId = value;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                ],
                // 存入金额输入
                Text(
                  '存入金额',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Builder(
                  builder: (context) {
                    final selectedAccountId =
                        goal.accountId ?? accounts.first.id;
                    final selectedAccount =
                        AccountService.getAccountById(selectedAccountId);
                    final accountBalance = selectedAccount?.currentBalance ?? 0;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            autofocus: true,
                            decoration: InputDecoration(
                              prefixText: '¥ ',
                              hintText: '输入存入金额',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSmall),
                        ElevatedButton(
                          onPressed: () {
                            final selectedAccountId =
                                goal.accountId ?? accounts.first.id;
                            final selectedAccount =
                                AccountService.getAccountById(
                                    selectedAccountId);
                            final accountBalance =
                                selectedAccount?.currentBalance ?? 0;
                            if (accountBalance > 0) {
                              amountController.text =
                                  accountBalance.toStringAsFixed(2);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('账户余额为0')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceMedium),
                          ),
                          child: const Text('全部'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showWithdrawSavingsDialog(goal);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warningColor,
                          side: BorderSide(color: AppTheme.warningColor),
                        ),
                        child: const Text('提取'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请输入有效的金额')),
                            );
                            return;
                          }

                          // 从账户扣除并添加到储蓄
                          if (goal.accountId != null) {
                            final account =
                                AccountService.getAccountById(goal.accountId!);
                            if (account != null) {
                              if (account.currentBalance < amount) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('账户余额不足')),
                                );
                                return;
                              }
                              await AccountService.updateAccountBalance(
                                  account.id, account.currentBalance - amount);
                            }
                          }

                          await SavingsGoalService.addSavings(goal.id, amount);
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('成功存入 ¥${amount.toStringAsFixed(2)}'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('确认存入'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWithdrawSavingsDialog(SavingsGoal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.remove_circle_rounded, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            const Text('提取存款'),
          ],
        ),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: '提取金额',
            prefixText: '¥ ',
            hintText: '可用余额: ¥${goal.currentAmount.toStringAsFixed(2)}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              if (amount > goal.currentAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('提取金额不能超过当前余额')),
                );
                return;
              }

              // 从储蓄提取并添加到账户
              if (goal.accountId != null) {
                final account = AccountService.getAccountById(goal.accountId!);
                if (account != null) {
                  await AccountService.updateAccountBalance(
                      account.id, account.currentBalance + amount);
                }
              }

              await SavingsGoalService.withdrawSavings(goal.id, amount);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认提取'),
          ),
        ],
      ),
    );
  }

  void _showAddSavingsGoalDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedIconName = 'savings_rounded';
    int selectedColorValue = AppTheme.primaryColor.value;
    DateTime? targetDate;
    String? selectedAccountId;
    final accounts = AccountService.getAllAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spaceLarge,
              right: AppTheme.spaceLarge,
              top: AppTheme.spaceLarge,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppTheme.spaceLarge,
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
                  const SizedBox(height: AppTheme.spaceMedium),
                  Text(
                    '创建储蓄目标',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '目标名称',
                      hintText: '如：旅行基金、购车款',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: '描述（可选）',
                      hintText: '目标的详细说明',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '目标金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  // 选择账户
                  if (accounts.isNotEmpty) ...[
                    Text(
                      '关联账户（可选）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral100,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedAccountId,
                          hint: const Text('选择账户'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('不关联'),
                            ),
                            ...accounts.map((account) {
                              return DropdownMenuItem(
                                value: account.id,
                                child: Text(
                                    '${account.name} (¥${account.currentBalance.toStringAsFixed(2)})'),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedAccountId = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMedium),
                  ],
                  // 目标日期
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date != null) {
                        setDialogState(() => targetDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spaceMedium),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.neutral300),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: AppTheme.neutral500, size: 20),
                          const SizedBox(width: AppTheme.spaceSmall),
                          Text(
                            targetDate != null
                                ? '${targetDate!.year}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}'
                                : '选择目标日期（可选）',
                            style: TextStyle(
                              color: targetDate != null
                                  ? AppTheme.neutral800
                                  : AppTheme.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final amount = double.tryParse(amountController.text);

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入目标名称')),
                          );
                          return;
                        }

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效的目标金额')),
                          );
                          return;
                        }

                        await SavingsGoalService.createGoal(
                          name: name,
                          description: descController.text.trim().isNotEmpty
                              ? descController.text.trim()
                              : null,
                          targetAmount: amount,
                          iconName: selectedIconName,
                          colorValue: selectedColorValue,
                          targetDate: targetDate,
                          accountId: selectedAccountId,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('目标创建成功'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMedium),
                      ),
                      child: const Text('创建目标'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

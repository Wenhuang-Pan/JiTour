import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'stats_screen.dart';
import 'accounts_screen.dart';
import 'budget_screen.dart';
import 'category_management_screen.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../utils/icon_library.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TransactionListScreen(),
    const StatsScreen(),
    const BudgetScreen(),
    const AccountsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: '账单'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.savings), label: '预算'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: '账户'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text('记一笔', style: TextStyle(fontWeight: FontWeight.w600)),
              elevation: 8,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final transactionDay = DateTime(date.year, date.month, date.day);

    if (transactionDay == today) {
      return '今天';
    } else if (transactionDay == yesterday) {
      return '昨天';
    } else if (now.year == date.year) {
      return DateFormat('M月d日').format(date);
    } else {
      return DateFormat('yyyy年M月d日').format(date);
    }
  }

  Category _getCategory(String categoryName) {
    final categories = [
      ...CategoryService.getIncomeCategories(),
      ...CategoryService.getExpenseCategories(),
    ];
    final matched = categories.where((c) => c.name == categoryName).firstOrNull;
    if (matched != null) {
      return matched;
    }
    return Category(
      id: '',
      name: categoryName,
      iconName: 'category',
      isIncome: false,
      color: '#6B7280',
      createdAt: DateTime.now(),
    );
  }

  Color _getCategoryColor(String category) {
    final cat = _getCategory(category);
    return Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
  }

  IconData _getCategoryIcon(String category) {
    final cat = _getCategory(category);
    try {
      return IconLibrary.getIconByName(cat.iconName);
    } catch (e) {
      return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记途'),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.transactions.listenable(),
        builder: (context, Box<Transaction> box, _) {
          final transactions = box.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLarge),
                    Text(
                      '暂无账单',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.neutral700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSmall),
                    Text(
                      '点击下方按钮开始记账',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayTransactions = transactions
              .where((t) => DateTime(t.date.year, t.date.month, t.date.day) == today)
              .toList();

          final todayIncome = todayTransactions
              .where((t) => t.isIncome)
              .fold(0.0, (sum, t) => sum + t.amount);
          final todayExpense = todayTransactions
              .where((t) => !t.isIncome)
              .fold(0.0, (sum, t) => sum + t.amount);
          final todayBalance = todayIncome - todayExpense;

          return Column(
            children: [
              _buildTodaySummary(context, todayIncome, todayExpense, todayBalance),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spaceLarge,
                    right: AppTheme.spaceLarge,
                    bottom: AppTheme.spaceXXXLarge,
                  ),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isFirstOfDay = index == 0 ||
                        _formatDate(transactions[index - 1].date) != _formatDate(transaction.date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFirstOfDay)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTheme.spaceLarge,
                              bottom: AppTheme.spaceSmall,
                            ),
                            child: Text(
                              _formatDate(transaction.date),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppTheme.neutral500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _buildTransactionCard(context, transaction),
                        const SizedBox(height: AppTheme.spaceSmall),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodaySummary(BuildContext context, double income, double expense, double balance) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceLarge),
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.today_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '今日概览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXLarge),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('收入', income, AppTheme.successLight),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: _buildSummaryItem('支出', expense, AppTheme.errorLight),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日结余',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '¥${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          onLongPress: () => _showDeleteDialog(context, transaction),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(transaction.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: _getCategoryColor(transaction.category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: AppTheme.neutral400,
                          ),
                          const SizedBox(width: AppTheme.spaceXSmall),
                          Text(
                            transaction.account,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                          ),
                          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                            const SizedBox(width: AppTheme.spaceSmall),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.neutral400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSmall),
                            Expanded(
                              child: Text(
                                transaction.note!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.neutral500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.isIncome ? '+' : '-'}¥${transaction.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: transaction.isIncome ? AppTheme.successColor : AppTheme.errorColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      DateFormat('HH:mm').format(transaction.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral400,
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

  void _showDeleteDialog(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这笔交易吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              DatabaseService.deleteTransaction(transaction.id);
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        children: [
          _buildSectionTitle('数据管理'),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildSettingsCard(
            context,
            icon: Icons.category_rounded,
            title: '分类管理',
            subtitle: '自定义收入和支出分类',
            color: AppTheme.primaryColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildSettingsCard(
            context,
            icon: Icons.backup_rounded,
            title: '数据备份',
            subtitle: '备份和恢复数据',
            color: AppTheme.successColor,
            onTap: () {
              // TODO: 实现数据备份功能
            },
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildSettingsCard(
            context,
            icon: Icons.file_upload_rounded,
            title: '数据导出',
            subtitle: '导出交易数据',
            color: AppTheme.warningColor,
            onTap: () {
              // TODO: 实现数据导出功能
            },
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          _buildSectionTitle('关于'),
          const SizedBox(height: AppTheme.spaceMedium),
          _buildSettingsCard(
            context,
            icon: Icons.info_rounded,
            title: '关于记途',
            subtitle: '版本 1.0.0',
            color: AppTheme.neutral600,
            onTap: () {
              // TODO: 显示关于信息
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spaceSmall),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.neutral500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
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
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.neutral400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

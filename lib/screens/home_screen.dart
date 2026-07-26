import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'stats_screen.dart';
import 'accounts_screen.dart';
import 'budget_screen.dart';
import 'category_management_screen.dart';
import 'tags_management_screen.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../services/database_service.dart';
import '../services/savings_goal_service.dart';
import '../services/category_service.dart';
import '../utils/icon_library.dart';
import '../utils/animation_utils.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      appBar: _currentIndex == 0
          ? AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: '菜单',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: const Text('记途'),
              centerTitle: true,
              elevation: 0,
            )
          : null,
      drawer: _buildDrawer(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          border: Border(
            top: BorderSide(
              color: AppTheme.getDividerColor(context),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: '账单',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded),
                label: '统计',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: '预算',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance_rounded),
                label: '账户',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ScaleOnTap(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXLarge,
                    vertical: AppTheme.spaceMedium,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.getPrimaryGradient(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXXLarge),
                    boxShadow:
                        AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      SizedBox(width: AppTheme.spaceSmall),
                      Text(
                        '记一笔',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.textBodyLarge,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 72,
                left: AppTheme.spaceXLarge,
                right: AppTheme.spaceXLarge,
                bottom: AppTheme.spaceXLarge,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.getPrimaryGradient(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                const Text(
                  '记途',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.textHeadlineMedium,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXSmall),
                Text(
                  '记录每一笔，走向财务自由',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: AppTheme.textBodySmall,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          _buildDrawerItem(
            context,
            icon: Icons.category_rounded,
            title: '分类管理',
            subtitle: '管理收入和支出分类',
            color: AppTheme.getPrimaryColor(context),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.label_rounded,
            title: '标签管理',
            subtitle: '管理交易标签',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TagsManagementScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildDrawerItem(
            context,
            icon: Icons.settings_rounded,
            title: '设置',
            subtitle: '主题、币种、备份等',
            color: AppTheme.neutral600,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.import_export_rounded,
            title: '导入导出',
            subtitle: 'CSV导入与数据管理',
            color: AppTheme.warningColor,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/data');
            },
          ),
          const Spacer(),
          _buildDrawerItem(
            context,
            icon: Icons.info_outline_rounded,
            title: '关于记途',
            subtitle: 'V1.2.0 · 一起记账吧',
            color: AppTheme.neutral500,
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: '记途',
                applicationVersion: 'V1.2.0',
                applicationIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.getPrimaryGradient(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                children: const [
                  Text('一款简洁好用的个人记账应用'),
                  SizedBox(height: 8),
                  Text('帮助你轻松管理日常收支'),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spaceLarge),
        ],
      ),
    ),
  );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLarge,
          vertical: AppTheme.spaceMedium,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.neutral400,
              size: 18,
            ),
          ],
        ),
      ),
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
      return DateFormat('M月d日 EEEE', 'zh_CN').format(date);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder(
          valueListenable: DatabaseService.transactions.listenable(),
          builder: (context, Box<Transaction> box, _) {
            final transactions = box.values.toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            if (transactions.isEmpty) {
              return _buildEmptyState(context);
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final todayTransactions = transactions
                .where((t) =>
                    DateTime(t.date.year, t.date.month, t.date.day) == today)
                .toList();

            final todayIncome = todayTransactions
                .where((t) => t.isIncome)
                .fold(0.0, (sum, t) => sum + t.amount);
            final todayExpense = todayTransactions
                .where((t) => !t.isIncome)
                .fold(0.0, (sum, t) => sum + t.amount);
            final todayBalance = todayIncome - todayExpense;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildTodaySummary(
                    context,
                    todayIncome,
                    todayExpense,
                    todayBalance,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSavingsSection(context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLarge,
                    AppTheme.spaceSmall,
                    AppTheme.spaceLarge,
                    120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final transaction = transactions[index];
                        final isFirstOfDay = index == 0 ||
                            _formatDate(transactions[index - 1].date) !=
                                _formatDate(transaction.date);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isFirstOfDay)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppTheme.spaceLarge,
                                  bottom: AppTheme.spaceSmall,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _formatDate(transaction.date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppTheme.neutral500,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceSmall),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color:
                                            AppTheme.getDividerColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _buildTransactionCard(context, transaction),
                          ],
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXLarge),
              decoration: BoxDecoration(
                gradient: AppTheme.getPrimaryGradient(context),
                shape: BoxShape.circle,
                boxShadow:
                    AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXLarge),
            Text(
              '暂无账单',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              '点击下方"记一笔"开始记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary(
    BuildContext context,
    double income,
    double expense,
    double balance,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLarge,
        AppTheme.spaceMedium,
        AppTheme.spaceLarge,
        AppTheme.spaceSmall,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXLarge),
        decoration: BoxDecoration(
          gradient: AppTheme.getPrimaryGradient(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.today_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                const Text(
                  '今日概览',
                  style: TextStyle(
                    fontSize: AppTheme.textBodyMedium,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    DateFormat('MM/dd').format(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.textLabelSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    '收入',
                    income,
                    Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    '支出',
                    expense,
                    Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: Colors.white.withOpacity(0.20),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '今日结余',
                    style: TextStyle(
                      fontSize: AppTheme.textBodySmall,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: AppTheme.textTitleLarge,
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
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppTheme.textLabelSmall,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: AppTheme.textTitleMedium,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsSection(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseService.savingsGoals.listenable(),
      builder: (context, Box<SavingsGoal> box, _) {
        final goals = box.values.toList();
        if (goals.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLarge,
            vertical: AppTheme.spaceSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXSmall,
                  vertical: AppTheme.spaceSmall,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      color: AppTheme.getPrimaryColor(context),
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Text(
                      '储蓄进度',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final progress = goal.targetAmount > 0
                        ? (goal.currentAmount / goal.targetAmount)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return Container(
                      width: 170,
                      margin: const EdgeInsets.only(right: AppTheme.spaceSmall),
                      padding: const EdgeInsets.all(AppTheme.spaceMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: AppTheme.textBodySmall,
                                  fontWeight: FontWeight.w700,
                                  color: goal.isCompleted
                                      ? AppTheme.successColor
                                      : AppTheme.getPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceXSmall),
                          Expanded(
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppTheme.neutral200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  goal.isCompleted
                                      ? AppTheme.successColor
                                      : AppTheme.getPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceXSmall),
                          Text(
                            '¥${goal.currentAmount.toStringAsFixed(0)} / ¥${goal.targetAmount.toStringAsFixed(0)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppTheme.neutral500,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    final categoryColor = _getCategoryColor(transaction.category);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 12,
                            color: AppTheme.neutral400,
                          ),
                          const SizedBox(width: AppTheme.spaceXSmall),
                          Flexible(
                            child: Text(
                              transaction.account,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.neutral500,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (transaction.note != null &&
                              transaction.note!.isNotEmpty) ...[
                            const SizedBox(width: AppTheme.spaceSmall),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppTheme.neutral400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSmall),
                            Flexible(
                              child: Text(
                                transaction.note!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.neutral500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.isIncome ? '+' : '-'}¥${transaction.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: transaction.isIncome
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(transaction.date),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    HapticFeedback.mediumImpact();
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

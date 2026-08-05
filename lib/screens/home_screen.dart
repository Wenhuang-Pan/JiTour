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
import 'debt_screen.dart';
import 'recurring_transaction_screen.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/recurring_transaction.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../services/filter_service.dart';
import '../services/recurring_transaction_service.dart';
import '../utils/icon_library.dart';
import '../utils/animation_utils.dart';
import '../widgets/filter_modal.dart';

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
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (_currentIndex == 0)
            Positioned(
              right: AppTheme.spaceMedium,
              bottom: 16,
              child: _buildFAB(context),
            ),
        ],
      ),
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
            // WHY: Material 3 规范 NavigationBar 推荐高度 80dp，
            // 保证每个图标的触摸目标 ≥48dp，提升点击舒适度
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined, size: 24),
                selectedIcon: Icon(Icons.receipt_long_rounded, size: 26),
                label: '账单',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded, size: 24),
                selectedIcon: Icon(Icons.pie_chart_rounded, size: 26),
                label: '统计',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 24),
                selectedIcon:
                    Icon(Icons.account_balance_wallet_rounded, size: 26),
                label: '预算',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined, size: 24),
                selectedIcon: Icon(Icons.account_balance_rounded, size: 26),
                label: '账户',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return ScaleOnTap(
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
        // WHY: 增大内边距使按钮触摸区域 ≥56dp（Material 3 FAB 标准），
        // 提升拇指点击舒适度，避免误触
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceXLarge,
          vertical: AppTheme.spaceMedium,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.getPrimaryGradient(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusXXLarge),
          boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 24),
            SizedBox(width: AppTheme.spaceSmall),
            Text(
              '记一笔',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTheme.textBodyLarge,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final primaryColor = AppTheme.getPrimaryColor(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        backgroundColor: primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: statusBarHeight),
            Container(
              padding: const EdgeInsets.only(
                left: AppTheme.spaceXLarge,
                right: AppTheme.spaceXLarge,
                top: 20,
                bottom: AppTheme.spaceXLarge,
              ),
              color: primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
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
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: AppTheme.textBodySmall,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXLarge),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    _buildDrawerItem(
                      context,
                      icon: Icons.account_balance_rounded,
                      title: '负债管理',
                      subtitle: '管理欠款和还款',
                      color: AppTheme.errorColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DebtScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.repeat_rounded,
                      title: '定期交易',
                      subtitle: '自动记账（工资、房租等）',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecurringTransactionScreen(),
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
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
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
            ),
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
                color: color.withValues(alpha: 0.12),
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
            const Icon(
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

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final FilterConditions _filterConditions = FilterConditions();

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
            final allTransactions = box.values.toList();

            // 应用筛选条件
            final transactions = FilterService.filterTransactions(
              allTransactions,
              _filterConditions,
            );

            if (transactions.isEmpty) {
              return _buildEmptyState(context);
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final todayTransactions = allTransactions
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
                  child: _buildSearchSection(context),
                ),
                // WHY: 用户要求隐藏储蓄进度区域，不在首页显示
                // SliverToBoxAdapter(
                //   child: _buildSavingsSection(context),
                // ),
                SliverToBoxAdapter(
                  child: _buildRecurringTransactionReminder(context),
                ),
                if (_filterConditions.hasFilters)
                  SliverToBoxAdapter(
                    child: _buildFilterIndicator(context),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMedium,
                    AppTheme.spaceXSmall,
                    AppTheme.spaceMedium,
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
                                  top: AppTheme.spaceMedium,
                                  bottom: AppTheme.spaceXSmall,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _formatDate(transaction.date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppTheme.neutral400,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceMedium),
                                    Expanded(
                                      child: Container(
                                        height: 0.5,
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

  /// 构建搜索和筛选区域
  Widget _buildSearchSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.getSecondaryBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppTheme.spaceMedium),
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppTheme.neutral400,
                  ),
                  const SizedBox(width: AppTheme.spaceSmall),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索账单',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterConditions.keyword = value;
                        });
                      },
                    ),
                  ),
                  if (_filterConditions.keyword != null &&
                      _filterConditions.keyword!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _filterConditions.keyword = null;
                        });
                      },
                    ),
                  const SizedBox(width: AppTheme.spaceSmall),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSmall),
          InkWell(
            onTap: () => _showFilterModal(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.getSecondaryBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                Icons.filter_alt_rounded,
                size: 20,
                color: _filterConditions.hasFilters
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.neutral400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建筛选状态指示器
  Widget _buildFilterIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLarge,
        AppTheme.spaceSmall,
        AppTheme.spaceLarge,
        AppTheme.spaceSmall,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        decoration: BoxDecoration(
          color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_rounded,
              size: 16,
              color: AppTheme.getPrimaryColor(context),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            Text(
              '已应用筛选',
              style: TextStyle(
                fontSize: AppTheme.textBodySmall,
                color: AppTheme.getPrimaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _clearFilters,
              child: Text(
                '清除',
                style: TextStyle(
                  fontSize: AppTheme.textBodySmall,
                  color: AppTheme.getPrimaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示筛选模态框
  void _showFilterModal(BuildContext context) {
    showFilterModal(
      context,
      conditions: _filterConditions,
      onApply: (conditions) {
        setState(() {
          _filterConditions.keyword = conditions.keyword;
          _filterConditions.category = conditions.category;
          _filterConditions.account = conditions.account;
          _filterConditions.startDate = conditions.startDate;
          _filterConditions.endDate = conditions.endDate;
          _filterConditions.minAmount = conditions.minAmount;
          _filterConditions.maxAmount = conditions.maxAmount;
          _filterConditions.isIncome = conditions.isIncome;
          _filterConditions.hasTag = conditions.hasTag;
          _filterConditions.tag = conditions.tag;
        });
      },
      onClear: _clearFilters,
    );
  }

  /// 清除所有筛选条件
  void _clearFilters() {
    setState(() {
      _filterConditions.reset();
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: AppTheme.getPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Text(
              '暂无账单',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              '点击下方"记一笔"开始记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutral400,
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
        AppTheme.spaceMedium,
        AppTheme.spaceMedium,
        AppTheme.spaceMedium,
        AppTheme.spaceXSmall,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        decoration: BoxDecoration(
          gradient: AppTheme.getPrimaryGradient(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '今日概览',
                  style: TextStyle(
                    fontSize: AppTheme.textBodyMedium,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MM月dd日').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: AppTheme.textLabelSmall,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '收入',
                        style: TextStyle(
                          fontSize: AppTheme.textBodySmall,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        '¥${income.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTheme.textHeadlineSmall,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '支出',
                        style: TextStyle(
                          fontSize: AppTheme.textBodySmall,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        '¥${expense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTheme.textHeadlineSmall,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLarge,
                vertical: AppTheme.spaceMedium,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '今日结余',
                    style: TextStyle(
                      fontSize: AppTheme.textBodySmall,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: AppTheme.textTitleLarge,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
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
            horizontal: AppTheme.spaceMedium,
            vertical: AppTheme.spaceXSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXSmall,
                  vertical: AppTheme.spaceXSmall,
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
                height: 100,
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
                      width: 160,
                      margin:
                          const EdgeInsets.only(right: AppTheme.spaceXSmall),
                      padding: const EdgeInsets.all(AppTheme.spaceSmall),
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

  /// 构建定期交易提醒区域
  Widget _buildRecurringTransactionReminder(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseService.recurringTransactions.listenable(),
      builder: (context, Box<RecurringTransaction> box, _) {
        final upcoming =
            RecurringTransactionService.getUpcomingRecurringTransactions(
                days: 7);
        if (upcoming.isEmpty) {
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
                    const Icon(
                      Icons.repeat_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Text(
                      '定期交易提醒',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${upcoming.length}笔',
                        style: const TextStyle(
                          fontSize: AppTheme.textLabelSmall,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecurringTransactionScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '查看全部',
                            style: TextStyle(
                              fontSize: AppTheme.textBodySmall,
                              color: AppTheme.getPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.getPrimaryColor(context),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final transaction = upcoming[index];
                    return Container(
                      width: 160,
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
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: transaction.amountColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSmall),
                                ),
                                child: Icon(
                                  Icons.repeat_rounded,
                                  color: transaction.amountColor,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceSmall),
                              Expanded(
                                child: Text(
                                  transaction.name,
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
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceXSmall),
                          Row(
                            children: [
                              Text(
                                transaction.amountText,
                                style: TextStyle(
                                  fontSize: AppTheme.textBodyLarge,
                                  fontWeight: FontWeight.w700,
                                  color: transaction.amountColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceXSmall),
                          Text(
                            '${transaction.frequencyText} · ${transaction.nextExecutionDateText}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppTheme.neutral400,
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
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          onLongPress: () => _showDeleteDialog(context, transaction),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSmall,
              vertical: AppTheme.spaceSmall,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: categoryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
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
                          Text(
                            transaction.account,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.neutral400,
                                    ),
                          ),
                          if (transaction.note != null &&
                              transaction.note!.isNotEmpty) ...[
                            const SizedBox(width: AppTheme.spaceSmall),
                            Container(
                              width: 2,
                              height: 2,
                              decoration: const BoxDecoration(
                                color: AppTheme.neutral300,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSmall),
                            // WHY: 使用 Flexible 包裹防止备注过长导致横向溢出
                            Flexible(
                              child: Text(
                                transaction.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.neutral400,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.isIncome ? '+' : '-'}¥${transaction.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: transaction.isIncome
                                ? AppTheme.successColor
                                : AppTheme.neutral900,
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

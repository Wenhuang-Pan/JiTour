import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
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
import '../services/update_service.dart';
import '../utils/icon_library.dart';
import '../utils/animation_utils.dart';
import '../widgets/filter_modal.dart';
import '../widgets/quick_entry_overlay.dart';
import '../widgets/update_checker.dart';
import '../services/notification_bridge_service.dart';
import '../models/pending_transaction.dart';

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
      body: QuickEntryOverlay(
        child: Stack(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceSmall,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                              builder: (_) =>
                                  const RecurringTransactionScreen(),
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
                      const SizedBox(height: AppTheme.spaceMedium),
                      _buildDrawerItem(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: '关于记途',
                        // WHY: 版本号从 UpdateService 动态读取，与 pubspec/发布版本保持一致，
                        // 旧代码硬编码 V1.2.0 已与实际版本（2.2.1）脱节
                        subtitle: 'V${UpdateService.getVersion()} · 一起记账吧',
                        color: AppTheme.neutral500,
                        onTap: () {
                          Navigator.pop(context);
                          // WHY: 使用 State 级 context 而非抽屉内部 context，
                          // 确保抽屉与关于对话框关闭后仍能弹出更新相关提示
                          final pageContext = this.context;
                          showAboutDialog(
                            context: pageContext,
                            applicationName: '记途',
                            applicationVersion:
                                'V${UpdateService.getVersion()}',
                            applicationIcon: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient:
                                    AppTheme.getPrimaryGradient(pageContext),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            children: [
                              const Text('一款简洁好用的个人记账应用'),
                              const SizedBox(height: 8),
                              const Text('帮助你轻松管理日常收支'),
                              const SizedBox(height: AppTheme.spaceLarge),
                              // WHY: 在关于对话框内提供手动检查更新入口；
                              // manualCheck 绕过缓存与"跳过此版本"标记强制拉取最新版本
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(pageContext);
                                  UpdateCheckerWidget.manualCheck(pageContext);
                                },
                                icon: const Icon(
                                  Icons.system_update_rounded,
                                  size: 18,
                                ),
                                label: const Text('检查更新'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spaceLarge),
                      // WHY: 调试入口仅在 debug 构建可见，release 自动剔除；
                      // 用于在无真实支付场景时模拟通知，验证弹窗全链路。
                      if (kDebugMode) ...[
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildDebugSection(context),
                      ],
                    ],
                  ), // Column
                ), // SingleChildScrollView
              ), // Container decoration
            ), // Expanded
          ], // outer Column children
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

  /// Debug 区：模拟支付通知触发弹窗（仅 debug 构建可见）
  Widget _buildDebugSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLarge,
        AppTheme.spaceMedium,
        AppTheme.spaceLarge,
        AppTheme.spaceMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spaceXSmall),
          Row(
            children: [
              Icon(Icons.bug_report_rounded,
                  size: 14, color: AppTheme.warningColor),
              const SizedBox(width: AppTheme.spaceXSmall),
              Text(
                '调试区（仅开发模式）',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Wrap(
            spacing: AppTheme.spaceSmall,
            runSpacing: AppTheme.spaceSmall,
            children: [
              _buildDebugChip(
                context: context,
                label: '美团外卖 ¥28.50',
                onTap: () {
                  NotificationBridgeService.injectMockPayment(
                    amount: 28.50,
                    merchant: '美团外卖',
                    source: PaymentSource.alipay,
                  );
                  Navigator.pop(context);
                },
              ),
              _buildDebugChip(
                context: context,
                label: '滴滴出行 ¥45.00',
                onTap: () {
                  NotificationBridgeService.injectMockPayment(
                    amount: 45.00,
                    merchant: '滴滴出行',
                    source: PaymentSource.wechat,
                  );
                  Navigator.pop(context);
                },
              ),
              _buildDebugChip(
                context: context,
                label: '星巴克 ¥38.00',
                onTap: () {
                  NotificationBridgeService.injectMockPayment(
                    amount: 38.00,
                    merchant: '星巴克咖啡',
                    source: PaymentSource.alipay,
                  );
                  Navigator.pop(context);
                },
              ),
              _buildDebugChip(
                context: context,
                label: '未知商户 ¥199.00',
                onTap: () {
                  NotificationBridgeService.injectMockPayment(
                    amount: 199.00,
                    merchant: '某某科技有限公司',
                    source: PaymentSource.wechat,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSmall),
        ],
      ),
    );
  }

  /// Debug Chip 按钮
  Widget _buildDebugChip({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark ? AppTheme.neutral700 : AppTheme.neutral100,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textBodySmall,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.neutral100 : AppTheme.neutral700,
            ),
          ),
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

  // WHY: 使用 TextEditingController 管理搜索框文本，避免 onChanged 中
  // setState 导致 Widget 重建丢失焦点的问题
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

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
            // WHY: 统一在数据源排除软删除账单，列表与月度预算支出均不再计入
            final allTransactions =
                box.values.where((t) => !t.isDeleted).toList();

            // 应用筛选条件
            final transactions = FilterService.filterTransactions(
              allTransactions,
              _filterConditions,
            );

            if (transactions.isEmpty) {
              // WHY: 区分"无账单"与"搜索/筛选无结果"：后者保留搜索框，
              // 方便直接改词重搜或一键清除，避免用户被困在无入口的空页面
              if (_filterConditions.hasFilters) {
                return ListView(
                  children: [
                    const SizedBox(height: AppTheme.spaceSmall),
                    _buildSearchSection(context),
                    const SizedBox(height: AppTheme.spaceSmall),
                    _buildFilterIndicator(context),
                    _buildNoResultState(context),
                  ],
                );
              }
              return _buildEmptyState(context);
            }

            final now = DateTime.now();

            // WHY: 计算当月支出和预算余额，显示在首页顶部
            final monthTransactions = allTransactions
                .where(
                    (t) => t.date.year == now.year && t.date.month == now.month)
                .toList();
            final monthExpense = monthTransactions
                .where((t) => !t.isIncome)
                .fold(0.0, (sum, t) => sum + t.amount);
            final monthBudgets =
                DatabaseService.getBudgetsForMonth(now.year, now.month);
            final totalBudget =
                monthBudgets.fold<double>(0.0, (sum, b) => sum + b.amount);
            final budgetBalance = totalBudget - monthExpense;

            // WHY: 按日期分组交易，计算每日收支汇总显示在日期标签右侧
            final groupedTransactions = <DateTime, List<Transaction>>{};
            for (final t in transactions) {
              final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
              groupedTransactions.putIfAbsent(dayKey, () => []).add(t);
            }
            final sortedDays = groupedTransactions.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            final flatTransactions = <Transaction>[];
            for (final day in sortedDays) {
              flatTransactions.addAll(groupedTransactions[day]!);
            }

            return CustomScrollView(
              slivers: [
                // WHY: 搜索/筛选态聚焦结果，隐藏月度预算卡片与定期交易提醒
                if (!_filterConditions.hasFilters)
                  SliverToBoxAdapter(
                    child: _buildMonthlyBudgetCard(
                      context,
                      monthExpense,
                      totalBudget,
                      budgetBalance,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _buildSearchSection(context),
                ),
                // WHY: 用户要求隐藏储蓄进度区域，不在首页显示
                // SliverToBoxAdapter(
                //   child: _buildSavingsSection(context),
                // ),
                if (!_filterConditions.hasFilters)
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
                        final transaction = flatTransactions[index];
                        final isFirstOfDay = index == 0 ||
                            _formatDate(flatTransactions[index - 1].date) !=
                                _formatDate(transaction.date);

                        // WHY: 计算当日收支汇总，显示在日期标签右侧
                        double? dayIncome, dayExpense;
                        if (isFirstOfDay) {
                          final dayKey = DateTime(transaction.date.year,
                              transaction.date.month, transaction.date.day);
                          final dayTx = groupedTransactions[dayKey] ?? [];
                          dayIncome = dayTx
                              .where((t) => t.isIncome)
                              .fold<double>(0.0, (sum, t) => sum + t.amount);
                          dayExpense = dayTx
                              .where((t) => !t.isIncome)
                              .fold<double>(0.0, (sum, t) => sum + t.amount);
                        }

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
                                    // WHY: 在日期最右侧显示当日收支汇总
                                    if (dayExpense! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: AppTheme.spaceSmall),
                                        child: Text(
                                          '支 ¥${dayExpense.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.errorColor
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    if (dayIncome! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: AppTheme.spaceSmall),
                                        child: Text(
                                          '收 ¥${dayIncome.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.successColor
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            _buildTransactionCard(context, transaction),
                          ],
                        );
                      },
                      childCount: flatTransactions.length,
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
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '搜索账单',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      // WHY: 使用防抖避免每次输入都触发 setState 导致焦点丢失
                      onChanged: (value) {
                        _filterConditions.keyword =
                            value.isEmpty ? null : value;
                        _searchDebounce?.cancel();
                        _searchDebounce =
                            Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {});
                          }
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _filterConditions.keyword = null;
                        setState(() {});
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
    _searchController.clear();
    setState(() {
      _filterConditions.reset();
    });
  }

  /// 构建搜索/筛选无结果状态
  ///
  /// WHY: 与"完全无账单"空状态区分，提示用户调整关键词或清除筛选
  Widget _buildNoResultState(BuildContext context) {
    return Padding(
      // WHY: bottom 120 避让右下角"记一笔"FAB，防止清除按钮被遮挡
      padding: const EdgeInsets.only(
        top: 96,
        bottom: 120,
        left: AppTheme.spaceXXXLarge,
        right: AppTheme.spaceXXXLarge,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppTheme.getPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '未找到相关账单',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '试试更换关键词或清除筛选条件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutral400,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXLarge),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('清除搜索与筛选'),
          ),
        ],
      ),
    );
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

  /// 构建月度预算余额卡片
  ///
  /// WHY: V2.1.0 新增，替换原"今日概览"大面积卡片，
  /// 显示当月支出和预算余额，帮助用户掌控月度财务状况。
  ///
  /// @param context 构建上下文
  /// @param monthExpense 当月总支出
  /// @param totalBudget 当月总预算
  /// @param budgetBalance 预算余额（预算 - 支出）
  /// @return 月度预算卡片 Widget
  Widget _buildMonthlyBudgetCard(
    BuildContext context,
    double monthExpense,
    double totalBudget,
    double budgetBalance,
  ) {
    // WHY: 预算余额为负表示超支
    final isOverBudget = budgetBalance < 0;
    final progress =
        totalBudget > 0 ? (monthExpense / totalBudget).clamp(0.0, 1.0) : 0.0;

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
                  '本月预算',
                  style: TextStyle(
                    fontSize: AppTheme.textBodyMedium,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('yyyy年M月').format(DateTime.now()),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '预算余额',
                        style: TextStyle(
                          fontSize: AppTheme.textBodySmall,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        // WHY: 超支时显示负号，让用户直观感知负结余
                        '${budgetBalance < 0 ? '-' : ''}¥${budgetBalance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: AppTheme.textHeadlineSmall,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOverBudget ? '已超支' : '剩余可用',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '本月支出',
                        style: TextStyle(
                          fontSize: AppTheme.textBodySmall,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXSmall),
                      Text(
                        '¥${monthExpense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTheme.textTitleLarge,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalBudget > 0
                            ? '预算 ¥${totalBudget.toStringAsFixed(2)}'
                            : '未设置预算',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            // WHY: 预算使用进度条，直观展示预算消耗情况
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已用 ${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  isOverBudget
                      ? '超支 ${(progress * 100 - 100).toStringAsFixed(0)}%'
                      : '剩余 ${((1 - progress) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    // WHY: 当存在优惠时，金额下方追加"优惠 ¥X.XX"小字，使用成功色标注
    final hasCoupon = !transaction.isIncome && transaction.coupon > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // WHY: 单击进入编辑页面，便于修改分类、金额、优惠等
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  editingTransaction: transaction,
                ),
              ),
            );
          },
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
                    if (hasCoupon) ...[
                      const SizedBox(height: 2),
                      Text(
                        '优惠 ¥${transaction.coupon.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.successColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/pending_transaction.dart';
import '../providers/auto_accounting_provider.dart';
import '../services/account_service.dart';
import '../services/category_service.dart';
import '../services/pending_transaction_service.dart';
import '../theme/app_theme.dart';

/// 待确认交易列表页
///
/// 展示支付通知自动记账生成的待确认交易，支持按状态筛选、
/// 确认记账、忽略以及清空已处理记录等操作。
class PendingTransactionsScreen extends StatefulWidget {
  /// 构造待确认交易列表页
  const PendingTransactionsScreen({super.key});

  @override
  State<PendingTransactionsScreen> createState() =>
      _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends State<PendingTransactionsScreen> {
  /// 所有待确认交易记录（含已处理），按 createdAt 倒序
  List<PendingTransaction> _allList = <PendingTransaction>[];

  /// 当前筛选状态，null 表示显示全部；默认显示待确认
  PendingStatus? _filter = PendingStatus.pending;

  /// 加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载所有待确认交易数据
  ///
  /// WHY: 调用 [PendingTransactionService.getAll] 获取全部记录，
  /// 已按 createdAt 倒序排序。
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allList = PendingTransactionService.getAll();
    setState(() => _isLoading = false);
  }

  /// 按当前筛选条件过滤列表
  ///
  /// WHY: 纯函数，不触发 setState，便于在 build 中重复调用。
  ///
  /// @return 过滤后的列表
  List<PendingTransaction> _filterList() {
    if (_filter == null) return _allList;
    return _allList
        .where((PendingTransaction t) => t.status == _filter)
        .toList();
  }

  /// 获取支付来源对应的品牌色
  ///
  /// @param s 支付来源
  /// @return 来源品牌色
  Color _getSourceColor(PaymentSource s) {
    switch (s) {
      case PaymentSource.alipay:
        return const Color(0xFF1677FF);
      case PaymentSource.wechat:
        return const Color(0xFF07C160);
    }
  }

  /// 获取状态对应的颜色
  ///
  /// @param s 待确认状态
  /// @return 状态色
  Color _getStatusColor(PendingStatus s) {
    switch (s) {
      case PendingStatus.pending:
        return AppTheme.warningColor;
      case PendingStatus.confirmed:
        return AppTheme.successColor;
      case PendingStatus.discarded:
        return AppTheme.neutral400;
    }
  }

  /// 获取推断置信度对应的颜色
  ///
  /// @param c 置信度（0.0-1.0）
  /// @return 置信度色：≥0.9 成功色，≥0.5 主色，<0.5 警告色
  Color _getConfidenceColor(double c) {
    if (c >= 0.9) return AppTheme.successColor;
    if (c >= 0.5) return AppTheme.getPrimaryColor(context);
    return AppTheme.warningColor;
  }

  /// 弹出确认记账 Sheet
  ///
  /// WHY: 用户在 Sheet 中选择分类与账户后调用 Provider 转正为正式交易。
  ///
  /// @param t 待确认交易
  void _showConfirmSheet(PendingTransaction t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _ConfirmSheet(
        pending: t,
        onConfirmed: _loadData,
      ),
    );
  }

  /// 丢弃待确认交易（带二次确认）
  ///
  /// WHY: 项目规范要求删除操作必须二次确认，避免误触。
  ///
  /// @param t 待确认交易
  Future<void> _discardTransaction(PendingTransaction t) async {
    // WHY: 在 async gap 之前提取 provider，避免 use_build_context_synchronously
    final AutoAccountingProvider provider =
        Provider.of<AutoAccountingProvider>(context, listen: false);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('确认忽略'),
        content: Text(
          '确定忽略 "${t.sourceDisplayName} · ${t.merchant ?? '未知商户'}" 的记录吗？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: AppTheme.neutral0,
            ),
            child: const Text('忽略'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await provider.discardTransaction(t.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已忽略')),
        );
      }
    } catch (e) {
      // WHY: 异常必须给出用户提示，禁止静默失败
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 清空所有已处理记录（带二次确认）
  ///
  /// WHY: 项目规范要求删除操作必须二次确认；仅清理 confirmed/discarded 状态记录。
  Future<void> _confirmClearProcessed() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清空已处理记录'),
        content: const Text('确定清空所有已处理记录吗？此操作不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: AppTheme.neutral0,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final int count = await PendingTransactionService.clearProcessed();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清空 $count 条记录')),
        );
      }
    } catch (e) {
      // WHY: 异常必须给出用户提示，禁止静默失败
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待确认记录'),
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清空已处理',
            onPressed: _confirmClearProcessed,
          ),
        ],
      ),
      body: Consumer<AutoAccountingProvider>(
        builder: (BuildContext context, AutoAccountingProvider provider,
            Widget? child) {
          return Column(
            children: <Widget>[
              _buildFilterTabs(provider),
              Expanded(child: _buildList()),
            ],
          );
        },
      ),
    );
  }

  /// 构建筛选 Chip 行
  ///
  /// WHY: 待确认数量来自 [AutoAccountingProvider.pendingCount] 实时响应；
  /// 其他状态数量从本地 [_allList] 计算。
  ///
  /// @param provider 自动记账状态管理
  Widget _buildFilterTabs(AutoAccountingProvider provider) {
    final int pendingCount = provider.pendingCount;
    final int confirmedCount = _allList
        .where((PendingTransaction t) => t.status == PendingStatus.confirmed)
        .length;
    final int discardedCount = _allList
        .where((PendingTransaction t) => t.status == PendingStatus.discarded)
        .length;
    final int allCount = _allList.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMedium,
        vertical: AppTheme.spaceSmall,
      ),
      // WHY: 使用 Wrap 而非 Row，避免 4 个 Chip 在窄屏溢出
      child: Wrap(
        spacing: AppTheme.spaceSmall,
        runSpacing: AppTheme.spaceSmall,
        children: <Widget>[
          _buildFilterChip(
            label: '待确认 ($pendingCount)',
            selected: _filter == PendingStatus.pending,
            onTap: () => setState(() => _filter = PendingStatus.pending),
          ),
          _buildFilterChip(
            label: '已记录 ($confirmedCount)',
            selected: _filter == PendingStatus.confirmed,
            onTap: () => setState(() => _filter = PendingStatus.confirmed),
          ),
          _buildFilterChip(
            label: '已忽略 ($discardedCount)',
            selected: _filter == PendingStatus.discarded,
            onTap: () => setState(() => _filter = PendingStatus.discarded),
          ),
          _buildFilterChip(
            label: '全部 ($allCount)',
            selected: _filter == null,
            onTap: () => setState(() => _filter = null),
          ),
        ],
      ),
    );
  }

  /// 构建单个筛选 Chip
  ///
  /// WHY: 选中状态使用 primary 渐变背景白字，未选中使用 neutral100 背景 neutral700 字，
  /// 符合简约风格设计规范。
  ///
  /// @param label Chip 文本
  /// @param selected 是否选中
  /// @param onTap 点击回调
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        decoration: BoxDecoration(
          // WHY: 选中状态用 primary 渐变背景白字；未选中用 neutral100 背景
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : AppTheme.neutral100,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.neutral0 : AppTheme.neutral700,
            fontSize: AppTheme.textLabelMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 构建列表区域
  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<PendingTransaction> list = _filterList();
    if (list.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      itemCount: list.length,
      itemBuilder: (BuildContext context, int index) =>
          _buildTransactionCard(list[index]),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppTheme.neutral400,
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '暂无记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '支付通知自动记账后，记录会显示在这里',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建单条交易卡片
  ///
  /// WHY: 卡片使用 elevation 0 + radiusLarge，符合简约风格；
  /// 仅 pending 状态显示操作按钮，已处理显示处理状态文本。
  ///
  /// @param t 待确认交易
  Widget _buildTransactionCard(PendingTransaction t) {
    final Color primary = AppTheme.getPrimaryColor(context);
    final Color statusColor = _getStatusColor(t.status);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMedium),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          children: <Widget>[
            // 第 1 行：来源标签 + 商户名 + 状态标签
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getSourceColor(t.source),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    t.sourceDisplayName,
                    style: const TextStyle(
                      color: AppTheme.neutral0,
                      fontSize: AppTheme.textLabelMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Text(
                    t.merchant ?? '未知商户',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    t.statusDisplayName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: AppTheme.textLabelSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            // 第 2 行：金额 + 时间
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '¥',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                ),
                const SizedBox(width: 2),
                Text(
                  // WHY: NumberFormat 内部运算要求 num，Decimal 直接传入会在
                  // 运行时抛 TypeError 导致卡片渲染崩溃（release 模式显示灰色块），
                  // 必须先 toDouble 转换（仅用于展示，精度损失可接受）
                  NumberFormat('#,##0.00').format(t.amount.toDouble()),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MM-dd HH:mm').format(t.paymentTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            // 第 3 行（可选）：推断分类 + 置信度
            if (t.inferredCategory != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: _getConfidenceColor(t.confidence),
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  Expanded(
                    child: Text(
                      '推断分类: ${t.inferredCategory} (置信度 ${(t.confidence * 100).toStringAsFixed(0)}%)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getConfidenceColor(t.confidence),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMedium),
            ],
            // 第 4 行：操作按钮或处理状态
            if (t.status == PendingStatus.pending)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _discardTransaction(t),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        side: const BorderSide(color: AppTheme.neutral300),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMedium,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                      ),
                      child: Text(
                        '忽略',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMedium),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _showConfirmSheet(t),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: AppTheme.neutral0,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMedium,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                      ),
                      child: Text(
                        '确认记账',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: t.status == PendingStatus.confirmed
                        ? AppTheme.successColor
                        : AppTheme.neutral400,
                  ),
                  const SizedBox(width: AppTheme.spaceXSmall),
                  Text(
                    t.status == PendingStatus.confirmed ? '已记录到账单' : '已忽略',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: t.status == PendingStatus.confirmed
                              ? AppTheme.successColor
                              : AppTheme.neutral500,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 待确认交易确认记账底部 Sheet
///
/// WHY: 与 P0-7 的 _QuickEntrySheet 不同，这里是轻量确认表单，
/// 仅包含分类下拉、账户下拉、备注与确认按钮。
class _ConfirmSheet extends StatefulWidget {
  /// 待确认的交易
  final PendingTransaction pending;

  /// 确认成功后的回调
  final VoidCallback onConfirmed;

  const _ConfirmSheet({
    required this.pending,
    required this.onConfirmed,
  });

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// 可选分类名列表
  late final List<String> _categories;

  /// 可选账户名列表
  late final List<String> _accounts;

  /// 当前选中的分类名
  String? _category;

  /// 当前选中的账户名
  String? _account;

  /// 备注文本
  String _note = '';

  /// 是否正在提交
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // WHY: 默认选中推断分类（若在列表中），否则第一个；账户默认第一个
    // 分类列表按收支方向选择：收入类 pending（收款/到账）展示收入分类
    final List<Category> categories = widget.pending.isIncome
        ? CategoryService.getIncomeCategories()
        : CategoryService.getExpenseCategories();
    final List<Account> accounts = AccountService.getActiveAccounts();
    _categories = categories.map((Category c) => c.name).toList();
    _accounts = accounts.map((Account a) => a.name).toList();

    final String? inferred = widget.pending.inferredCategory;
    if (inferred != null && _categories.contains(inferred)) {
      _category = inferred;
    } else if (_categories.isNotEmpty) {
      _category = _categories.first;
    }

    if (_accounts.isNotEmpty) {
      _account = _accounts.first;
    }
  }

  /// 提交确认记账
  ///
  /// WHY: 调用 [AutoAccountingProvider.confirmTransaction] 转正为正式交易；
  /// 成功后关闭 Sheet 并刷新列表，失败给出友好提示。
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_category == null || _account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类和账户')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // WHY: 在 await 之前提取 provider，避免在 async gap 后使用 BuildContext
      final AutoAccountingProvider provider =
          Provider.of<AutoAccountingProvider>(context, listen: false);
      final result = await provider.confirmTransaction(
        widget.pending.id,
        category: _category!,
        account: _account!,
        note: _note.isNotEmpty ? _note : null,
      );
      if (result != null) {
        widget.onConfirmed();
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已记录到账单')),
          );
        }
      } else {
        // WHY: 转正失败说明记录已被处理或不存在，给出明确提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记录已处理或不存在')),
          );
        }
      }
    } catch (e) {
      // WHY: 异常必须给出用户提示，禁止静默失败
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('确认失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.getPrimaryColor(context);
    // WHY: 键盘弹出时避免底部内容被遮挡
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.neutral0,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXXLarge),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 顶部把手
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral200,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
              ),
              Text(
                '确认记账',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Text(
                // WHY: 同上——NumberFormat 不接受 Decimal，必须 toDouble，
                // 否则运行时抛 TypeError 导致 Sheet 渲染崩溃
                '${widget.pending.sourceDisplayName} · ${widget.pending.merchant ?? '未知商户'} · ¥${NumberFormat('#,##0.00').format(widget.pending.amount.toDouble())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 分类下拉
              _buildDropdown(
                label: '分类',
                value: _category,
                items: _categories,
                onChanged: (String? v) => setState(() => _category = v),
              ),

              // 账户下拉
              _buildDropdown(
                label: '账户',
                value: _account,
                items: _accounts,
                onChanged: (String? v) => setState(() => _account = v),
              ),

              // 备注
              const SizedBox(height: AppTheme.spaceSmall),
              Text(
                '备注（可选）',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              TextFormField(
                initialValue: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '如：午餐、打车回家',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: const BorderSide(color: AppTheme.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(color: primary),
                  ),
                ),
                onSaved: (String? v) => _note = v?.trim() ?? '',
              ),

              const SizedBox(height: AppTheme.spaceXXLarge),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: AppTheme.neutral0,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.neutral0,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          '确认记账',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.neutral0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建下拉选择字段
  ///
  /// WHY: 当 value 不在 items 中时使用 null，避免 DropdownButtonFormField 断言失败。
  ///
  /// @param label 字段标签
  /// @param value 当前值
  /// @param items 可选项
  /// @param onChanged 选择回调
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // WHY: value 不在 items 中时强制 null，防止断言异常
    final String? safeValue =
        (value != null && items.contains(value)) ? value : null;
    final Color primary = AppTheme.getPrimaryColor(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          DropdownButtonFormField<String>(
            initialValue: safeValue,
            hint: Text('请选择$label'),
            items: items
                .map((String item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: const BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide(color: primary),
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

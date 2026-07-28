import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';
import '../theme/app_theme.dart';
import '../utils/icon_library.dart';

/// 负债管理页面
class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  List<Debt> _debts = [];
  String _filterStatus = 'all'; // all, active, completed

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  void _loadDebts() {
    setState(() {
      _debts = DebtService.getAllDebts();
    });
  }

  List<Debt> get _filteredDebts {
    switch (_filterStatus) {
      case 'active':
        return _debts.where((d) => !d.isCompleted).toList();
      case 'completed':
        return _debts.where((d) => d.isCompleted).toList();
      default:
        return _debts;
    }
  }

  void _showAddDebtDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXLarge),
            ),
          ),
          child: const AddDebtModal(),
        );
      },
    ).then((_) => _loadDebts());
  }

  void _showDebtDetail(Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXLarge),
            ),
          ),
          child: DebtDetailModal(debt: debt),
        );
      },
    ).then((_) => _loadDebts());
  }

  @override
  Widget build(BuildContext context) {
    final stats = DebtService.getDebtStats();

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            _buildStatsCards(context, stats),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 筛选标签
            _buildFilterTabs(context),
            const SizedBox(height: AppTheme.spaceLarge),

            // 负债列表
            _buildDebtList(context),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('负债管理'),
      elevation: 0,
    );
  }

  Widget _buildStatsCards(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.spaceMedium,
      mainAxisSpacing: AppTheme.spaceMedium,
      children: [
        // 待还金额
        _buildStatCard(
          context,
          title: '待还金额',
          value: '¥${stats['remainingAmount'].toStringAsFixed(2)}',
          icon: Icons.trending_down_rounded,
          color: AppTheme.errorColor,
        ),
        // 总负债
        _buildStatCard(
          context,
          title: '总负债',
          value: '¥${stats['totalAmount'].toStringAsFixed(2)}',
          icon: Icons.account_balance_rounded,
          color: AppTheme.getPrimaryColor(context),
        ),
        // 已还金额
        _buildStatCard(
          context,
          title: '已还金额',
          value: '¥${stats['paidAmount'].toStringAsFixed(2)}',
          icon: Icons.check_circle_rounded,
          color: AppTheme.successColor,
        ),
        // 逾期数量
        _buildStatCard(
          context,
          title: '逾期数量',
          value: '${stats['overdueCount']}笔',
          icon: Icons.warning_rounded,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Row(
      children: [
        _buildFilterTab(context, '全部', 'all'),
        const SizedBox(width: AppTheme.spaceSmall),
        _buildFilterTab(context, '待还款', 'active'),
        const SizedBox(width: AppTheme.spaceSmall),
        _buildFilterTab(context, '已还清', 'completed'),
      ],
    );
  }

  Widget _buildFilterTab(BuildContext context, String label, String status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.1)
              : AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppTheme.getPrimaryColor(context)
                : AppTheme.getDividerColor(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppTheme.getPrimaryColor(context)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildDebtList(BuildContext context) {
    if (_filteredDebts.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(
              Icons.file_copy_rounded,
              size: 48,
              color: AppTheme.neutral400,
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              '暂无负债记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          _filteredDebts.map((debt) => _buildDebtItem(context, debt)).toList(),
    );
  }

  Widget _buildDebtItem(BuildContext context, Debt debt) {
    return InkWell(
      onTap: () => _showDebtDetail(debt),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(debt.colorValue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    IconLibrary.getIconByName(debt.iconName),
                    color: Color(debt.colorValue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        debt.creditor,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: debt.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    debt.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: debt.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 进度条
            if (!debt.isCompleted) ...[
              _buildProgressBar(context, debt),
              const SizedBox(height: AppTheme.spaceSmall),
            ],

            // 金额和到期时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  debt.isCompleted
                      ? '已还 ¥${debt.totalAmount.toStringAsFixed(2)}'
                      : '待还 ¥${debt.remainingAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: debt.isCompleted
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                ),
                Text(
                  '到期: ${DateFormat('yyyy-MM-dd').format(debt.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            debt.isOverdue ? Colors.red : AppTheme.neutral500,
                      ),
                ),
              ],
            ),

            // 逾期提示
            if (debt.isOverdue)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '已逾期 ${-debt.remainingDays!} 天',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Debt debt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '还款进度',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
            Text(
              '${debt.progressPercent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryColor(context),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.getSecondaryBackground(context),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: debt.progressPercent / 100,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已还 ¥${debt.paidAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
            Text(
              '总金额 ¥${debt.totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: _showAddDebtDialog,
      backgroundColor: AppTheme.getPrimaryColor(context),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: const Icon(Icons.add_rounded),
    );
  }
}

/// 添加负债模态框
class AddDebtModal extends StatefulWidget {
  const AddDebtModal({super.key});

  @override
  State<AddDebtModal> createState() => _AddDebtModalState();
}

class _AddDebtModalState extends State<AddDebtModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditorController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    _creditorController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _saveDebt() {
    if (!_formKey.currentState!.validate()) return;

    final debt = DebtService.createDebt(
      name: _nameController.text,
      creditor: _creditorController.text,
      totalAmount: double.parse(_amountController.text),
      dueDate: _dueDate,
      interestRate: double.tryParse(_rateController.text) ?? 0.0,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    DebtService.addDebt(debt);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('负债添加成功')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppTheme.spaceLarge,
        left: AppTheme.spaceLarge,
        right: AppTheme.spaceLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLarge,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: AppTheme.spaceLarge),
                  Expanded(
                    child: Text(
                      '添加负债',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXLarge),

              // 负债名称
              _buildFormField(
                context,
                controller: _nameController,
                label: '负债名称',
                hintText: '如：信用卡欠款',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入负债名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 债权人
              _buildFormField(
                context,
                controller: _creditorController,
                label: '债权人',
                hintText: '如：招商银行',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入债权人';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 金额
              _buildFormField(
                context,
                controller: _amountController,
                label: '金额',
                hintText: '0.00',
                prefixText: '¥',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '请输入有效的金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 利率
              _buildFormField(
                context,
                controller: _rateController,
                label: '利率 (%)',
                hintText: '0.00',
                suffixText: '%',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 到期日期
              GestureDetector(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.getSecondaryBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceSmall),
                        decoration: BoxDecoration(
                          color: AppTheme.getPrimaryColor(context)
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child:
                            const Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      const SizedBox(width: AppTheme.spaceMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '到期日期',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.neutral500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('yyyy-MM-dd').format(_dueDate),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.neutral400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 备注
              _buildFormField(
                context,
                controller: _noteController,
                label: '备注',
                hintText: '添加备注信息（可选）',
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spaceXLarge),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveDebt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.getPrimaryColor(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            suffixText: suffixText,
            filled: true,
            fillColor: AppTheme.getSecondaryBackground(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: AppTheme.getPrimaryColor(context),
                width: 2,
              ),
            ),
          ),
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
        ),
      ],
    );
  }
}

/// 负债详情模态框
class DebtDetailModal extends StatefulWidget {
  final Debt debt;

  const DebtDetailModal({super.key, required this.debt});

  @override
  State<DebtDetailModal> createState() => _DebtDetailModalState();
}

class _DebtDetailModalState extends State<DebtDetailModal> {
  final _payAmountController = TextEditingController();

  @override
  void dispose() {
    _payAmountController.dispose();
    super.dispose();
  }

  void _showPayDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('还款'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('待还金额: ¥${widget.debt.remainingAmount.toStringAsFixed(2)}'),
              const SizedBox(height: AppTheme.spaceMedium),
              TextField(
                controller: _payAmountController,
                decoration: const InputDecoration(
                  prefixText: '¥',
                  hintText: '输入还款金额',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(_payAmountController.text);
                if (amount != null && amount > 0) {
                  DebtService.payDebt(widget.debt.id, amount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('还款成功')),
                  );
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _deleteDebt() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除负债'),
          content: const Text('确定要删除这条负债记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                DebtService.deleteDebt(widget.debt.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除成功')),
                );
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;

    return Padding(
      padding: EdgeInsets.only(
        top: AppTheme.spaceLarge,
        left: AppTheme.spaceLarge,
        right: AppTheme.spaceLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLarge,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: AppTheme.spaceLarge),
                Expanded(
                  child: Text(
                    '负债详情',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 负债名称和状态
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color(debt.colorValue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  ),
                  child: Icon(
                    IconLibrary.getIconByName(debt.iconName),
                    color: Color(debt.colorValue),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSmall,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: debt.statusColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          debt.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: debt.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 金额信息
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              decoration: BoxDecoration(
                color: AppTheme.getSecondaryBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Column(
                children: [
                  _buildDetailRow(context, '债权人', debt.creditor),
                  const Divider(height: 1),
                  _buildDetailRow(context, '总金额',
                      '¥${debt.totalAmount.toStringAsFixed(2)}'),
                  const Divider(height: 1),
                  _buildDetailRow(context, '已还金额',
                      '¥${debt.paidAmount.toStringAsFixed(2)}'),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    '待还金额',
                    '¥${debt.remainingAmount.toStringAsFixed(2)}',
                    highlight: !debt.isCompleted,
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(context, '利率', '${debt.interestRate}%'),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    '到期日期',
                    DateFormat('yyyy-MM-dd').format(debt.dueDate),
                    highlight: debt.isOverdue,
                  ),
                  if (debt.note != null) ...[
                    const Divider(height: 1),
                    _buildDetailRow(context, '备注', debt.note!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 进度条
            if (!debt.isCompleted) ...[
              _buildProgressBar(context, debt),
              const SizedBox(height: AppTheme.spaceXLarge),
            ],

            // 操作按钮
            Row(
              children: [
                if (!debt.isCompleted)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showPayDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.getPrimaryColor(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMedium),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                      ),
                      child: const Text('还款'),
                    ),
                  ),
                if (!debt.isCompleted)
                  const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleteDebt,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      side: const BorderSide(color: AppTheme.errorColor),
                      foregroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppTheme.errorColor : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Debt debt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '还款进度',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
            Text(
              '${debt.progressPercent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryColor(context),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.getSecondaryBackground(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: debt.progressPercent / 100,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

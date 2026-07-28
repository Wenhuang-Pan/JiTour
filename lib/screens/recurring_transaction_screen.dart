import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_transaction_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';
import '../utils/icon_library.dart';
import '../utils/uuid_util.dart';

/// 定期交易管理页面
class RecurringTransactionScreen extends StatefulWidget {
  const RecurringTransactionScreen({super.key});

  @override
  State<RecurringTransactionScreen> createState() =>
      _RecurringTransactionScreenState();
}

class _RecurringTransactionScreenState
    extends State<RecurringTransactionScreen> {
  List<RecurringTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  /// 加载定期交易列表
  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    _transactions = RecurringTransactionService.getAllRecurringTransactions();
    setState(() => _isLoading = false);
  }

  /// 添加定期交易
  void _addTransaction() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _TransactionFormModal(
          onSaved: () => _loadTransactions(),
        );
      },
    );
  }

  /// 编辑定期交易
  void _editTransaction(RecurringTransaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _TransactionFormModal(
          transaction: transaction,
          onSaved: () => _loadTransactions(),
        );
      },
    );
  }

  /// 删除定期交易
  void _deleteTransaction(RecurringTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除定期交易 "${transaction.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await RecurringTransactionService.deleteRecurringTransaction(
                  transaction.id);
              Navigator.pop(context);
              _loadTransactions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('删除成功')),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 执行定期交易
  void _executeTransaction(RecurringTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认执行'),
        content: Text('确定执行定期交易 "${transaction.name}" 吗？将生成一笔新的交易记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await RecurringTransactionService.executeRecurringTransaction(
                  transaction);
              Navigator.pop(context);
              _loadTransactions();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已生成交易: ${transaction.amountText}')),
              );
            },
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }

  /// 切换启用状态
  void _toggleStatus(RecurringTransaction transaction) {
    RecurringTransactionService.toggleStatus(
        transaction.id, !transaction.isEnabled);
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定期交易'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addTransaction,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionCard(_transactions[index]);
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.repeat_rounded,
            color: AppTheme.neutral400,
            size: 64,
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '暂无定期交易',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '点击右上角添加定期交易，如每月工资、房租等',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          ElevatedButton(
            onPressed: _addTransaction,
            child: const Text('添加定期交易'),
          ),
        ],
      ),
    );
  }

  /// 构建交易卡片
  Widget _buildTransactionCard(RecurringTransaction transaction) {
    final icon = IconLibrary.getIconByName('repeat');

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMedium),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: transaction.amountColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(icon, color: transaction.amountColor, size: 22),
                ),
                const SizedBox(width: AppTheme.spaceLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.category} · ${transaction.frequencyText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      transaction.amountText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: transaction.amountColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.nextExecutionDateText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Row(
              children: [
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: transaction.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction.statusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: transaction.statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                // 操作按钮
                IconButton(
                  icon: Icon(
                    transaction.isEnabled
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: transaction.isEnabled
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                    size: 20,
                  ),
                  onPressed: () => _toggleStatus(transaction),
                  tooltip: transaction.isEnabled ? '禁用' : '启用',
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_rounded, size: 20),
                  onPressed: transaction.isEnabled
                      ? () => _executeTransaction(transaction)
                      : null,
                  color: AppTheme.successColor,
                  tooltip: '执行',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: () => _editTransaction(transaction),
                  color: AppTheme.neutral400,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  onPressed: () => _deleteTransaction(transaction),
                  color: AppTheme.errorColor,
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 定期交易表单模态框
class _TransactionFormModal extends StatefulWidget {
  final RecurringTransaction? transaction;
  final VoidCallback onSaved;

  const _TransactionFormModal({
    this.transaction,
    required this.onSaved,
  });

  @override
  State<_TransactionFormModal> createState() => _TransactionFormModalState();
}

class _TransactionFormModalState extends State<_TransactionFormModal> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late bool _isIncome;
  late double _amount;
  late String _category;
  String? _subCategory;
  late String _account;
  String? _account2;
  late String _currency;
  late String _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _isEnabled;
  String? _note;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _name = widget.transaction!.name;
      _isIncome = widget.transaction!.isIncome;
      _amount = widget.transaction!.amount;
      _category = widget.transaction!.category;
      _subCategory = widget.transaction!.subCategory;
      _account = widget.transaction!.account;
      _account2 = widget.transaction!.account2;
      _currency = widget.transaction!.currency;
      _frequency = widget.transaction!.frequency;
      _startDate = widget.transaction!.startDate;
      _endDate = widget.transaction!.endDate;
      _isEnabled = widget.transaction!.isEnabled;
      _note = widget.transaction!.note;
    } else {
      _name = '';
      _isIncome = false;
      _amount = 0;
      _category = '';
      _account = '';
      _currency = 'CNY';
      _frequency = 'monthly';
      _startDate = DateTime.now();
      _isEnabled = true;
    }
  }

  /// 获取所有分类
  List<String> get _categories {
    final categories = _isIncome
        ? CategoryService.getIncomeCategories().map((c) => c.name).toList()
        : CategoryService.getExpenseCategories().map((c) => c.name).toList();
    return categories;
  }

  /// 获取所有账户
  List<String> get _accounts {
    return AccountService.getActiveAccounts().map((a) => a.name).toList();
  }

  /// 保存定期交易
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final recurringTransaction = RecurringTransaction(
      id: widget.transaction?.id ?? UuidUtil.generate(),
      name: _name,
      isIncome: _isIncome,
      amount: _amount,
      category: _category,
      subCategory: _subCategory,
      account: _account,
      account2: _account2,
      currency: _currency,
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      isEnabled: _isEnabled,
      note: _note,
    );

    // 计算下次执行日期
    recurringTransaction.updateNextExecutionDate();

    if (widget.transaction != null) {
      await RecurringTransactionService.updateRecurringTransaction(
          recurringTransaction);
    } else {
      await RecurringTransactionService.addRecurringTransaction(
          recurringTransaction);
    }

    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transaction != null ? '编辑定期交易' : '添加定期交易',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceLarge),

              // 名称
              _buildFormField(
                label: '名称',
                hintText: '如：工资、房租、房贷',
                initialValue: _name,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入名称';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),

              // 收支类型
              const SizedBox(height: AppTheme.spaceLarge),
              Text(
                '收支类型',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isIncome = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isIncome
                            ? Colors.transparent
                            : AppTheme.errorColor,
                        foregroundColor:
                            _isIncome ? AppTheme.neutral400 : Colors.white,
                        side: const BorderSide(color: AppTheme.neutral300),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceLarge),
                      ),
                      child: const Text('支出'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMedium),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isIncome = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isIncome
                            ? AppTheme.successColor
                            : Colors.transparent,
                        foregroundColor:
                            _isIncome ? Colors.white : AppTheme.neutral400,
                        side: const BorderSide(color: AppTheme.neutral300),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceLarge),
                      ),
                      child: const Text('收入'),
                    ),
                  ),
                ],
              ),

              // 金额
              _buildFormField(
                label: '金额',
                hintText: '0.00',
                initialValue: _amount.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return '请输入有效金额';
                  }
                  return null;
                },
                onSaved: (value) => _amount = double.parse(value!),
              ),

              // 分类
              _buildDropdownField(
                label: '分类',
                items: _categories,
                value: _category,
                hintText: '请选择分类',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择分类';
                  }
                  return null;
                },
                onChanged: (value) => setState(() => _category = value!),
              ),

              // 账户
              _buildDropdownField(
                label: '账户',
                items: _accounts,
                value: _account,
                hintText: '请选择账户',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择账户';
                  }
                  return null;
                },
                onChanged: (value) => setState(() => _account = value!),
              ),

              // 周期
              _buildDropdownField(
                label: '周期',
                items: const ['每天', '每周', '每月', '每年'],
                value: _frequency == 'daily'
                    ? '每天'
                    : _frequency == 'weekly'
                        ? '每周'
                        : _frequency == 'yearly'
                            ? '每年'
                            : '每月',
                hintText: '请选择周期',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择周期';
                  }
                  return null;
                },
                onChanged: (value) => setState(() {
                  _frequency = value == '每天'
                      ? 'daily'
                      : value == '每周'
                          ? 'weekly'
                          : value == '每年'
                              ? 'yearly'
                              : 'monthly';
                }),
              ),

              // 开始日期
              _buildDateField(
                label: '开始日期',
                value: _startDate,
                onChanged: (date) => setState(() => _startDate = date!),
              ),

              // 结束日期（可选）
              _buildDateField(
                label: '结束日期（可选）',
                value: _endDate,
                onChanged: (date) => setState(() => _endDate = date),
              ),

              // 备注（可选）
              _buildFormField(
                label: '备注',
                hintText: '备注信息（可选）',
                initialValue: _note ?? '',
                maxLines: 3,
                onSaved: (value) =>
                    _note = value?.isNotEmpty == true ? value : null,
              ),

              // 启用开关
              const SizedBox(height: AppTheme.spaceLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '启用',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: (value) => setState(() => _isEnabled = value),
                    activeThumbColor: AppTheme.getPrimaryColor(context),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceXXLarge),

              // 保存按钮
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
                ),
                child: const Text('保存'),
              ),

              const SizedBox(height: AppTheme.spaceLarge),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建表单输入框
  Widget _buildFormField({
    required String label,
    required String hintText,
    required String initialValue,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spaceLarge),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: const BorderSide(color: AppTheme.neutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: AppTheme.getPrimaryColor(context)),
            ),
            contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
          ),
          validator: validator,
          onSaved: onSaved,
        ),
      ],
    );
  }

  /// 构建下拉选择框
  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String? value,
    required String hintText,
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spaceLarge),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: Text(hintText),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: const BorderSide(color: AppTheme.neutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: AppTheme.getPrimaryColor(context)),
            ),
            contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 构建日期选择框
  Widget _buildDateField({
    required String label,
    DateTime? value,
    void Function(DateTime?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spaceLarge),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText:
                value != null ? DateFormat('yyyy-MM-dd').format(value) : '选择日期',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: const BorderSide(color: AppTheme.neutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: AppTheme.getPrimaryColor(context)),
            ),
            contentPadding: const EdgeInsets.all(AppTheme.spaceMedium),
            suffixIcon: const Icon(Icons.calendar_month_rounded),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2099),
            );
            onChanged?.call(date);
          },
        ),
      ],
    );
  }
}

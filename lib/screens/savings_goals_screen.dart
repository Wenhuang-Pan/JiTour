import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/savings_goal.dart';
import '../services/savings_goal_service.dart';
import '../services/account_service.dart';
import '../utils/icon_library.dart';
import '../providers/currency_provider.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('储蓄目标'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '进行中'),
            Tab(text: '已完成'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveGoalsList(),
          _buildCompletedGoalsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildActiveGoalsList() {
    final goals = SavingsGoalService.getActiveGoals();

    if (goals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.savings_outlined,
        title: '暂无储蓄目标',
        subtitle: '点击下方按钮创建第一个目标',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceMedium),
          child: _buildGoalCard(context, goals[index]),
        );
      },
    );
  }

  Widget _buildCompletedGoalsList() {
    final goals = SavingsGoalService.getCompletedGoals();

    if (goals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: '暂无已完成目标',
        subtitle: '完成储蓄目标后会显示在这里',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceMedium),
          child: _buildGoalCard(context, goals[index], isCompleted: true),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.neutral100.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            child: Icon(
              icon,
              color: AppTheme.neutral400,
              size: 40,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.neutral600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.neutral500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal,
      {bool isCompleted = false}) {
    final color = Color(goal.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    IconLibrary.getIconByName(goal.iconName),
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
                        goal.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      if (goal.description != null)
                        Text(
                          goal.description!,
                          style: TextStyle(
                            color: AppTheme.neutral500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (goal.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '逾期',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 进度信息
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            child: Column(
              children: [
                // 金额进度
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${goal.currentAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      '/ ¥${goal.targetAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSmall),

                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: LinearProgressIndicator(
                    value: goal.progressPercent / 100,
                    backgroundColor: AppTheme.neutral100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),

                // 进度百分比和剩余金额
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${goal.progressPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '还差 ¥${goal.remainingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.neutral500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // 目标日期信息
                if (goal.targetDate != null) ...[
                  const SizedBox(height: AppTheme.spaceSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: goal.isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.neutral500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        goal.isOverdue
                            ? '已逾期 ${goal.daysToTargetDate} 天'
                            : '剩余 ${goal.daysToTargetDate} 天',
                        style: TextStyle(
                          color: goal.isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.neutral500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],

                // 关联账户信息
                if (goal.accountId != null) ...[
                  const SizedBox(height: AppTheme.spaceSmall),
                  _buildLinkedAccountInfo(goal.accountId!),
                ],
              ],
            ),
          ),

          // 操作按钮
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            decoration: BoxDecoration(
              color: AppTheme.neutral50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showAddSavingsDialog(context, goal),
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: const Text('存款'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.successColor,
                    ),
                  ),
                ),
                if (!isCompleted)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showWithdrawDialog(context, goal),
                      icon: Icon(Icons.remove_rounded, size: 18),
                      label: const Text('提取'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.warningColor,
                      ),
                    ),
                  ),
                Expanded(
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.neutral500,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditGoalDialog(context, goal);
                          break;
                        case 'reset':
                          _showResetConfirmDialog(context, goal);
                          break;
                        case 'delete':
                          _showDeleteConfirmDialog(context, goal);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('编辑'),
                          ],
                        ),
                      ),
                      if (!isCompleted)
                        const PopupMenuItem(
                          value: 'reset',
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('重置'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 18, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            Text('删除',
                                style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedIconName = 'savings_rounded';
    int selectedColorValue = AppTheme.primaryColor.value;
    DateTime? targetDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('创建储蓄目标'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    maxLines: 2,
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
                                ? '${targetDate!.year}-${targetDate!.month}-${targetDate!.day}'
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
                  const SizedBox(height: AppTheme.spaceMedium),
                  Text(
                    '选择图标',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: SavingsGoalService.getDefaultIcons().length,
                      itemBuilder: (context, index) {
                        final iconName =
                            SavingsGoalService.getDefaultIcons()[index];
                        final isSelected = selectedIconName == iconName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setDialogState(
                                () => selectedIconName = iconName),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(selectedColorValue)
                                        .withOpacity(0.1)
                                    : AppTheme.neutral100,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSmall),
                                border: isSelected
                                    ? Border.all(
                                        color: Color(selectedColorValue))
                                    : null,
                              ),
                              child: Icon(
                                IconLibrary.getIconByName(iconName),
                                color: isSelected
                                    ? Color(selectedColorValue)
                                    : AppTheme.neutral600,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  Text(
                    '选择颜色',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: SavingsGoalService.getDefaultColors().length,
                      itemBuilder: (context, index) {
                        final colorValue =
                            SavingsGoalService.getDefaultColors()[index];
                        final color = Color(colorValue);
                        final isSelected = selectedColorValue == colorValue;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setDialogState(
                                () => selectedColorValue = colorValue),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: AppTheme.neutral800, width: 2)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.2),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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

                  try {
                    await SavingsGoalService.createGoal(
                      name: name,
                      description: descController.text.trim().isNotEmpty
                          ? descController.text.trim()
                          : null,
                      targetAmount: amount,
                      iconName: selectedIconName,
                      colorValue: selectedColorValue,
                      targetDate: targetDate,
                    );
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('目标创建成功'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('创建失败: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('创建'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditGoalDialog(BuildContext context, SavingsGoal goal) {
    final nameController = TextEditingController(text: goal.name);
    final descController = TextEditingController(text: goal.description ?? '');
    final amountController =
        TextEditingController(text: goal.targetAmount.toString());
    DateTime? targetDate = goal.targetDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑目标'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '目标名称',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMedium),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                maxLines: 2,
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ],
          ),
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
            onPressed: () async {
              final updatedGoal = goal.copyWith(
                name: nameController.text.trim(),
                description: descController.text.trim().isNotEmpty
                    ? descController.text.trim()
                    : null,
                targetAmount:
                    double.tryParse(amountController.text) ?? goal.targetAmount,
                targetDate: targetDate,
              );
              await SavingsGoalService.updateGoal(updatedGoal);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddSavingsDialog(BuildContext context, SavingsGoal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle_rounded, color: AppTheme.successColor),
            const SizedBox(width: 8),
            Text('存入 ${goal.name}'),
          ],
        ),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: '存入金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
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
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              await SavingsGoalService.addSavings(goal.id, amount);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, SavingsGoal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.remove_circle_rounded, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            Text('提取 ${goal.name}'),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
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

              await SavingsGoalService.withdrawSavings(goal.id, amount);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置目标'),
        content: Text('确定要重置「${goal.name}」的进度吗？这不会删除目标，只是将当前存款清零。'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SavingsGoalService.resetGoal(goal.id);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定要删除「${goal.name}」吗？此操作不可恢复。'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SavingsGoalService.deleteGoal(goal.id);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountInfo(String accountId) {
    final account = AccountService.getAccountById(accountId);
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    if (account == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSmall,
        vertical: AppTheme.spaceXSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            size: 12,
            color: AppTheme.neutral500,
          ),
          const SizedBox(width: 4),
          Text(
            '关联账户: ${account.name}',
            style: TextStyle(
              color: AppTheme.neutral600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            '余额: ${currencyProvider.formatAmount(account.currentBalance)}',
            style: TextStyle(
              color: AppTheme.neutral500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

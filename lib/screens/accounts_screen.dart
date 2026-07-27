import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../services/database_service.dart';
import '../services/test_data_service.dart';
import '../utils/icon_library.dart';
import 'export_screen.dart';
import 'backup_screen.dart';
import 'transfer_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: '账户转账',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransferScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.backup_rounded),
            tooltip: '数据备份',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: '数据导出',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.accounts.listenable(),
        builder: (context, Box<Account> box, _) {
          final accounts = AccountService.getActiveAccounts();
          final totalBalance = AccountService.getTotalBalance();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalBalanceCard(context, totalBalance),
                const SizedBox(height: AppTheme.spaceXLarge),
                _buildSectionTitle(context, '账户列表', '各账户余额详情'),
                const SizedBox(height: AppTheme.spaceMedium),
                if (accounts.isEmpty)
                  _buildEmptyState(context)
                else
                  ...accounts.map((account) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppTheme.spaceSmall),
                        child: _buildAccountCard(context, account),
                      )),
                const SizedBox(height: AppTheme.spaceXLarge),
                _buildQuickActions(context),
                const SizedBox(height: AppTheme.spaceXLarge),
                _buildTestDataTools(context),
                const SizedBox(height: AppTheme.spaceXXXLarge),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        backgroundColor: AppTheme.getPrimaryColor(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context, double totalBalance) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.getPrimaryGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.glowShadow(AppTheme.getPrimaryColor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              const Text(
                '总资产',
                style: TextStyle(
                  fontSize: AppTheme.textBodyLarge,
                  fontWeight: FontWeight.w500,
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
                  color: totalBalance >= 0
                      ? AppTheme.successColor.withValues(alpha: 0.25)
                      : AppTheme.errorColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      totalBalance >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      totalBalance >= 0 ? '资产健康' : '负债状态',
                      style: const TextStyle(
                        fontSize: AppTheme.textLabelSmall,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '¥${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          Text(
            '共 ${AccountService.getActiveAccounts().length} 个账户',
            style: TextStyle(
              fontSize: AppTheme.textBodySmall,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account) {
    final icon = IconLibrary.getIconByName(account.iconName);
    final color = Color(account.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showAccountOptionsDialog(context, account),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '初始余额: ¥${account.initialBalance.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${account.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: AppTheme.textTitleLarge,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: account.currentBalance >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (account.currentBalance >= 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      account.currentBalance >= 0 ? '正常' : '透支',
                      style: TextStyle(
                        fontSize: AppTheme.textLabelSmall,
                        fontWeight: FontWeight.w600,
                        color: account.currentBalance >= 0
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.neutral200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const Icon(
              Icons.wallet_rounded,
              size: 40,
              color: AppTheme.neutral400,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Text(
            '暂无账户',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.neutral600,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '点击右下角按钮添加账户',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.neutral200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.swap_horiz_rounded,
                label: '转账',
                color: AppTheme.getPrimaryColor(context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransferScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.edit_rounded,
                label: '调整余额',
                color: AppTheme.warningColor,
                onTap: () => _showAdjustBalanceDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMedium,
          vertical: AppTheme.spaceSmall,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppTheme.spaceSmall),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestDataTools(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Text(
                  '测试数据工具',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              '生成模拟数据用于测试应用功能',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generateTestData(context),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text('生成测试数据'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMedium,
                        vertical: AppTheme.spaceSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _clearAllData(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('清除所有数据'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMedium,
                        vertical: AppTheme.spaceSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAccountDialog(BuildContext context) async {
    final result = await showDialog<Account>(
      context: context,
      builder: (context) => const _AccountFormDialog(),
    );

    if (result != null) {
      await AccountService.createAccount(
        name: result.name,
        iconName: result.iconName,
        colorValue: result.colorValue,
        initialBalance: result.initialBalance,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('账户 "${result.name}" 创建成功'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAccountOptionsDialog(
      BuildContext context, Account account) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Text(
              account.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: AppTheme.getPrimaryColor(context),
                ),
              ),
              title: const Text('编辑账户'),
              subtitle: const Text('修改账户名称、图标、颜色'),
              onTap: () {
                Navigator.pop(context);
                _showEditAccountDialog(context, account);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.warningColor,
                ),
              ),
              title: const Text('调整余额'),
              subtitle: const Text('手动调整账户余额'),
              onTap: () {
                Navigator.pop(context);
                _showAdjustAccountBalanceDialog(context, account);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                ),
              ),
              title: Text(
                '删除账户',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              subtitle: const Text('账户将被隐藏，但数据保留'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAccount(context, account);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAccountDialog(
      BuildContext context, Account account) async {
    final result = await showDialog<Account>(
      context: context,
      builder: (context) => _AccountFormDialog(account: account),
    );

    if (result != null) {
      account.name = result.name;
      account.iconName = result.iconName;
      account.colorValue = result.colorValue;
      await AccountService.updateAccount(account);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('账户 "${result.name}" 更新成功'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAdjustAccountBalanceDialog(
      BuildContext context, Account account) async {
    final controller = TextEditingController(
      text: account.currentBalance.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('调整 ${account.name} 余额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '当前余额',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newBalance = double.tryParse(controller.text);
              Navigator.pop(context, newBalance);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      account.currentBalance = result;
      await AccountService.updateAccount(account);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('余额已更新'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('确认删除'),
        content: Text(
          '确定要删除账户 "${account.name}" 吗？\n\n'
          '账户将被隐藏，交易记录将保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AccountService.deleteAccount(account.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('账户 "${account.name}" 已删除'),
            backgroundColor: AppTheme.neutral600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAdjustBalanceDialog(BuildContext context) async {
    final accounts = AccountService.getActiveAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先添加账户'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    Account? selectedAccount = accounts.first;
    final controller = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: const Text('调整账户余额'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Account>(
                initialValue: selectedAccount,
                decoration: const InputDecoration(
                  labelText: '选择账户',
                ),
                items: accounts.map((account) {
                  return DropdownMenuItem(
                    value: account,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAccount = value;
                    controller.text =
                        value?.currentBalance.toStringAsFixed(2) ?? '';
                  });
                },
              ),
              const SizedBox(height: AppTheme.spaceMedium),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '新余额',
                  prefixText: '¥ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'account': selectedAccount,
                  'balance': double.tryParse(controller.text) ??
                      selectedAccount!.currentBalance,
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final account = result['account'] as Account;
      final balance = result['balance'] as double;

      account.currentBalance = balance;
      await AccountService.updateAccount(account);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${account.name} 余额已更新为 ¥${balance.toStringAsFixed(2)}'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _generateTestData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
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
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: AppTheme.warningColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('生成测试数据'),
          ],
        ),
        content: const Text(
          '这将生成最近3个月的模拟交易数据（约50-90笔）和预算数据。\n\n'
          '现有数据将被清除，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: AppTheme.neutral600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TestDataService.generateTestData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('测试数据生成成功！'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('生成失败: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
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
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.errorColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            const Text('清除所有数据'),
          ],
        ),
        content: const Text(
          '此操作将永久删除所有交易记录、预算数据和账户数据，无法恢复！\n\n'
          '建议先备份数据。确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: AppTheme.neutral600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.transactions.clear();
        await DatabaseService.budgets.clear();
        await DatabaseService.accounts.clear();

        // 重新创建默认账户
        await AccountService.init();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('所有数据已清除'),
              backgroundColor: AppTheme.neutral600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清除失败: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      }
    }
  }
}

class _AccountFormDialog extends StatefulWidget {
  final Account? account;

  const _AccountFormDialog({this.account});

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedIconName = '现金';
  int _selectedColorValue = 0xFFFFB020;
  IconData _selectedIcon = Icons.account_balance_wallet_rounded;

  final List<String> _iconNames = [
    '现金',
    '银行卡',
    '支付宝',
    '微信',
    '信用卡',
    '储蓄卡',
    '其他'
  ];
  final Map<String, IconData> _iconMap = {
    '现金': Icons.account_balance_wallet_rounded,
    '银行卡': Icons.credit_card_rounded,
    '支付宝': Icons.mobile_friendly_rounded,
    '微信': Icons.message_rounded,
    '信用卡': Icons.credit_score_rounded,
    '储蓄卡': Icons.savings_rounded,
    '其他': Icons.category_rounded,
  };

  final Map<String, int> _colorMap = {
    '现金': 0xFFFFB020,
    '银行卡': 0xFF2979FF,
    '支付宝': 0xFF00C853,
    '微信': 0xFF07C160,
    '信用卡': 0xFFFF5252,
    '储蓄卡': 0xFF651FFF,
    '其他': 0xFF9E9E9E,
  };

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _balanceController.text =
          widget.account!.currentBalance.toStringAsFixed(2);
      _selectedIconName = widget.account!.iconName;
      _selectedColorValue = widget.account!.colorValue;
      _selectedIcon = _iconMap[_selectedIconName] ?? Icons.category_rounded;
    } else {
      _balanceController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account != null ? '编辑账户' : '添加账户',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),

            // 账户名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '账户名称',
                hintText: '例如：我的银行卡',
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),

            // 初始余额
            TextField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '初始余额',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: AppTheme.spaceLarge),

            // 图标选择
            Text(
              '选择图标',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Wrap(
              spacing: AppTheme.spaceSmall,
              runSpacing: AppTheme.spaceSmall,
              children: _iconNames.map((name) {
                final isSelected = name == _selectedIconName;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIconName = name;
                      _selectedIcon = _iconMap[name]!;
                      _selectedColorValue = _colorMap[name]!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(AppTheme.spaceSmall),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(_selectedColorValue).withValues(alpha: 0.2)
                          : AppTheme.neutral100,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: isSelected
                            ? Color(_selectedColorValue)
                            : AppTheme.neutral200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      _iconMap[name],
                      color: isSelected
                          ? Color(_selectedColorValue)
                          : AppTheme.neutral600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spaceLarge),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                ElevatedButton(
                  onPressed: _saveAccount,
                  child: Text(widget.account != null ? '保存' : '添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveAccount() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入账户名称'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    // 检查名称是否重复
    final existingAccount = AccountService.getAccountByName(name);
    if (existingAccount != null &&
        (widget.account == null || existingAccount.id != widget.account!.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('账户名称已存在'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    final balance = double.tryParse(_balanceController.text) ?? 0.0;

    final account = Account(
      id: widget.account?.id ?? '',
      name: name,
      iconName: _selectedIconName,
      colorValue: _selectedColorValue,
      initialBalance: widget.account?.initialBalance ?? balance,
      currentBalance: widget.account?.currentBalance ?? balance,
      sortOrder: widget.account?.sortOrder ?? 0,
    );

    Navigator.pop(context, account);
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../utils/icon_library.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Account? _fromAccount;
  Account? _toAccount;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = AccountService.getActiveAccounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户转账'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 转账说明卡片
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spaceSmall),
                  Expanded(
                    child: Text(
                      '转账会在账户间移动资金，不会影响总资产',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 转账示意图
            _buildTransferDiagram(),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 转出账户
            Text(
              '转出账户',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildAccountSelector(
              accounts: accounts,
              selectedAccount: _fromAccount,
              onChanged: (account) {
                setState(() {
                  _fromAccount = account;
                });
              },
              excludeAccount: _toAccount,
              hint: '请选择转出账户',
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 转入账户
            Text(
              '转入账户',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildAccountSelector(
              accounts: accounts,
              selectedAccount: _toAccount,
              onChanged: (account) {
                setState(() {
                  _toAccount = account;
                });
              },
              excludeAccount: _fromAccount,
              hint: '请选择转入账户',
            ),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 转账金额
            Text(
              '转账金额',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral800,
                ),
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral300,
                ),
                filled: true,
                fillColor: AppTheme.neutral50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_fromAccount != null) ...[
              const SizedBox(height: AppTheme.spaceXSmall),
              Text(
                '可用余额: ¥${_fromAccount!.currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppTheme.neutral500,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceXLarge),

            // 备注
            Text(
              '备注（可选）',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '添加备注...',
                hintStyle: TextStyle(color: AppTheme.neutral400),
                filled: true,
                fillColor: AppTheme.neutral50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXXLarge),

            // 转账按钮
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _canTransfer() ? _performTransfer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.neutral300,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '确认转账',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferDiagram() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAccountPreview(
          account: _fromAccount,
          label: '转出',
        ),
        const SizedBox(width: AppTheme.spaceMedium),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSmall),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMedium),
        _buildAccountPreview(
          account: _toAccount,
          label: '转入',
        ),
      ],
    );
  }

  Widget _buildAccountPreview({
    Account? account,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: account != null
                ? Color(account.colorValue).withOpacity(0.1)
                : AppTheme.neutral100,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: account != null
                  ? Color(account.colorValue)
                  : AppTheme.neutral300,
              width: 2,
            ),
          ),
          child: Icon(
            account != null
                ? IconLibrary.getIconByName(account.iconName)
                : Icons.account_balance_wallet_outlined,
            color: account != null
                ? Color(account.colorValue)
                : AppTheme.neutral400,
            size: 28,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXSmall),
        Text(
          account?.name ?? label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: account != null ? AppTheme.neutral800 : AppTheme.neutral400,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector({
    required List<Account> accounts,
    required Account? selectedAccount,
    required Function(Account?) onChanged,
    Account? excludeAccount,
    required String hint,
  }) {
    final availableAccounts =
        accounts.where((a) => a.id != excludeAccount?.id).toList();

    if (availableAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: AppTheme.neutral50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Text(
          '请先添加至少两个账户',
          style: TextStyle(color: AppTheme.neutral500),
        ),
      );
    }

    return DropdownButtonFormField<Account>(
      value: selectedAccount,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.neutral400),
        filled: true,
        fillColor: AppTheme.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
      ),
      items: availableAccounts.map((account) {
        return DropdownMenuItem(
          value: account,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(account.colorValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  IconLibrary.getIconByName(account.iconName),
                  color: Color(account.colorValue),
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Text(account.name),
              const Spacer(),
              Text(
                '¥${account.currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppTheme.neutral500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  bool _canTransfer() {
    if (_fromAccount == null || _toAccount == null) return false;
    if (_fromAccount!.id == _toAccount!.id) return false;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return false;

    if (amount > _fromAccount!.currentBalance) return false;

    return true;
  }

  Future<void> _performTransfer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();

      await AccountService.transfer(
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: amount,
        note: note.isNotEmpty ? note : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '转账成功: ${_fromAccount!.name} → ${_toAccount!.name} ¥${amount.toStringAsFixed(2)}',
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转账失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/pending_transaction.dart';
import '../providers/auto_accounting_provider.dart';
import '../providers/theme_provider.dart';
import '../services/account_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

/// 支付通知快速记账弹窗叠加层
///
/// 包裹在页面主体外层，自动监听 [AutoAccountingProvider] 的待确认交易列表，
/// 当有新交易时弹出底部 Sheet 供用户快速确认或忽略。
///
/// 使用方式：
/// ```dart
/// QuickEntryOverlay(
///   child: HomePageBody(),
/// )
/// ```
class QuickEntryOverlay extends StatefulWidget {
  /// 页面主体内容
  final Widget child;

  const QuickEntryOverlay({
    super.key,
    required this.child,
  });

  @override
  State<QuickEntryOverlay> createState() => _QuickEntryOverlayState();
}

class _QuickEntryOverlayState extends State<QuickEntryOverlay> {
  /// WHY: 使用 Set<String> 记录已弹窗的交易 ID，
  /// 防止同一笔交易在 Provider 多次 notify 时重复弹出。
  final Set<String> _shownIds = <String>{};

  /// 底部 Sheet 是否正在展示中
  bool _isSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPendingCheck();
    });
  }

  @override
  void dispose() {
    _shownIds.clear();
    super.dispose();
  }

  /// 初始化时检查一次待确认列表
  void _initPendingCheck() {
    final provider =
        Provider.of<AutoAccountingProvider>(context, listen: false);
    if (provider.pendingList.isNotEmpty) {
      final first = provider.pendingList.first;
      if (!_shownIds.contains(first.id)) {
        _showBottomSheet(first);
      }
    }
  }

  /// 弹出快速记账底部 Sheet
  ///
  /// @param pending 待确认交易
  void _showBottomSheet(PendingTransaction pending) {
    if (_isSheetShowing) return;

    _isSheetShowing = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXXLarge),
        ),
      ),
      builder: (BuildContext ctx) {
        return _QuickEntrySheet(pending: pending);
      },
    ).then((_) {
      _isSheetShowing = false;
      _shownIds.add(pending.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AutoAccountingProvider, ThemeProvider>(
      builder: (
        BuildContext context,
        AutoAccountingProvider autoProvider,
        ThemeProvider themeProvider,
        Widget? child,
      ) {
        // WHY: 只弹 pendingList 中的最新第一条，
        // 其余待确认交易让用户通过待确认列表页集中处理，避免连续弹窗混乱。
        if (autoProvider.pendingList.isNotEmpty && !_isSheetShowing) {
          final first = autoProvider.pendingList.first;
          if (!_shownIds.contains(first.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showBottomSheet(first);
              }
            });
          }
        }
        return widget.child;
      },
    );
  }
}

/// 快速记账底部弹窗内容
///
/// 展示待确认交易的详细信息，包含金额、商户、分类选择、账户选择、备注等，
/// 用户可选择"忽略"丢弃该交易，或"确认记账"将其转正为正式交易。
class _QuickEntrySheet extends StatefulWidget {
  /// 待确认的交易数据
  final PendingTransaction pending;

  const _QuickEntrySheet({
    required this.pending,
  });

  @override
  State<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<_QuickEntrySheet> {
  /// 当前选中的分类名
  late String _selectedCategory;

  /// 当前选中的账户名
  late String _selectedAccount;

  /// 备注输入控制器
  late TextEditingController _noteController;

  /// 金额输入控制器（用户可手动修改）
  late TextEditingController _amountController;

  /// 可选支出分类列表
  List<Category> _expenseCategories = <Category>[];

  /// 可选活跃账户列表
  List<Account> _activeAccounts = <Account>[];

  @override
  void initState() {
    super.initState();
    // WHY: 分类列表按收支方向选择——收入类 pending（收款/到账）
    // 展示收入分类，支出保持原有行为；变量名保留 _expenseCategories
    // 避免大范围重命名，实际承载"当前方向的分类列表"
    _expenseCategories = widget.pending.isIncome
        ? CategoryService.getIncomeCategories()
        : CategoryService.getExpenseCategories();
    _activeAccounts = AccountService.getActiveAccounts();

    // WHY: 默认优先选中推断的分类（若存在且在列表中），
    // 否则选中第一个分类，减少用户操作成本。
    final categoryNames =
        _expenseCategories.map((Category c) => c.name).toSet();
    if (widget.pending.inferredCategory != null &&
        categoryNames.contains(widget.pending.inferredCategory)) {
      _selectedCategory = widget.pending.inferredCategory!;
    } else {
      _selectedCategory =
          _expenseCategories.isNotEmpty ? _expenseCategories.first.name : '';
    }

    // WHY: 账户默认选中第一个，后续可根据支付来源智能匹配（如支付宝→支付宝账户）。
    _selectedAccount =
        _activeAccounts.isNotEmpty ? _activeAccounts.first.name : '';

    _noteController =
        TextEditingController(text: widget.pending.merchant ?? '');
    _amountController = TextEditingController(
      text: widget.pending.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// 获取用户输入的最终金额
  ///
  /// @return 解析后的金额；解析失败回退到 pending 原金额
  Decimal get _effectiveAmount {
    final parsed = Decimal.tryParse(_amountController.text.trim());
    return parsed != null && parsed > Decimal.zero
        ? parsed
        : widget.pending.amount;
  }

  /// 格式化金额为千分位、两位小数
  ///
  /// @param amount 金额
  /// @return 格式化后的字符串，如 "1,234.56"
  String formatAmount(Decimal amount) {
    // WHY: NumberFormat 需要 double，Decimal 转 double 仅用于展示
    return NumberFormat('#,##0.00', 'zh_CN').format(amount.toDouble());
  }

  /// 根据支付来源获取标签颜色
  ///
  /// @param source 支付来源
  /// @return 对应的品牌色
  Color _getSourceColor(PaymentSource source) {
    switch (source) {
      case PaymentSource.alipay:
        return const Color(0xFF1677FF);
      case PaymentSource.wechat:
        return const Color(0xFF07C160);
    }
  }

  /// 构建自定义 ChoiceChip（支持选中时渐变背景）
  ///
  /// @param label 显示文本
  /// @param isSelected 是否选中
  /// @param onTap 点击回调
  /// @return Chip Widget
  Widget _buildGradientChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryGradient = AppTheme.getPrimaryGradient(context);
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
            gradient: isSelected ? primaryGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppTheme.neutral700 : AppTheme.neutral100),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textBodyMedium,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.neutral100 : AppTheme.neutral700),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建分类选择器
  Widget _buildCategorySelector() {
    if (_expenseCategories.isEmpty) {
      return const Text(
        '暂无分类，请先创建',
        style: TextStyle(
          fontSize: AppTheme.textBodySmall,
          color: AppTheme.errorColor,
        ),
      );
    }

    return Wrap(
      spacing: AppTheme.spaceSmall,
      runSpacing: AppTheme.spaceSmall,
      children: _expenseCategories.map((Category category) {
        final isSelected = _selectedCategory == category.name;
        return _buildGradientChip(
          label: category.name,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategory = category.name;
            });
          },
        );
      }).toList(),
    );
  }

  /// 构建账户选择器
  Widget _buildAccountSelector() {
    if (_activeAccounts.isEmpty) {
      return const Text(
        '暂无账户，请先创建',
        style: TextStyle(
          fontSize: AppTheme.textBodySmall,
          color: AppTheme.errorColor,
        ),
      );
    }

    return Wrap(
      spacing: AppTheme.spaceSmall,
      runSpacing: AppTheme.spaceSmall,
      children: _activeAccounts.map((Account account) {
        final isSelected = _selectedAccount == account.name;
        return _buildGradientChip(
          label: account.name,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedAccount = account.name;
            });
          },
        );
      }).toList(),
    );
  }

  /// 构建置信度提示文本
  Widget? _buildConfidenceHint() {
    final confidence = widget.pending.confidence;
    final hasInferred = widget.pending.inferredCategory != null;

    if (!hasInferred) return null;

    // WHY: 置信度低于 0.5 时提示用户手动确认，避免错误分类；
    // 置信度高于 0.9 时反馈已学习该商户偏好，增强用户信任感。
    if (confidence < 0.5) {
      return const Padding(
        padding: EdgeInsets.only(top: AppTheme.spaceSmall),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppTheme.warningColor),
            SizedBox(width: AppTheme.spaceXSmall),
            Expanded(
              child: Text(
                '智能推断可能不准确，建议手动确认',
                style: TextStyle(
                  fontSize: AppTheme.textBodySmall,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (confidence >= 0.9) {
      return const Padding(
        padding: EdgeInsets.only(top: AppTheme.spaceSmall),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppTheme.successColor),
            SizedBox(width: AppTheme.spaceXSmall),
            Expanded(
              child: Text(
                '已学习该商户的分类偏好',
                style: TextStyle(
                  fontSize: AppTheme.textBodySmall,
                  color: AppTheme.successColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  /// 构建忽略按钮
  Widget _buildDiscardButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      onPressed: () async {
        HapticFeedback.lightImpact();
        await Provider.of<AutoAccountingProvider>(context, listen: false)
            .discardTransaction(widget.pending.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已忽略'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppTheme.neutral700 : AppTheme.neutral100,
        foregroundColor: isDark ? AppTheme.neutral200 : AppTheme.neutral600,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        textStyle: const TextStyle(
          fontSize: AppTheme.textBodyLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('忽略'),
    );
  }

  /// 构建确认记账按钮（带渐变背景）
  Widget _buildConfirmButton() {
    final primaryGradient = AppTheme.getPrimaryGradient(context);

    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: ElevatedButton(
        onPressed: () async {
          if (_selectedCategory.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('请选择分类'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 1),
              ),
            );
            return;
          }
          if (_selectedAccount.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('请选择账户'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 1),
              ),
            );
            return;
          }

          HapticFeedback.mediumImpact();
          final noteText = _noteController.text.trim();
          final result =
              await Provider.of<AutoAccountingProvider>(context, listen: false)
                  .confirmTransaction(
            widget.pending.id,
            category: _selectedCategory,
            account: _selectedAccount,
            note: noteText.isEmpty ? null : noteText,
            amount: _effectiveAmount,
          );

          if (mounted) {
            if (result != null) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已记账: ${widget.pending.merchant ?? '支出'}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('记账失败，请重试'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 1),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 20),
            const SizedBox(width: AppTheme.spaceXSmall),
            Text(
              '确认记账 ¥${formatAmount(_effectiveAmount)}',
              style: const TextStyle(
                fontSize: AppTheme.textBodyLarge,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.getPrimaryColor(context);
    final confidenceHint = _buildConfidenceHint();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.neutral800 : AppTheme.neutral0,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXXLarge),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppTheme.spaceLarge,
              right: AppTheme.spaceLarge,
              bottom: AppTheme.spaceXLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceMedium,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSmall,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSourceColor(widget.pending.source),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        widget.pending.sourceDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.textLabelMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: Text(
                        '检测到支付',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(widget.pending.paymentTime),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  ),
                  color: primaryColor.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceXLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '支付金额',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.neutral500,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSmall),
                            // WHY: 提示用户金额可点击修改
                            const Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: AppTheme.neutral400,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceSmall),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '¥',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              // WHY: 金额改为可编辑 TextField，
                              // 让用户在分类预测错误或金额识别错误时手动修改
                              child: TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  // WHY: 触发重建以更新确认按钮上的金额显示
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                Row(
                  children: [
                    const Icon(
                      Icons.store_outlined,
                      size: 18,
                      color: AppTheme.neutral400,
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Expanded(
                      child: Text(
                        widget.pending.merchant ?? '未知商户',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '分类',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                _buildCategorySelector(),
                if (confidenceHint != null) confidenceHint,
                const SizedBox(height: AppTheme.spaceXLarge),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '账户',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                _buildAccountSelector(),
                const SizedBox(height: AppTheme.spaceXLarge),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '备注',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutral500,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                TextFormField(
                  controller: _noteController,
                  maxLength: 50,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: '添加备注（可选）',
                    counterText: '',
                    filled: true,
                    fillColor:
                        isDark ? AppTheme.neutral700 : AppTheme.neutral100,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMedium,
                      vertical: AppTheme.spaceMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                Row(
                  children: [
                    Expanded(child: _buildDiscardButton()),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(flex: 2, child: _buildConfirmButton()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

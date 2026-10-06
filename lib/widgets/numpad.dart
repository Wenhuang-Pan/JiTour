import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

typedef OnNumberPressed = void Function(String number);
typedef OnDeletePressed = void Function();
typedef OnSavePressed = void Function();
typedef OnSaveAndAddPressed = void Function();

/// 现代化自定义数字键盘
/// 扁平化设计 + 流畅动画 + 触感反馈
class Numpad extends StatefulWidget {
  final OnNumberPressed onNumberPressed;
  final OnDeletePressed onDeletePressed;
  final OnSavePressed onSavePressed;
  final OnSaveAndAddPressed? onSaveAndAddPressed;
  final bool canSave;
  final TextEditingController? noteController;
  final String? selectedAccountName;
  final VoidCallback? onAccountTap;
  final VoidCallback? onDateTap;
  final VoidCallback? onReimbursedTap;
  final bool isReimbursed;
  final VoidCallback? onCouponTap;
  final String? couponText;
  final VoidCallback? onTagTap;
  final String? tagText;
  final String? timeText;
  final VoidCallback? onLocationTap;
  final String? locationText;

  /// 保存按钮的自定义文案，未指定时默认为"保存"
  final String? saveButtonText;

  const Numpad({
    super.key,
    required this.onNumberPressed,
    required this.onDeletePressed,
    required this.onSavePressed,
    this.onSaveAndAddPressed,
    this.canSave = true,
    this.noteController,
    this.selectedAccountName,
    this.onAccountTap,
    this.onDateTap,
    this.onReimbursedTap,
    this.isReimbursed = false,
    this.onCouponTap,
    this.couponText,
    this.onTagTap,
    this.tagText,
    this.timeText,
    this.onLocationTap,
    this.locationText,
    this.saveButtonText,
  });

  @override
  State<Numpad> createState() => _NumpadState();
}

class _NumpadState extends State<Numpad> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spaceXSmall),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildNoteSection(),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildOptionsRow(),
            const SizedBox(height: AppTheme.spaceSmall),
            const Divider(height: 1, thickness: 0.5),
            _buildKeyboardSection(),
            const SizedBox(height: AppTheme.spaceSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMedium,
        vertical: AppTheme.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded,
              color: AppTheme.neutral500, size: 20),
          const SizedBox(width: AppTheme.spaceSmall),
          Expanded(
            child: TextField(
              controller: widget.noteController,
              decoration: const InputDecoration(
                hintText: '添加备注...',
                hintStyle: TextStyle(
                  color: AppTheme.neutral400,
                  fontSize: AppTheme.textBodyMedium,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              style: const TextStyle(
                fontSize: AppTheme.textBodyMedium,
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsRow() {
    return Container(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMedium),
        children: [
          _buildOptionButton(
            icon: Icons.account_balance_wallet_rounded,
            label: widget.selectedAccountName ?? '账户',
            onTap: widget.onAccountTap,
          ),
          const SizedBox(width: 4),
          _buildOptionButton(
            icon: Icons.access_time_rounded,
            label: widget.timeText ?? '今天',
            onTap: widget.onDateTap,
          ),
          const SizedBox(width: 4),
          _buildOptionButton(
            icon: Icons.receipt_rounded,
            label: widget.isReimbursed ? '已报销' : '报销',
            isActive: widget.isReimbursed,
            activeColor: AppTheme.successColor,
            onTap: widget.onReimbursedTap,
          ),
          const SizedBox(width: 4),
          _buildOptionButton(
            icon: Icons.tag_rounded,
            label: widget.tagText ?? '标签',
            onTap: widget.onTagTap,
          ),
          const SizedBox(width: 4),
          _buildOptionButton(
            icon: Icons.percent_rounded,
            label: widget.couponText ?? '优惠',
            onTap: widget.onCouponTap,
          ),
          const SizedBox(width: 4),
          _buildOptionButton(
            icon: Icons.location_on_rounded,
            label: widget.locationText ?? '位置',
            onTap: widget.onLocationTap,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color activeColor = AppTheme.primaryColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 11,
                color: isActive ? activeColor : AppTheme.neutral500,
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isActive ? activeColor : AppTheme.neutral500,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
      child: Column(
        children: [
          _buildKeyboardRow(['1', '2', '3', 'del'], isLast: false),
          const SizedBox(height: AppTheme.spaceSmall),
          _buildKeyboardRow(['4', '5', '6', '+'], isLast: false),
          const SizedBox(height: AppTheme.spaceSmall),
          _buildKeyboardRow(['7', '8', '9', '-'], isLast: false),
          const SizedBox(height: AppTheme.spaceSmall),
          _buildKeyboardRow(['more', '0', '.', 'save'], isLast: true),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys, {required bool isLast}) {
    return Row(
      children: List.generate(keys.length, (index) {
        final key = keys[index];
        final isEdge = index == 0 || index == keys.length - 1;
        return Expanded(
          flex: isEdge ? 14 : 12,
          child: _buildKey(key),
        );
      }).separate((index) => const SizedBox(width: AppTheme.spaceSmall)),
    );
  }

  Widget _buildKey(String key) {
    if (key == 'del') return _buildDeleteButton();
    if (key == '+') return _buildFunctionKey('+', AppTheme.successColor);
    if (key == '-') return _buildFunctionKey('-', AppTheme.errorColor);
    if (key == 'save') return _buildSaveButton();
    if (key == 'more') return _buildSaveAndAddButton();
    return _buildNumberButton(key);
  }

  Widget _buildNumberButton(String text) {
    return _NumpadKey(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNumberPressed(text);
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return _NumpadKey(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onDeletePressed();
      },
      backgroundColor: AppTheme.getSecondaryBackground(context),
      child: const Icon(
        Icons.backspace_outlined,
        size: 22,
        color: AppTheme.neutral600,
      ),
    );
  }

  Widget _buildFunctionKey(String symbol, Color color) {
    return _NumpadKey(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNumberPressed(symbol);
      },
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return _NumpadKey(
      onTap: widget.canSave
          ? () {
              HapticFeedback.mediumImpact();
              widget.onSavePressed();
            }
          : null,
      backgroundColor:
          widget.canSave ? AppTheme.primaryColor : AppTheme.neutral300,
      boxShadow:
          widget.canSave ? AppTheme.glowShadow(AppTheme.primaryColor) : null,
      child: Text(
        widget.saveButtonText ?? '保存',
        style: const TextStyle(
          fontSize: AppTheme.textTitleSmall,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildSaveAndAddButton() {
    // WHY: 编辑模式下不传 onSaveAndAddPressed，此处直接占位空容器，
    // 让"保存"按钮占满整行，避免视觉错位
    if (widget.onSaveAndAddPressed == null) {
      return const SizedBox.shrink();
    }
    return _NumpadKey(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSaveAndAddPressed?.call();
      },
      backgroundColor: AppTheme.getSecondaryBackground(context),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_rounded,
            size: 16,
            color: AppTheme.neutral600,
          ),
          Text(
            '再记',
            style: TextStyle(
              fontSize: AppTheme.textLabelMedium,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 数字键组件 - 统一外观
class _NumpadKey extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  const _NumpadKey({
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// List 元素之间的间距工具扩展
extension _ListSeparators<T extends Widget> on Iterable<T> {
  List<Widget> separate(Widget Function(int) separator) {
    final list = toList();
    final result = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i < list.length - 1) {
        result.add(separator(i));
      }
    }
    return result;
  }
}

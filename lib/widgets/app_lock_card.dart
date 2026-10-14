import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';

/// 设置页「应用锁」开关卡片
///
/// 开启与关闭前均需先通过身份验证，防止他人拿到已解锁手机后篡改开关。
class AppLockCard extends StatefulWidget {
  const AppLockCard({super.key});

  @override
  State<AppLockCard> createState() => _AppLockCardState();
}

class _AppLockCardState extends State<AppLockCard> {
  bool _enabled = AppLockService.isEnabled;

  /// 是否正在验证中，期间禁用开关防止重复触发
  bool _busy = false;

  /// 处理开关切换：先验证设备能力与身份，通过后持久化开关状态
  ///
  /// @param value 目标开关状态（true 开启 / false 关闭）
  /// @return 无
  Future<void> _toggle(bool value) async {
    if (_busy) return;

    // WHY: 开启前先确认设备具备验证能力（生物识别或锁屏凭据），
    // 否则开启后用户可能永远无法通过验证，导致无法进入应用
    if (value && !await AppLockService.canAuthenticate()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设备不支持生物识别，请先在系统中设置锁屏密码或录入指纹'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final success = await AppLockService.authenticate(
      reason: value ? '验证身份以开启应用锁' : '验证身份以关闭应用锁',
    );
    if (!mounted) return;

    if (success) {
      await AppLockService.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '应用锁已开启' : '应用锁已关闭'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // WHY: 验证未通过时开关保持原状，仅提示，不改变持久化状态
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('验证未通过，操作已取消'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXSmall),
              decoration: BoxDecoration(
                color:
                    AppTheme.getPrimaryColor(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.lock_rounded,
                color: AppTheme.getPrimaryColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '应用锁',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _enabled ? '已开启 · 启动时需验证身份' : '开启后启动应用需验证身份',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _enabled,
              onChanged: _busy ? null : _toggle,
            ),
          ],
        ),
      ),
    );
  }
}

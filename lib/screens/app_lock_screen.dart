import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';

/// 应用锁屏页面
///
/// 应用锁开启后，在应用启动或从后台恢复时展示，
/// 验证通过后通过 [onUnlocked] 回调切换到主界面。
class AppLockScreen extends StatefulWidget {
  /// 验证通过后的解锁回调
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  /// 是否正在等待系统验证结果，防止生命周期重建导致重复拉起验证弹窗
  bool _authenticating = false;

  /// 上一轮验证是否失败（用于展示重试提示文案）
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // WHY: 首帧渲染完成后自动拉起系统验证弹窗，无需用户手动点击
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  /// 发起身份验证，成功后回调解锁，失败则展示重试入口
  ///
  /// @return 无
  Future<void> _authenticate() async {
    // WHY: 验证弹窗期间 app 可能发生 inactive/resumed 切换触发重建，
    // 防重入避免同时弹出多个系统验证框
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });

    final success = await AppLockService.authenticate(reason: '验证身份以解锁记途');

    if (!mounted) return;
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _authenticating = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // WHY: canPop: false 拦截系统返回键，防止未验证绕过锁屏页
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 48,
                    color: AppTheme.getPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                Text(
                  '记途已锁定',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Text(
                  _failed ? '验证失败，请重试' : '使用指纹、人脸或锁屏密码解锁',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _failed
                            ? AppTheme.errorColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceXXLarge),
                // WHY: 验证弹窗拉起期间隐藏按钮，避免用户误以为未响应而重复点击
                if (!_authenticating)
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('点击解锁'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

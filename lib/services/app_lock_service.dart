import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用锁服务
///
/// 负责应用锁开关的持久化与身份验证（指纹/人脸，或回落设备 PIN/图案/密码）。
/// Web 平台不支持生物识别，所有方法均安全降级，不会抛出平台异常。
class AppLockService {
  /// SharedPreferences 中开关状态的存储键
  static const String _keyEnabled = 'app_lock_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

  /// 内存中的开关缓存，随 [init] 加载、[setEnabled] 更新
  static bool _enabled = false;

  /// 当前应用锁是否已开启
  static bool get isEnabled => _enabled;

  /// 初始化：从 SharedPreferences 加载开关状态
  ///
  /// @return 无
  /// @throws 不抛出异常，读取失败时保持默认关闭
  static Future<void> init() async {
    // WHY: Web 平台无生物识别能力，直接保持关闭，避免插件调用抛 MissingPluginException
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? false;
    } catch (e) {
      debugPrint('AppLockService init 失败: $e');
      _enabled = false;
    }
  }

  /// 设置应用锁开关并持久化
  ///
  /// @param value true 开启，false 关闭
  /// @return 无
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  /// 检查设备是否支持身份验证（生物识别或已设置设备锁屏凭据）
  ///
  /// @return true 表示设备可发起验证
  static Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (e) {
      // WHY: 插件不可用（如单元测试环境）时视为不支持，安全降级
      debugPrint('AppLockService canAuthenticate 失败: $e');
      return false;
    }
  }

  /// 发起身份验证
  ///
  /// 优先使用指纹/人脸等生物识别，失败后或不可用时回落到
  /// 设备 PIN/图案/密码（biometricOnly: false）。
  ///
  /// @param reason 显示在系统验证弹窗中的说明文案
  /// @return true 验证通过；false 验证失败、用户取消或平台不支持
  static Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // WHY: 允许回落到设备 PIN/图案/密码，满足"指纹/PIN"双重解锁需求
        biometricOnly: false,
        // WHY: 验证期间切到后台再回到前台时插件自动重试，
        // 避免用户返回后验证框消失必须手动点击重试
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      // WHY: 用户取消或系统异常（PlatformException）均视为未通过，不向上抛出
      debugPrint('AppLockService authenticate 失败: $e');
      return false;
    }
  }
}

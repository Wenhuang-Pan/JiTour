import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../models/parsed_payment.dart';
import '../models/pending_transaction.dart';
import 'notification_parser_service.dart';

/// 通知桥接服务
///
/// WHY: 封装 Android 原生 EventChannel/MethodChannel 通信，
/// 将原生侧的 [NotificationListenerService] 接收到的支付通知
/// 转换为 [ParsedPayment] 事件流供 Flutter 业务层订阅。
///
/// 在 Web/iOS 平台上方法调用会静默失败，事件流为空。
class NotificationBridgeService {
  NotificationBridgeService._();

  /// EventChannel 名称
  static const String _eventChannelName = 'jitu.auto_accounting/events';

  /// MethodChannel 名称
  static const String _methodChannelName = 'jitu.auto_accounting/methods';

  /// Launch MethodChannel 名称
  ///
  /// WHY: 独立通道用于查询 Intent extra 中的 overlay 结果，
  /// 避免与事件/方法通道混用导致时序问题。
  static const String _launchChannelName = 'jitu.auto_accounting/launch';

  static const EventChannel _eventChannel = EventChannel(_eventChannelName);
  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static const MethodChannel _launchChannel = MethodChannel(_launchChannelName);

  /// 内部控制器，用于合并原生事件和 mock 事件
  static final StreamController<ParsedPayment> _controller =
      StreamController<ParsedPayment>.broadcast();

  /// Overlay 悬浮窗结果事件控制器
  ///
  /// WHY: 当用户在原生悬浮窗点击"确认记账"或"忽略"时，原生层通过
  /// EventChannel 推送结果，此控制器广播供 AutoAccountingProvider 订阅。
  static final StreamController<Map<String, dynamic>> _overlayResultController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 是否已初始化监听
  static bool _initialized = false;

  /// 支付事件流
  ///
  /// WHY: 业务层通过订阅此流接收支付通知解析结果。
  /// 使用 broadcast 允许多个监听者。
  ///
  /// @return 支付事件 Stream
  static Stream<ParsedPayment> get paymentStream {
    _ensureInitialized();
    return _controller.stream;
  }

  /// Overlay 悬浮窗结果事件流
  ///
  /// 当用户在原生悬浮窗点击"确认记账"或"忽略"时，原生层通过 EventChannel
  /// 推送结果，此 Stream 广播这些事件供 AutoAccountingProvider 订阅。
  ///
  /// @return Overlay 结果事件 Stream
  static Stream<Map<String, dynamic>> get overlayResultStream {
    _ensureInitialized();
    return _overlayResultController.stream;
  }

  /// 确保事件流已初始化
  ///
  /// WHY: 延迟初始化，避免在 Web 平台调用原生通道报错。
  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // WHY: Web 平台不注册原生监听，避免 MissingPluginException
    if (kIsWeb) return;

    _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        _handleNativeEvent(event);
      },
      onError: (Object error) {
        debugPrint('[NotificationBridge] 事件流错误: $error');
      },
    );
  }

  /// 处理原生事件
  ///
  /// WHY: 区分两种事件类型：
  /// - 有 `action` 字段：Overlay 悬浮窗的结果回调（confirm/ignore），
  ///   直接转发到 [overlayResultStream]；
  /// - 无 `action` 字段：普通支付通知事件，由 [NotificationParserService]
  ///   解析后推送到 [paymentStream]。
  ///
  /// @param event 原生侧传递的 Map 数据
  static void _handleNativeEvent(dynamic event) {
    try {
      if (event is! Map) return;
      final map = Map<String, dynamic>.from(event);

      // WHY: 区分两种事件类型
      // - 有 action 字段：Overlay 悬浮窗的结果回调（confirm/ignore）
      // - 无 action 字段：普通支付通知事件，由 Parser 解析后推送
      if (map.containsKey('action')) {
        _overlayResultController.add(map);
      } else {
        final packageName = map['packageName'] as String? ?? '';
        final text = map['combined'] as String? ?? '';
        // WHY: 调用解析服务提取金额和商户
        final parsed = NotificationParserService.parse(text, packageName);
        if (parsed != null) {
          _controller.add(parsed);
        }
      }
    } catch (e) {
      debugPrint('[NotificationBridge] 事件处理异常: $e');
    }
  }

  /// 检查通知监听器是否已启用
  ///
  /// @return true 表示用户已授权通知监听权限
  static Future<bool> isListenerEnabled() async {
    if (kIsWeb) return false;
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] 检查监听器状态失败: $e');
      return false;
    }
  }

  /// 打开系统通知监听设置页
  ///
  /// WHY: 用户必须在此页面手动授权通知监听权限。
  ///
  /// @return true 表示成功跳转
  static Future<bool> openNotificationSettings() async {
    if (kIsWeb) return false;
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('openNotificationSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] 打开通知设置失败: $e');
      return false;
    }
  }

  /// 推送分类列表到原生层缓存
  ///
  /// WHY: OverlayService 显示悬浮窗时需要分类列表渲染 Chip，
  /// Flutter 启动时调用此方法将最新分类推给原生层。
  ///
  /// @param categories 分类名列表
  static Future<void> pushCategories(List<String> categories) async {
    if (kIsWeb) return;
    try {
      final list = categories.map((String name) => {'name': name}).toList();
      await _methodChannel.invokeMethod('pushCategories', list);
      debugPrint('[NotificationBridge] pushCategories 成功: ${list.length} 个分类');
    } catch (e) {
      debugPrint('[NotificationBridge] pushCategories 失败: $e');
    }
  }

  /// 推送账户列表到原生层缓存
  ///
  /// WHY: OverlayService 显示悬浮窗时需要账户列表渲染 Chip，
  /// Flutter 启动时调用此方法将最新账户推给原生层。
  ///
  /// @param accounts 账户名列表
  static Future<void> pushAccounts(List<String> accounts) async {
    if (kIsWeb) return;
    try {
      final list = accounts.map((String name) => {'name': name}).toList();
      await _methodChannel.invokeMethod('pushAccounts', list);
      debugPrint('[NotificationBridge] pushAccounts 成功: ${list.length} 个账户');
    } catch (e) {
      debugPrint('[NotificationBridge] pushAccounts 失败: $e');
    }
  }

  /// 查询悬浮窗权限是否已授权
  ///
  /// WHY: Android 通过 SYSTEM_ALERT_WINDOW 权限控制悬浮窗，
  /// Web/iOS 平台不支持，返回 false。
  ///
  /// @return 已授权返回 true，未授权或当前平台不支持返回 false
  static Future<bool> isOverlayEnabled() async {
    if (kIsWeb) return false;
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isOverlayEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] isOverlayEnabled 失败: $e');
      return false;
    }
  }

  /// 跳转系统悬浮窗权限设置页
  ///
  /// WHY: 用户必须在此页面手动授权悬浮窗权限。
  ///
  /// @return 成功跳转返回 true，失败或当前平台不支持返回 false
  static Future<bool> openOverlaySettings() async {
    if (kIsWeb) return false;
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] openOverlaySettings 失败: $e');
      return false;
    }
  }

  /// 查询 POST_NOTIFICATIONS 权限是否已授权
  ///
  /// WHY: Android 13+ 需运行时请求通知权限，否则前台 Service 通知无法显示，
  /// 系统可能在 1 分钟后杀死 OverlayService。Android 13 以下直接返回 true。
  ///
  /// @return 已授权返回 true，未授权或当前平台不支持返回 false
  static Future<bool> isPostNotificationsGranted() async {
    if (kIsWeb) return false;
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('isPostNotificationsGranted');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] isPostNotificationsGranted 失败: $e');
      return false;
    }
  }

  /// 请求 POST_NOTIFICATIONS 运行时权限
  ///
  /// WHY: Android 13+ 必须运行时请求通知权限。调用后系统会弹出权限对话框。
  /// 由于请求是异步的，此方法返回 false 不代表用户拒绝，需配合
  /// [isPostNotificationsGranted] 在 onResume 时刷新状态。
  ///
  /// @return 已授权返回 true，未授权或异步请求中返回 false
  static Future<bool> requestPostNotifications() async {
    if (kIsWeb) return false;
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('requestPostNotifications');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationBridge] requestPostNotifications 失败: $e');
      return false;
    }
  }

  /// 获取启动数据（来自 Intent extra 的 overlay 结果）
  ///
  /// WHY: 当应用被杀，用户在悬浮窗操作后，原生层通过 Intent extra
  /// 传递数据并启动 MainActivity。Flutter 启动后调用此方法获取数据。
  ///
  /// @return 启动数据 Map，无数据返回 null
  static Future<Map<String, dynamic>?> getLaunchData() async {
    if (kIsWeb) return null;
    try {
      final result = await _launchChannel.invokeMethod('getLaunchData');
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map<dynamic, dynamic>);
    } catch (e) {
      debugPrint('[NotificationBridge] getLaunchData 失败: $e');
      return null;
    }
  }

  /// 清除启动数据
  ///
  /// WHY: 处理完 Intent extra 中的 overlay 结果后必须清除，
  /// 避免下次启动时重复处理。
  static Future<void> clearLaunchData() async {
    if (kIsWeb) return;
    try {
      await _launchChannel.invokeMethod('clearLaunchData');
    } catch (e) {
      debugPrint('[NotificationBridge] clearLaunchData 失败: $e');
    }
  }

  /// 注入 mock 支付事件（用于测试）
  ///
  /// WHY: 开发调试用，无需真实支付即可测试 UI 和状态管理。
  ///
  /// @param amount 金额
  /// @param merchant 商户名
  /// @param source 支付来源
  static void injectMockPayment({
    required Decimal amount,
    String? merchant,
    PaymentSource source = PaymentSource.alipay,
  }) {
    _ensureInitialized();
    _controller.add(ParsedPayment(
      amount: amount,
      merchant: merchant,
      source: source,
      rawText: '[MOCK] $merchant $amount',
      timestamp: DateTime.now(),
    ));
  }
}

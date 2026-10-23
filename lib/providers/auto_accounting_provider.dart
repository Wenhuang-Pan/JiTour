import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../models/parsed_payment.dart';
import '../models/pending_transaction.dart';
import '../models/transaction.dart';
import '../services/account_service.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/notification_bridge_service.dart';
import '../services/overlay_result_service.dart';
import '../services/pending_transaction_service.dart';
import '../services/category_inference_service.dart';

/// 支付通知自动记账状态管理
///
/// 管理自动记账开关、通知监听权限状态、待确认交易列表，
/// 订阅支付通知事件流并处理新支付的分类推断与持久化。
class AutoAccountingProvider extends ChangeNotifier {
  /// 自动记账功能开关
  bool _isEnabled = true;

  /// 通知监听权限是否已授权（仅 Android，Web/未初始化时为 false）
  bool _isListenerAuthorized = false;

  /// 无障碍服务（支付页面识别）是否已授权（仅 Android）
  bool _isAccessibilityAuthorized = false;

  /// 悬浮窗权限是否已授权（仅 Android，Web/iOS 永远为 false）
  bool _isOverlayAuthorized = false;

  /// POST_NOTIFICATIONS 权限是否已授权（Android 13+ 必需）
  bool _isPostNotificationsGranted = false;

  /// 待确认交易列表（状态=PendingStatus.pending，按 createdAt 倒序）
  List<PendingTransaction> _pendingList = <PendingTransaction>[];

  /// 订阅 NotificationBridgeService.paymentStream
  StreamSubscription<ParsedPayment>? _paymentSubscription;

  /// 订阅 NotificationBridgeService.overlayResultStream
  StreamSubscription<Map<String, dynamic>>? _overlaySubscription;

  /// 是否已初始化，避免重复订阅
  bool _initialized = false;

  /// 获取自动记账功能是否开启
  bool get isEnabled => _isEnabled;

  /// 获取通知监听权限是否已授权
  bool get isListenerAuthorized => _isListenerAuthorized;

  /// 获取无障碍服务（支付页面识别）是否已授权
  bool get isAccessibilityAuthorized => _isAccessibilityAuthorized;

  /// 获取悬浮窗权限是否已授权
  bool get isOverlayAuthorized => _isOverlayAuthorized;

  /// 获取 POST_NOTIFICATIONS 权限是否已授权
  bool get isPostNotificationsGranted => _isPostNotificationsGranted;

  /// 获取待确认交易列表（不可修改视图）
  List<PendingTransaction> get pendingList => List.unmodifiable(_pendingList);

  /// 获取待确认交易数量
  int get pendingCount => _pendingList.length;

  /// 是否存在待确认交易
  bool get hasPending => _pendingList.isNotEmpty;

  /// 初始化自动记账状态
  ///
  /// 从 Hive 读取偏好设置、加载待确认列表、同步监听权限状态、
  /// 订阅支付事件流。重复调用安全，内部已去重。
  ///
  /// @return Future 完成初始化
  Future<void> init() async {
    if (_initialized) return;

    // WHY: 从 auto_accounting_prefs box 读取开关，默认开启
    _isEnabled = DatabaseService.autoAccountingPrefs.get(
      'isEnabled',
      defaultValue: true,
    ) as bool;

    _loadPendingList();

    // WHY: 同步 Android 通知监听授权状态，Web 平台直接返回 false
    _isListenerAuthorized = await NotificationBridgeService.isListenerEnabled();

    // WHY: 同步无障碍服务授权状态（支付页面识别补充通道）
    _isAccessibilityAuthorized =
        await NotificationBridgeService.isAccessibilityEnabled();

    _subscribePaymentStream();
    _subscribeOverlayStream();

    // WHY: 启动时推送分类和账户列表到原生层，供 OverlayService 悬浮窗使用
    await _pushCacheToNative();
    // WHY: 查询悬浮窗权限状态（仅 Android 有意义，Web/iOS 返回 false）
    _isOverlayAuthorized = await NotificationBridgeService.isOverlayEnabled();

    // WHY: 查询并请求 POST_NOTIFICATIONS 权限（Android 13+ 必需）
    // 未授权时自动请求，授权后才能显示前台 Service 通知保活 OverlayService
    _isPostNotificationsGranted =
        await NotificationBridgeService.isPostNotificationsGranted();
    if (!_isPostNotificationsGranted) {
      await NotificationBridgeService.requestPostNotifications();
      // WHY: 请求是异步的，立即查询一次状态（用户可能已快速响应）
      _isPostNotificationsGranted =
          await NotificationBridgeService.isPostNotificationsGranted();
    }

    _initialized = true;
    notifyListeners();

    // WHY: 启动补录兜底——headless 引擎落库失败时，悬浮窗确认/pending 数据
    // 滞留在原生 SharedPreferences 补录队列；此处读取并处理，确保用户确认过
    // 的记账最终落地。原生侧读取即清空，不会重复处理。
    final drained = await NotificationBridgeService.drainPendingOverlayResults();
    for (final Map<String, dynamic> data in drained) {
      await _handleOverlayResult(data);
    }
    if (drained.isNotEmpty) {
      debugPrint('[AutoAccounting] 启动补录完成: ${drained.length} 条');
    }
  }

  /// 订阅支付事件流
  ///
  /// WHY: 重复调用前先取消旧订阅，避免同一事件被多次处理。
  void _subscribePaymentStream() {
    _paymentSubscription?.cancel();
    _paymentSubscription =
        NotificationBridgeService.paymentStream.listen((ParsedPayment payment) {
      _handleNewPayment(payment);
    }, onError: (Object error) {
      debugPrint('[AutoAccounting] 支付事件流错误: $error');
    });
  }

  /// 订阅 Overlay 悬浮窗结果事件流
  ///
  /// WHY: 当 Flutter 在前台/后台 attached 时，原生悬浮窗的结果通过
  /// EventChannel 推送，此处订阅并转交 [_handleOverlayResult] 处理。
  void _subscribeOverlayStream() {
    _overlaySubscription?.cancel();
    _overlaySubscription = NotificationBridgeService.overlayResultStream.listen(
        (Map<String, dynamic> data) {
      _handleOverlayResult(data);
    }, onError: (Object error) {
      debugPrint('[AutoAccounting] Overlay 事件流错误: $error');
    });
  }

  /// 推送分类和账户列表到原生层缓存
  ///
  /// WHY: OverlayService 显示悬浮窗时需要分类和账户列表渲染 Chip，
  /// Flutter 启动时调用此方法将最新数据推给原生层。
  Future<void> _pushCacheToNative() async {
    try {
      final categories = CategoryService.getExpenseCategories();
      final categoryNames = categories.map((c) => c.name).toList();
      await NotificationBridgeService.pushCategories(categoryNames);

      final accounts = AccountService.getActiveAccounts();
      final accountNames = accounts.map((a) => a.name).toList();
      await NotificationBridgeService.pushAccounts(accountNames);

      debugPrint('[AutoAccounting] 缓存推送完成: ${categoryNames.length} 分类, '
          '${accountNames.length} 账户');
    } catch (e) {
      debugPrint('[AutoAccounting] 缓存推送失败: $e');
    }
  }

  /// 刷新悬浮窗权限状态
  ///
  /// WHY: 用户从系统设置返回后调用，重新检查授权状态。
  ///
  /// @return Future 完成刷新
  Future<void> refreshOverlayStatus() async {
    _isOverlayAuthorized = await NotificationBridgeService.isOverlayEnabled();
    notifyListeners();
    debugPrint('[AutoAccounting] 悬浮窗权限状态: $_isOverlayAuthorized');
  }

  /// 刷新 POST_NOTIFICATIONS 权限状态
  ///
  /// WHY: 用户从系统权限对话框或设置页返回后调用，重新检查授权状态。
  ///
  /// @return Future 完成刷新
  Future<void> refreshPostNotificationsStatus() async {
    _isPostNotificationsGranted =
        await NotificationBridgeService.isPostNotificationsGranted();
    notifyListeners();
    debugPrint(
        '[AutoAccounting] POST_NOTIFICATIONS 权限状态: $_isPostNotificationsGranted');
  }

  /// 处理原生悬浮窗的结果回调
  ///
  /// WHY: 事件可能来自两个渠道——EventChannel 推送（应用在后台但引擎活着）
  /// 与启动补录队列（headless 引擎失败时的兜底）。落库逻辑统一在
  /// OverlayResultService（与 headless 引擎共用），本方法只负责调用后
  /// 刷新 UI 状态。
  ///
  /// @param data Overlay 结果数据，含 action/amount/merchant/category/account/rawText
  Future<void> _handleOverlayResult(Map<String, dynamic> data) async {
    await OverlayResultService.handle(data);

    // WHY: 落库后统一重载待确认列表驱动 UI 刷新（confirm 移除记录、
    // pending 新增记录均由此覆盖），与逐条 removeWhere/insert 等价且更简单
    _loadPendingList();
    notifyListeners();
  }

  /// 处理新的支付通知事件
  ///
  /// WHY: 功能未启用时直接跳过，节省推断与持久化开销。
  ///
  /// @param payment 解析后的支付信息
  /// @return Future 完成处理
  Future<void> _handleNewPayment(ParsedPayment payment) async {
    if (!_isEnabled) return;

    // WHY: 跨通道去重兜底——原生侧已按「包名+金额」15 秒窗口统一去重，
    // 但进程重启后原生去重表清空，且同一笔支付的通知与无障碍事件可能
    // 在窗口边界先后到达。此处再查最近 15 秒内是否已有同金额同来源的记录
    // （含已确认/已忽略），命中即丢弃，杜绝重复弹窗与重复记账。
    // 时间复杂度：O(n)，n 为历史待确认记录数（通常 < 100）
    final bool isDuplicate = PendingTransactionService.getAll().any(
      (PendingTransaction t) =>
          t.amount == payment.amount &&
          t.source == payment.source &&
          DateTime.now().difference(t.createdAt).inSeconds.abs() < 15,
    );
    if (isDuplicate) {
      debugPrint('[AutoAccounting] 重复支付事件被 Dart 侧去重: '
          '${payment.source} ¥${payment.amount}');
      return;
    }

    // WHY: 基于商户名推断分类，置信度低时上层 UI 会提示用户手动选择
    InferredCategory inferred =
        await CategoryInferenceService.infer(payment.merchant);

    // WHY: 商户推断未命中时，按支付类型关键词兜底——转账/红包等场景
    // 往往无商户名可学习，但页/通知文本含明确类型词；
    // 仅当用户分类表中存在同名分类时才采用，避免推断出不存在的分类
    if (inferred.categoryName == null) {
      inferred = _inferByPaymentType(payment);
    }

    final PendingTransaction pending = await PendingTransactionService.create(
      amount: payment.amount,
      source: payment.source,
      rawText: payment.rawText,
      merchant: payment.merchant,
      inferredCategory: inferred.categoryName,
      confidence: inferred.confidence,
      isIncome: payment.isIncome,
    );

    // WHY: 新记录插入列表头部，保证最新的在最前面
    _pendingList.insert(0, pending);
    notifyListeners();
  }

  /// 按支付类型关键词兜底推断分类
  ///
  /// WHY: 转账/红包等场景没有商户名可供学习，但通知或页面文本包含
  /// 明确的类型词；按收支方向取对应分类表，命中同名分类才采用，
  /// 置信度 0.6（低于商户学习的 0.9，UI 仍会提示用户确认）。
  /// 时间复杂度：O(k·m)，k 为关键词数（常量级），m 为用户分类数
  ///
  /// @param payment 解析后的支付信息
  /// @return 推断结果，未命中返回空分类
  InferredCategory _inferByPaymentType(ParsedPayment payment) {
    const List<String> typeKeywords = <String>['转账', '红包', '退款', '扫码'];
    final categories = payment.isIncome
        ? CategoryService.getIncomeCategories()
        : CategoryService.getExpenseCategories();
    for (final keyword in typeKeywords) {
      if (!payment.rawText.contains(keyword)) continue;
      final hit = categories.where((c) => c.name.contains(keyword)).firstOrNull;
      if (hit != null) {
        return InferredCategory(hit.name, 0.6);
      }
    }
    return const InferredCategory(null, 0.0);
  }

  /// 从服务层加载待确认交易到内存
  ///
  /// WHY: PendingTransactionService.getPending() 已按 createdAt 倒序，
  /// 直接赋值即可。
  void _loadPendingList() {
    _pendingList = PendingTransactionService.getPending();
  }

  /// 确认待确认交易，转正为正式交易
  ///
  /// @param pendingId 待确认交易 ID
  /// @param category 用户最终选择的分类
  /// @param account 账户名
  /// @param note 备注（可选）
  /// @param amount 用户修改后的金额（可选，未传则使用 pending 原金额）
  /// @return 创建的正式 Transaction，失败返回 null
  Future<Transaction?> confirmTransaction(
    String pendingId, {
    required String category,
    required String account,
    String? note,
    Decimal? amount,
  }) async {
    final Transaction? result = await PendingTransactionService.confirm(
      pendingId,
      category: category,
      account: account,
      note: note,
      amount: amount,
    );

    if (result != null) {
      _pendingList.removeWhere((PendingTransaction t) => t.id == pendingId);
      notifyListeners();
    }

    return result;
  }

  /// 丢弃待确认交易
  ///
  /// @param pendingId 待确认交易 ID
  /// @return Future 完成丢弃
  Future<void> discardTransaction(String pendingId) async {
    await PendingTransactionService.discard(pendingId);
    _pendingList.removeWhere((PendingTransaction t) => t.id == pendingId);
    notifyListeners();
  }

  /// 设置自动记账功能开关
  ///
  /// @param value true 开启，false 关闭
  /// @return Future 完成持久化
  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    await DatabaseService.autoAccountingPrefs.put('isEnabled', value);
    notifyListeners();
  }

  /// 刷新通知监听权限状态
  ///
  /// WHY: 用户从系统设置页返回后需重新检查授权状态。
  ///
  /// @return Future 完成刷新
  Future<void> refreshListenerStatus() async {
    _isListenerAuthorized = await NotificationBridgeService.isListenerEnabled();
    notifyListeners();
  }

  /// 刷新无障碍服务授权状态
  ///
  /// WHY: 用户从系统无障碍设置页返回后调用，重新检查授权状态。
  ///
  /// @return Future 完成刷新
  Future<void> refreshAccessibilityStatus() async {
    _isAccessibilityAuthorized =
        await NotificationBridgeService.isAccessibilityEnabled();
    notifyListeners();
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _overlaySubscription?.cancel();
    super.dispose();
  }
}

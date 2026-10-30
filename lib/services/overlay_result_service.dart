import 'package:flutter/foundation.dart';
import '../models/pending_transaction.dart';
import '../services/pending_transaction_service.dart';
import '../services/notification_parser_service.dart';
import '../utils/decimal_util.dart';

/// 悬浮窗事件落库服务（无 UI 依赖）
///
/// WHY: 悬浮窗/无障碍事件的处理逻辑需要被两个环境复用——
/// 1. 主引擎：AutoAccountingProvider（EventChannel 路径 + 启动补录兜底）；
/// 2. headless 引擎：main.dart 的 `overlayHeadlessMain` 入口（应用被杀时
///    原生创建无界面引擎立即后台落库）。
/// 服务层不依赖 Provider/UI 状态，保证 headless 场景可直接调用；
/// UI 状态刷新由调用方（Provider）在 handle 完成后统一处理。
class OverlayResultService {
  OverlayResultService._();

  /// 处理一条悬浮窗事件并落库。
  ///
  /// WHY: 三分支纯数据操作——confirm 创建 pending 记录并立即转正、
  /// pending 创建待确认记录（15 秒去重兜底防双通道重复）、
  /// ignore 创建后标记丢弃（保留审计痕迹）。
  ///
  /// @param data 事件数据，含 action/amount/merchant/category/account/rawText/isIncome。
  static Future<void> handle(Map<String, dynamic> data) async {
    final action = data['action'] as String? ?? '';
    final amount = parseDecimal(data['amount']);
    final merchant = data['merchant'] as String? ?? '';
    final category = data['category'] as String?;
    final account = data['account'] as String?;
    final rawText = data['rawText'] as String? ?? '';
    // WHY: 收支方向由原生侧（通知监听/无障碍服务）识别后透传，
    // 缺失时按支出处理，与历史版本行为一致
    final isIncome = data['isIncome'] as bool? ?? false;
    // WHY: 来源由原生侧透传的包名决定，不能靠商户名里是否含「微信」猜测，
    // 否则银行/其他渠道会被错误归类（v3.4.2 新增银行消息通道）
    final packageName = data['packageName'] as String? ?? '';
    final PaymentSource source =
        NotificationParserService.sourceForPackage(packageName);

    debugPrint('[OverlayResult] 处理事件: action=$action, amount=$amount, '
        'merchant=$merchant, isIncome=$isIncome');

    if (action == 'confirm') {
      // WHY: 悬浮窗确认后，创建待确认交易并立即转正
      if (category == null ||
          category.isEmpty ||
          account == null ||
          account.isEmpty) {
        debugPrint('[OverlayResult] 确认失败: 分类或账户为空');
        return;
      }
      try {
        final pending = await PendingTransactionService.create(
          amount: amount,
          source: source,
          rawText: rawText,
          merchant: merchant.isEmpty ? null : merchant,
          inferredCategory: category,
          confidence: 0.95,
          isIncome: isIncome,
        );
        final result = await PendingTransactionService.confirm(
          pending.id,
          category: category,
          account: account,
        );
        debugPrint('[OverlayResult] 确认${result != null ? '成功' : '失败'}');
      } catch (e) {
        debugPrint('[OverlayResult] 确认异常: $e');
      }
    } else if (action == 'pending') {
      // WHY: 悬浮窗权限未授权时的回退路径：创建待确认交易等待用户手动处理。
      // 与支付事件流同构的去重兜底——通知与无障碍双通道可能各触发一次
      // pending，15 秒内同金额同来源记录已存在时直接丢弃
      final bool isDuplicate = PendingTransactionService.getAll().any(
        (PendingTransaction t) =>
            t.amount == amount &&
            t.source == source &&
            DateTime.now().difference(t.createdAt).inSeconds.abs() < 15,
      );
      if (isDuplicate) {
        debugPrint('[OverlayResult] 重复 pending 事件被去重: '
            '$source ¥$amount');
        return;
      }
      try {
        final pending = await PendingTransactionService.create(
          amount: amount,
          source: source,
          rawText: rawText,
          merchant: merchant.isEmpty ? null : merchant,
          isIncome: isIncome,
        );
        debugPrint('[OverlayResult] pending 创建成功: ${pending.id}');
      } catch (e) {
        debugPrint('[OverlayResult] pending 创建异常: $e');
      }
    } else if (action == 'ignore') {
      // WHY: 悬浮窗忽略后，创建待确认交易并标记为 discarded（审计痕迹）
      try {
        final pending = await PendingTransactionService.create(
          amount: amount,
          source: source,
          rawText: rawText,
          merchant: merchant.isEmpty ? null : merchant,
          isIncome: isIncome,
        );
        await PendingTransactionService.discard(pending.id);
        debugPrint('[OverlayResult] 忽略成功');
      } catch (e) {
        debugPrint('[OverlayResult] 忽略异常: $e');
      }
    }
  }
}

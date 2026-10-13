import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auto_accounting_provider.dart';
import '../services/notification_bridge_service.dart';
import '../theme/app_theme.dart';
import 'merchant_rule_editor_screen.dart';
import 'pending_transactions_screen.dart';

/// 自动记账设置页面
///
/// 提供自动记账功能开关、通知监听权限管理、待确认记录入口
/// 以及工作原理说明。
///
/// WHY: 需要在用户从系统通知设置页返回后刷新授权状态，故使用
/// StatefulWidget 以便在 [State.didChangeAppLifecycleState] 之外
/// 通过 postFrameCallback 触发状态刷新。
class AutoAccountingSettingsScreen extends StatefulWidget {
  /// 构造自动记账设置页面
  ///
  /// @param key 用于控件标识的可选键
  const AutoAccountingSettingsScreen({super.key});

  @override
  State<AutoAccountingSettingsScreen> createState() =>
      _AutoAccountingSettingsScreenState();
}

class _AutoAccountingSettingsScreenState
    extends State<AutoAccountingSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动记账'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle(context, '功能'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildFeatureToggleCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            // WHY: 通知权限相关仅 Android 需要，Web/iOS 平台直接跳过该 section
            if (!kIsWeb) ...<Widget>[
              _buildSectionTitle(context, '通知权限'),
              const SizedBox(height: AppTheme.spaceSmall),
              _buildNotificationPermissionCard(context),
              const SizedBox(height: AppTheme.spaceMedium),
              _buildPostNotificationsCard(context),
              const SizedBox(height: AppTheme.spaceLarge),
            ],
            // WHY: 悬浮窗权限仅 Android 需要，授权后应用在后台检测到支付通知
            // 会显示原生悬浮窗，用户可直接在悬浮窗完成记账
            if (!kIsWeb) ...<Widget>[
              _buildSectionTitle(context, '悬浮窗'),
              const SizedBox(height: AppTheme.spaceSmall),
              _buildOverlayPermissionCard(context),
              const SizedBox(height: AppTheme.spaceLarge),
            ],
            _buildSectionTitle(context, '待确认'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildPendingCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '规则'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildMerchantRuleCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '说明'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildHowItWorksCard(context),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
    );
  }

  /// 构建 section 标题
  ///
  /// @param context 构建上下文
  /// @param title 标题文本
  /// @return 标题 Text 组件
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  /// 构建功能开关卡片（Section 1）
  ///
  /// @param context 构建上下文
  /// @return 功能开关 Container
  Widget _buildFeatureToggleCard(BuildContext context) {
    return Consumer<AutoAccountingProvider>(
      builder: (BuildContext context, AutoAccountingProvider provider,
          Widget? child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.getPrimaryColor(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '自动记账',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '支付后自动弹窗记录',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutral500,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isEnabled,
                  onChanged: (bool value) => provider.setEnabled(value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建通知监听权限卡片（Section 2，仅非 Web 平台显示）
  ///
  /// @param context 构建上下文
  /// @return 通知权限 Container
  Widget _buildNotificationPermissionCard(BuildContext context) {
    return Consumer<AutoAccountingProvider>(
      builder: (BuildContext context, AutoAccountingProvider provider,
          Widget? child) {
        final bool isAuthorized = provider.isListenerAuthorized;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.notifications_active_rounded,
                  color: isAuthorized
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                title: const Text('通知监听权限'),
                subtitle: Text(
                  isAuthorized ? '已授权' : '未授权，点击前往系统设置开启',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAuthorized
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.neutral400,
                ),
                onTap: () async {
                  final bool ok = await NotificationBridgeService
                      .openNotificationSettings();
                  if (!context.mounted) return;
                  if (ok) {
                    // WHY: 用户从系统设置返回后，需重新检查授权状态。
                    // 使用 addPostFrameCallback 避免在 build 期间触发 Provider 更新。
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Provider.of<AutoAccountingProvider>(context,
                                listen: false)
                            .refreshListenerStatus();
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('当前平台不支持通知监听'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                child: Text(
                  '记途需要「通知使用权」才能在支付宝或微信支付后自动识别金额和商户。授权后，您的支付数据仅在本地处理，不会上传到任何服务器。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建悬浮窗权限卡片（仅 Android 显示）
  ///
  /// WHY: Web/iOS 不支持悬浮窗权限，调用前已通过 `if (!kIsWeb)` 过滤。
  ///
  /// @param context 构建上下文
  /// @return 悬浮窗权限 Container
  Widget _buildOverlayPermissionCard(BuildContext context) {
    return Consumer<AutoAccountingProvider>(
      builder: (BuildContext context, AutoAccountingProvider provider,
          Widget? child) {
        final bool isAuthorized = provider.isOverlayAuthorized;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: isAuthorized
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                title: const Text('悬浮窗权限'),
                subtitle: Text(
                  isAuthorized ? '已授权' : '未授权，点击前往系统设置开启',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAuthorized
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.neutral400,
                ),
                onTap: () async {
                  final bool ok =
                      await NotificationBridgeService.openOverlaySettings();
                  if (!context.mounted) return;
                  if (ok) {
                    // WHY: 用户从系统设置返回后，需重新检查授权状态。
                    // 使用 addPostFrameCallback 避免在 build 期间触发 Provider 更新。
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Provider.of<AutoAccountingProvider>(context,
                                listen: false)
                            .refreshOverlayStatus();
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('当前平台不支持悬浮窗'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLarge,
                  0,
                  AppTheme.spaceLarge,
                  AppTheme.spaceMedium,
                ),
                child: Text(
                  '授权后，应用在后台时检测到支付通知会显示悬浮窗，可直接在悬浮窗完成记账，无需打开应用。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建待确认记录卡片（Section 3）
  ///
  /// @param context 构建上下文
  /// @return 待确认记录 Container
  Widget _buildPendingCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Consumer<AutoAccountingProvider>(
        builder: (BuildContext context, AutoAccountingProvider provider,
            Widget? child) {
          final int pendingCount = provider.pendingCount;
          return ListTile(
            leading: Icon(
              Icons.pending_actions_rounded,
              color: AppTheme.getPrimaryColor(context),
            ),
            title: const Text('待确认记录'),
            subtitle: Text(
              pendingCount > 0 ? '$pendingCount 条待确认' : '无待确认记录',
            ),
            trailing: pendingCount > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceXSmall),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.neutral400,
                      ),
                    ],
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.neutral400,
                  ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PendingTransactionsScreen(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 构建 POST_NOTIFICATIONS 权限卡片
  ///
  /// WHY: Android 13+ 需运行时请求通知权限，授权后前台 Service 通知才能显示，
  /// 系统不会因通知不可见而杀死 OverlayService。未授权时显示醒目警告。
  ///
  /// @param context 构建上下文
  /// @return 权限卡片 Container，已授权时返回紧凑状态卡片
  Widget _buildPostNotificationsCard(BuildContext context) {
    return Consumer<AutoAccountingProvider>(
      builder: (BuildContext context, AutoAccountingProvider provider,
          Widget? child) {
        final bool granted = provider.isPostNotificationsGranted;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.notifications_active_rounded,
                  color:
                      granted ? AppTheme.successColor : AppTheme.warningColor,
                ),
                title: const Text('通知显示权限'),
                subtitle: Text(
                  granted ? '已授权' : '未授权，后台悬浮窗服务可能被系统杀死',
                  style: TextStyle(
                    color:
                        granted ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
                trailing: granted
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppTheme.successColor, size: 20)
                    : const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningColor, size: 24),
                onTap: granted
                    ? null
                    : () async {
                        await NotificationBridgeService
                            .requestPostNotifications();
                        if (context.mounted) {
                          Provider.of<AutoAccountingProvider>(context,
                                  listen: false)
                              .refreshPostNotificationsStatus();
                        }
                      },
              ),
              if (!granted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLarge,
                    0,
                    AppTheme.spaceLarge,
                    AppTheme.spaceMedium,
                  ),
                  child: Text(
                    'Android 13+ 需授权通知显示权限以保证后台悬浮窗服务稳定运行。'
                    '点击上方卡片授权。',
                    style: TextStyle(
                      color: AppTheme.neutral500,
                      fontSize: AppTheme.textBodySmall,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建商户规则入口卡片（Section "规则"）
  ///
  /// 跳转到商户规则编辑器，管理商户名与分类的映射规则。
  ///
  /// @param context 构建上下文
  /// @return 商户规则入口 Container
  Widget _buildMerchantRuleCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: Icon(
          Icons.rule_rounded,
          color: AppTheme.getPrimaryColor(context),
        ),
        title: const Text('商户规则'),
        subtitle: Text(
          '管理商户名与分类的映射规则',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.neutral500,
              ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.neutral400,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MerchantRuleEditorScreen(),
            ),
          );
        },
      ),
    );
  }

  /// 构建工作原理说明卡片（Section 4）
  ///
  /// @param context 构建上下文
  /// @return 工作原理 Container
  Widget _buildHowItWorksCard(BuildContext context) {
    const List<String> steps = <String>[
      '支付宝/微信支付后，系统会推送支付通知',
      '记途自动解析通知中的金额和商户名',
      '智能匹配可能的分类（已学习的商户会自动套用）',
      '弹出快速记账弹窗，您确认后即记录为正式交易',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: AppTheme.getPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Text(
                    steps[i],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          // WHY: 改用 onSurfaceVariant，暗色模式下自动变为浅灰
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            // WHY: 仅在步骤之间添加间距，最后一步后单独加间距到提示文字
            if (i < steps.length - 1)
              const SizedBox(height: AppTheme.spaceMedium),
          ],
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '提示：所有数据仅在本地处理，不上传任何服务器。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
          ),
        ],
      ),
    );
  }
}

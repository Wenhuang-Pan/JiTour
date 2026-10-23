import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/auto_accounting_provider.dart';
import '../services/ai_config_service.dart';
import '../services/update_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/update_checker.dart';
import '../widgets/app_lock_card.dart';
import '../widgets/ai_config_dialog.dart';
import 'reminder_settings_screen.dart';
import 'auto_accounting_settings_screen.dart';
import 'recycle_bin_screen.dart';
import 'template_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, '外观'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildThemeModeCard(context, themeProvider),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildThemeColorCard(context, themeProvider),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '币种'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildCurrencyCard(context, currencyProvider),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '数据'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildDataCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '提醒'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildReminderCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, '自动记账'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildAutoAccountingCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildSectionTitle(context, 'AI 助手'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildAiAssistantCard(context),
            const SizedBox(height: AppTheme.spaceLarge),
            // WHY: 应用锁依赖 local_auth 原生插件，Web 平台不支持，隐藏整个安全区块
            if (!kIsWeb) ...[
              _buildSectionTitle(context, '安全'),
              const SizedBox(height: AppTheme.spaceSmall),
              const AppLockCard(),
              const SizedBox(height: AppTheme.spaceLarge),
            ],
            _buildSectionTitle(context, '关于'),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildAboutCard(context),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _buildThemeModeCard(BuildContext context, ThemeProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSmall),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    color: AppTheme.getPrimaryColor(context),
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Text(
                  '主题模式',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Row(
              children: ThemeModeOption.values.map((mode) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => provider.setThemeMode(mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceSmall),
                      margin:
                          const EdgeInsets.only(right: AppTheme.spaceXSmall),
                      decoration: BoxDecoration(
                        color: provider.themeMode == mode
                            ? AppTheme.getPrimaryColor(context)
                                .withValues(alpha: 0.10)
                            : AppTheme.getSecondaryBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: provider.themeMode == mode
                              ? AppTheme.getPrimaryColor(context)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        provider.getThemeModeName(mode),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: provider.themeMode == mode
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: provider.themeMode == mode
                              ? AppTheme.getPrimaryColor(context)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorCard(BuildContext context, ThemeProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSmall),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.color_lens_rounded,
                    color: AppTheme.successColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Text(
                  '主题颜色',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Row(
              children: ThemeColorOption.values.map((color) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => provider.setThemeColor(color),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: provider.primaryColor ==
                                    provider.getThemeColorOptionColor(color)
                                ? provider.getThemeColorOptionColor(color)
                                : provider
                                    .getThemeColorOptionColor(color)
                                    .withValues(alpha: 0.30),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: provider.themeColor == color
                                  ? provider.getThemeColorOptionColor(color)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: provider.themeColor == color
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        Text(
                          provider.getThemeColorName(color),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(BuildContext context, CurrencyProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSmall),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: AppTheme.warningColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Text(
                  '币种设置',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Row(
              children: CurrencyOption.values.map((currency) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => provider.setCurrency(currency),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceSmall),
                      margin:
                          const EdgeInsets.only(right: AppTheme.spaceXSmall),
                      decoration: BoxDecoration(
                        color: provider.currency == currency
                            ? AppTheme.getPrimaryColor(context)
                                .withValues(alpha: 0.10)
                            : AppTheme.getSecondaryBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: provider.currency == currency
                              ? AppTheme.getPrimaryColor(context)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            provider.getCurrencySymbol(currency),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: provider.currency == currency
                                  ? AppTheme.getPrimaryColor(context)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                          Text(
                            currency.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildDataItem(
            context,
            icon: Icons.upload_file_rounded,
            iconColor: AppTheme.getPrimaryColor(context),
            title: '导入数据',
            subtitle: '从CSV文件导入记账数据',
            onTap: () {
              Navigator.pushNamed(context, '/import');
            },
          ),
          const Divider(height: 1, indent: 60),
          _buildDataItem(
            context,
            icon: Icons.download_rounded,
            iconColor: AppTheme.successColor,
            title: '导出数据',
            subtitle: '将数据导出为CSV文件',
            onTap: () {
              Navigator.pushNamed(context, '/export');
            },
          ),
          const Divider(height: 1, indent: 60),
          _buildDataItem(
            context,
            icon: Icons.bookmark_border_rounded,
            iconColor: AppTheme.getPrimaryColor(context),
            title: '账单模板',
            subtitle: '常用交易存为模板，一键填充',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplateManagementScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 60),
          _buildDataItem(
            context,
            icon: Icons.auto_delete_outlined,
            iconColor: AppTheme.warningColor,
            title: '回收站',
            subtitle: '恢复或彻底删除已删交易',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecycleBinScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 60),
          _buildDataItem(
            context,
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.errorColor,
            title: '清除所有数据',
            subtitle: '谨慎操作，此操作不可撤销',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  title: const Text('确认清除'),
                  content: const Text('确定要清除所有数据吗？此操作不可撤销。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () async {
                        // 清除所有数据
                        await DatabaseService.transactions.clear();
                        await DatabaseService.budgets.clear();
                        await DatabaseService.accounts.clear();
                        await DatabaseService.tags.clear();
                        await DatabaseService.savingsGoals.clear();
                        await DatabaseService.categories.clear();

                        // WHY: 异步清除数据后需校验 context 是否仍然挂载，避免使用已销毁的上下文
                        if (!context.mounted) return;
                        Navigator.pop(context);

                        // 显示成功提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('数据已清除'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor),
                      child: const Text('确认清除'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSmall),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXSmall),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: AppTheme.spaceSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildAboutItem(
            context,
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.getPrimaryColor(context),
            title: '版本信息',
            subtitle: '当前版本 v${UpdateService.getVersion()}，点击检查更新',
            onTap: () => _checkForUpdate(context, ignoreSkip: true),
          ),
          const Divider(height: 1, indent: 60),
          _buildAboutItem(
            context,
            icon: Icons.code_rounded,
            iconColor: AppTheme.successColor,
            title: '关于应用',
            subtitle: '记途 - 记录每一笔，走向财务自由的旅途',
            showArrow: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXSmall),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow && onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context,
      {bool ignoreSkip = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('正在检查更新...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    final updateInfo = await UpdateService.checkForUpdate(
        ignoreSkip: ignoreSkip, forceRefresh: true);

    if (!context.mounted) return;

    scaffoldMessenger.hideCurrentSnackBar();

    if (updateInfo != null) {
      UpdateCheckerWidget.showUpdateDialog(context, updateInfo);
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('当前已是最新版本'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildReminderCard(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, reminderProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildReminderItem(
                context,
                icon: Icons.notifications_rounded,
                iconColor: AppTheme.successColor,
                title: '记账提醒',
                subtitle: reminderProvider.isEnabled
                    ? '${reminderProvider.getFrequencyLabel()} ${reminderProvider.getTimeLabel()}'
                    : '未开启',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReminderSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建自动记账设置卡片
  ///
  /// 复用 [_buildReminderItem] 通用列表项，展示自动记账开关状态与
  /// 待确认记录数量摘要，点击进入自动记账设置页。
  ///
  /// @param context 构建上下文
  /// @return 自动记账设置 Container
  Widget _buildAutoAccountingCard(BuildContext context) {
    return Consumer<AutoAccountingProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildReminderItem(
                context,
                icon: Icons.auto_awesome_rounded,
                iconColor: AppTheme.getPrimaryColor(context),
                title: '自动记账',
                subtitle: provider.isEnabled
                    ? (provider.pendingCount > 0
                        ? '已开启 · ${provider.pendingCount} 条待确认'
                        : '已开启')
                    : '未开启',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AutoAccountingSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXSmall),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建 AI 助手设置卡片
  ///
  /// WHY: 点击进入 API Key 配置弹窗，展示当前配置状态。
  ///
  /// @param context 构建上下文。
  /// @return AI 助手卡片 Widget。
  Widget _buildAiAssistantCard(BuildContext context) {
    final isConfigured = AiConfigService.isConfigured();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: _buildReminderItem(
        context,
        icon: Icons.auto_awesome_rounded,
        iconColor: AppTheme.getPrimaryColor(context),
        title: 'AI 账单分析',
        // WHY: 动态显示当前服务商与模型，方便用户确认配置是否生效
        subtitle: isConfigured
            ? '已配置 · ${AiConfigService.getProvider().name} · '
                '${AiConfigService.getModel()}'
            : '未配置 · 点击设置',
        onTap: () => _showAiConfigDialog(context),
      ),
    );
  }

  /// 显示 AI 服务商配置弹窗。
  ///
  /// WHY: 配置项（服务商 / Key / 模型 / 端点）统一由 AiConfigDialog 承载，
  /// 支持切换服务商与搜索模型，后续升级无需改设置页。
  ///
  /// @param context 构建上下文。
  Future<void> _showAiConfigDialog(BuildContext context) async {
    // WHY: 在 async 操作前获取 ScaffoldMessenger，避免跨 async gap 使用 BuildContext
    final messenger = ScaffoldMessenger.of(context);
    final bool? saved = await AiConfigDialog.show(context);
    if (saved != true || !context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已保存 · ${AiConfigService.getProvider().name} · '
          '${AiConfigService.getModel()}',
        ),
      ),
    );
    (context as Element).markNeedsBuild();
  }
}

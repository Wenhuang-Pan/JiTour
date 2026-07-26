import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../services/update_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/update_checker.dart';

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
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.10),
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
                                .withOpacity(0.10)
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
                    color: AppTheme.successColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
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
                                    .withOpacity(0.30),
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
                    color: AppTheme.warningColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
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
                                .withOpacity(0.10)
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
            onTap: () {},
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
                color: iconColor.withOpacity(0.10),
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
            subtitle: '当前版本 v${UpdateService.getVersion()}',
            onTap: () => _checkForUpdate(context, ignoreSkip: true),
          ),
          const Divider(height: 1, indent: 60),
          _buildAboutItem(
            context,
            icon: Icons.refresh_rounded,
            iconColor: AppTheme.warningColor,
            title: '检查更新',
            subtitle: '手动检查是否有新版本',
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
                color: iconColor.withOpacity(0.10),
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
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';

/// 记账提醒设置页面
class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reminderProvider = Provider.of<ReminderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记账提醒'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提醒开关
            _buildReminderToggle(context, reminderProvider),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 提醒时间设置
            _buildTimeSection(context, reminderProvider),
            const SizedBox(height: AppTheme.spaceXLarge),

            // 提醒频率设置
            _buildFrequencySection(context, reminderProvider),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
    );
  }

  /// 构建提醒开关卡片
  Widget _buildReminderToggle(
      BuildContext context, ReminderProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Icon(
                Icons.notifications_rounded,
                color: AppTheme.getPrimaryColor(context),
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.spaceLarge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '记账提醒',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.getReminderSummary(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: provider.isEnabled,
              onChanged: (value) => provider.setEnabled(value),
              activeThumbColor: AppTheme.getPrimaryColor(context),
              activeTrackColor:
                  AppTheme.getPrimaryColor(context).withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建提醒时间设置区域
  Widget _buildTimeSection(
      BuildContext context, ReminderProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '提醒时间'),
        const SizedBox(height: AppTheme.spaceMedium),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: AppTheme.neutral400,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spaceLarge),
                Expanded(
                  child: Text(
                    '设置每天提醒时间',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                InkWell(
                  onTap: () => _showTimePicker(context, provider),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMedium,
                      vertical: AppTheme.spaceSmall,
                    ),
                    child: Text(
                      provider.reminderTimeString,
                      style: TextStyle(
                        fontSize: AppTheme.textBodyLarge,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getPrimaryColor(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示时间选择器
  Future<void> _showTimePicker(
      BuildContext context, ReminderProvider provider) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: provider.hour, minute: provider.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              primary: AppTheme.getPrimaryColor(context),
              onPrimary: Colors.white,
              secondary: AppTheme.getPrimaryColor(context),
              onSecondary: Colors.white,
              surface: AppTheme.getCardColor(context),
              onSurface: Theme.of(context).colorScheme.onSurface,
              error: AppTheme.errorColor,
              onError: Colors.white,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await provider.setHour(picked.hour);
      await provider.setMinute(picked.minute);
    }
  }

  /// 构建提醒频率设置区域
  Widget _buildFrequencySection(
      BuildContext context, ReminderProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '提醒频率'),
        const SizedBox(height: AppTheme.spaceMedium),

        // 频率选择
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(
            children: [
              _buildFrequencyOption(
                context,
                provider,
                'daily',
                '每天',
                '每天固定时间提醒',
                Icons.calendar_today_rounded,
              ),
              const Divider(color: AppTheme.neutral200, height: 1),
              _buildFrequencyOption(
                context,
                provider,
                'weekly',
                '每周',
                '选择特定日期提醒',
                Icons.calendar_view_week_rounded,
              ),
              const Divider(color: AppTheme.neutral200, height: 1),
              _buildFrequencyOption(
                context,
                provider,
                'custom',
                '自定义',
                '选择每月特定日期',
                Icons.calendar_month_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),

        // 频率详情设置
        if (provider.frequency == 'weekly')
          _buildWeekdaySelector(context, provider),
        if (provider.frequency == 'custom')
          _buildCustomDaySelector(context, provider),
      ],
    );
  }

  /// 构建频率选项
  Widget _buildFrequencyOption(
    BuildContext context,
    ReminderProvider provider,
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = provider.frequency == value;

    return InkWell(
      onTap: () => provider.setFrequency(value),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.12)
                    : AppTheme.neutral100,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                icon,
                color:
                    isSelected ? AppTheme.getPrimaryColor(context) : AppTheme.neutral400,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTheme.spaceLarge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.neutral200,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建每周日期选择器
  Widget _buildWeekdaySelector(
      BuildContext context, ReminderProvider provider) {
    final weekdays = [1, 2, 3, 4, 5, 6, 7];
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择提醒日期',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Wrap(
              spacing: AppTheme.spaceSmall,
              runSpacing: AppTheme.spaceSmall,
              children: weekdays.map((day) {
                final isSelected = provider.weekdays.contains(day);
                return InkWell(
                  onTap: () {
                    final newWeekdays = List<int>.from(provider.weekdays);
                    if (isSelected) {
                      newWeekdays.remove(day);
                    } else {
                      newWeekdays.add(day);
                    }
                    provider.setWeekdays(newWeekdays..sort());
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMedium,
                      vertical: AppTheme.spaceSmall,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Text(
                      weekdayNames[day - 1],
                      style: TextStyle(
                        fontSize: AppTheme.textBodySmall,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.neutral600,
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

  /// 构建自定义日期选择器
  Widget _buildCustomDaySelector(
      BuildContext context, ReminderProvider provider) {
    final days = List.generate(31, (index) => index + 1);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择提醒日期',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Wrap(
              spacing: AppTheme.spaceSmall,
              runSpacing: AppTheme.spaceSmall,
              children: days.map((day) {
                final isSelected = provider.customDays.contains(day);
                return InkWell(
                  onTap: () {
                    final newDays = List<int>.from(provider.customDays);
                    if (isSelected) {
                      newDays.remove(day);
                    } else {
                      newDays.add(day);
                    }
                    provider.setCustomDays(newDays..sort());
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: AppTheme.textBodySmall,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.neutral600,
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

  /// 构建区域标题
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

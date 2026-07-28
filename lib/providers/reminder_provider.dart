import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 记账提醒设置状态管理
/// 管理提醒开关、提醒时间、提醒频率等设置
class ReminderProvider extends ChangeNotifier {
  /// 提醒是否开启
  bool _isEnabled = false;

  /// 提醒时间（小时）
  int _hour = 20;

  /// 提醒时间（分钟）
  int _minute = 0;

  /// 提醒频率（daily: 每天, weekly: 每周, custom: 自定义日期）
  String _frequency = 'daily';

  /// 每周提醒的日期（1-7 表示周一到周日）
  List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];

  /// 自定义提醒日期（每月的几号）
  List<int> _customDays = [1, 15];

  /// 最后一次提醒时间
  DateTime? _lastReminderTime;

  /// 是否显示过提醒
  bool _hasShownToday = false;

  /// Hive box 名称
  static const String _boxName = 'reminder_settings';

  /// 初始化提醒设置
  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    _isEnabled = box.get('isEnabled', defaultValue: false);
    _hour = box.get('hour', defaultValue: 20);
    _minute = box.get('minute', defaultValue: 0);
    _frequency = box.get('frequency', defaultValue: 'daily');
    _weekdays =
        (box.get('weekdays') as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];
    _customDays = (box.get('customDays') as List?)?.cast<int>() ?? [1, 15];
    final lastReminder = box.get('lastReminderTime');
    if (lastReminder != null) {
      _lastReminderTime = DateTime.parse(lastReminder);
    }
    _hasShownToday = _isToday(_lastReminderTime);
    notifyListeners();
  }

  /// 判断日期是否是今天
  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// 获取提醒是否开启
  bool get isEnabled => _isEnabled;

  /// 设置提醒开关
  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final box = await Hive.openBox(_boxName);
    await box.put('isEnabled', value);
    notifyListeners();
  }

  /// 获取提醒时间（小时）
  int get hour => _hour;

  /// 设置提醒时间（小时）
  Future<void> setHour(int value) async {
    _hour = value;
    final box = await Hive.openBox(_boxName);
    await box.put('hour', value);
    notifyListeners();
  }

  /// 获取提醒时间（分钟）
  int get minute => _minute;

  /// 设置提醒时间（分钟）
  Future<void> setMinute(int value) async {
    _minute = value;
    final box = await Hive.openBox(_boxName);
    await box.put('minute', value);
    notifyListeners();
  }

  /// 获取提醒频率
  String get frequency => _frequency;

  /// 设置提醒频率
  Future<void> setFrequency(String value) async {
    _frequency = value;
    final box = await Hive.openBox(_boxName);
    await box.put('frequency', value);
    notifyListeners();
  }

  /// 获取每周提醒日期
  List<int> get weekdays => _weekdays;

  /// 设置每周提醒日期
  Future<void> setWeekdays(List<int> value) async {
    _weekdays = value;
    final box = await Hive.openBox(_boxName);
    await box.put('weekdays', value);
    notifyListeners();
  }

  /// 获取自定义提醒日期
  List<int> get customDays => _customDays;

  /// 设置自定义提醒日期
  Future<void> setCustomDays(List<int> value) async {
    _customDays = value;
    final box = await Hive.openBox(_boxName);
    await box.put('customDays', value);
    notifyListeners();
  }

  /// 获取提醒时间字符串
  String get reminderTimeString {
    return '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
  }

  /// 获取下一次提醒时间
  DateTime? getNextReminderTime() {
    if (!_isEnabled) return null;

    final now = DateTime.now();
    final todayReminder =
        DateTime(now.year, now.month, now.day, _hour, _minute);

    DateTime nextReminder;

    switch (_frequency) {
      case 'daily':
        nextReminder = todayReminder.isAfter(now)
            ? todayReminder
            : todayReminder.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextReminder = _getNextWeeklyReminder(now, todayReminder);
        break;
      case 'custom':
        nextReminder = _getNextCustomReminder(now, todayReminder);
        break;
      default:
        nextReminder = todayReminder.isAfter(now)
            ? todayReminder
            : todayReminder.add(const Duration(days: 1));
    }

    return nextReminder;
  }

  /// 获取下一次每周提醒时间
  DateTime _getNextWeeklyReminder(DateTime now, DateTime todayReminder) {
    // 按日期排序
    final sortedWeekdays = List<int>.from(_weekdays)..sort();

    // 查找今天之后的提醒日
    final todayWeekday = now.weekday;
    for (final day in sortedWeekdays) {
      if (day > todayWeekday) {
        return todayReminder.add(Duration(days: day - todayWeekday));
      }
    }

    // 如果今天是最后一个提醒日，返回下一周的第一个提醒日
    if (sortedWeekdays.isNotEmpty) {
      final daysUntilNext = 7 - todayWeekday + sortedWeekdays.first;
      return todayReminder.add(Duration(days: daysUntilNext));
    }

    return todayReminder.add(const Duration(days: 7));
  }

  /// 获取下一次自定义提醒时间
  DateTime _getNextCustomReminder(DateTime now, DateTime todayReminder) {
    // 按日期排序
    final sortedDays = List<int>.from(_customDays)..sort();

    // 查找本月剩余的提醒日
    final todayDay = now.day;
    for (final day in sortedDays) {
      if (day > todayDay) {
        return DateTime(now.year, now.month, day, _hour, _minute);
      }
    }

    // 如果本月没有提醒日了，查找下个月的提醒日
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    if (sortedDays.isNotEmpty) {
      return DateTime(
          nextMonth.year, nextMonth.month, sortedDays.first, _hour, _minute);
    }

    return todayReminder.add(const Duration(days: 15));
  }

  /// 检查是否应该显示提醒
  bool shouldShowReminder() {
    if (!_isEnabled) return false;
    if (_hasShownToday) return false;

    final now = DateTime.now();
    final todayReminder =
        DateTime(now.year, now.month, now.day, _hour, _minute);

    // 检查是否在提醒时间之后
    if (now.isAfter(todayReminder) || now.isAtSameMomentAs(todayReminder)) {
      // 检查频率是否匹配
      switch (_frequency) {
        case 'daily':
          return true;
        case 'weekly':
          return _weekdays.contains(now.weekday);
        case 'custom':
          return _customDays.contains(now.day);
        default:
          return true;
      }
    }

    return false;
  }

  /// 标记今天已显示过提醒
  Future<void> markReminderShown() async {
    _hasShownToday = true;
    _lastReminderTime = DateTime.now();
    final box = await Hive.openBox(_boxName);
    await box.put('lastReminderTime', _lastReminderTime!.toIso8601String());
    notifyListeners();
  }

  /// 重置今日提醒状态（用于测试）
  Future<void> resetTodayReminder() async {
    _hasShownToday = false;
    _lastReminderTime = null;
    final box = await Hive.openBox(_boxName);
    await box.delete('lastReminderTime');
    notifyListeners();
  }

  /// 获取频率显示名称
  String getFrequencyDisplayName() {
    switch (_frequency) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'custom':
        return '自定义';
      default:
        return '每天';
    }
  }

  /// 获取提醒设置摘要
  String getReminderSummary() {
    if (!_isEnabled) return '提醒已关闭';

    final time = reminderTimeString;

    switch (_frequency) {
      case 'daily':
        return '每天 $time';
      case 'weekly':
        final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final dayNames = _weekdays.map((d) => weekdayNames[d]).join('、');
        return '每周 $dayNames $time';
      case 'custom':
        return '每月 ${_customDays.join('、')}日 $time';
      default:
        return '每天 $time';
    }
  }

  /// 获取频率标签（用于设置页面显示）
  String getFrequencyLabel() {
    switch (_frequency) {
      case 'daily':
        return '每天';
      case 'weekly':
        final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final dayNames = _weekdays.map((d) => weekdayNames[d]).join('、');
        return '每周 $dayNames';
      case 'custom':
        return '每月 ${_customDays.join('、')}日';
      default:
        return '每天';
    }
  }

  /// 获取时间标签（用于设置页面显示）
  String getTimeLabel() {
    return '$_hour:${_minute.toString().padLeft(2, '0')}';
  }
}

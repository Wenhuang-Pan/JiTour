import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'backup_service.dart';

/// 自动备份服务
/// 
/// 功能：
/// - 定时自动备份（每天/每周/每月）
/// - 备份提醒通知
/// - 备份历史记录
class AutoBackupService {
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupFrequency = 'backup_frequency';
  static const String _keyLastBackupTime = 'last_backup_time';
  static const String _keyBackupHistory = 'backup_history';
  static const String _taskName = 'auto_backup_task';

  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  /// 初始化通知服务
  static Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 点击通知时的处理
      },
    );
  }

  /// 初始化后台任务
  static Future<void> initializeWorkmanager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// 后台任务调度器回调
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        // 执行备份
        final backupContent = await BackupService.createBackup();
        final file = await saveAutoBackup(backupContent);
        
        // 发送成功通知
        await showBackupSuccessNotification(file.path);
        
        return Future.value(true);
      } catch (e) {
        // 发送失败通知
        await showBackupFailedNotification(e.toString());
        return Future.value(false);
      }
    });
  }

  /// 是否开启自动备份
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoBackupEnabled) ?? false;
  }

  /// 设置自动备份开关
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, enabled);
    
    if (enabled) {
      await startAutoBackup();
    } else {
      await stopAutoBackup();
    }
  }

  /// 获取备份频率（天数）
  static Future<int> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBackupFrequency) ?? 7; // 默认每周
  }

  /// 设置备份频率
  static Future<void> setBackupFrequency(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBackupFrequency, days);
    
    // 重新启动自动备份
    if (await isAutoBackupEnabled()) {
      await stopAutoBackup();
      await startAutoBackup();
    }
  }

  /// 启动自动备份任务
  static Future<void> startAutoBackup() async {
    final frequency = await getBackupFrequency();
    
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15), // 最小间隔15分钟（实际执行频率由frequency控制）
      initialDelay: Duration.zero,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: true,
      ),
      inputData: {'frequency_days': frequency},
    );
  }

  /// 停止自动备份任务
  static Future<void> stopAutoBackup() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }

  /// 立即执行一次备份
  static Future<File?> performBackupNow() async {
    try {
      final backupContent = await BackupService.createBackup();
      final file = await saveAutoBackup(backupContent);
      
      // 记录备份时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastBackupTime, DateTime.now().toIso8601String());
      
      // 添加到备份历史
      await addToBackupHistory(file.path);
      
      return file;
    } catch (e) {
      return null;
    }
  }

  /// 保存自动备份文件
  static Future<File> saveAutoBackup(String content) async {
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final fileName = 'auto_backup_${dateFormat.format(DateTime.now())}.json';
    
    // 保存到应用外部存储目录（便于云盘同步）
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      // 如果外部存储不可用，使用内部存储
      final internalDir = await getApplicationDocumentsDirectory();
      final file = File('${internalDir.path}/backups/$fileName');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return file;
    }
    
    // 创建备份子目录
    final backupDir = Directory('${directory.path}/SimpleLedger_Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsString(content);
    
    return file;
  }

  /// 获取上次备份时间
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastBackupTime);
    if (timeStr == null) return null;
    return DateTime.parse(timeStr);
  }

  /// 获取备份历史列表
  static Future<List<String>> getBackupHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBackupHistory) ?? [];
  }

  /// 添加到备份历史
  static Future<void> addToBackupHistory(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getBackupHistory();
    history.insert(0, filePath); // 最新备份在前
    
    // 只保留最近20次备份记录
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    
    await prefs.setStringList(_keyBackupHistory, history);
  }

  /// 清理旧备份文件
  static Future<void> cleanupOldBackups({int keepCount = 10}) async {
    final history = await getBackupHistory();
    if (history.length <= keepCount) return;
    
    // 删除超出数量的旧备份
    final toDelete = history.skip(keepCount).toList();
    for (final path in toDelete) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除错误
      }
    }
    
    // 更新历史记录
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyBackupHistory, 
      history.take(keepCount).toList(),
    );
  }

  /// 显示备份成功通知
  static Future<void> showBackupSuccessNotification(String filePath) async {
    const androidDetails = AndroidNotificationDetails(
      'backup_channel',
      '备份通知',
      channelDescription: '数据自动备份通知',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: true,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      '自动备份完成',
      '数据已成功备份到：$filePath',
      details,
    );
  }

  /// 显示备份失败通知
  static Future<void> showBackupFailedNotification(String error) async {
    const androidDetails = AndroidNotificationDetails(
      'backup_channel',
      '备份通知',
      channelDescription: '数据自动备份通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      1,
      '自动备份失败',
      '备份过程中出现错误：$error',
      details,
    );
  }

  /// 检查备份状态并提醒
  static Future<void> checkBackupStatus() async {
    final lastBackup = await getLastBackupTime();
    if (lastBackup == null) {
      // 从未备份，提醒用户
      await showBackupReminderNotification('您从未备份过数据，建议立即备份');
      return;
    }
    
    final frequency = await getBackupFrequency();
    final daysSinceBackup = DateTime.now().difference(lastBackup).inDays;
    
    if (daysSinceBackup >= frequency) {
      await showBackupReminderNotification(
        '距上次备份已$daysSinceBackup天，建议立即备份'
      );
    }
  }

  /// 显示备份提醒通知
  static Future<void> showBackupReminderNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'backup_reminder_channel',
      '备份提醒',
      channelDescription: '数据备份提醒通知',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      2,
      '数据备份提醒',
      message,
      details,
    );
  }
}

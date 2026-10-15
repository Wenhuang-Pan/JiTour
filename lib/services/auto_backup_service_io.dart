import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';

/// 本地自动备份服务 —— IO 平台实现（Android/iOS/桌面）
///
/// WHY: 旧实现基于 workmanager 后台任务，部分 Android 设备上存在崩溃历史
/// （见 main.dart 禁用注释与项目教训），故改为与 WebDAV 自动备份一致的
/// 启动时惰性检查模式：App 启动后 fire-and-forget 调用
/// [performAutoBackupIfNeeded]，距上次备份超过频率天数才执行，
/// 失败仅记录日志，不影响启动。
///
/// 自动备份文件使用独立前缀 `jitu_auto_backup_`，与手动备份
/// （`jitu_backup_`）区分：轮转清理只作用于自动备份，避免误删用户手动
/// 创建的备份；两者同目录存储，备份管理页统一展示。
class AutoBackupService {
  AutoBackupService._();

  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupFrequency = 'backup_frequency';
  static const String _keyLastBackupTime = 'last_backup_time';

  /// 自动备份文件名前缀（与手动备份 `jitu_backup_` 区分）
  static const String autoBackupPrefix = 'jitu_auto_backup_';

  /// 自动备份保留份数，超出后按时间倒序删除最旧文件
  static const int _keepCount = 10;

  /// 是否开启自动备份
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoBackupEnabled) ?? false;
  }

  /// 设置自动备份开关
  ///
  /// @param enabled true 开启，false 关闭
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, enabled);
  }

  /// 获取备份频率（天数），默认 7 天
  static Future<int> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBackupFrequency) ?? 7;
  }

  /// 设置备份频率（天数）
  ///
  /// @param days 频率天数（1/7/30）
  static Future<void> setBackupFrequency(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBackupFrequency, days);
  }

  /// 获取上次备份时间，从未备份返回 null
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastBackupTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// 启动时惰性检查，距上次备份超过频率天数则自动执行一次备份
  ///
  /// WHY: fire-and-forget 设计，任何失败仅记录日志；
  /// 首次开启时 lastBackupTime 为 null，直接执行一次立即备份
  static Future<void> performAutoBackupIfNeeded() async {
    try {
      if (!await isAutoBackupEnabled()) return;
      final frequency = await getBackupFrequency();
      final lastTime = await getLastBackupTime();
      if (lastTime != null &&
          DateTime.now().difference(lastTime).inDays < frequency) {
        return;
      }
      final path = await performBackupNow();
      debugPrint('[AutoBackup] 惰性自动备份完成: $path');
    } catch (e) {
      // WHY: 启动路径上的备份失败绝不阻塞 App，仅记录日志
      debugPrint('[AutoBackup] 惰性自动备份失败: $e');
    }
  }

  /// 立即执行一次备份
  ///
  /// @return 备份文件路径；失败返回 null
  static Future<String?> performBackupNow() async {
    try {
      final content = await BackupService.createBackup();
      final file = await _saveToFile(content);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keyLastBackupTime, DateTime.now().toIso8601String());

      await _rotateBackups();
      return file.path;
    } catch (e) {
      debugPrint('[AutoBackup] 备份失败: $e');
      return null;
    }
  }

  /// 保存备份内容到应用文档目录（与手动备份同目录，独立前缀）
  static Future<File> _saveToFile(String content) async {
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final fileName = '$autoBackupPrefix${dateFormat.format(DateTime.now())}.json';
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  /// 轮转清理：自动备份文件按文件名倒序保留最近 [_keepCount] 份
  ///
  /// WHY: 文件名内嵌时间戳，按路径字符串排序即按时间排序；
  /// 只匹配自动备份前缀，绝不触碰用户手动创建的备份文件
  static Future<void> _rotateBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final autoBackups = directory
          .listSync()
          .where((f) =>
              f.path.endsWith('.json') && f.path.contains(autoBackupPrefix))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (autoBackups.length <= _keepCount) return;
      for (final stale in autoBackups.skip(_keepCount)) {
        await File(stale.path).delete();
        debugPrint('[AutoBackup] 轮转清理旧备份: ${stale.path}');
      }
    } catch (e) {
      debugPrint('[AutoBackup] 轮转清理失败: $e');
    }
  }
}

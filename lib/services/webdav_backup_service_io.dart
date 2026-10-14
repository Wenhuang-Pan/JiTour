import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'backup_service.dart';
import 'webdav_backup_types.dart';

/// WebDAV 云端备份服务（移动端/桌面端实现）
///
/// 功能：
/// - 服务器配置存取（SharedPreferences）
/// - 连接测试、上传、列表、下载恢复、删除
/// - 启动时按需静默自动备份（不使用 workmanager，避免部分设备崩溃）
class WebdavBackupService {
  static const String _keyUrl = 'webdav_url';
  static const String _keyUsername = 'webdav_username';
  static const String _keyPassword = 'webdav_password';
  static const String _keyEnabled = 'webdav_enabled';
  static const String _keyFrequencyDays = 'webdav_frequency_days';
  static const String _keyLastBackupTime = 'last_webdav_backup_time';

  /// 远端备份目录
  static const String remoteDirPath = '/jitu_backups/';

  /// 当前平台是否支持 WebDAV 备份
  static const bool isSupported = true;

  /// 读取服务器配置
  ///
  /// @return 已保存的配置；未配置时各字段为空字符串
  static Future<WebdavConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return WebdavConfig(
      url: prefs.getString(_keyUrl) ?? '',
      username: prefs.getString(_keyUsername) ?? '',
      password: prefs.getString(_keyPassword) ?? '',
    );
  }

  /// 保存服务器配置
  ///
  /// @param config 待保存的配置，地址与用户名会去首尾空格
  static Future<void> saveConfig(WebdavConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, config.url.trim());
    await prefs.setString(_keyUsername, config.username.trim());
    // WHY: 密码不做 trim，避免用户密码本身含首尾空格时被静默修改
    await prefs.setString(_keyPassword, config.password);
  }

  /// 测试服务器连接
  ///
  /// @param config 服务器配置（使用传入值而非已保存值，便于先测试后保存）
  /// @return 连接成功时正常返回
  /// @throws 连接失败、认证失败或地址非法时抛出异常，由调用方展示错误信息
  static Future<void> testConnection(WebdavConfig config) async {
    if (!config.isValid) {
      throw Exception('服务器地址不能为空');
    }
    final client = _newClient(config);
    await client.ping();
  }

  /// 创建本地备份并上传到 WebDAV 远端目录
  ///
  /// @return 上传成功的远端文件名
  /// @throws 未配置服务器、网络失败或服务端写入失败时抛出异常
  static Future<String> uploadBackup() async {
    final config = await getConfig();
    if (!config.isValid) {
      throw Exception('WebDAV 服务器未配置');
    }
    final client = _newClient(config);

    final content = await BackupService.createBackup();
    final bytes = Uint8List.fromList(utf8.encode(content));
    final fileName =
        'jitu_webdav_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    // WHY: 首次上传时目录可能不存在；mkdirAll 幂等创建，
    // 目录已存在时服务端返回 405，webdav_client 内部按成功处理
    await client.mkdirAll(remoteDirPath);
    await client.write('$remoteDirPath$fileName', bytes);

    await _recordBackupTime(DateTime.now());
    return fileName;
  }

  /// 列出远端备份文件，按修改时间倒序
  ///
  /// @return 备份文件列表；未配置服务器时返回空列表
  /// @throws 网络失败或服务端读取失败时抛出异常，由调用方展示错误信息
  static Future<List<WebdavBackupItem>> listBackups() async {
    final config = await getConfig();
    if (!config.isValid) return const [];

    final client = _newClient(config);
    // WHY: 从未备份过时目录不存在，部分服务端 readDir 会返回 404；
    // 先幂等创建目录，使“无备份”与“连接失败”可区分：前者返回空列表，后者抛异常
    await client.mkdirAll(remoteDirPath);

    final files = await client.readDir(remoteDirPath);
    final backups = files
        .where((f) => f.isDir == false && (f.name ?? '').endsWith('.json'))
        .map((f) {
      final name = f.name ?? '';
      // WHY: 不同服务端返回的 path 格式不一（href 解码差异），
      // 为空时兜底拼接目录+文件名，保证下载/删除可用
      final path = (f.path ?? '').isNotEmpty ? f.path! : '$remoteDirPath$name';
      return WebdavBackupItem(
        name: name,
        path: path,
        size: f.size ?? 0,
        modifiedAt: f.mTime,
      );
    }).toList();

    backups.sort((a, b) {
      final at = a.modifiedAt;
      final bt = b.modifiedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return backups;
  }

  /// 下载远端备份并恢复到本地数据库
  ///
  /// WHY: 恢复会清空并覆盖现有数据，调用方必须先经用户确认再调用
  /// @param remotePath 远端备份文件完整路径
  /// @return 备份内容解析恢复成功返回 true，格式非法返回 false
  /// @throws 网络失败或下载失败时抛出异常
  static Future<bool> restoreBackup(String remotePath) async {
    final config = await getConfig();
    if (!config.isValid) {
      throw Exception('WebDAV 服务器未配置');
    }
    final client = _newClient(config);

    final bytes = await client.read(remotePath);
    final content = utf8.decode(bytes);
    return BackupService.restoreBackup(content);
  }

  /// 删除远端备份文件
  ///
  /// @param remotePath 远端备份文件完整路径
  /// @throws 网络失败或服务端删除失败时抛出异常
  static Future<void> deleteBackup(String remotePath) async {
    final config = await getConfig();
    if (!config.isValid) {
      throw Exception('WebDAV 服务器未配置');
    }
    final client = _newClient(config);
    await client.remove(remotePath);
  }

  /// 是否开启 WebDAV 自动备份
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// 设置 WebDAV 自动备份开关
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  /// 获取自动备份频率（天数），默认每天
  static Future<int> getFrequencyDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFrequencyDays) ?? 1;
  }

  /// 设置自动备份频率（天数）
  static Future<void> setFrequencyDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFrequencyDays, days);
  }

  /// 获取上次 WebDAV 备份时间
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastBackupTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// 应用启动时按需静默执行自动备份
  ///
  /// WHY: 本地自动备份的 workmanager 方案在部分设备有崩溃史，
  /// WebDAV 改为启动时惰性检查（fire-and-forget）：
  /// 开启自动备份且距上次备份达到频率天数则静默上传，失败仅记录日志
  static Future<void> performAutoBackupIfNeeded() async {
    try {
      if (!await isAutoBackupEnabled()) return;

      final config = await getConfig();
      if (!config.isValid) return;

      final last = await getLastBackupTime();
      final frequency = await getFrequencyDays();
      if (last != null && DateTime.now().difference(last).inDays < frequency) {
        return;
      }

      final fileName = await uploadBackup();
      debugPrint('WebDAV 自动备份成功: $fileName');
    } catch (e) {
      // WHY: 自动备份失败不得影响应用启动流程，仅记录日志，
      // 用户可在 WebDAV 备份页面查看状态并手动重试
      debugPrint('WebDAV 自动备份失败: $e');
    }
  }

  /// 按配置创建 WebDAV 客户端
  static webdav.Client _newClient(WebdavConfig config) {
    final client = webdav.newClient(
      config.url.trim(),
      user: config.username.trim(),
      password: config.password,
    );
    // WHY: 家用 NAS/坚果云等响应可能较慢，适当放宽超时，避免弱网误判失败
    client.setConnectTimeout(15000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
    return client;
  }

  /// 记录备份时间
  static Future<void> _recordBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackupTime, time.toIso8601String());
  }
}

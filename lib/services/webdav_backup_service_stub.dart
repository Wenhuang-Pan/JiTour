import 'webdav_backup_types.dart';

/// WebDAV 云端备份服务（Web 平台桩实现）
///
/// WHY: Web 平台不支持 dart:io（webdav_client 依赖之），
/// 提供同签名空实现保证编译通过；UI 层已通过 isSupported/kIsWeb 隐藏入口，
/// 正常流程不会触达本类方法
class WebdavBackupService {
  /// 远端备份目录
  static const String remoteDirPath = '/jitu_backups/';

  /// 当前平台是否支持 WebDAV 备份
  static const bool isSupported = false;

  /// 读取服务器配置
  static Future<WebdavConfig> getConfig() async =>
      const WebdavConfig(url: '', username: '', password: '');

  /// 保存服务器配置
  static Future<void> saveConfig(WebdavConfig config) async {}

  /// 测试服务器连接
  static Future<void> testConnection(WebdavConfig config) async {
    throw UnsupportedError('Web 平台不支持 WebDAV 备份');
  }

  /// 上传备份到远端
  static Future<String> uploadBackup() async {
    throw UnsupportedError('Web 平台不支持 WebDAV 备份');
  }

  /// 列出远端备份文件
  static Future<List<WebdavBackupItem>> listBackups() async => const [];

  /// 下载远端备份并恢复到本地
  static Future<bool> restoreBackup(String remotePath) async => false;

  /// 删除远端备份文件
  static Future<void> deleteBackup(String remotePath) async {}

  /// 是否开启自动备份
  static Future<bool> isAutoBackupEnabled() async => false;

  /// 设置自动备份开关
  static Future<void> setAutoBackupEnabled(bool enabled) async {}

  /// 获取自动备份频率（天数）
  static Future<int> getFrequencyDays() async => 1;

  /// 设置自动备份频率（天数）
  static Future<void> setFrequencyDays(int days) async {}

  /// 获取上次备份时间
  static Future<DateTime?> getLastBackupTime() async => null;

  /// 应用启动时按需静默执行自动备份
  static Future<void> performAutoBackupIfNeeded() async {}
}

/// 本地自动备份服务 —— Web 平台桩实现
///
/// WHY: Web 无本地文件系统，所有方法返回惰性值，
/// 保证条件导出下编译通过且调用方无需平台判断。
class AutoBackupService {
  AutoBackupService._();

  /// 是否开启自动备份（Web 恒为 false）
  static Future<bool> isAutoBackupEnabled() async => false;

  /// 设置自动备份开关（Web 无操作）
  static Future<void> setAutoBackupEnabled(bool enabled) async {}

  /// 获取备份频率天数（Web 恒为 7）
  static Future<int> getBackupFrequency() async => 7;

  /// 设置备份频率天数（Web 无操作）
  static Future<void> setBackupFrequency(int days) async {}

  /// 获取上次备份时间（Web 恒为 null）
  static Future<DateTime?> getLastBackupTime() async => null;

  /// 立即执行一次备份（Web 恒为 null 表示不可用）
  static Future<String?> performBackupNow() async => null;

  /// 启动时惰性检查并执行自动备份（Web 无操作）
  static Future<void> performAutoBackupIfNeeded() async {}
}

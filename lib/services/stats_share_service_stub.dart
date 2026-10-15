import 'dart:typed_data';

/// 统计报表图片分享服务 —— Web 平台桩实现
///
/// WHY: Web 无本地临时文件系统与系统分享面板，所有方法返回惰性值，
/// 保证条件导出下编译通过且调用方无需平台判断。
class StatsShareService {
  StatsShareService._();

  /// Web 平台不支持导出文件分享，恒返回 false
  ///
  /// @param bytes PNG 图片字节（忽略）
  /// @param fileName 临时文件名（忽略）
  /// @return 恒为 false，表示当前平台不可用
  static Future<bool> sharePngBytes(Uint8List bytes, String fileName) async =>
      false;
}

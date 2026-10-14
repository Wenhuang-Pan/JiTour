/// APK 应用内下载与安装服务（Web 平台桩实现）
///
/// WHY: Web 端无本地文件系统与 APK 安装能力，该桩仅保证条件导入编译通过。
/// 实际不会被调用——Web 端更新走浏览器刷新分支
class ApkDownloadService {
  /// 下载 APK（Web 不支持，直接抛异常）
  ///
  /// @param url APK 下载地址
  /// @param onProgress 进度回调：(已下载字节数, 总字节数)
  /// @return 不会返回，固定抛 [UnsupportedError]
  /// @throws UnsupportedError Web 平台不支持应用内下载
  static Future<String> downloadApk(
    String url,
    void Function(int received, int total) onProgress,
  ) {
    throw UnsupportedError('Web 平台不支持应用内下载 APK');
  }

  /// 取消下载（Web 无下载，空实现）
  static void cancelDownload() {}

  /// 调起系统安装器（Web 不支持，直接抛异常）
  ///
  /// @param filePath APK 本地路径
  /// @return 不会返回，固定抛 [UnsupportedError]
  /// @throws UnsupportedError Web 平台不支持安装 APK
  static Future<bool> installApk(String filePath) {
    throw UnsupportedError('Web 平台不支持安装 APK');
  }
}

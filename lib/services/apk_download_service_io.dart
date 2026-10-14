// WHY: 该文件仅在 dart:io 可用平台参与编译，Web 端由 stub 替代
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// APK 应用内下载与安装服务（IO 平台实现）
///
/// 下载到应用私有外部存储目录（免存储权限），完成后通过系统安装器覆盖安装
class ApkDownloadService {
  static http.Client? _activeClient;
  static bool _cancelRequested = false;

  /// 流式下载 APK 到本地，并通过回调汇报进度
  ///
  /// @param url APK 下载地址（GitHub Releases 的 302 重定向由 http 自动跟随）
  /// @param onProgress 进度回调：(已下载字节数, 总字节数)，总字节数未知时为 0
  /// @return 下载完成后的本地文件路径
  /// @throws Exception 网络错误、HTTP 非 200、取消或写文件失败时抛出
  static Future<String> downloadApk(
    String url,
    void Function(int received, int total) onProgress,
  ) async {
    _cancelRequested = false;
    final client = http.Client();
    _activeClient = client;
    IOSink? sink;
    File? file;
    try {
      final request = http.Request('GET', Uri.parse(url));
      // WHY: 30s 仅约束建连；下载过程不设总超时（大文件慢网耗时长），停滞可由用户取消
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('服务器返回 HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;

      // WHY: getExternalStorageDirectory 为应用私有目录，Android 10+ 免存储权限
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      file = File('${dir.path}${Platform.pathSeparator}jitu_update.apk');
      sink = file.openWrite();

      var received = 0;
      // O(n)：按字节流单次写入，内存占用为当前分块大小而非整个文件
      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          throw Exception('下载已取消');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      debugPrint('[Update] APK 下载完成: ${file.path}, $received 字节');
      return file.path;
    } catch (e) {
      // WHY: 失败/取消时删除半成品文件，避免残留占用空间或被误安装
      debugPrint('[Update] APK 下载中断: $e');
      if (file != null && await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      await sink?.close();
      _activeClient = null;
      client.close();
    }
  }

  /// 取消正在进行的下载：置标记并断开连接，流式循环在下一分块处抛出
  static void cancelDownload() {
    _cancelRequested = true;
    _activeClient?.close();
  }

  /// 调起系统安装器安装 APK
  ///
  /// WHY: Android 8+ 安装未知来源应用由系统弹窗确认，无需运行时权限申请；
  /// open_filex 内部已配置 FileProvider，无需额外 manifest 声明
  ///
  /// @param filePath APK 本地路径
  /// @return true 表示安装器成功调起并完成交互；false 表示失败或被拒绝
  /// @throws 不抛异常，失败以返回值表达
  static Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        debugPrint('[Update] 调起安装器失败: ${result.type} ${result.message}');
      }
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[Update] 调起安装器异常: $e');
      return false;
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 统计报表图片分享服务 —— IO 平台实现（Android/iOS/桌面）
///
/// WHY: 将统计页 RepaintBoundary 导出的 PNG 字节写入系统临时目录，
/// 再调起系统分享面板（微信/QQ/保存到相册等）；临时目录由系统定期清理，
/// 无需手动维护缓存文件生命周期。
class StatsShareService {
  StatsShareService._();

  /// 将 PNG 字节写入临时文件并调起系统分享面板
  ///
  /// @param bytes PNG 图片字节
  /// @param fileName 临时文件名（含 .png 后缀）
  /// @return true 表示分享面板已成功调起；写入或调起失败返回 false
  /// @throws 不抛异常，所有失败均收敛为 false 返回
  static Future<bool> sharePngBytes(Uint8List bytes, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      // WHY: 分享面板成功调起即视为成功，用户是否真正完成分享由系统决定
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '记途统计报表',
      );
      return true;
    } catch (e) {
      debugPrint('[StatsShare] 分享失败: $e');
      return false;
    }
  }
}

// WHY: 写临时分享文件依赖 dart:io 与 path_provider，Web 编译不允许；
// 参照 apk_download_service / webdav_backup_service 的条件导出模式按平台分发：
// Android/iOS/桌面走 stats_share_service_io.dart，Web 走 stub 保证编译通过
export 'stats_share_service_stub.dart'
    if (dart.library.io) 'stats_share_service_io.dart';

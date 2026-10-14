// WHY: webdav_client 依赖 dart:io，Web 编译不允许导入 dart:io；
// 参照 apk_download_service 的条件导出模式按平台分发：
// Android/iOS/桌面走 webdav_backup_service_io.dart，Web 走 stub 保证编译通过
export 'webdav_backup_service_stub.dart'
    if (dart.library.io) 'webdav_backup_service_io.dart';

// WHY: 自动备份实现依赖 dart:io（File 操作），Web 编译不允许导入 dart:io；
// 参照 webdav_backup_service 的条件导出模式按平台分发：
// Android/iOS/桌面走 auto_backup_service_io.dart，Web 走 stub 保证编译通过
export 'auto_backup_service_stub.dart'
    if (dart.library.io) 'auto_backup_service_io.dart';

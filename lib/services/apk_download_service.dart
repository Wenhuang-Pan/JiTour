// WHY: Web 编译不允许导入 dart:io，通过条件导入按平台选择实现：
// Android/桌面走 apk_download_service_io.dart，Web 走 stub 保证编译通过
export 'apk_download_service_stub.dart'
    if (dart.library.io) 'apk_download_service_io.dart';

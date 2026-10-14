/// WebDAV 备份共享类型定义
///
/// WHY: 条件导出的 stub/io 两个实现与 UI 层都需要引用这些类型，
/// 独立成纯 Dart 文件（不依赖 dart:io / webdav_client），保证 Web 端可编译
library;

/// WebDAV 服务器配置
class WebdavConfig {
  /// 服务器地址（如 https://dav.jianguoyun.com/dav/）
  final String url;

  /// 用户名
  final String username;

  /// 密码（建议使用应用专用密码）
  final String password;

  const WebdavConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  /// 配置是否满足最低可用条件（地址非空）
  bool get isValid => url.trim().isNotEmpty;
}

/// WebDAV 远端备份文件信息
class WebdavBackupItem {
  /// 文件名（如 jitu_webdav_20261014_120000.json）
  final String name;

  /// 远端完整路径，用于下载/删除
  final String path;

  /// 文件大小（字节）
  final int size;

  /// 服务端修改时间
  final DateTime? modifiedAt;

  const WebdavBackupItem({
    required this.name,
    required this.path,
    required this.size,
    this.modifiedAt,
  });
}

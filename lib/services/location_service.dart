import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

/// 位置服务
/// 管理常用位置列表和位置记录功能
class LocationService {
  /// Hive box 名称
  static const String _boxName = 'locations';

  /// 获取位置 Box
  static Box<Map<String, dynamic>> get _box {
    try {
      return DatabaseService.locations;
    } catch (_) {
      return Hive.box<Map<String, dynamic>>(_boxName);
    }
  }

  /// 位置数据模型
  /// @param id 位置ID
  /// @param name 位置名称
  /// @param latitude 纬度
  /// @param longitude 经度
  /// @param address 详细地址
  /// @param usageCount 使用次数
  /// @param lastUsedAt 最后使用时间
  static Map<String, dynamic> createLocation(
      {required String id,
      required String name,
      required double latitude,
      required double longitude,
      String? address,
      int usageCount = 0,
      DateTime? lastUsedAt}) {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'usageCount': usageCount,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  /// 获取所有常用位置
  /// @return 位置列表，按使用次数降序排列
  static List<Map<String, dynamic>> getFavoriteLocations() {
    final locations = _box.values.toList().cast<Map<String, dynamic>>();
    locations.sort((a, b) => (b['usageCount'] ?? 0) - (a['usageCount'] ?? 0));
    return locations;
  }

  /// 添加或更新常用位置
  /// @param id 位置ID
  /// @param name 位置名称
  /// @param latitude 纬度
  /// @param longitude 经度
  /// @param address 详细地址
  static Future<void> addOrUpdateLocation(
      {required String id,
      required String name,
      required double latitude,
      required double longitude,
      String? address}) async {
    final existing = _box.get(id);
    if (existing != null) {
      await _box.put(id, {
        ...existing,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'usageCount': (existing['usageCount'] ?? 0) + 1,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
    } else {
      await _box.put(
          id,
          createLocation(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            usageCount: 1,
            lastUsedAt: DateTime.now(),
          ));
    }
  }

  /// 删除常用位置
  /// @param id 位置ID
  static Future<void> removeLocation(String id) async {
    await _box.delete(id);
  }

  /// 搜索位置（模拟搜索，实际应用中调用地图API）
  /// @param query 搜索关键词
  /// @return 匹配的位置列表
  static Future<List<Map<String, dynamic>>> searchLocations(
      String query) async {
    // 模拟搜索结果，实际应用中应调用地图SDK API
    await Future.delayed(const Duration(milliseconds: 500));

    final mockResults = [
      {
        'id': '1',
        'name': '万达广场',
        'address': '北京市朝阳区建国路93号',
        'latitude': 39.9042,
        'longitude': 116.4074
      },
      {
        'id': '2',
        'name': '星巴克',
        'address': '北京市朝阳区三里屯太古里北区',
        'latitude': 39.9371,
        'longitude': 116.4484
      },
      {
        'id': '3',
        'name': '全家便利店',
        'address': '北京市海淀区中关村大街15号',
        'latitude': 39.9842,
        'longitude': 116.3074
      },
      {
        'id': '4',
        'name': '海底捞火锅',
        'address': '北京市西城区西单北大街120号',
        'latitude': 39.9142,
        'longitude': 116.3774
      },
      {
        'id': '5',
        'name': '京东商城',
        'address': '北京市大兴区亦庄经济技术开发区',
        'latitude': 39.8042,
        'longitude': 116.6074
      },
    ];

    return mockResults.where((loc) {
      // WHY: 使用 null 安全访问，防止字段缺失时类型转换崩溃
      final name = loc['name'] as String? ?? '';
      final address = loc['address'] as String? ?? '';
      return name.toLowerCase().contains(query.toLowerCase()) ||
          address.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// 获取当前位置（使用 geolocator 真实定位 + Nominatim 反向地理编码）
  ///
  /// 先获取设备 GPS 经纬度，再调用 OpenStreetMap Nominatim 免费 API
  /// 解析出具体地址（国家/省/市/区/街道），避免只显示经纬度数字。
  ///
  /// @return 当前位置信息，包含经纬度、名称和详细地址
  /// @throws Exception 如果权限被拒绝或定位失败
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    // 1. 检查定位服务是否开启
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('定位服务未开启，请在系统设置中开启定位');
    }

    // 2. 检查并请求定位权限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('定位权限被拒绝');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝，请在系统设置中授予权限');
    }

    // 3. 获取当前位置经纬度
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    debugPrint('当前位置: ${position.latitude}, ${position.longitude}');

    // 4. 反向地理编码：将经纬度转换为具体地址
    // WHY: 使用 OpenStreetMap Nominatim 免费公共服务，无需 API Key，
    // 遵守其使用政策（单次请求、标识 User-Agent）
    String address =
        '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    String name = '当前位置';

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1&accept-language=zh-CN',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'JiTuLedger/2.0 (simple-ledger-app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          // WHY: 按中文地址习惯拼接：省+市+区+街道+门牌号
          final parts = <String>[
            addr['province'] as String? ?? '',
            addr['city'] as String? ?? addr['town'] as String? ?? '',
            addr['district'] as String? ??
                addr['county'] as String? ??
                addr['suburb'] as String? ??
                '',
            addr['road'] as String? ?? addr['street'] as String? ?? '',
            addr['house_number'] as String? ?? '',
          ].where((s) => s.isNotEmpty).toList();

          if (parts.isNotEmpty) {
            address = parts.join('');
            // 取最后两级作为短名称显示（如"朝阳区建国路93号"）
            name = parts.length >= 2
                ? parts.sublist(parts.length - 2).join('')
                : parts.first;
          }
        }
      }
    } catch (e) {
      debugPrint('反向地理编码失败，使用经纬度兜底: $e');
      // WHY: 编码失败时不抛错，地址仍保留经纬度，保证主流程可用
    }

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'name': name,
      'address': address,
    };
  }

  /// 计算两个位置之间的距离（单位：米）
  /// @param lat1 纬度1
  /// @param lon1 经度1
  /// @param lat2 纬度2
  /// @param lon2 经度2
  /// @return 距离（米）
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // 地球半径（米）
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// 将角度转换为弧度
  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  /// 格式化距离显示
  /// @param distance 距离（米）
  /// @return 格式化后的距离字符串
  static String formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 获取最近的常用位置
  /// @param currentLat 当前纬度
  /// @param currentLon 当前经度
  /// @param limit 返回数量限制
  /// @return 按距离排序的位置列表
  static List<Map<String, dynamic>> getNearbyLocations(
      double currentLat, double currentLon, int limit) {
    final locations = _box.values.toList().cast<Map<String, dynamic>>();
    locations.sort((a, b) {
      // WHY: 使用 null 安全访问，防止字段为 null 时传入 calculateDistance 崩溃
      final latA = a['latitude'] ?? 0.0;
      final lonA = a['longitude'] ?? 0.0;
      final latB = b['latitude'] ?? 0.0;
      final lonB = b['longitude'] ?? 0.0;
      final distA = calculateDistance(currentLat, currentLon, latA, lonA);
      final distB = calculateDistance(currentLat, currentLon, latB, lonB);
      return distA.compareTo(distB);
    });
    return locations.take(limit).toList();
  }
}

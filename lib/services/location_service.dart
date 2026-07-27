import 'dart:async';
import 'dart:math';
import 'package:hive/hive.dart';

/// 位置服务
/// 管理常用位置列表和位置记录功能
class LocationService {
  /// Hive box 名称
  static const String _boxName = 'locations';

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
    final box = Hive.box(_boxName);
    final locations = box.values.toList().cast<Map<String, dynamic>>();
    // 按使用次数降序排列
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
    final box = await Hive.openBox(_boxName);
    final existing = box.get(id);
    if (existing != null) {
      // 更新现有位置
      await box.put(id, {
        ...existing,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'usageCount': (existing['usageCount'] ?? 0) + 1,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
    } else {
      // 添加新位置
      await box.put(
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
    final box = await Hive.openBox(_boxName);
    await box.delete(id);
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

    return mockResults
        .where((loc) =>
            (loc['name'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (loc['address'] as String).toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// 获取当前位置（模拟）
  /// @return 当前位置信息
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    // 模拟获取当前位置，实际应用中应使用 geolocator 插件
    await Future.delayed(const Duration(milliseconds: 1000));

    // 模拟位置：北京市中心
    return {
      'latitude': 39.9042,
      'longitude': 116.4074,
      'name': '北京市中心',
      'address': '北京市东城区',
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
    final locations = getFavoriteLocations();
    locations.sort((a, b) {
      final distA = calculateDistance(
          currentLat, currentLon, a['latitude'], a['longitude']);
      final distB = calculateDistance(
          currentLat, currentLon, b['latitude'], b['longitude']);
      return distA.compareTo(distB);
    });
    return locations.take(limit).toList();
  }
}

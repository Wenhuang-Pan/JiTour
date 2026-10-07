import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/tag.dart';
import '../theme/app_theme.dart';
import 'database_service.dart';

class TagService {
  static const _uuid = Uuid();

  // 获取标签 Box
  static Box<Tag> get box => DatabaseService.tags;

  // 初始化服务
  static Future<void> init() async {
    // 如果没有标签，创建默认标签
    if (box.isEmpty) {
      await _createDefaultTags();
    }
  }

  // 创建默认标签
  static Future<void> _createDefaultTags() async {
    final defaultTags = [
      Tag(
        id: _uuid.v4(),
        name: '日常',
        iconName: 'home_rounded',
        colorValue: AppTheme.primaryColor.value,
        sortOrder: 0,
      ),
      Tag(
        id: _uuid.v4(),
        name: '购物',
        iconName: 'shopping_bag_rounded',
        colorValue: const Color(0xFFE91E63).value,
        sortOrder: 1,
      ),
      Tag(
        id: _uuid.v4(),
        name: '餐饮',
        iconName: 'restaurant_rounded',
        colorValue: const Color(0xFFFF9800).value,
        sortOrder: 2,
      ),
      Tag(
        id: _uuid.v4(),
        name: '交通',
        iconName: 'directions_car_rounded',
        colorValue: const Color(0xFF4CAF50).value,
        sortOrder: 3,
      ),
      Tag(
        id: _uuid.v4(),
        name: '娱乐',
        iconName: 'movie_rounded',
        colorValue: const Color(0xFF9C27B0).value,
        sortOrder: 4,
      ),
      Tag(
        id: _uuid.v4(),
        name: '健康',
        iconName: 'favorite_rounded',
        colorValue: const Color(0xFFF44336).value,
        sortOrder: 5,
      ),
      Tag(
        id: _uuid.v4(),
        name: '教育',
        iconName: 'school_rounded',
        colorValue: const Color(0xFF2196F3).value,
        sortOrder: 6,
      ),
      Tag(
        id: _uuid.v4(),
        name: '礼物',
        iconName: 'card_giftcard_rounded',
        colorValue: const Color(0xFFFF5722).value,
        sortOrder: 7,
      ),
      Tag(
        id: _uuid.v4(),
        name: '旅行',
        iconName: 'flight_rounded',
        colorValue: const Color(0xFF00BCD4).value,
        sortOrder: 8,
      ),
      Tag(
        id: _uuid.v4(),
        name: '工作',
        iconName: 'work_rounded',
        colorValue: const Color(0xFF607D8B).value,
        sortOrder: 9,
      ),
    ];

    for (final tag in defaultTags) {
      await box.put(tag.id, tag);
    }
  }

  // 获取所有标签
  static List<Tag> getAllTags() {
    return box.values.toList();
  }

  // 获取活跃标签（按排序顺序）
  static List<Tag> getActiveTags() {
    final tags = getAllTags().where((tag) => tag.isActive).toList();
    tags.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tags;
  }

  // 根据 ID 获取标签
  static Tag? getTagById(String id) {
    return box.get(id);
  }

  // 根据名称获取标签
  static Tag? getTagByName(String name) {
    return getAllTags()
        .where((tag) => tag.name == name && tag.isActive)
        .firstOrNull;
  }

  /// 统计各标签被多少笔未删除账单使用
  ///
  /// WHY: 标签管理页需要展示使用情况、删除前需要提示影响范围。
  /// 仅统计未软删除账单（getAllTransactions 已过滤），一笔账单带多个标签时各计一次。
  ///
  /// 时间复杂度：O(n·k)，n=账单数，k=单笔平均标签数
  ///
  /// @return tagId → 使用笔数；从未使用的标签不在 Map 中
  static Map<String, int> getTagUsageCounts() {
    final counts = <String, int>{};
    for (final transaction in DatabaseService.getAllTransactions()) {
      for (final tagId in transaction.tagIds) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // 检查标签名称是否存在
  static bool tagNameExists(String name, {String? excludeId}) {
    return getAllTags()
        .any((tag) => tag.name == name && tag.id != excludeId && tag.isActive);
  }

  // 创建新标签
  static Future<Tag> createTag({
    required String name,
    required String iconName,
    required int colorValue,
    int sortOrder = 0,
  }) async {
    if (tagNameExists(name)) {
      throw Exception('标签名称已存在');
    }

    final tag = Tag(
      id: _uuid.v4(),
      name: name,
      iconName: iconName,
      colorValue: colorValue,
      sortOrder: sortOrder,
    );

    await box.put(tag.id, tag);
    return tag;
  }

  // 更新标签
  static Future<void> updateTag(Tag tag) async {
    tag.updateTimestamp();
    await tag.save();
  }

  // 删除标签（软删除）
  static Future<void> deleteTag(String id) async {
    final tag = getTagById(id);
    if (tag != null) {
      tag.softDelete();
    }
  }

  // 永久删除标签
  static Future<void> permanentDeleteTag(String id) async {
    await box.delete(id);
  }

  // 批量更新排序
  static Future<void> updateSortOrder(List<String> tagIds) async {
    for (int i = 0; i < tagIds.length; i++) {
      final tag = getTagById(tagIds[i]);
      if (tag != null) {
        tag.sortOrder = i;
        await updateTag(tag);
      }
    }
  }

  // 获取默认图标列表
  static List<IconData> getDefaultIcons() {
    return [
      Icons.home_rounded,
      Icons.shopping_bag_rounded,
      Icons.restaurant_rounded,
      Icons.directions_car_rounded,
      Icons.movie_rounded,
      Icons.favorite_rounded,
      Icons.school_rounded,
      Icons.card_giftcard_rounded,
      Icons.flight_rounded,
      Icons.work_rounded,
      Icons.star_rounded,
      Icons.book_rounded,
      Icons.pets_rounded,
      Icons.sports_esports_rounded,
      Icons.music_note_rounded,
      Icons.photo_camera_rounded,
      Icons.phone_rounded,
      Icons.laptop_rounded,
      Icons.coffee_rounded,
      Icons.local_bar_rounded,
    ];
  }

  // 获取默认颜色列表
  static List<Color> getDefaultColors() {
    return [
      AppTheme.primaryColor,
      const Color(0xFFE91E63),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
      const Color(0xFFF44336),
      const Color(0xFF2196F3),
      const Color(0xFFFF5722),
      const Color(0xFF00BCD4),
      const Color(0xFF607D8B),
      const Color(0xFF673AB7),
      const Color(0xFF8BC34A),
      const Color(0xFFCDDC39),
      const Color(0xFF009688),
      const Color(0xFF795548),
    ];
  }
}

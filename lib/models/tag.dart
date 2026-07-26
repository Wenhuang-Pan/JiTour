import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 4)
class Tag extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String iconName;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  int sortOrder;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  Tag({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 更新时间
  void updateTimestamp() {
    updatedAt = DateTime.now();
  }

  // 软删除（标记为不活跃）
  void softDelete() {
    isActive = false;
    updateTimestamp();
    save();
  }

  // 恢复
  void restore() {
    isActive = true;
    updateTimestamp();
    save();
  }

  // 复制标签
  Tag copyWith({
    String? name,
    String? iconName,
    int? colorValue,
    bool? isActive,
    int? sortOrder,
  }) {
    return Tag(
      id: id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
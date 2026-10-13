import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String iconName; // Material Symbols图标名称

  @HiveField(3)
  bool isIncome;

  @HiveField(4)
  String color; // 颜色值，如 '#FF6B6B'

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? deletedAt;

  // WHY: defaultValue 保证旧版本数据（无此字段）读取时自动补 0，
  // 配合 CategoryService 的排序迁移逻辑按 createdAt 初始化顺序
  @HiveField(7, defaultValue: 0)
  int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.iconName,
    required this.isIncome,
    required this.color,
    required this.createdAt,
    this.deletedAt,
    this.sortOrder = 0,
  });

  // 创建收入分类
  factory Category.createIncome({
    required String id,
    required String name,
    required String iconName,
    required String color,
  }) {
    return Category(
      id: id,
      name: name,
      iconName: iconName,
      isIncome: true,
      color: color,
      createdAt: DateTime.now(),
    );
  }

  // 创建支出分类
  factory Category.createExpense({
    required String id,
    required String name,
    required String iconName,
    required String color,
  }) {
    return Category(
      id: id,
      name: name,
      iconName: iconName,
      isIncome: false,
      color: color,
      createdAt: DateTime.now(),
    );
  }

  // 软删除
  void softDelete() {
    deletedAt = DateTime.now();
    save();
  }

  // 恢复删除
  void restore() {
    deletedAt = null;
    save();
  }

  // 是否已删除
  bool get isDeleted => deletedAt != null;

  // 复制
  Category copyWith({
    String? id,
    String? name,
    String? iconName,
    bool? isIncome,
    String? color,
    DateTime? createdAt,
    DateTime? deletedAt,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      isIncome: isIncome ?? this.isIncome,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'isIncome': isIncome,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  // 从Map创建
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      iconName: map['iconName'] as String,
      isIncome: map['isIncome'] as bool,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      // WHY: 旧备份数据无 sortOrder 字段，缺省为 0 由迁移逻辑补齐
      sortOrder: (map['sortOrder'] as int?) ?? 0,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, iconName: $iconName, isIncome: $isIncome, color: $color)';
  }
}

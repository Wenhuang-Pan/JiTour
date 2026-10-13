import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  Decimal amount;

  @HiveField(2)
  bool isIncome;

  @HiveField(3)
  String category;

  @HiveField(4)
  String account;

  @HiveField(5)
  DateTime date;

  @HiveField(6)
  String? note;

  @HiveField(7)
  DateTime? deletedAt;

  @HiveField(8)
  String? tags;

  @HiveField(9)
  String? subCategory;

  @HiveField(10)
  String? currency;

  @HiveField(11)
  String? account2;

  @HiveField(12)
  bool isReimbursed;

  @HiveField(13)
  Decimal fee;

  @HiveField(14)
  Decimal coupon;

  @HiveField(15)
  String? locationName;

  @HiveField(16)
  double? latitude;

  @HiveField(17)
  double? longitude;

  Transaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.account,
    required this.date,
    this.note,
    this.deletedAt,
    this.tags,
    this.subCategory,
    this.currency = 'CNY',
    this.account2,
    this.isReimbursed = false,
    Decimal? fee,
    Decimal? coupon,
    this.locationName,
    this.latitude,
    this.longitude,
  })  : fee = fee ?? Decimal.zero,
        coupon = coupon ?? Decimal.zero;

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

  // 获取标签ID列表
  List<String> get tagIds {
    if (tags == null || tags!.isEmpty) return [];
    return tags!.split(',').where((id) => id.isNotEmpty).toList();
  }

  // 设置标签ID列表
  void setTagIds(List<String> ids) {
    tags = ids.join(',');
  }

  // 添加标签
  void addTag(String tagId) {
    final currentTags = tagIds;
    if (!currentTags.contains(tagId)) {
      currentTags.add(tagId);
      setTagIds(currentTags);
    }
  }

  // 移除标签
  void removeTag(String tagId) {
    final currentTags = tagIds;
    currentTags.remove(tagId);
    setTagIds(currentTags);
  }

  // 清空标签
  void clearTags() {
    tags = null;
  }
}

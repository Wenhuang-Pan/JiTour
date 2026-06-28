import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

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

  Transaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.account,
    required this.date,
    this.note,
    this.deletedAt,
  });

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
}

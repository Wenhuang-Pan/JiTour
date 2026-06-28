import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 1)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String category;

  @HiveField(2)
  double amount;

  @HiveField(3)
  int year;

  @HiveField(4)
  int month;

  Budget({
    required this.id,
    required this.category,
    required this.amount,
    required this.year,
    required this.month,
  });
}

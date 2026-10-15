import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import '../utils/decimal_util.dart';

part 'transaction_template.g.dart';

/// 账单模板模型
///
/// WHY: 常用交易（如每天咖啡、每月房租）通过模板一键填充表单，
/// 减少重复录入；模板不存日期，应用模板时默认使用当天。
@HiveType(typeId: 11)
class TransactionTemplate extends HiveObject {
  /// 模板 ID（UUID）
  @HiveField(0)
  String id;

  /// 模板名称（用户自定义，如"每日咖啡"）
  @HiveField(1)
  String name;

  /// 金额（null 表示不预填，使用时需手动输入）
  @HiveField(2)
  Decimal? amount;

  /// 是否收入（false=支出，true=收入）
  @HiveField(3)
  bool isIncome;

  /// 分类名称
  @HiveField(4)
  String category;

  /// 账户名称
  @HiveField(5)
  String account;

  /// 备注
  @HiveField(6)
  String? note;

  /// 标签 ID 列表（逗号分隔字符串存储，与 Transaction.tags 口径一致）
  @HiveField(7)
  String? tags;

  /// 创建时间
  @HiveField(8)
  DateTime createdAt;

  /// 更新时间
  @HiveField(9)
  DateTime updatedAt;

  TransactionTemplate({
    required this.id,
    required this.name,
    this.amount,
    required this.isIncome,
    required this.category,
    required this.account,
    this.note,
    this.tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 更新时间戳
  void updateTimestamp() {
    updatedAt = DateTime.now();
  }

  /// 获取标签 ID 列表
  List<String> get tagIds {
    if (tags == null || tags!.isEmpty) return [];
    return tags!.split(',').where((id) => id.isNotEmpty).toList();
  }

  /// 设置标签 ID 列表
  void setTagIds(List<String> ids) {
    tags = ids.isEmpty ? null : ids.join(',');
  }

  /// 获取金额显示文本
  String get amountText {
    if (amount == null) return isIncome ? '收入' : '支出';
    final prefix = isIncome ? '+' : '-';
    return '$prefix¥${amount!.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount?.toString(),
      'isIncome': isIncome,
      'category': category,
      'account': account,
      'note': note,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransactionTemplate.fromJson(Map<String, dynamic> json) {
    return TransactionTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: json['amount'] != null ? parseDecimal(json['amount']) : null,
      isIncome: json['isIncome'] as bool? ?? false,
      category: json['category'] as String,
      account: json['account'] as String,
      note: json['note'] as String?,
      tags: json['tags'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

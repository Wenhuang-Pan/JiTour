import 'package:decimal/decimal.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_template.dart';
import '../utils/uuid_util.dart';
import 'database_service.dart';

/// 账单模板服务
///
/// 提供模板的增删改查，数据统一走 [DatabaseService] 的 box。
class TemplateService {
  TemplateService._();

  /// 模板 Box
  static Box<TransactionTemplate> get box =>
      DatabaseService.transactionTemplates;

  /// 获取全部模板（按创建时间倒序）
  ///
  /// @return 模板列表，最新创建在前
  static List<TransactionTemplate> getAllTemplates() {
    final templates = box.values.toList();
    templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return templates;
  }

  /// 按 ID 获取模板
  ///
  /// @param id 模板 ID
  /// @return 找到返回模板，否则 null
  static TransactionTemplate? getTemplateById(String id) {
    return box.get(id);
  }

  /// 模板名称是否已存在
  ///
  /// @param name 模板名称
  /// @param excludeId 排除的模板 ID（编辑场景排除自身）
  /// @return true 表示已存在
  static bool templateNameExists(String name, {String? excludeId}) {
    return box.values.any((t) => t.name == name.trim() && t.id != excludeId);
  }

  /// 创建模板
  ///
  /// @param name 模板名称（去首尾空格，重名抛异常）
  /// @param isIncome 是否收入
  /// @param category 分类名称
  /// @param account 账户名称
  /// @param amount 金额（可为 null）
  /// @param note 备注
  /// @param tagIds 标签 ID 列表
  /// @return 创建成功的模板
  /// @throws 名称已存在或为空时抛出异常
  static Future<TransactionTemplate> createTemplate({
    required String name,
    required bool isIncome,
    required String category,
    required String account,
    Decimal? amount,
    String? note,
    List<String>? tagIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('模板名称不能为空');
    }
    if (templateNameExists(trimmedName)) {
      throw Exception('模板名称已存在');
    }
    final template = TransactionTemplate(
      id: UuidUtil.generate(),
      name: trimmedName,
      amount: amount,
      isIncome: isIncome,
      category: category,
      account: account,
      note: note?.trim().isEmpty == true ? null : note,
      tags: tagIds == null || tagIds.isEmpty ? null : tagIds.join(','),
    );
    await box.put(template.id, template);
    return template;
  }

  /// 更新模板
  ///
  /// @param template 已修改的模板对象
  /// @throws 不抛异常
  static Future<void> updateTemplate(TransactionTemplate template) async {
    template.updateTimestamp();
    await template.save();
  }

  /// 删除模板（物理删除）
  ///
  /// WHY: 模板是用户配置而非交易数据，删除不进回收站；
  /// 删除操作在 UI 层已做二次确认
  ///
  /// @param id 模板 ID
  /// @throws 不抛异常
  static Future<void> deleteTemplate(String id) async {
    await box.delete(id);
  }
}

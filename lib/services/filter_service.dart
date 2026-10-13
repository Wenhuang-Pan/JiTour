import 'package:decimal/decimal.dart';
import '../models/transaction.dart';
import 'tag_service.dart';

/// 筛选条件模型
///
/// 用于定义交易筛选的各种条件，支持按分类、账户、日期、金额、收支类型等维度筛选。
class FilterConditions {
  /// 搜索关键词（匹配备注、分类名）
  String? keyword;

  /// 分类名称（可选）
  String? category;

  /// 账户名称（可选）
  String? account;

  /// 开始日期（可选）
  DateTime? startDate;

  /// 结束日期（可选）
  DateTime? endDate;

  /// 最小金额（可选）
  Decimal? minAmount;

  /// 最大金额（可选）
  Decimal? maxAmount;

  /// 收支类型：null=全部, true=收入, false=支出
  bool? isIncome;

  /// 是否只显示有标签的交易
  bool? hasTag;

  /// 标签名称（可选）
  String? tag;

  /// 创建空的筛选条件
  FilterConditions({
    this.keyword,
    this.category,
    this.account,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.isIncome,
    this.hasTag,
    this.tag,
  });

  /// 判断是否有任何筛选条件
  bool get hasFilters {
    // WHY: 纯空格关键词视为无筛选，避免输入空格后误进"无结果"态
    return keyword != null && keyword!.trim().isNotEmpty ||
        category != null && category!.isNotEmpty ||
        account != null && account!.isNotEmpty ||
        startDate != null ||
        endDate != null ||
        minAmount != null ||
        maxAmount != null ||
        isIncome != null ||
        hasTag != null ||
        tag != null && tag!.isNotEmpty;
  }

  /// 重置所有筛选条件
  void reset() {
    keyword = null;
    category = null;
    account = null;
    startDate = null;
    endDate = null;
    minAmount = null;
    maxAmount = null;
    isIncome = null;
    hasTag = null;
    tag = null;
  }

  /// 复制筛选条件
  FilterConditions copyWith({
    String? keyword,
    String? category,
    String? account,
    DateTime? startDate,
    DateTime? endDate,
    Decimal? minAmount,
    Decimal? maxAmount,
    bool? isIncome,
    bool? hasTag,
    String? tag,
  }) {
    return FilterConditions(
      keyword: keyword ?? this.keyword,
      category: category ?? this.category,
      account: account ?? this.account,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      isIncome: isIncome ?? this.isIncome,
      hasTag: hasTag ?? this.hasTag,
      tag: tag ?? this.tag,
    );
  }
}

/// 筛选服务
///
/// 提供交易数据的筛选功能，支持多维度组合筛选。
class FilterService {
  FilterService._();

  /// 根据筛选条件筛选交易列表
  ///
  /// @param transactions 原始交易列表
  /// @param conditions 筛选条件
  /// @return 筛选后的交易列表（按日期倒序排列）
  static List<Transaction> filterTransactions(
    List<Transaction> transactions,
    FilterConditions conditions,
  ) {
    // WHY: 软删除账单在任何情况下都不进入列表/搜索结果（备份导出等场景走独立通道）；
    // 无筛选条件的早退分支也必须过滤，否则首页默认态仍会显示软删除账单
    final List<Transaction> activeTransactions =
        transactions.where((t) => !t.isDeleted).toList();

    if (!conditions.hasFilters) {
      return activeTransactions..sort((a, b) => b.date.compareTo(a.date));
    }

    List<Transaction> filtered = activeTransactions;

    // WHY: Transaction.tags 存的是逗号分隔的标签 ID，预构建一次 tagId→标签名
    // 映射（O(标签数)），避免在交易循环内重复查 Hive box
    final Map<String, String> tagNameById = <String, String>{
      for (final tag in TagService.getAllTags()) tag.id: tag.name,
    };

    // 按收支类型筛选
    if (conditions.isIncome != null) {
      filtered =
          filtered.where((t) => t.isIncome == conditions.isIncome).toList();
    }

    // 按分类筛选
    if (conditions.category != null && conditions.category!.isNotEmpty) {
      filtered =
          filtered.where((t) => t.category == conditions.category).toList();
    }

    // 按账户筛选
    if (conditions.account != null && conditions.account!.isNotEmpty) {
      filtered =
          filtered.where((t) => t.account == conditions.account).toList();
    }

    // 按日期范围筛选
    if (conditions.startDate != null) {
      final start = DateTime(
        conditions.startDate!.year,
        conditions.startDate!.month,
        conditions.startDate!.day,
      );
      filtered = filtered.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.compareTo(start) >= 0;
      }).toList();
    }

    if (conditions.endDate != null) {
      final end = DateTime(
        conditions.endDate!.year,
        conditions.endDate!.month,
        conditions.endDate!.day,
      ).add(const Duration(days: 1));
      filtered = filtered.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isBefore(end);
      }).toList();
    }

    // 按金额范围筛选
    if (conditions.minAmount != null) {
      filtered =
          filtered.where((t) => t.amount >= conditions.minAmount!).toList();
    }

    if (conditions.maxAmount != null) {
      filtered =
          filtered.where((t) => t.amount <= conditions.maxAmount!).toList();
    }

    // 按标签筛选
    if (conditions.hasTag != null) {
      final hasTag = conditions.hasTag!;
      filtered = filtered
          .where((t) => (t.tags?.isNotEmpty ?? false) == hasTag)
          .toList();
    }

    if (conditions.tag != null && conditions.tag!.isNotEmpty) {
      final targetTag = conditions.tag!;
      filtered = filtered.where((t) {
        // WHY: 兼容按标签 ID 或标签名称筛选；旧代码误用 t.tags as List<String>，
        // 但 tags 实际是逗号分隔的 ID 字符串，该分支永不命中
        return t.tagIds
            .any((id) => id == targetTag || tagNameById[id] == targetTag);
      }).toList();
    }

    // 按关键词搜索（匹配备注、分类名、账户名、消费位置、标签名）
    if (conditions.keyword != null && conditions.keyword!.trim().isNotEmpty) {
      final keyword = conditions.keyword!.trim().toLowerCase();
      filtered = filtered.where((t) {
        // WHY: 标签 ID 反查名称后再匹配关键词
        final bool tagMatched = t.tagIds.any(
            (id) => (tagNameById[id] ?? '').toLowerCase().contains(keyword));
        return (t.note?.toLowerCase().contains(keyword) ?? false) ||
            t.category.toLowerCase().contains(keyword) ||
            t.account.toLowerCase().contains(keyword) ||
            (t.locationName?.toLowerCase().contains(keyword) ?? false) ||
            tagMatched;
      }).toList();
    }

    // 按日期倒序排列
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  /// 获取快捷日期范围
  ///
  /// @param type 日期类型：today/yesterday/week/month/quarter/year/custom
  /// @return 包含开始和结束日期的 Map
  static Map<String, DateTime> getDateRange(String type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (type) {
      case 'today':
        return {
          'start': today,
          'end': today.add(const Duration(days: 1)),
        };
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return {
          'start': yesterday,
          'end': today,
        };
      case 'week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return {
          'start': weekStart,
          'end': weekStart.add(const Duration(days: 7)),
        };
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        return {
          'start': monthStart,
          'end': DateTime(now.year, now.month + 1, 1),
        };
      case 'quarter':
        final quarter = (now.month - 1) ~/ 3;
        final quarterStart = DateTime(now.year, quarter * 3 + 1, 1);
        return {
          'start': quarterStart,
          'end': DateTime(now.year, quarter * 3 + 4, 1),
        };
      case 'year':
        final yearStart = DateTime(now.year, 1, 1);
        return {
          'start': yearStart,
          'end': DateTime(now.year + 1, 1, 1),
        };
      default:
        return {
          'start': today.subtract(const Duration(days: 30)),
          'end': today.add(const Duration(days: 1)),
        };
    }
  }
}

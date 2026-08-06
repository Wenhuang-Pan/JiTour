import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

/// 日志统一前缀，便于在控制台过滤商户规则相关日志
const String _logTag = '[MerchantRule]';

/// 推断分类结果
///
/// 包含分类名和置信度，置信度低于 0.5 时建议让用户手动选择。
class InferredCategory {
  /// 推断的分类名
  final String? categoryName;

  /// 置信度（0.0-1.0）
  final double confidence;

  /// 构造推断结果
  ///
  /// @param categoryName 分类名
  /// @param confidence 置信度
  const InferredCategory(this.categoryName, this.confidence);
}

/// 分类推断服务
///
/// WHY: 采用「用户学习表 > 内置关键词映射 > 兜底分类」三级匹配，
/// 用户确认过的商户名后续自动套用，提升准确率。
///
/// 算法复杂度：关键词匹配 O(n)，n 为关键词数量（约 50）。
class CategoryInferenceService {
  CategoryInferenceService._();

  /// 内置关键词 -> 分类名映射表
  ///
  /// WHY: 与 CategoryService 默认分类对齐，覆盖常见支付场景。
  static const Map<String, String> _keywordMap = {
    // 餐饮
    '美团': '餐饮',
    '饿了么': '餐饮',
    '肯德基': '餐饮',
    '麦当劳': '餐饮',
    '星巴克': '餐饮',
    '瑞幸': '餐饮',
    '海底捞': '餐饮',
    '必胜客': '餐饮',
    '汉堡王': '餐饮',
    '喜茶': '餐饮',
    '奈雪': '餐饮',
    '蜜雪冰城': '餐饮',
    // 交通
    '滴滴': '交通',
    '高德': '交通',
    '12306': '交通',
    '地铁': '交通',
    '公交': '交通',
    '携程': '交通',
    '去哪儿': '交通',
    '飞猪': '交通',
    // 购物
    '京东': '购物',
    '淘宝': '购物',
    '拼多多': '购物',
    '天猫': '购物',
    '苏宁': '购物',
    '当当': '购物',
    '唯品会': '购物',
    '得物': '购物',
    // 汽车
    '加油': '汽车',
    '中石化': '汽车',
    '中石油': '汽车',
    '充电': '汽车',
    '停车': '汽车',
    // 居家
    '水电煤': '居家',
    '电费': '居家',
    '水费': '居家',
    '燃气': '居家',
    '物业': '居家',
    '宽带': '居家',
    // 娱乐
    '电影': '娱乐',
    '猫眼': '娱乐',
    '淘票票': '娱乐',
    'KTV': '娱乐',
    '游戏': '娱乐',
    'Steam': '娱乐',
    // 医疗
    '医院': '医疗',
    '药店': '医疗',
    '药品': '医疗',
    // 教育
    '学而思': '教育',
    '新东方': '教育',
    '培训': '教育',
    '书店': '教育',
  };

  /// 推断分类
  ///
  /// 匹配顺序：1) 商户学习表 2) 关键词包含匹配 3) 兜底返回 null
  ///
  /// @param merchant 商户名
  /// @return 推断结果，confidence 0.0-1.0，低于 0.5 时上层应让用户选
  static Future<InferredCategory> infer(String? merchant) async {
    // WHY: 入口日志记录原始输入，便于排查空商户名或异常字符问题
    debugPrint('$_logTag infer 开始: merchant="${merchant ?? 'null'}"');

    if (merchant == null || merchant.isEmpty) {
      debugPrint('$_logTag infer 跳过: 商户名为空');
      return const InferredCategory(null, 0.0);
    }

    // 1. 查学习表
    final learned = _queryLearnedMap(merchant);
    if (learned != null) {
      // WHY: 学习表命中是最高优先级，记录匹配结果便于统计准确率
      debugPrint(
          '$_logTag infer 命中学习表: merchant="$merchant" → category="$learned", confidence=0.95');
      return InferredCategory(learned, 0.95);
    }
    debugPrint('$_logTag infer 未命中学习表: merchant="$merchant"');

    // 2. 关键词包含匹配 O(n)
    for (final entry in _keywordMap.entries) {
      if (merchant.contains(entry.key)) {
        // WHY: 关键词命中记录匹配的具体关键词，便于排查误匹配
        debugPrint(
            '$_logTag infer 命中关键词: merchant="$merchant", keyword="${entry.key}" → category="${entry.value}", confidence=0.8');
        return InferredCategory(entry.value, 0.8);
      }
    }
    debugPrint('$_logTag infer 未命中关键词: merchant="$merchant"');

    // 3. 兜底
    debugPrint('$_logTag infer 兜底返回: merchant="$merchant", confidence=0.3');
    return const InferredCategory(null, 0.3);
  }

  /// 查询商户学习表
  ///
  /// @param merchant 商户名
  /// @return 学习到的分类名，未学习返回 null
  static String? _queryLearnedMap(String merchant) {
    try {
      return DatabaseService.merchantCategoryMap.get(merchant);
    } catch (e) {
      // WHY: 查询异常不应阻断推断流程，但需记录详细错误便于排查 Hive box 损坏等问题
      debugPrint(
          '$_logTag _queryLearnedMap 异常: merchant="$merchant", error=$e');
      return null;
    }
  }

  /// 学习商户-分类映射
  ///
  /// WHY: 用户确认后调用，后续相同商户自动套用此分类。
  ///
  /// @param merchant 商户名
  /// @param categoryName 用户最终选择的分类名
  static Future<void> learn(String merchant, String categoryName) async {
    debugPrint(
        '$_logTag learn 开始: merchant="$merchant" → category="$categoryName"');
    try {
      await DatabaseService.merchantCategoryMap.put(merchant, categoryName);
      debugPrint(
          '$_logTag learn 成功: merchant="$merchant" → category="$categoryName"');
    } catch (e) {
      // WHY: 保存失败是关键节点，记录详细错误便于排查 Hive 写入异常
      debugPrint(
          '$_logTag learn 失败: merchant="$merchant", category="$categoryName", error=$e');
      rethrow;
    }
  }

  /// 获取所有已学习商户
  ///
  /// @return 商户名 -> 分类名 的映射
  static Map<String, String> getAllLearned() {
    final result = <String, String>{};
    try {
      for (final key in DatabaseService.merchantCategoryMap.keys) {
        final value = DatabaseService.merchantCategoryMap.get(key);
        if (value != null && key is String) {
          result[key] = value;
        }
      }
      debugPrint('$_logTag getAllLearned 成功: 共 ${result.length} 条规则');
    } catch (e) {
      // WHY: 加载失败会导致规则列表为空，记录详细错误避免静默失败
      debugPrint('$_logTag getAllLearned 异常: error=$e');
    }
    return result;
  }

  /// 删除学习记录
  ///
  /// @param merchant 商户名
  static Future<void> forget(String merchant) async {
    debugPrint('$_logTag forget 开始: merchant="$merchant"');
    try {
      await DatabaseService.merchantCategoryMap.delete(merchant);
      debugPrint('$_logTag forget 成功: merchant="$merchant"');
    } catch (e) {
      // WHY: 删除失败需记录详细错误，避免用户误以为已删除但实际仍存在
      debugPrint('$_logTag forget 失败: merchant="$merchant", error=$e');
      rethrow;
    }
  }
}

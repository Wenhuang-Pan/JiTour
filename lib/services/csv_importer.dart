import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../utils/uuid_util.dart';

/// CSV 导入器
/// 
/// 支持多种格式的CSV文件导入，包括：
/// - 记途格式（时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券）
/// - 微信支付账单格式
/// - 支付宝账单格式
/// - 随手记格式
/// - 通用CSV格式
class CsvImporter {
  /// 解析CSV文件内容
  /// 
  /// @param csvContent CSV文件内容字符串
  /// @return 解析后的行数据列表，每行是字段名到值的映射
  static List<Map<String, String>> parseCsv(String csvContent) {
    final lines =
        csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = _parseLine(lines[0]);
    final result = <Map<String, String>>[];

    for (int i = 1; i < lines.length; i++) {
      final values = _parseLine(lines[i]);
      if (values.length >= headers.length) {
        final row = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          row[headers[j].trim()] = values[j].trim();
        }
        result.add(row);
      }
    }

    return result;
  }

  /// 解析日期字符串
  /// 
  /// @param dateString 日期字符串
  /// @return 解析后的DateTime对象，解析失败返回null
  static DateTime? parseDate(String dateString) {
    if (dateString.isEmpty) return null;

    // 尝试多种日期格式
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy/MM/dd HH:mm',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'yyyy年MM月dd日',
      'yyyy年MM月dd日 HH:mm',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateString);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(dateString);
  }

  /// 解析CSV行
  /// 
  /// @param line CSV行字符串
  /// @return 解析后的字段值列表
  static List<String> _parseLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString());
    return result;
  }

  /// 检测CSV格式类型
  /// 
  /// @param rows 解析后的行数据
  /// @return 检测到的格式字段列表
  static List<String> detectCsvFormat(List<Map<String, String>> rows) {
    if (rows.isEmpty) return [];

    final headers = rows[0].keys.toList();
    
    // 检测微信支付格式
    if (_isWeChatFormat(headers)) {
      return ['交易时间', '交易类型', '商品', '金额', '收/支', '备注'];
    }
    
    // 检测支付宝格式
    if (_isAlipayFormat(headers)) {
      return ['交易时间', '交易类型', '商品名称', '金额', '收/支', '备注'];
    }
    
    // 检测记途格式
    if (_isJituFormat(headers)) {
      return ['时间', '分类', '二级分类', '类型', '金额', '币种', '账户1', '账户2', '备注', '已报销', '手续费', '优惠券'];
    }
    
    // 检测随手记格式
    if (_isSuishoujiFormat(headers)) {
      return ['日期', '分类', '子分类', '金额', '账户', '备注', '收支类型'];
    }

    // 默认返回所有表头
    return headers;
  }

  /// 判断是否为微信支付格式
  static bool _isWeChatFormat(List<String> headers) {
    return headers.any((h) => h.contains('交易时间')) &&
           headers.any((h) => h.contains('收/支')) &&
           headers.any((h) => h.contains('金额'));
  }

  /// 判断是否为支付宝格式
  static bool _isAlipayFormat(List<String> headers) {
    return headers.any((h) => h.contains('交易时间')) &&
           headers.any((h) => h.contains('收/支')) &&
           headers.any((h) => h.contains('金额')) &&
           headers.any((h) => h.contains('商品名称'));
  }

  /// 判断是否为记途格式
  static bool _isJituFormat(List<String> headers) {
    return headers.any((h) => h.contains('时间')) &&
           headers.any((h) => h.contains('分类')) &&
           headers.any((h) => h.contains('类型')) &&
           headers.any((h) => h.contains('金额'));
  }

  /// 判断是否为随手记格式
  static bool _isSuishoujiFormat(List<String> headers) {
    return headers.any((h) => h.contains('日期')) &&
           headers.any((h) => h.contains('分类')) &&
           headers.any((h) => h.contains('金额')) &&
           headers.any((h) => h.contains('账户'));
  }

  /// 获取格式名称
  static String getFormatName(List<String> format) {
    if (format.contains('交易时间') && format.contains('收/支')) {
      if (format.contains('商品名称')) {
        return '支付宝账单';
      }
      return '微信支付账单';
    }
    if (format.contains('时间') && format.contains('分类') && format.contains('类型')) {
      return '记途格式';
    }
    if (format.contains('日期') && format.contains('子分类')) {
      return '随手记格式';
    }
    return '通用CSV格式';
  }

  /// 映射CSV字段到交易模型字段
  /// 
  /// @param detectedFormat 检测到的格式字段列表
  /// @param row CSV行数据
  /// @return 映射后的字段数据
  static Map<String, String> mapFields(
      List<String> detectedFormat, Map<String, String> row) {
    final mapping = <String, String>{
      'date': '',
      'category': '',
      'subCategory': '',
      'amount': '',
      'isIncome': 'false',
      'currency': 'CNY',
      'account': '',
      'account2': '',
      'note': '',
      'isReimbursed': 'false',
      'fee': '',
      'coupon': '',
    };

    final rowKeys = row.keys.toList();

    for (int i = 0; i < detectedFormat.length; i++) {
      final formatField = detectedFormat[i];
      String? matchedKey;

      for (final key in rowKeys) {
        if (key.toLowerCase().contains(formatField.toLowerCase()) ||
            formatField.toLowerCase().contains(key.toLowerCase())) {
          matchedKey = key;
          break;
        }
      }

      if (matchedKey != null) {
        switch (formatField.toLowerCase()) {
          case 'date':
          case '时间':
          case '日期':
          case '交易时间':
            mapping['date'] = row[matchedKey] ?? '';
            break;
          case 'category':
          case '分类':
          case '交易类型':
            mapping['category'] = row[matchedKey] ?? '';
            break;
          case '二级分类':
          case 'subcategory':
          case 'sub_category':
          case '子分类':
          case '商品':
          case '商品名称':
            mapping['subCategory'] = row[matchedKey] ?? '';
            break;
          case 'amount':
          case '金额':
            mapping['amount'] = row[matchedKey] ?? '';
            break;
          case 'currency':
          case '币种':
            mapping['currency'] = row[matchedKey] ?? 'CNY';
            break;
          case 'account':
          case '账户':
            if ((mapping['account'] ?? '').isEmpty) {
              mapping['account'] = row[matchedKey] ?? '';
            } else {
              mapping['account2'] = row[matchedKey] ?? '';
            }
            break;
          case '账户1':
            mapping['account'] = row[matchedKey] ?? '';
            break;
          case '账户2':
            mapping['account2'] = row[matchedKey] ?? '';
            break;
          case 'note':
          case '备注':
            mapping['note'] = row[matchedKey] ?? '';
            break;
          case 'type':
          case '类型':
          case '收支类型':
            final type = row[matchedKey] ?? '';
            mapping['isIncome'] = _parseTypeToIsIncome(type);
            break;
          case '收/支':
            final type = row[matchedKey] ?? '';
            mapping['isIncome'] = type.contains('收') ? 'true' : 'false';
            break;
          case '收入':
            final income =
                double.tryParse(row[matchedKey]?.replaceAll(',', '') ?? '0') ??
                    0;
            if (income > 0) {
              mapping['amount'] = income % 1 == 0
                  ? income.toInt().toString()
                  : income.toString();
              mapping['isIncome'] = 'true';
            }
            break;
          case '支出':
            final expense =
                double.tryParse(row[matchedKey]?.replaceAll(',', '') ?? '0') ??
                    0;
            if (expense > 0) {
              mapping['amount'] = expense % 1 == 0
                  ? expense.toInt().toString()
                  : expense.toString();
              mapping['isIncome'] = 'false';
            }
            break;
          case '已报销':
          case 'reimbursed':
            final value = row[matchedKey] ?? '';
            mapping['isReimbursed'] =
                value == '1' || value.toLowerCase() == 'true' || value == '是'
                    ? 'true'
                    : 'false';
            break;
          case '手续费':
          case 'fee':
            mapping['fee'] = row[matchedKey] ?? '';
            break;
          case '优惠券':
          case 'coupon':
            mapping['coupon'] = row[matchedKey] ?? '';
            break;
        }
      }
    }

    return mapping;
  }

  /// 解析类型字段为收入/支出标识
  static String _parseTypeToIsIncome(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('收入') || 
        lowerType.contains('income') || 
        lowerType.contains('in') ||
        lowerType.contains('转入') ||
        lowerType.contains('收款') ||
        lowerType.contains('存入')) {
      return 'true';
    }
    return 'false';
  }

  /// 解析金额字符串
  /// 
  /// @param amountStr 金额字符串
  /// @return 解析后的金额数值
  static double parseAmount(String amountStr) {
    final cleaned = amountStr.replaceAll(RegExp(r'[¥$€,，]'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  /// 将映射数据转换为交易对象
  /// 
  /// @param mapping 映射后的字段数据
  /// @return 交易对象，转换失败返回null
  static Transaction? mappingToTransaction(Map<String, String> mapping) {
    final date = parseDate(mapping['date'] ?? '');
    if (date == null) return null;

    final amount = parseAmount(mapping['amount'] ?? '');
    if (amount <= 0) return null;

    return Transaction(
      id: UuidUtil.generate(),
      amount: amount,
      isIncome: mapping['isIncome']?.toLowerCase() == 'true',
      category: mapping['category'] ?? '',
      account: mapping['account'] ?? '',
      date: date,
      note: mapping['note']?.isNotEmpty == true ? mapping['note'] : null,
      subCategory: mapping['subCategory']?.isNotEmpty == true
          ? mapping['subCategory']
          : null,
      currency: mapping['currency']?.isNotEmpty == true
          ? mapping['currency']!
          : 'CNY',
      account2:
          mapping['account2']?.isNotEmpty == true ? mapping['account2'] : null,
      isReimbursed: mapping['isReimbursed']?.toLowerCase() == 'true',
      fee: double.tryParse(mapping['fee'] ?? '') ?? 0.0,
      coupon: double.tryParse(mapping['coupon'] ?? '') ?? 0.0,
    );
  }
}

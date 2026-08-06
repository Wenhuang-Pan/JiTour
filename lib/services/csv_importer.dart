import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  /// 从原始字节解析CSV文件
  ///
  /// WHY: Flutter Web 端 FilePicker 返回的 bytes 可能被 JS 层按 Latin-1 解码，
  /// 导致直接 utf8.decode 失败。此方法尝试多种编码策略确保正确解码中文。
  ///
  /// @param bytes CSV文件的原始字节
  /// @return 解析后的行数据列表
  static List<Map<String, String>> parseCsvFromBytes(List<int> bytes) {
    debugPrint('[CsvImporter] === parseCsvFromBytes 开始 ===');
    debugPrint('[CsvImporter] bytes 长度: ${bytes.length}');
    debugPrint('[CsvImporter] 前30字节: ${bytes.take(30).toList()}');

    // 策略1: 直接 utf8.decode
    String content;
    try {
      content = utf8.decode(bytes);
      debugPrint(
          '[CsvImporter] 策略1 utf8.decode 前50字符: "${content.substring(0, content.length > 50 ? 50 : content.length)}"');
    } catch (e) {
      debugPrint('[CsvImporter] 策略1 utf8.decode 失败: $e');
      // 策略2: 降级到 latin1 再尝试
      content = latin1.decode(bytes);
      debugPrint(
          '[CsvImporter] 策略2 latin1.decode 前50字符: "${content.substring(0, content.length > 50 ? 50 : content.length)}"');
    }

    // WHY: 检测 Latin-1 误解码 UTF-8 的典型特征：
    // - "ï»¿" 是 UTF-8 BOM (EF BB BF) 被 Latin-1 解码的结果
    // - "æ" "å" "è" "é" 等是中文 UTF-8 多字节序列被 Latin-1 解码的典型字符
    if (content.contains('ï»¿') || _looksLikeMojibake(content)) {
      debugPrint('[CsvImporter] ⚠️ 检测到 Latin-1 误解码 UTF-8 特征，尝试修复编码');
      try {
        // WHY: latin1.encode 把每个字符转回原始字节(0-255)，
        // 然后 utf8.decode 正确解析这些字节为 UTF-8 字符串
        final rawBytes = latin1.encode(content);
        final fixed = utf8.decode(rawBytes);
        debugPrint(
            '[CsvImporter] 修复后前50字符: "${fixed.substring(0, fixed.length > 50 ? 50 : fixed.length)}"');
        content = fixed;
      } catch (e) {
        debugPrint('[CsvImporter] 编码修复失败: $e');
      }
    } else {
      debugPrint('[CsvImporter] 未检测到乱码特征，直接使用 utf8.decode 结果');
    }

    return parseCsv(content);
  }

  /// 检测字符串是否包含 Latin-1 误解码 UTF-8 的典型特征
  ///
  /// WHY: UTF-8 中文字节范围 E4-E9，被 Latin-1 解码后变成 æ/å/è/é/ç 等字符
  static bool _looksLikeMojibake(String s) {
    final sample = s.length > 200 ? s.substring(0, 200) : s;
    // WHY: 中文字符在 UTF-8 中是 3 字节(E4-E9开头)，Latin-1 解码后会产生
    // æ(0xE6) å(0xE5) è(0xE8) é(0xE9) ç(0xE7) ã(0xE3) ä(0xE4) 等字符
    final mojibakeChars =
        RegExp(r'[æåèéçãäðñöüïîíìëêéèçæåäãâáàðïîíìëêéèçæåäãâáà]');
    final matches = mojibakeChars.allMatches(sample).length;
    debugPrint('[CsvImporter] 乱码特征字符检测: $matches 个匹配');
    return matches > 5;
  }

  /// 解析CSV文件内容
  ///
  /// WHY: 处理 Excel 导出的 CSV 文件三大常见问题：
  /// 1. BOM (Byte Order Mark)：UTF-8 BOM 会导致首列表头异常
  /// 2. Windows CRLF 行尾：\r\n 行尾导致最后字段带 \r，数值解析失败
  /// 3. 空行过滤：避免空行产生异常记录
  ///
  /// @param csvContent CSV文件内容字符串
  /// @return 解析后的行数据列表，每行是字段名到值的映射
  static List<Map<String, String>> parseCsv(String csvContent) {
    debugPrint('[CsvImporter] === parseCsv 开始 ===');
    // WHY: 移除 UTF-8 BOM (Excel 保存的 CSV 常在文件头添加 BOM)
    var content = csvContent;
    final hasBom = content.isNotEmpty && content[0] == '\uFEFF';
    if (hasBom) {
      debugPrint('[CsvImporter] 检测到 UTF-8 BOM，已移除');
      content = content.substring(1);
    }

    // WHY: 统一行尾为 \n，先将 \r\n 转为 \n，再将 \r 转为 \n
    // 这样无论是 Windows (\r\n)、Linux (\n) 还是旧 Mac (\r) 都能正确处理
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final allLines = content.split('\n');
    final lines = allLines.where((line) => line.trim().isNotEmpty).toList();
    debugPrint(
        '[CsvImporter] 总行数(含空行): ${allLines.length}, 非空行数: ${lines.length}');
    if (lines.isEmpty) {
      debugPrint('[CsvImporter] ❌ parseCsv 返回空：无非空行');
      return [];
    }

    final headers = _parseLine(lines[0]);
    debugPrint('[CsvImporter] 表头字段数: ${headers.length}');
    debugPrint('[CsvImporter] 表头内容: $headers');
    final threshold = headers.length ~/ 2;
    debugPrint('[CsvImporter] 字段数阈值(>= 才保留): $threshold (headers.length~/2)');

    final result = <Map<String, String>>[];
    int skippedCount = 0;
    for (int i = 1; i < lines.length; i++) {
      final values = _parseLine(lines[i]);
      // WHY: 允许字段数少于表头数（末尾空列被 Excel 省略逗号时），
      // 缺少的字段视为空字符串；但如果比表头少太多（<50%）则跳过
      if (values.length >= threshold) {
        final row = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          // WHY: 如果 values 中没有对应索引，填空字符串（末尾空列被省略）
          final value = j < values.length ? values[j].trim() : '';
          row[headers[j].trim()] = value;
        }
        result.add(row);
        // 前3行详细日志
        if (i <= 3) {
          debugPrint(
              '[CsvImporter] 第$i行 ✅ 保留 (字段数: ${values.length}/${headers.length})');
          debugPrint('[CsvImporter]   row: $row');
        }
      } else {
        skippedCount++;
        if (skippedCount <= 3) {
          debugPrint(
              '[CsvImporter] 第$i行 ❌ 跳过 (字段数 ${values.length} < 阈值 $threshold)');
          debugPrint('[CsvImporter]   原始: "${lines[i]}"');
        }
      }
    }
    debugPrint(
        '[CsvImporter] parseCsv 完成: 保留 ${result.length} 行, 跳过 $skippedCount 行');
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
    debugPrint('[CsvImporter] === detectCsvFormat 开始 ===');
    if (rows.isEmpty) {
      debugPrint('[CsvImporter] ❌ rows 为空');
      return [];
    }

    final headers = rows[0].keys.toList();
    debugPrint('[CsvImporter] 待检测表头: $headers');

    // WHY: 记录每个格式检测函数的结果，便于定位误判
    debugPrint(
        '[CsvImporter] _isWeChatFormatV2: ${_isWeChatFormatV2(headers)}');
    debugPrint('[CsvImporter] _isWeChatFormat: ${_isWeChatFormat(headers)}');
    debugPrint('[CsvImporter] _isAlipayFormat: ${_isAlipayFormat(headers)}');
    debugPrint(
        '[CsvImporter] _isAlipayFormatSimple: ${_isAlipayFormatSimple(headers)}');
    debugPrint('[CsvImporter] _isJituFormat: ${_isJituFormat(headers)}');
    debugPrint(
        '[CsvImporter] _isSuishoujiFormat: ${_isSuishoujiFormat(headers)}');
    debugPrint('[CsvImporter] _isGenericFormat: ${_isGenericFormat(headers)}');

    // 检测微信支付格式（新版）
    if (_isWeChatFormatV2(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 微信支付格式(新版)');
      return ['交易时间', '交易类型', '商品', '金额', '收/支', '微信红包', '备注'];
    }

    // 检测微信支付格式（旧版）
    if (_isWeChatFormat(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 微信支付格式(旧版)');
      return ['交易时间', '交易类型', '商品', '金额', '收/支', '备注'];
    }

    // 检测支付宝格式
    if (_isAlipayFormat(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 支付宝格式');
      return ['交易时间', '交易类型', '商品名称', '金额', '收/支', '备注'];
    }

    // 检测支付宝格式（简化版）
    if (_isAlipayFormatSimple(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 支付宝格式(简化版)');
      return ['交易时间', '交易类型', '商品名称', '金额', '收/支', '备注'];
    }

    // 检测记途格式
    if (_isJituFormat(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 记途格式');
      return [
        '时间',
        '分类',
        '二级分类',
        '类型',
        '金额',
        '币种',
        '账户1',
        '账户2',
        '备注',
        '已报销',
        '手续费',
        '优惠券'
      ];
    }

    // 检测随手记格式
    if (_isSuishoujiFormat(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 随手记格式');
      return ['日期', '分类', '子分类', '金额', '账户', '备注', '收支类型'];
    }

    // 检测通用格式（包含日期、金额）
    if (_isGenericFormat(headers)) {
      debugPrint('[CsvImporter] ✅ 命中: 通用格式，返回原表头');
      return headers;
    }

    debugPrint('[CsvImporter] ⚠️ 未命中任何已知格式，返回原表头');
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

  /// 判断是否为微信支付格式（新版）
  static bool _isWeChatFormatV2(List<String> headers) {
    return headers.any((h) => h.contains('交易时间')) &&
        headers.any((h) => h.contains('收/支')) &&
        headers.any((h) => h.contains('金额')) &&
        headers.any((h) => h.contains('微信红包'));
  }

  /// 判断是否为支付宝格式（简化版）
  static bool _isAlipayFormatSimple(List<String> headers) {
    return headers.any((h) => h.contains('交易时间')) &&
        headers.any((h) => h.contains('金额')) &&
        headers.any((h) => h.contains('收/支'));
  }

  /// 判断是否为通用格式
  static bool _isGenericFormat(List<String> headers) {
    final headerLower = headers.map((h) => h.toLowerCase()).toList();
    return headerLower.any((h) =>
            h.contains('date') || h.contains('日期') || h.contains('时间')) &&
        headerLower.any((h) =>
            h.contains('amount') || h.contains('金额') || h.contains('price'));
  }

  /// 获取格式名称
  static String getFormatName(List<String> format) {
    if (format.contains('交易时间') && format.contains('收/支')) {
      if (format.contains('商品名称')) {
        return '支付宝账单';
      }
      if (format.contains('微信红包')) {
        return '微信支付账单';
      }
      return '微信支付账单';
    }
    if (format.contains('时间') &&
        format.contains('分类') &&
        format.contains('类型')) {
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
  /// @param debugRowIdx 调试行号(>=0 且 <3 时输出详细匹配日志)，默认-1不输出
  /// @return 映射后的字段数据
  static Map<String, String> mapFields(
      List<String> detectedFormat, Map<String, String> row,
      [int debugRowIdx = -1]) {
    final verbose = debugRowIdx >= 0 && debugRowIdx < 3;
    if (verbose) {
      debugPrint('[CsvImporter] === mapFields 第${debugRowIdx + 1}行 ===');
      debugPrint('[CsvImporter] row keys: ${row.keys.toList()}');
      debugPrint('[CsvImporter] row values: $row');
      debugPrint('[CsvImporter] detectedFormat: $detectedFormat');
    }

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
      String? matchStep;

      // WHY: 三步匹配策略，优先级从高到低：
      // 1. 精确匹配（完全相等）——最可靠
      // 2. 前缀/后缀精确匹配（如 "时间" 匹配 "交易时间"）
      // 3. 模糊包含匹配（如 "商户" 匹配 "对方商户名称"）
      // 关键改进：匹配时优先更长的 key，避免 "分类" 抢先匹配 "二级分类"
      for (final key in rowKeys) {
        if (key == formatField) {
          matchedKey = key;
          matchStep = '精确匹配';
          break;
        }
      }

      if (matchedKey == null) {
        // 第2步：前缀/后缀匹配，同时优先更长的 key
        for (final key in rowKeys) {
          if (key.startsWith(formatField) ||
              key.endsWith(formatField) ||
              formatField.startsWith(key) ||
              formatField.endsWith(key)) {
            // WHY: 只有当没有更长的 key 也匹配时才采用当前 key
            if (matchedKey == null || key.length > matchedKey.length) {
              matchedKey = key;
              matchStep = '前缀/后缀匹配';
            }
          }
        }
      }

      if (matchedKey == null) {
        // 第3步：模糊包含匹配，优先更长的 key
        for (final key in rowKeys) {
          if (key.contains(formatField) || formatField.contains(key)) {
            if (matchedKey == null || key.length > matchedKey.length) {
              matchedKey = key;
              matchStep = '模糊包含匹配';
            }
          }
        }
      }

      if (matchedKey == null) {
        // 第4步：_fieldMatches 分词匹配
        for (final key in rowKeys) {
          if (_fieldMatches(key, formatField)) {
            if (matchedKey == null || key.length > matchedKey.length) {
              matchedKey = key;
              matchStep = '分词匹配';
            }
          }
        }
      }

      if (verbose) {
        if (matchedKey != null) {
          final value = row[matchedKey]?.trim() ?? '';
          debugPrint(
              '[CsvImporter]   formatField="$formatField" → key="$matchedKey" ($matchStep) value="$value"');
        } else {
          debugPrint('[CsvImporter]   formatField="$formatField" ❌ 未匹配到任何key');
        }
      }

      if (matchedKey != null) {
        final value = row[matchedKey]?.trim() ?? '';
        final lowerField = formatField.toLowerCase();
        String? hitCase;

        switch (lowerField) {
          case 'date':
          case '时间':
          case '日期':
          case '交易时间':
          case '交易日期':
          case '发生时间':
            mapping['date'] = value;
            hitCase = 'date';
            break;
          case 'category':
          case '分类':
          case '交易类型':
            if (mapping['category']!.isEmpty) {
              mapping['category'] = value;
            } else if (mapping['subCategory']!.isEmpty) {
              mapping['subCategory'] = value;
            }
            hitCase = 'category';
            break;
          case '二级分类':
          case 'subcategory':
          case 'sub_category':
          case '子分类':
          case '商品':
          case '商品名称':
          case '商品说明':
          case '交易对象':
          case '商户名称':
          case '对方':
            if (mapping['subCategory']!.isEmpty) {
              mapping['subCategory'] = value;
            } else if (mapping['note']!.isEmpty) {
              mapping['note'] = value;
            }
            hitCase = 'subCategory';
            break;
          case 'amount':
          case '金额':
          case '交易金额':
            mapping['amount'] = value;
            hitCase = 'amount';
            break;
          case 'currency':
          case '币种':
            mapping['currency'] = value.isNotEmpty ? value : 'CNY';
            hitCase = 'currency';
            break;
          case 'account':
          case '账户':
          case '账户名称':
          case '支付方式':
          case '支付渠道':
          case '来源':
            if (mapping['account']!.isEmpty) {
              mapping['account'] = value;
            } else {
              mapping['account2'] = value;
            }
            hitCase = 'account';
            break;
          case '账户1':
            mapping['account'] = value;
            hitCase = 'account1';
            break;
          case '账户2':
            mapping['account2'] = value;
            hitCase = 'account2';
            break;
          case 'note':
          case '备注':
          case '说明':
          case '附言':
            if (mapping['note']!.isEmpty) {
              mapping['note'] = value;
            }
            hitCase = 'note';
            break;
          case 'type':
          case '类型':
          case '收支类型':
          case '交易性质':
            mapping['isIncome'] = _parseTypeToIsIncome(value);
            hitCase = 'type→isIncome';
            break;
          case '收/支':
          case '收支':
          case '收支方向':
            mapping['isIncome'] = value.contains('收') ? 'true' : 'false';
            hitCase = '收/支→isIncome';
            break;
          case '收入':
            final income = double.tryParse(value.replaceAll(',', '')) ?? 0;
            if (income > 0) {
              mapping['amount'] = income % 1 == 0
                  ? income.toInt().toString()
                  : income.toString();
              mapping['isIncome'] = 'true';
            }
            hitCase = '收入→amount';
            break;
          case '支出':
            final expense = double.tryParse(value.replaceAll(',', '')) ?? 0;
            if (expense > 0) {
              mapping['amount'] = expense % 1 == 0
                  ? expense.toInt().toString()
                  : expense.toString();
              mapping['isIncome'] = 'false';
            }
            hitCase = '支出→amount';
            break;
          case '已报销':
          case 'reimbursed':
          case '报销状态':
            final val = value.toLowerCase();
            mapping['isReimbursed'] =
                val == '1' || val == 'true' || val == '是' || val == '已报销'
                    ? 'true'
                    : 'false';
            hitCase = 'isReimbursed';
            break;
          case '手续费':
          case 'fee':
          case '服务费':
            mapping['fee'] = value;
            hitCase = 'fee';
            break;
          case '优惠券':
          case 'coupon':
          case '优惠金额':
          case '红包':
            mapping['coupon'] = value;
            hitCase = 'coupon';
            break;
        }
        if (verbose) {
          debugPrint('[CsvImporter]     switch case: "$hitCase"');
        }
      }
    }

    if (verbose) {
      debugPrint('[CsvImporter] 最终映射结果: $mapping');
    }
    return mapping;
  }

  /// 判断字段是否匹配（模糊匹配）
  static bool _fieldMatches(String key, String formatField) {
    final keyLower = key.toLowerCase();
    final formatLower = formatField.toLowerCase();

    final keyKeywords =
        keyLower.split(RegExp(r'[\s_,，-]')).where((k) => k.isNotEmpty).toList();
    final formatKeywords = formatLower
        .split(RegExp(r'[\s_,，-]'))
        .where((k) => k.isNotEmpty)
        .toList();

    for (final kw in formatKeywords) {
      if (keyKeywords.any((k) => k.contains(kw) || kw.contains(k))) {
        return true;
      }
    }

    return false;
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
    final dateStr = mapping['date'] ?? '';
    final amountStr = mapping['amount'] ?? '';
    final date = parseDate(dateStr);
    final amount = parseAmount(amountStr);

    if (date == null) {
      debugPrint('[CsvImporter] mappingToTransaction ❌ date 解析失败: "$dateStr"');
      debugPrint('[CsvImporter]   mapping: $mapping');
      return null;
    }
    if (amount <= 0) {
      debugPrint(
          '[CsvImporter] mappingToTransaction ❌ amount 无效: "$amountStr" → $amount');
      debugPrint('[CsvImporter]   mapping: $mapping');
      return null;
    }

    debugPrint(
        '[CsvImporter] mappingToTransaction ✅ date=$date, amount=$amount, isIncome=${mapping['isIncome']}, category="${mapping['category']}"');
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

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';

class CsvImporter {
  static const _uuid = Uuid();
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

  static DateTime? parseDate(String dateString) {
    if (dateString.isEmpty) return null;

    // Try more specific patterns first (with seconds and exact separators)
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

  static List<String> detectCsvFormat(List<Map<String, String>> rows) {
    if (rows.isEmpty) return [];

    final commonFormats = [
      [
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
      ],
      ['日期', '分类', '金额', '账户', '备注'],
      ['date', 'category', 'amount', 'account', 'note'],
      ['日期', '类型', '金额', '分类', '账户'],
      ['时间', '分类', '收入', '支出', '账户'],
    ];

    final headers = rows[0].keys.toList();

    for (final format in commonFormats) {
      int matchCount = 0;
      for (final field in format) {
        if (headers.any((h) =>
            h.toLowerCase().contains(field.toLowerCase()) ||
            field.toLowerCase().contains(h.toLowerCase()))) {
          matchCount++;
        }
      }
      if (matchCount >= format.length - 1) {
        return format;
      }
    }

    return headers;
  }

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
            mapping['date'] = row[matchedKey] ?? '';
            break;
          case 'category':
          case '分类':
            mapping['category'] = row[matchedKey] ?? '';
            break;
          case '二级分类':
          case 'subcategory':
          case 'sub_category':
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
            final type = row[matchedKey] ?? '';
            mapping['isIncome'] = type.toLowerCase().contains('收入') ||
                    type.toLowerCase().contains('income') ||
                    type.toLowerCase().contains('in')
                ? 'true'
                : 'false';
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

  static double parseAmount(String amountStr) {
    final cleaned = amountStr.replaceAll(RegExp(r'[¥$€,，]'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  static Transaction? mappingToTransaction(Map<String, String> mapping) {
    final date = parseDate(mapping['date'] ?? '');
    if (date == null) return null;

    final amount = parseAmount(mapping['amount'] ?? '');
    if (amount <= 0) return null;

    return Transaction(
      id: _uuid.v4(),
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

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/services/csv_importer.dart';

void main() {
  group('CsvImporter', () {
    group('parseCsv', () {
      test('解析简单CSV', () {
        const csv = '日期,分类,金额\n2024/01/01,餐饮,100.00\n2024/01/02,交通,50.00';
        final result = CsvImporter.parseCsv(csv);
        
        expect(result.length, 2);
        expect(result[0]['日期'], '2024/01/01');
        expect(result[0]['分类'], '餐饮');
        expect(result[0]['金额'], '100.00');
        expect(result[1]['日期'], '2024/01/02');
        expect(result[1]['分类'], '交通');
        expect(result[1]['金额'], '50.00');
      });

      test('解析包含空行的CSV', () {
        const csv = '日期,分类,金额\n\n2024/01/01,餐饮,100.00\n\n2024/01/02,交通,50.00\n';
        final result = CsvImporter.parseCsv(csv);
        
        expect(result.length, 2);
      });

      test('解析包含引号的CSV', () {
        const csv = '日期,分类,金额\n2024/01/01,"餐饮,外卖",100.00';
        final result = CsvImporter.parseCsv(csv);
        
        expect(result.length, 1);
        expect(result[0]['分类'], '餐饮,外卖');
      });

      test('解析包含双引号的CSV', () {
        const csv = '日期,备注\n2024/01/01,"订单编号""123"""';
        final result = CsvImporter.parseCsv(csv);
        
        expect(result.length, 1);
        expect(result[0]['备注'], '订单编号"123"');
      });
    });

    group('parseDate', () {
      test('解析yyyy/MM/dd格式', () {
        final date = CsvImporter.parseDate('2024/01/15');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
      });

      test('解析yyyy-MM-dd格式', () {
        final date = CsvImporter.parseDate('2024-01-15');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
      });

      test('解析yyyy/MM/dd HH:mm格式', () {
        final date = CsvImporter.parseDate('2024/01/15 14:30');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
        expect(date?.hour, 14);
        expect(date?.minute, 30);
      });

      test('解析yyyy-MM-dd HH:mm:ss格式', () {
        final date = CsvImporter.parseDate('2024-01-15 14:30:45');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
        expect(date?.hour, 14);
        expect(date?.minute, 30);
        expect(date?.second, 45);
      });

      test('解析dd/MM/yyyy格式', () {
        final date = CsvImporter.parseDate('15/01/2024');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
      });

      test('解析MM/dd/yyyy格式', () {
        final date = CsvImporter.parseDate('01/15/2024');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
      });

      test('解析中文日期格式', () {
        final date = CsvImporter.parseDate('2024年01月15日');
        expect(date?.year, 2024);
        expect(date?.month, 1);
        expect(date?.day, 15);
      });

      test('解析无效日期返回null', () {
        final date = CsvImporter.parseDate('invalid-date');
        expect(date, isNull);
      });

      test('解析空字符串返回null', () {
        final date = CsvImporter.parseDate('');
        expect(date, isNull);
      });
    });

    group('parseAmount', () {
      test('解析普通数字', () {
        expect(CsvImporter.parseAmount('100'), Decimal.parse('100'));
        expect(CsvImporter.parseAmount('100.50'), Decimal.parse('100.50'));
      });

      test('解析带千位分隔符的数字', () {
        expect(CsvImporter.parseAmount('1,000'), Decimal.parse('1000'));
        expect(CsvImporter.parseAmount('1,234.56'), Decimal.parse('1234.56'));
        expect(CsvImporter.parseAmount('1，234.56'), Decimal.parse('1234.56'));
      });

      test('解析带货币符号的数字', () {
        expect(CsvImporter.parseAmount('¥100'), Decimal.parse('100'));
        expect(CsvImporter.parseAmount('¥1,000.50'), Decimal.parse('1000.50'));
        expect(CsvImporter.parseAmount(r'$100'), Decimal.parse('100'));
        expect(CsvImporter.parseAmount('€100'), Decimal.parse('100'));
      });

      test('解析无效金额返回0', () {
        expect(CsvImporter.parseAmount('invalid'), Decimal.zero);
        expect(CsvImporter.parseAmount(''), Decimal.zero);
      });
    });

    group('detectCsvFormat', () {
      test('检测常见中文格式', () {
        final rows = [
          {'日期': '2024/01/01', '分类': '餐饮', '金额': '100', '账户': '现金', '备注': ''}
        ];
        final format = CsvImporter.detectCsvFormat(rows);
        
        expect(format, isNotEmpty);
      });

      test('检测常见英文格式', () {
        final rows = [
          {'date': '2024/01/01', 'category': 'Food', 'amount': '100', 'account': 'Cash', 'note': ''}
        ];
        final format = CsvImporter.detectCsvFormat(rows);
        
        expect(format, isNotEmpty);
      });

      test('空行返回空列表', () {
        final format = CsvImporter.detectCsvFormat([]);
        expect(format, isEmpty);
      });
    });

    group('mapFields', () {
      test('映射标准字段', () {
        final row = {
          '日期': '2024/01/01',
          '分类': '餐饮',
          '金额': '100',
          '账户': '现金',
          '备注': '午餐'
        };
        final format = ['日期', '分类', '金额', '账户', '备注'];
        final mapping = CsvImporter.mapFields(format, row);
        
        expect(mapping['date'], '2024/01/01');
        expect(mapping['category'], '餐饮');
        expect(mapping['amount'], '100');
        expect(mapping['account'], '现金');
        expect(mapping['note'], '午餐');
      });

      test('映射收入/支出类型', () {
        final row = {'类型': '收入', '金额': '5000'};
        final format = ['类型', '金额'];
        final mapping = CsvImporter.mapFields(format, row);
        
        expect(mapping['isIncome'], 'true');
        expect(mapping['amount'], '5000');
      });

      test('映射单独的收入/支出字段', () {
        final row = {'收入': '5000', '支出': '0'};
        final format = ['收入', '支出'];
        final mapping = CsvImporter.mapFields(format, row);
        
        expect(mapping['isIncome'], 'true');
        expect(mapping['amount'], '5000');
      });
    });

    group('mappingToTransaction', () {
      test('有效映射创建交易', () {
        final mapping = {
          'date': '2024/01/01',
          'category': '餐饮',
          'amount': '100',
          'account': '现金',
          'isIncome': 'false',
          'currency': 'CNY'
        };
        final transaction = CsvImporter.mappingToTransaction(mapping);
        
        expect(transaction, isNotNull);
        expect(transaction!.amount, Decimal.parse('100'));
        expect(transaction.isIncome, false);
        expect(transaction.category, '餐饮');
        expect(transaction.account, '现金');
        expect(transaction.date.year, 2024);
      });

      test('无效日期返回null', () {
        final mapping = {
          'date': '',
          'category': '餐饮',
          'amount': '100',
          'account': '现金'
        };
        final transaction = CsvImporter.mappingToTransaction(mapping);
        
        expect(transaction, isNull);
      });

      test('无效金额返回null', () {
        final mapping = {
          'date': '2024/01/01',
          'category': '餐饮',
          'amount': '',
          'account': '现金'
        };
        final transaction = CsvImporter.mappingToTransaction(mapping);
        
        expect(transaction, isNull);
      });

      test('负金额返回null', () {
        final mapping = {
          'date': '2024/01/01',
          'category': '餐饮',
          'amount': '-100',
          'account': '现金'
        };
        final transaction = CsvImporter.mappingToTransaction(mapping);
        
        expect(transaction, isNull);
      });
    });
  });
}

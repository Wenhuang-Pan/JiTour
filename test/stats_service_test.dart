import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/models/transaction.dart';
import 'package:jitu/services/stats_service.dart';

/// StatsService 纯函数聚合测试
///
/// WHY: 统计报表的收入/支出聚合、分类汇总、趋势与年度数据是图表核心，
/// 此处固化关键计算行为防止重构回归
void main() {
  final now = DateTime.now();

  /// 构造内存交易对象（不落库，仅参与纯函数计算）
  Transaction makeTx({
    required String id,
    required Decimal amount,
    required bool isIncome,
    String category = '餐饮',
    String account = '现金',
    required DateTime date,
  }) =>
      Transaction(
        id: id,
        amount: amount,
        isIncome: isIncome,
        category: category,
        account: account,
        date: date,
      );

  group('calculateTotal', () {
    test('按收支方向分别求和', () {
      final list = [
        makeTx(
            id: '1',
            amount: Decimal.parse('10.50'),
            isIncome: false,
            date: now),
        makeTx(
            id: '2',
            amount: Decimal.parse('20.00'),
            isIncome: false,
            date: now),
        makeTx(
            id: '3',
            amount: Decimal.parse('100.00'),
            isIncome: true,
            date: now),
      ];
      expect(StatsService.calculateTotal(list, false), Decimal.parse('30.50'));
      expect(StatsService.calculateTotal(list, true), Decimal.parse('100.00'));
    });

    test('空列表返回零', () {
      expect(StatsService.calculateTotal(<Transaction>[], true), Decimal.zero);
    });
  });

  group('calculateCategoryStats', () {
    test('按分类聚合支出金额', () {
      final list = [
        makeTx(
            id: '1',
            amount: Decimal.parse('15.00'),
            isIncome: false,
            date: now),
        makeTx(
            id: '2',
            amount: Decimal.parse('25.50'),
            isIncome: false,
            category: '交通',
            date: now),
        makeTx(
            id: '3', amount: Decimal.parse('5.00'), isIncome: false, date: now),
        makeTx(
            id: '4', amount: Decimal.parse('99.00'), isIncome: true, date: now),
      ];
      final stats = StatsService.calculateCategoryStats(list, false);
      expect(stats['餐饮'], Decimal.parse('20.00'));
      expect(stats['交通'], Decimal.parse('25.50'));
      // WHY: 收入交易不得混入支出分类统计
      expect(stats.containsKey('99.00'), isFalse);
      expect(stats.length, 2);
    });
  });

  group('calculateTrendData', () {
    test('返回近 6 个月数据，键为 yyyy-MM，当月聚合正确', () {
      final list = [
        makeTx(
            id: '1', amount: Decimal.parse('50.00'), isIncome: true, date: now),
        makeTx(
            id: '2',
            amount: Decimal.parse('30.00'),
            isIncome: false,
            date: now),
      ];
      final trend = StatsService.calculateTrendData(list);
      expect(trend.length, 6);
      final nowKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      expect(trend[nowKey]!['income'], Decimal.parse('50.00'));
      expect(trend[nowKey]!['expense'], Decimal.parse('30.00'));
    });

    test('无交易月份为 0 而非缺失', () {
      final trend = StatsService.calculateTrendData(<Transaction>[]);
      expect(trend.length, 6);
      for (final data in trend.values) {
        expect(data['income'], Decimal.zero);
        expect(data['expense'], Decimal.zero);
      }
    });
  });

  group('calculateMaxY', () {
    test('取全组最大值放大 1.2 倍', () {
      final data = <String, Map<String, Decimal>>{
        '2026-01': {
          'income': Decimal.parse('100'),
          'expense': Decimal.parse('50')
        },
        '2026-02': {
          'income': Decimal.parse('80'),
          'expense': Decimal.parse('120')
        },
      };
      expect(StatsService.calculateMaxY(data), closeTo(144.0, 0.001));
    });

    test('空数据回退默认 1000', () {
      expect(
          StatsService.calculateMaxY(<String, Map<String, Decimal>>{}), 1000);
    });
  });

  group('calculateChangeRate', () {
    test('正常增长计算', () {
      // WHY: 返回值为百分比数值——(120-100)/100*100 = 20.0 表示 20%
      expect(StatsService.calculateChangeRate(120, 100), closeTo(20.0, 0.0001));
    });

    test('上期为零时不做除法，返回 null', () {
      expect(StatsService.calculateChangeRate(50, 0), isNull);
    });

    test('两期均为零返回 null', () {
      expect(StatsService.calculateChangeRate(0, 0), isNull);
    });
  });
}

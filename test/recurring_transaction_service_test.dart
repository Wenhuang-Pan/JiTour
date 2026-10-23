import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/models/recurring_transaction.dart';
import 'package:jitu/services/account_service.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/services/recurring_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecurringTransactionService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_recurring_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      await DatabaseService.recurringTransactions.clear();
      await DatabaseService.transactions.clear();
      await AccountService.box.clear();
    });

    tearDown(() async {
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    /// 构造一个定期交易辅助方法
    RecurringTransaction makeRecurring({
      String id = 'rt1',
      String name = '房租',
      bool isIncome = false,
      String amount = '3000.00',
      String category = '住房',
      String account = '银行卡',
      String frequency = 'monthly',
      DateTime? startDate,
      DateTime? endDate,
      DateTime? nextExecutionDate,
      bool isEnabled = true,
      DateTime? lastExecutedDate,
    }) {
      return RecurringTransaction(
        id: id,
        name: name,
        isIncome: isIncome,
        amount: Decimal.parse(amount),
        category: category,
        account: account,
        frequency: frequency,
        startDate: startDate ?? DateTime(2026, 1, 1),
        endDate: endDate,
        nextExecutionDate: nextExecutionDate,
        isEnabled: isEnabled,
        lastExecutedDate: lastExecutedDate,
      );
    }

    group('CRUD', () {
      test('add 后可通过 get 取回', () async {
        final rt = makeRecurring();
        await RecurringTransactionService.addRecurringTransaction(rt);

        final fetched =
            RecurringTransactionService.getRecurringTransaction(rt.id);
        expect(fetched, isNotNull);
        expect(fetched!.name, '房租');
        expect(fetched.amount, Decimal.parse('3000.00'));
      });

      test('delete 后 get 返回 null', () async {
        final rt = makeRecurring();
        await RecurringTransactionService.addRecurringTransaction(rt);
        await RecurringTransactionService.deleteRecurringTransaction(rt.id);

        expect(
            RecurringTransactionService.getRecurringTransaction(rt.id), isNull);
      });

      test('update 更新字段', () async {
        final rt = makeRecurring();
        await RecurringTransactionService.addRecurringTransaction(rt);

        rt.name = '房租(涨)';
        rt.amount = Decimal.parse('3500.00');
        await RecurringTransactionService.updateRecurringTransaction(rt);

        final fetched =
            RecurringTransactionService.getRecurringTransaction(rt.id);
        expect(fetched!.name, '房租(涨)');
        expect(fetched.amount, Decimal.parse('3500.00'));
      });
    });

    group('getAllRecurringTransactions', () {
      test('includeDisabled=false 过滤已禁用', () async {
        await RecurringTransactionService.addRecurringTransaction(
            makeRecurring(id: '1', isEnabled: true));
        await RecurringTransactionService.addRecurringTransaction(
            makeRecurring(id: '2', isEnabled: false));

        final all = RecurringTransactionService.getAllRecurringTransactions();
        expect(all.length, 2);

        final enabled = RecurringTransactionService.getAllRecurringTransactions(
            includeDisabled: false);
        expect(enabled.length, 1);
        expect(enabled[0].id, '1');
      });
    });

    group('executeRecurringTransaction', () {
      test('支出执行：生成交易并扣减余额', () async {
        await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2196F3,
          initialBalance: Decimal.parse('10000.00'),
        );

        final rt = makeRecurring(
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        await RecurringTransactionService.addRecurringTransaction(rt);

        final tx =
            await RecurringTransactionService.executeRecurringTransaction(rt);
        expect(tx, isNotNull);
        expect(tx!.amount, Decimal.parse('3000.00'));
        expect(tx.isIncome, isFalse);

        final account = AccountService.getAccountByName('银行卡');
        expect(account!.currentBalance, Decimal.parse('7000.00'));
      });

      test('收入执行：余额增加', () async {
        await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2196F3,
          initialBalance: Decimal.parse('10000.00'),
        );

        final rt = makeRecurring(
          isIncome: true,
          amount: '5000.00',
          category: '工资',
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        await RecurringTransactionService.executeRecurringTransaction(rt);

        final account = AccountService.getAccountByName('银行卡');
        expect(account!.currentBalance, Decimal.parse('15000.00'));
      });

      test('当天重复执行返回 null（幂等）', () async {
        final rt = makeRecurring(
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        final first =
            await RecurringTransactionService.executeRecurringTransaction(rt);
        expect(first, isNotNull);

        // WHY: 同一天内再次执行应返回 null，防止重复生成交易
        final second =
            await RecurringTransactionService.executeRecurringTransaction(rt);
        expect(second, isNull);
      });

      test('执行后 lastExecutedDate 更新为今天', () async {
        final rt = makeRecurring(
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        await RecurringTransactionService.executeRecurringTransaction(rt);

        expect(rt.lastExecutedDate, isNotNull);
        final now = DateTime.now();
        expect(rt.lastExecutedDate!.year, now.year);
        expect(rt.lastExecutedDate!.month, now.month);
        expect(rt.lastExecutedDate!.day, now.day);
      });
    });

    group('isExecutedToday', () {
      test('从未执行返回 false', () {
        final rt = makeRecurring();
        expect(RecurringTransactionService.isExecutedToday(rt), isFalse);
      });

      test('今天执行过返回 true', () {
        final rt = makeRecurring(lastExecutedDate: DateTime.now());
        expect(RecurringTransactionService.isExecutedToday(rt), isTrue);
      });

      test('昨天执行过返回 false', () {
        final rt = makeRecurring(
            lastExecutedDate: DateTime.now().subtract(const Duration(days: 1)));
        expect(RecurringTransactionService.isExecutedToday(rt), isFalse);
      });
    });

    group('shouldExecute / isExpired', () {
      test('nextExecutionDate 在过去 → shouldExecute 为 true', () {
        final rt = makeRecurring(
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(rt.shouldExecute, isTrue);
      });

      test('nextExecutionDate 在未来 → shouldExecute 为 false', () {
        final rt = makeRecurring(
          nextExecutionDate: DateTime.now().add(const Duration(days: 1)),
        );
        expect(rt.shouldExecute, isFalse);
      });

      test('已禁用 → shouldExecute 为 false', () {
        final rt = makeRecurring(
          isEnabled: false,
          nextExecutionDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(rt.shouldExecute, isFalse);
      });

      test('endDate 已过 → isExpired 为 true', () {
        final rt = makeRecurring(
          endDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(rt.isExpired, isTrue);
      });

      test('无 endDate → isExpired 为 false', () {
        final rt = makeRecurring();
        expect(rt.isExpired, isFalse);
      });
    });

    group('calculateNextExecutionDate', () {
      test('daily：基准+1天', () {
        final rt = makeRecurring(frequency: 'daily');
        final now = DateTime.now();
        // WHY: fromDate 为今天，基础计算明天，明天在未来不触发推进
        final next = rt.calculateNextExecutionDate(fromDate: now);
        expect(next.difference(now).inDays, 1);
      });

      test('weekly：基准+7天', () {
        final rt = makeRecurring(frequency: 'weekly');
        final now = DateTime.now();
        final next = rt.calculateNextExecutionDate(fromDate: now);
        expect(next.difference(now).inDays, 7);
      });

      test('monthly：基准+1月', () {
        final rt = makeRecurring(frequency: 'monthly');
        final now = DateTime.now();
        final next = rt.calculateNextExecutionDate(fromDate: now);
        final expectedMonth = now.month == 12 ? 1 : now.month + 1;
        expect(next.month, expectedMonth);
      });

      test('monthly 月末：1月31日基准不抛异常且日期合法', () {
        final rt = makeRecurring(frequency: 'monthly');
        // WHY: 1 月 31 日 +1 月会触发月末处理（2 月没有 31 日），
        // 验证 catch 分支取当月最后一天的逻辑不抛异常
        final next =
            rt.calculateNextExecutionDate(fromDate: DateTime(2026, 1, 31));
        expect(next.day, lessThanOrEqualTo(31));
        // 推进逻辑保证结果在未来
        expect(next.isAfter(DateTime.now()), isTrue);
      });

      test('yearly：基准+1年', () {
        final rt = makeRecurring(frequency: 'yearly');
        final now = DateTime.now();
        final next = rt.calculateNextExecutionDate(fromDate: now);
        expect(next.year, now.year + 1);
      });
    });

    group('getStats', () {
      test('统计启用的收支总额与数量', () async {
        await RecurringTransactionService.addRecurringTransaction(
            makeRecurring(id: '1', isIncome: false, amount: '3000'));
        await RecurringTransactionService.addRecurringTransaction(makeRecurring(
            id: '2', isIncome: true, amount: '8000', category: '工资'));
        await RecurringTransactionService.addRecurringTransaction(
            makeRecurring(id: '3', isEnabled: false, amount: '500'));

        final stats = RecurringTransactionService.getStats();
        expect(stats['totalCount'], 3);
        expect(stats['enabledCount'], 2);
        expect(stats['monthlyExpense'], Decimal.parse('3000'));
        expect(stats['monthlyIncome'], Decimal.parse('8000'));
      });
    });

    group('toggleStatus', () {
      test('禁用后 isEnabled 为 false', () async {
        final rt = makeRecurring();
        await RecurringTransactionService.addRecurringTransaction(rt);

        await RecurringTransactionService.toggleStatus(rt.id, false);

        final fetched =
            RecurringTransactionService.getRecurringTransaction(rt.id);
        expect(fetched!.isEnabled, isFalse);
      });
    });
  });
}

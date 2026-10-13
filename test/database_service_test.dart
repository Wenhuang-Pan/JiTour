import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/models/transaction.dart';
import 'package:jitu/models/budget.dart';

void main() {
  group('DatabaseService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      await DatabaseService.transactions.clear();
      await DatabaseService.budgets.clear();
    });

    tearDown(() async {
      await DatabaseService.transactions.clear();
      await DatabaseService.budgets.clear();
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    group('Transaction', () {
      test('创建交易', () async {
        final transaction = Transaction(
          id: 'test-transaction-1',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 15),
          note: '午餐',
        );

        await DatabaseService.addTransaction(transaction);

        final stored = DatabaseService.transactions.get('test-transaction-1');
        expect(stored, isNotNull);
        expect(stored?.amount, Decimal.parse('100.0'));
        expect(stored?.category, '餐饮');
        expect(stored?.note, '午餐');
      });

      test('删除交易', () async {
        final transaction = Transaction(
          id: 'test-transaction-delete',
          amount: Decimal.parse('50.0'),
          isIncome: false,
          category: '交通',
          account: '现金',
          date: DateTime(2024, 1, 15),
        );

        await DatabaseService.addTransaction(transaction);
        await DatabaseService.deleteTransaction('test-transaction-delete');

        final stored =
            DatabaseService.transactions.get('test-transaction-delete');
        expect(stored, isNull);
      });

      test('获取所有交易按日期排序', () async {
        await DatabaseService.transactions.clear();

        final transaction1 = Transaction(
          id: 'trans-1',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 10),
        );
        final transaction2 = Transaction(
          id: 'trans-2',
          amount: Decimal.parse('200.0'),
          isIncome: false,
          category: '购物',
          account: '银行卡',
          date: DateTime(2024, 1, 15),
        );
        final transaction3 = Transaction(
          id: 'trans-3',
          amount: Decimal.parse('5000.0'),
          isIncome: true,
          category: '工资',
          account: '银行卡',
          date: DateTime(2024, 1, 5),
        );

        await DatabaseService.addTransaction(transaction1);
        await DatabaseService.addTransaction(transaction2);
        await DatabaseService.addTransaction(transaction3);

        final transactions = DatabaseService.getAllTransactions();

        expect(transactions.length, 3);
        expect(transactions[0].date, DateTime(2024, 1, 15));
        expect(transactions[1].date, DateTime(2024, 1, 10));
        expect(transactions[2].date, DateTime(2024, 1, 5));
      });

      test('获取日期范围内的交易', () async {
        await DatabaseService.transactions.clear();

        final transaction1 = Transaction(
          id: 'range-1',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 10),
        );
        final transaction2 = Transaction(
          id: 'range-2',
          amount: Decimal.parse('200.0'),
          isIncome: false,
          category: '购物',
          account: '银行卡',
          date: DateTime(2024, 1, 15),
        );
        final transaction3 = Transaction(
          id: 'range-3',
          amount: Decimal.parse('5000.0'),
          isIncome: true,
          category: '工资',
          account: '银行卡',
          date: DateTime(2024, 2, 1),
        );

        await DatabaseService.addTransaction(transaction1);
        await DatabaseService.addTransaction(transaction2);
        await DatabaseService.addTransaction(transaction3);

        final transactions = DatabaseService.getTransactionsInRange(
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 31),
        );

        expect(transactions.length, 2);
        expect(transactions.any((t) => t.id == 'range-3'), false);
      });

      test('交易软删除', () async {
        final transaction = Transaction(
          id: 'soft-delete-test',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 15),
        );

        await DatabaseService.addTransaction(transaction);
        transaction.softDelete();

        final stored = DatabaseService.transactions.get('soft-delete-test');
        expect(stored?.isDeleted, true);
        expect(stored?.deletedAt, isNotNull);
      });

      test('恢复已删除的交易', () async {
        final transaction = Transaction(
          id: 'restore-test',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 15),
        );

        await DatabaseService.addTransaction(transaction);
        transaction.softDelete();
        transaction.restore();

        final stored = DatabaseService.transactions.get('restore-test');
        expect(stored?.isDeleted, false);
        expect(stored?.deletedAt, isNull);
      });

      test('交易标签管理', () async {
        final transaction = Transaction(
          id: 'tags-test',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 15),
        );

        expect(transaction.tagIds, isEmpty);

        transaction.addTag('tag-1');
        expect(transaction.tagIds, ['tag-1']);

        transaction.addTag('tag-2');
        expect(transaction.tagIds, ['tag-1', 'tag-2']);

        transaction.addTag('tag-1');
        expect(transaction.tagIds, ['tag-1', 'tag-2']);

        transaction.removeTag('tag-1');
        expect(transaction.tagIds, ['tag-2']);

        transaction.clearTags();
        expect(transaction.tagIds, isEmpty);
      });

      test('交易默认值', () {
        final transaction = Transaction(
          id: 'defaults-test',
          amount: Decimal.parse('100.0'),
          isIncome: false,
          category: '餐饮',
          account: '现金',
          date: DateTime(2024, 1, 15),
        );

        expect(transaction.currency, 'CNY');
        expect(transaction.isReimbursed, false);
        expect(transaction.fee, Decimal.parse('0.0'));
        expect(transaction.coupon, Decimal.parse('0.0'));
        expect(transaction.note, isNull);
        expect(transaction.subCategory, isNull);
        expect(transaction.account2, isNull);
      });
    });

    group('Budget', () {
      test('创建预算', () async {
        final budget = Budget(
          id: 'test-budget-1',
          category: '餐饮',
          amount: Decimal.parse('2000.0'),
          year: 2024,
          month: 1,
        );

        await DatabaseService.addBudget(budget);

        final stored = DatabaseService.budgets.get('test-budget-1');
        expect(stored, isNotNull);
        expect(stored?.category, '餐饮');
        expect(stored?.amount, Decimal.parse('2000.0'));
        expect(stored?.year, 2024);
        expect(stored?.month, 1);
      });

      test('更新预算', () async {
        final budget = Budget(
          id: 'test-budget-update',
          category: '餐饮',
          amount: Decimal.parse('2000.0'),
          year: 2024,
          month: 1,
        );

        await DatabaseService.addBudget(budget);
        budget.amount = Decimal.parse('3000.0');
        await DatabaseService.updateBudget(budget);

        final updated = DatabaseService.budgets.get('test-budget-update');
        expect(updated?.amount, Decimal.parse('3000.0'));
      });

      test('删除预算', () async {
        final budget = Budget(
          id: 'test-budget-delete',
          category: '交通',
          amount: Decimal.parse('500.0'),
          year: 2024,
          month: 1,
        );

        await DatabaseService.addBudget(budget);
        await DatabaseService.deleteBudget('test-budget-delete');

        final stored = DatabaseService.budgets.get('test-budget-delete');
        expect(stored, isNull);
      });

      test('获取指定月份的预算', () async {
        await DatabaseService.budgets.clear();

        final budget1 = Budget(
          id: 'month-budget-1',
          category: '餐饮',
          amount: Decimal.parse('2000.0'),
          year: 2024,
          month: 1,
        );
        final budget2 = Budget(
          id: 'month-budget-2',
          category: '交通',
          amount: Decimal.parse('500.0'),
          year: 2024,
          month: 1,
        );
        final budget3 = Budget(
          id: 'month-budget-3',
          category: '餐饮',
          amount: Decimal.parse('2000.0'),
          year: 2024,
          month: 2,
        );

        await DatabaseService.addBudget(budget1);
        await DatabaseService.addBudget(budget2);
        await DatabaseService.addBudget(budget3);

        final januaryBudgets = DatabaseService.getBudgetsForMonth(2024, 1);
        expect(januaryBudgets.length, 2);
        expect(januaryBudgets.any((b) => b.category == '交通'), true);
        expect(januaryBudgets.any((b) => b.category == '餐饮'), true);
      });

      test('获取指定分类和月份的预算', () async {
        await DatabaseService.budgets.clear();

        final budget1 = Budget(
          id: 'category-budget-1',
          category: '餐饮',
          amount: Decimal.parse('2000.0'),
          year: 2024,
          month: 1,
        );
        final budget2 = Budget(
          id: 'category-budget-2',
          category: '餐饮',
          amount: Decimal.parse('2500.0'),
          year: 2024,
          month: 2,
        );

        await DatabaseService.addBudget(budget1);
        await DatabaseService.addBudget(budget2);

        final januaryFoodBudget =
            DatabaseService.getBudgetForCategory('餐饮', 2024, 1);
        final februaryFoodBudget =
            DatabaseService.getBudgetForCategory('餐饮', 2024, 2);
        final marchFoodBudget =
            DatabaseService.getBudgetForCategory('餐饮', 2024, 3);

        expect(januaryFoodBudget?.amount, Decimal.parse('2000.0'));
        expect(februaryFoodBudget?.amount, Decimal.parse('2500.0'));
        expect(marchFoodBudget, isNull);
      });
    });
  });
}

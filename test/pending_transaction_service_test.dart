import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:decimal/decimal.dart';
import 'package:jitu/models/pending_transaction.dart';
import 'package:jitu/services/account_service.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/services/pending_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PendingTransactionService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_pending_');
      Hive.init(tmpDir.path);
      // WHY: DatabaseService.init() 会打开所有 box 并注册适配器，
      // PendingTransactionService 才能访问 pendingTransactions 和 transactions
      await DatabaseService.init();
      await DatabaseService.pendingTransactions.clear();
      await DatabaseService.transactions.clear();
      await AccountService.box.clear();
    });

    tearDown(() async {
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    group('create', () {
      test('创建待确认交易并持久化', () async {
        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('38.00'),
          source: PaymentSource.alipay,
          rawText: '你在星巴克消费了38.00元',
          merchant: '星巴克',
          inferredCategory: '餐饮',
          confidence: 0.9,
        );

        expect(pending.amount, Decimal.parse('38.00'));
        expect(pending.source, PaymentSource.alipay);
        expect(pending.merchant, '星巴克');
        expect(pending.inferredCategory, '餐饮');
        expect(pending.confidence, 0.9);
        expect(pending.status, PendingStatus.pending);
        expect(pending.isIncome, isFalse);
        expect(pending.id, isNotEmpty);

        // WHY: 持久化后从 box 读取应一致
        final stored = DatabaseService.pendingTransactions.get(pending.id);
        expect(stored, isNotNull);
        expect(stored!.amount, Decimal.parse('38.00'));
      });

      test('收入场景 isIncome 为 true', () async {
        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('100.00'),
          source: PaymentSource.wechat,
          rawText: '微信支付收款成功100.00元',
          isIncome: true,
        );
        expect(pending.isIncome, isTrue);
      });
    });

    group('getAll / getPending', () {
      test('getAll 按创建时间倒序排列', () async {
        await PendingTransactionService.create(
            amount: Decimal.parse('10'),
            source: PaymentSource.alipay,
            rawText: 'a');
        await PendingTransactionService.create(
            amount: Decimal.parse('20'),
            source: PaymentSource.wechat,
            rawText: 'b');

        final list = PendingTransactionService.getAll();
        expect(list.length, 2);
        // WHY: 倒序——后创建的排在前面
        expect(list[0].amount, Decimal.parse('20'));
        expect(list[1].amount, Decimal.parse('10'));
      });

      test('getPending 仅返回 pending 状态', () async {
        final p1 = await PendingTransactionService.create(
            amount: Decimal.parse('10'),
            source: PaymentSource.alipay,
            rawText: 'a');
        await PendingTransactionService.create(
            amount: Decimal.parse('20'),
            source: PaymentSource.wechat,
            rawText: 'b');
        await PendingTransactionService.discard(p1.id);

        final pending = PendingTransactionService.getPending();
        expect(pending.length, 1);
        expect(pending[0].amount, Decimal.parse('20'));
      });
    });

    group('confirm', () {
      test('确认支出交易：创建正式交易并扣减余额', () async {
        // WHY: 测试余额联动需先创建账户
        await AccountService.createAccount(
          name: '零钱',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: Decimal.parse('1000.00'),
        );

        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('38.00'),
          source: PaymentSource.alipay,
          rawText: '你在星巴克消费了38.00元',
          merchant: '星巴克',
        );

        final tx = await PendingTransactionService.confirm(
          pending.id,
          category: '餐饮',
          account: '零钱',
        );

        expect(tx, isNotNull);
        expect(tx!.amount, Decimal.parse('38.00'));
        expect(tx.category, '餐饮');
        expect(tx.account, '零钱');
        expect(tx.isIncome, isFalse);

        // WHY: pending 状态应变为 confirmed 并关联正式交易 ID
        final updated = DatabaseService.pendingTransactions.get(pending.id);
        expect(updated!.status, PendingStatus.confirmed);
        expect(updated.confirmedTransactionId, tx.id);

        // WHY: 支出应扣减账户余额
        final account = AccountService.getAccountByName('零钱');
        expect(account!.currentBalance, Decimal.parse('962.00'));
      });

      test('确认收入交易：余额增加', () async {
        await AccountService.createAccount(
          name: '零钱',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: Decimal.parse('1000.00'),
        );

        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('100.00'),
          source: PaymentSource.wechat,
          rawText: '收款成功100.00元',
          isIncome: true,
        );

        await PendingTransactionService.confirm(
          pending.id,
          category: '工资',
          account: '零钱',
        );

        final account = AccountService.getAccountByName('零钱');
        expect(account!.currentBalance, Decimal.parse('1100.00'));
      });

      test('幂等：已 confirmed 的交易再次确认返回 null', () async {
        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('10'),
          source: PaymentSource.alipay,
          rawText: 'a',
        );

        await PendingTransactionService.confirm(
          pending.id,
          category: '餐饮',
          account: '零钱',
        );

        // WHY: status != pending 时 confirm 返回 null，防止重复建交易/重复扣款
        final second = await PendingTransactionService.confirm(
          pending.id,
          category: '餐饮',
          account: '零钱',
        );
        expect(second, isNull);
      });

      test('不存在的 pendingId 返回 null', () async {
        final result = await PendingTransactionService.confirm(
          'non-existent-id',
          category: '餐饮',
          account: '零钱',
        );
        expect(result, isNull);
      });

      test('用户修改金额后确认使用新金额', () async {
        await AccountService.createAccount(
          name: '零钱',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: Decimal.parse('1000.00'),
        );

        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('38.00'),
          source: PaymentSource.alipay,
          rawText: '消费38.00元',
        );

        final tx = await PendingTransactionService.confirm(
          pending.id,
          category: '餐饮',
          account: '零钱',
          amount: Decimal.parse('36.00'),
        );

        expect(tx!.amount, Decimal.parse('36.00'));
        final account = AccountService.getAccountByName('零钱');
        expect(account!.currentBalance, Decimal.parse('964.00'));
      });
    });

    group('discard', () {
      test('丢弃后状态变为 discarded', () async {
        final pending = await PendingTransactionService.create(
          amount: Decimal.parse('10'),
          source: PaymentSource.alipay,
          rawText: 'a',
        );

        await PendingTransactionService.discard(pending.id);

        final updated = DatabaseService.pendingTransactions.get(pending.id);
        expect(updated!.status, PendingStatus.discarded);
      });

      test('丢弃不存在的交易不抛异常', () async {
        await PendingTransactionService.discard('non-existent');
      });
    });

    group('clearProcessed', () {
      test('只清理已确认/已丢弃的，pending 保留', () async {
        final p1 = await PendingTransactionService.create(
            amount: Decimal.parse('10'),
            source: PaymentSource.alipay,
            rawText: 'a');
        final p2 = await PendingTransactionService.create(
            amount: Decimal.parse('20'),
            source: PaymentSource.wechat,
            rawText: 'b');
        await PendingTransactionService.discard(p1.id);

        final cleared = await PendingTransactionService.clearProcessed();
        expect(cleared, 1);

        final remaining = PendingTransactionService.getAll();
        expect(remaining.length, 1);
        expect(remaining[0].id, p2.id);
        expect(remaining[0].status, PendingStatus.pending);
      });
    });
  });
}

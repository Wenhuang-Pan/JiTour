import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jitu/services/account_service.dart';

void main() {
  group('AccountService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tmpDir.path);
      await AccountService.init();
      await AccountService.box.clear();
    });

    tearDown(() async {
      await AccountService.box.clear();
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    group('createAccount', () {
      test('创建新账户', () async {
        final account = await AccountService.createAccount(
          name: '测试账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );

        expect(account.name, '测试账户');
        expect(account.iconName, '现金');
        expect(account.colorValue, 0xFFFFB020);
        expect(account.initialBalance, 1000.0);
        expect(account.currentBalance, 1000.0);
        expect(account.isActive, true);
        expect(account.id, isNotEmpty);
      });

      test('创建账户时自动分配sortOrder', () async {
        await AccountService.createAccount(
          name: '账户1',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );
        await AccountService.createAccount(
          name: '账户2',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final accounts = AccountService.getAllAccounts();
        expect(accounts.length, 2);
        expect(accounts[0].sortOrder, 0);
        expect(accounts[1].sortOrder, 1);
      });
    });

    group('getAllAccounts', () {
      test('获取所有账户', () async {
        await AccountService.createAccount(
          name: '现金',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );
        await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final accounts = AccountService.getAllAccounts();
        expect(accounts.length, 2);
        expect(accounts[0].name, '现金');
        expect(accounts[1].name, '银行卡');
      });

      test('账户按sortOrder排序', () async {
        await AccountService.createAccount(
          name: '账户B',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );
        await AccountService.createAccount(
          name: '账户A',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final accounts = AccountService.getAllAccounts();
        expect(accounts[0].name, '账户B');
        expect(accounts[1].name, '账户A');
      });
    });

    group('getActiveAccounts', () {
      test('只获取活跃账户', () async {
        await AccountService.createAccount(
          name: '活跃账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );
        final inactiveAccount = await AccountService.createAccount(
          name: '非活跃账户',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );
        inactiveAccount.isActive = false;
        await inactiveAccount.save();

        final activeAccounts = AccountService.getActiveAccounts();
        expect(activeAccounts.length, 1);
        expect(activeAccounts[0].name, '活跃账户');
      });
    });

    group('getAccountById', () {
      test('根据ID获取账户', () async {
        final account = await AccountService.createAccount(
          name: '测试账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );

        final found = AccountService.getAccountById(account.id);
        expect(found, isNotNull);
        expect(found?.name, '测试账户');
      });

      test('获取不存在的账户返回null', () {
        final found = AccountService.getAccountById('nonexistent-id');
        expect(found, isNull);
      });
    });

    group('getAccountByName', () {
      test('根据名称获取账户', () async {
        await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final found = AccountService.getAccountByName('银行卡');
        expect(found, isNotNull);
        expect(found?.name, '银行卡');
      });

      test('获取不存在的账户返回null', () {
        final found = AccountService.getAccountByName('不存在');
        expect(found, isNull);
      });
    });

    group('updateAccount', () {
      test('更新账户信息', () async {
        final account = await AccountService.createAccount(
          name: '旧名称',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );

        account.name = '新名称';
        account.iconName = '银行卡';
        final updated = await AccountService.updateAccount(account);

        expect(updated.name, '新名称');
        expect(updated.iconName, '银行卡');
        expect(updated.updatedAt.isAfter(account.createdAt), true);
      });
    });

    group('deleteAccount', () {
      test('软删除账户', () async {
        final account = await AccountService.createAccount(
          name: '待删除账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );

        await AccountService.deleteAccount(account.id);

        final deleted = AccountService.getAccountById(account.id);
        expect(deleted?.isActive, false);
        expect(deleted?.updatedAt.isAfter(account.createdAt), true);
      });
    });

    group('permanentDeleteAccount', () {
      test('永久删除账户', () async {
        final account = await AccountService.createAccount(
          name: '待删除账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
        );

        await AccountService.permanentDeleteAccount(account.id);

        final found = AccountService.getAccountById(account.id);
        expect(found, isNull);
      });
    });

    group('updateAccountBalance', () {
      test('更新账户余额', () async {
        final account = await AccountService.createAccount(
          name: '测试账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );

        await AccountService.updateAccountBalance(account.id, 1500.0);

        final updated = AccountService.getAccountById(account.id);
        expect(updated?.currentBalance, 1500.0);
      });
    });

    group('getAccountBalance', () {
      test('获取账户余额', () async {
        final account = await AccountService.createAccount(
          name: '测试账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 500.0,
        );

        final balance = AccountService.getAccountBalance(account.id);
        expect(balance, 500.0);
      });

      test('获取不存在账户的余额返回0', () {
        final balance = AccountService.getAccountBalance('nonexistent-id');
        expect(balance, 0.0);
      });
    });

    group('getTotalBalance', () {
      test('计算所有活跃账户的总余额', () async {
        await AccountService.createAccount(
          name: '账户1',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );
        await AccountService.createAccount(
          name: '账户2',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
          initialBalance: 2000.0,
        );
        final inactive = await AccountService.createAccount(
          name: '非活跃账户',
          iconName: '支付宝',
          colorValue: 0xFF00C853,
          initialBalance: 500.0,
        );
        inactive.isActive = false;
        await inactive.save();

        final total = AccountService.getTotalBalance();
        expect(total, 3000.0);
      });
    });

    group('transfer', () {
      test('账户间转账', () async {
        final fromAccount = await AccountService.createAccount(
          name: '转出账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );
        final toAccount = await AccountService.createAccount(
          name: '转入账户',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
          initialBalance: 500.0,
        );

        await AccountService.transfer(
          fromAccountId: fromAccount.id,
          toAccountId: toAccount.id,
          amount: 300.0,
        );

        expect(fromAccount.currentBalance, 700.0);
        expect(toAccount.currentBalance, 800.0);
      });

      test('转账金额必须大于0', () async {
        final fromAccount = await AccountService.createAccount(
          name: '转出账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );
        final toAccount = await AccountService.createAccount(
          name: '转入账户',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
          initialBalance: 500.0,
        );

        expect(
            () => AccountService.transfer(
                  fromAccountId: fromAccount.id,
                  toAccountId: toAccount.id,
                  amount: 0.0,
                ),
            throwsException);
      });

      test('余额不足时抛出异常', () async {
        final fromAccount = await AccountService.createAccount(
          name: '转出账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 100.0,
        );
        final toAccount = await AccountService.createAccount(
          name: '转入账户',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
          initialBalance: 500.0,
        );

        expect(
            () => AccountService.transfer(
                  fromAccountId: fromAccount.id,
                  toAccountId: toAccount.id,
                  amount: 200.0,
                ),
            throwsException);
      });

      test('账户不存在时抛出异常', () async {
        final fromAccount = await AccountService.createAccount(
          name: '转出账户',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 1000.0,
        );

        expect(
            () => AccountService.transfer(
                  fromAccountId: fromAccount.id,
                  toAccountId: 'nonexistent-id',
                  amount: 100.0,
                ),
            throwsException);
      });
    });

    group('accountNameExists', () {
      test('检查账户名称是否存在', () async {
        await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        expect(AccountService.accountNameExists('银行卡'), true);
        expect(AccountService.accountNameExists('不存在'), false);
      });

      test('排除指定ID检查', () async {
        final account = await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        expect(AccountService.accountNameExists('银行卡', excludeId: account.id),
            false);
      });
    });

    group('exportAllAccounts', () {
      test('导出所有账户为JSON', () async {
        await AccountService.createAccount(
          name: '现金',
          iconName: '现金',
          colorValue: 0xFFFFB020,
          initialBalance: 100.0,
        );

        final exported = AccountService.exportAllAccounts();
        expect(exported.length, 1);
        expect(exported[0]['name'], '现金');
        expect(exported[0]['initialBalance'], 100.0);
      });
    });

    group('importAccounts', () {
      test('导入新账户', () async {
        final data = [
          {
            'id': 'test-id-1',
            'name': '导入账户',
            'iconName': '现金',
            'colorValue': 0xFFFFB020,
            'initialBalance': 1000.0,
            'currentBalance': 1000.0,
            'isActive': true,
            'sortOrder': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ];

        final count = await AccountService.importAccounts(data);
        expect(count, 1);
        expect(AccountService.getAccountByName('导入账户'), isNotNull);
      });

      test('导入重复账户不替换', () async {
        final account = await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final data = [
          {
            'id': account.id,
            'name': '银行卡',
            'iconName': '银行卡',
            'colorValue': 0xFF2979FF,
            'initialBalance': 2000.0,
            'currentBalance': 2000.0,
            'isActive': true,
            'sortOrder': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ];

        final count = await AccountService.importAccounts(data);
        expect(count, 0);
        expect(account.currentBalance, 0.0);
      });

      test('导入重复账户并替换', () async {
        final account = await AccountService.createAccount(
          name: '银行卡',
          iconName: '银行卡',
          colorValue: 0xFF2979FF,
        );

        final data = [
          {
            'id': account.id,
            'name': '银行卡',
            'iconName': '银行卡',
            'colorValue': 0xFF2979FF,
            'initialBalance': 2000.0,
            'currentBalance': 2000.0,
            'isActive': true,
            'sortOrder': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ];

        final count =
            await AccountService.importAccounts(data, replaceExisting: true);
        expect(count, 1);
        expect(account.currentBalance, 2000.0);
      });
    });
  });
}

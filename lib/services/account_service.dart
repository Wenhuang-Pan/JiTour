import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';
import '../models/account.dart';
import 'database_service.dart';
import 'notification_bridge_service.dart';

class AccountService {
  static const _uuid = Uuid();

  static Box<Account> get box => DatabaseService.accounts;

  static Future<void> init() async {
    // 如果没有账户，创建默认账户
    if (box.isEmpty) {
      await _createDefaultAccounts();
    }
  }

  // 创建默认账户
  static Future<void> _createDefaultAccounts() async {
    final defaultAccounts = [
      Account(
        id: _uuid.v4(),
        name: '现金',
        iconName: '现金',
        colorValue: 0xFFFFB020,
        initialBalance: Decimal.zero,
        sortOrder: 0,
      ),
      Account(
        id: _uuid.v4(),
        name: '银行卡',
        iconName: '银行卡',
        colorValue: 0xFF2979FF,
        initialBalance: Decimal.zero,
        sortOrder: 1,
      ),
      Account(
        id: _uuid.v4(),
        name: '支付宝',
        iconName: '支付宝',
        colorValue: 0xFF00C853,
        initialBalance: Decimal.zero,
        sortOrder: 2,
      ),
      Account(
        id: _uuid.v4(),
        name: '微信',
        iconName: '微信',
        colorValue: 0xFF07C160,
        initialBalance: Decimal.zero,
        sortOrder: 3,
      ),
    ];

    for (final account in defaultAccounts) {
      await box.put(account.id, account);
    }
  }

  // 获取所有账户
  static List<Account> getAllAccounts() {
    final accounts = box.values.toList();
    accounts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return accounts;
  }

  // 获取活跃账户
  static List<Account> getActiveAccounts() {
    return getAllAccounts().where((a) => a.isActive).toList();
  }

  // 根据ID获取账户
  static Account? getAccountById(String id) {
    try {
      return box.get(id);
    } catch (e) {
      return null;
    }
  }

  // 根据名称获取账户
  static Account? getAccountByName(String name) {
    try {
      return box.values.firstWhere((a) => a.name == name);
    } catch (e) {
      return null;
    }
  }

  // 创建账户
  static Future<Account> createAccount({
    required String name,
    required String iconName,
    required int colorValue,
    Decimal? initialBalance,
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name,
      iconName: iconName,
      colorValue: colorValue,
      initialBalance: initialBalance ?? Decimal.zero,
      currentBalance: initialBalance ?? Decimal.zero,
      sortOrder: getAllAccounts().length,
    );

    await box.put(account.id, account);
    _syncAccountsToNative();
    return account;
  }

  // 更新账户
  static Future<Account> updateAccount(Account account) async {
    account.updatedAt = DateTime.now();
    await box.put(account.id, account);
    _syncAccountsToNative();
    return account;
  }

  // 删除账户（软删除）
  static Future<void> deleteAccount(String id) async {
    final account = getAccountById(id);
    if (account != null) {
      account.isActive = false;
      account.updatedAt = DateTime.now();
      await account.save();
      _syncAccountsToNative();
    }
  }

  // 永久删除账户
  static Future<void> permanentDeleteAccount(String id) async {
    await box.delete(id);
    _syncAccountsToNative();
  }

  /// 将最新活跃账户推送到原生悬浮窗缓存
  ///
  /// WHY: 账户增删改后若不重新推送，后台悬浮窗 Chip 仍是旧列表，
  /// 用户无法选择新建账户。fire-and-forget，失败仅打日志不影响主流程。
  static void _syncAccountsToNative() {
    final names = getActiveAccounts().map((a) => a.name).toList();
    NotificationBridgeService.pushAccounts(names);
  }

  // 更新账户余额
  static Future<void> updateAccountBalance(
      String accountId, Decimal newBalance) async {
    final account = getAccountById(accountId);
    if (account != null) {
      account.currentBalance = newBalance;
      await account.save();
    }
  }

  // 获取账户余额
  static Decimal getAccountBalance(String accountId) {
    final account = getAccountById(accountId);
    return account?.currentBalance ?? Decimal.zero;
  }

  static Decimal getTotalBalance() {
    return getActiveAccounts()
        .fold(Decimal.zero, (sum, account) => sum + account.currentBalance);
  }

  // 账户间转账
  static Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required Decimal amount,
    String? note,
  }) async {
    final fromAccount = getAccountById(fromAccountId);
    final toAccount = getAccountById(toAccountId);

    if (fromAccount == null || toAccount == null) {
      throw Exception('账户不存在');
    }

    if (fromAccountId == toAccountId) {
      throw Exception('不能向同一账户转账');
    }

    if (amount <= Decimal.zero) {
      throw Exception('转账金额必须大于0');
    }

    if (fromAccount.currentBalance < amount) {
      throw Exception('余额不足');
    }

    // 更新余额
    fromAccount.currentBalance -= amount;
    toAccount.currentBalance += amount;

    await fromAccount.save();
    await toAccount.save();
  }

  // 检查账户名称是否已存在
  static bool accountNameExists(String name, {String? excludeId}) {
    return box.values.any((a) =>
        a.name == name &&
        a.isActive &&
        (excludeId == null || a.id != excludeId));
  }

  // 导出所有账户
  static List<Map<String, dynamic>> exportAllAccounts() {
    return getAllAccounts().map((a) => a.toJson()).toList();
  }

  // 导入账户
  static Future<int> importAccounts(
    List<Map<String, dynamic>> dataList, {
    bool replaceExisting = false,
  }) async {
    int importedCount = 0;

    for (final data in dataList) {
      try {
        final account = Account.fromJson(data);

        // 检查是否已存在
        final existing = getAccountById(account.id);
        if (existing != null) {
          if (replaceExisting) {
            // 替换现有账户
            await box.put(account.id, account);
            importedCount++;
          }
        } else {
          // 添加新账户
          await box.put(account.id, account);
          importedCount++;
        }
      } catch (e) {
        // 跳过无效数据
        continue;
      }
    }

    // WHY: 批量导入绕过了 createAccount，需显式同步原生悬浮窗缓存
    if (importedCount > 0) {
      _syncAccountsToNative();
    }
    return importedCount;
  }
}

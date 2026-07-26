import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../models/tag.dart';
import '../models/savings_goal.dart';
import '../models/category.dart';

class BackupService {
  static Future<String> createBackup() async {
    final backupData = <String, dynamic>{
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'transactions': [],
      'budgets': [],
      'accounts': [],
      'tags': [],
      'savingsGoals': [],
      'categories': [],
    };

    // 读取所有交易记录
    final transactionsBox = Hive.box<Transaction>('transactions');
    for (var transaction in transactionsBox.values) {
      backupData['transactions'].add({
        'id': transaction.id,
        'amount': transaction.amount,
        'isIncome': transaction.isIncome,
        'category': transaction.category,
        'account': transaction.account,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
        'subCategory': transaction.subCategory,
        'currency': transaction.currency,
        'account2': transaction.account2,
        'isReimbursed': transaction.isReimbursed,
        'fee': transaction.fee,
        'coupon': transaction.coupon,
        'tags': transaction.tags,
        'deletedAt': transaction.deletedAt?.toIso8601String(),
      });
    }

    // 读取所有预算记录
    final budgetsBox = Hive.box<Budget>('budgets');
    for (var budget in budgetsBox.values) {
      backupData['budgets'].add({
        'id': budget.id,
        'category': budget.category,
        'amount': budget.amount,
        'year': budget.year,
        'month': budget.month,
      });
    }

    // 读取所有账户记录
    final accountsBox = Hive.box<Account>('accounts');
    for (var account in accountsBox.values) {
      backupData['accounts'].add({
        'id': account.id,
        'name': account.name,
        'iconName': account.iconName,
        'colorValue': account.colorValue,
        'initialBalance': account.initialBalance,
        'currentBalance': account.currentBalance,
        'isActive': account.isActive,
        'sortOrder': account.sortOrder,
        'createdAt': account.createdAt.toIso8601String(),
        'updatedAt': account.updatedAt.toIso8601String(),
      });
    }

    // 读取所有标签记录
    final tagsBox = Hive.box<Tag>('tags');
    for (var tag in tagsBox.values) {
      backupData['tags'].add({
        'id': tag.id,
        'name': tag.name,
        'colorValue': tag.colorValue,
        'iconName': tag.iconName,
        'isActive': tag.isActive,
        'sortOrder': tag.sortOrder,
        'createdAt': tag.createdAt.toIso8601String(),
        'updatedAt': tag.updatedAt.toIso8601String(),
      });
    }

    // 读取所有储蓄目标记录
    final savingsGoalsBox = Hive.box<SavingsGoal>('savings_goals');
    for (var goal in savingsGoalsBox.values) {
      backupData['savingsGoals'].add({
        'id': goal.id,
        'name': goal.name,
        'description': goal.description,
        'targetAmount': goal.targetAmount,
        'currentAmount': goal.currentAmount,
        'iconName': goal.iconName,
        'colorValue': goal.colorValue,
        'startDate': goal.startDate.toIso8601String(),
        'targetDate': goal.targetDate?.toIso8601String(),
        'isCompleted': goal.isCompleted,
        'createdAt': goal.createdAt.toIso8601String(),
        'updatedAt': goal.updatedAt.toIso8601String(),
        'accountId': goal.accountId,
      });
    }

    // 读取所有分类记录
    final categoriesBox = Hive.box<Category>('categories');
    for (var category in categoriesBox.values) {
      backupData['categories'].add({
        'id': category.id,
        'name': category.name,
        'iconName': category.iconName,
        'isIncome': category.isIncome,
        'color': category.color,
        'createdAt': category.createdAt.toIso8601String(),
        'deletedAt': category.deletedAt?.toIso8601String(),
      });
    }

    return jsonEncode(backupData);
  }

  static Future<Map<String, dynamic>?> readBackupFile(String content) async {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> restoreBackup(String content) async {
    try {
      final data = await readBackupFile(content);
      if (data == null) return false;

      // 清空现有数据
      final transactionsBox = Hive.box<Transaction>('transactions');
      final budgetsBox = Hive.box<Budget>('budgets');
      final accountsBox = Hive.box<Account>('accounts');
      final tagsBox = Hive.box<Tag>('tags');
      final savingsGoalsBox = Hive.box<SavingsGoal>('savings_goals');
      final categoriesBox = Hive.box<Category>('categories');

      await transactionsBox.clear();
      await budgetsBox.clear();
      await accountsBox.clear();
      await tagsBox.clear();
      await savingsGoalsBox.clear();
      await categoriesBox.clear();

      // 恢复交易记录
      if (data['transactions'] != null) {
        for (var t in data['transactions']) {
          final transaction = Transaction(
            id: t['id'],
            amount: (t['amount'] as num).toDouble(),
            isIncome: t['isIncome'],
            category: t['category'],
            account: t['account'],
            date: DateTime.parse(t['date']),
            note: t['note'],
            subCategory: t['subCategory'],
            currency: t['currency'] ?? 'CNY',
            account2: t['account2'],
            isReimbursed: t['isReimbursed'] ?? false,
            fee: (t['fee'] as num?)?.toDouble() ?? 0.0,
            coupon: (t['coupon'] as num?)?.toDouble() ?? 0.0,
            tags: t['tags'],
            deletedAt: t['deletedAt'] != null ? DateTime.parse(t['deletedAt']) : null,
          );
          await transactionsBox.put(transaction.id, transaction);
        }
      }

      // 恢复预算记录
      if (data['budgets'] != null) {
        for (var b in data['budgets']) {
          final budget = Budget(
            id: b['id'],
            category: b['category'],
            amount: (b['amount'] as num).toDouble(),
            year: b['year'],
            month: b['month'],
          );
          await budgetsBox.put(budget.id, budget);
        }
      }

      // 恢复账户记录
      if (data['accounts'] != null) {
        for (var a in data['accounts']) {
          final account = Account(
            id: a['id'],
            name: a['name'],
            iconName: a['iconName'],
            colorValue: a['colorValue'] as int,
            initialBalance: (a['initialBalance'] as num?)?.toDouble() ?? 0.0,
            currentBalance: (a['currentBalance'] as num?)?.toDouble() ?? 0.0,
            isActive: a['isActive'] ?? true,
            sortOrder: a['sortOrder'] as int? ?? 0,
            createdAt: a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime.now(),
            updatedAt: a['updatedAt'] != null ? DateTime.parse(a['updatedAt']) : DateTime.now(),
          );
          await accountsBox.put(account.id, account);
        }
      }

      // 恢复标签记录
      if (data['tags'] != null) {
        for (var t in data['tags']) {
          final tag = Tag(
            id: t['id'],
            name: t['name'],
            colorValue: t['colorValue'] as int,
            iconName: t['iconName'],
            isActive: t['isActive'] ?? true,
            sortOrder: t['sortOrder'] as int? ?? 0,
            createdAt: t['createdAt'] != null ? DateTime.parse(t['createdAt']) : DateTime.now(),
            updatedAt: t['updatedAt'] != null ? DateTime.parse(t['updatedAt']) : DateTime.now(),
          );
          await tagsBox.put(tag.id, tag);
        }
      }

      // 恢复储蓄目标记录
      if (data['savingsGoals'] != null) {
        for (var g in data['savingsGoals']) {
          final goal = SavingsGoal(
            id: g['id'],
            name: g['name'],
            description: g['description'],
            targetAmount: (g['targetAmount'] as num).toDouble(),
            currentAmount: (g['currentAmount'] as num?)?.toDouble() ?? 0.0,
            iconName: g['iconName'],
            colorValue: g['colorValue'] as int,
            startDate: DateTime.parse(g['startDate']),
            targetDate: g['targetDate'] != null ? DateTime.parse(g['targetDate']) : null,
            isCompleted: g['isCompleted'] ?? false,
            createdAt: g['createdAt'] != null ? DateTime.parse(g['createdAt']) : DateTime.now(),
            updatedAt: g['updatedAt'] != null ? DateTime.parse(g['updatedAt']) : DateTime.now(),
            accountId: g['accountId'],
          );
          await savingsGoalsBox.put(goal.id, goal);
        }
      }

      // 恢复分类记录
      if (data['categories'] != null) {
        for (var c in data['categories']) {
          final category = Category(
            id: c['id'],
            name: c['name'],
            iconName: c['iconName'],
            isIncome: c['isIncome'],
            color: c['color'],
            createdAt: DateTime.parse(c['createdAt']),
            deletedAt: c['deletedAt'] != null ? DateTime.parse(c['deletedAt']) : null,
          );
          await categoriesBox.put(category.id, category);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<File> saveBackupToFile(String content) async {
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final fileName = 'jitu_backup_${dateFormat.format(DateTime.now())}.json';
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsString(content);
    return file;
  }

  static Future<List<FileSystemEntity>> getBackupFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((f) => f.path.endsWith('.json') && 
                      f.path.contains('jitu_backup_'))
        .toList();
    
    files.sort((a, b) => b.path.compareTo(a.path)); // 最新备份在前
    return files;
  }

  static Future<bool> deleteBackupFile(File file) async {
    try {
      await file.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> readBackupFileContent(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }
}

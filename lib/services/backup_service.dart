import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

class BackupService {
  static Future<String> createBackup() async {
    final backupData = <String, dynamic>{
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'transactions': [],
      'budgets': [],
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

      await transactionsBox.clear();
      await budgetsBox.clear();

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

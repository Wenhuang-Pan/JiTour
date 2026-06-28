import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ExportService {
  static String exportToCsv(List<Transaction> transactions, DateTime startDate, DateTime endDate) {
    final buffer = StringBuffer();
    
    // CSV表头
    buffer.writeln('日期,时间,类型,分类,账户,金额,备注');
    
    // 格式化器
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    
    // 添加数据行
    for (var transaction in transactions) {
      final date = dateFormat.format(transaction.date);
      final time = timeFormat.format(transaction.date);
      final type = transaction.isIncome ? '收入' : '支出';
      final category = transaction.category;
      final account = transaction.account;
      final amount = transaction.amount.toStringAsFixed(2);
      final note = _escapeCsvField(transaction.note ?? '');
      
      buffer.writeln('$date,$time,$type,$category,$account,$amount,$note');
    }
    
    return buffer.toString();
  }

  static String exportToText(List<Transaction> transactions, DateTime startDate, DateTime endDate) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final moneyFormat = NumberFormat.currency(symbol: '¥');
    
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln('记途 - 记账记录导出');
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln('导出时间: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('统计周期: ${dateFormat.format(startDate)} 至 ${dateFormat.format(endDate)}');
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln();
    
    // 分组统计
    final income = transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
    final expense = transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
    
    buffer.writeln('【收支概况】');
    buffer.writeln('总收入: ${moneyFormat.format(income)}');
    buffer.writeln('总支出: ${moneyFormat.format(expense)}');
    buffer.writeln('结余:   ${moneyFormat.format(income - expense)}');
    buffer.writeln();
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln('【详细记录】');
    buffer.writeln('='.padRight(50, '='));
    
    // 按日期分组
    final grouped = <String, List<Transaction>>{};
    for (var t in transactions) {
      final key = dateFormat.format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    
    for (var entry in grouped.entries) {
      buffer.writeln();
      buffer.writeln('--- ${entry.key} ---');
      for (var t in entry.value) {
        final type = t.isIncome ? '[收入]' : '[支出]';
        final amountStr = moneyFormat.format(t.amount);
        buffer.writeln('${t.category.padRight(8)} ${type} $amountStr');
        if (t.note != null && t.note!.isNotEmpty) {
          buffer.writeln('  备注: ${t.note}');
        }
      }
    }
    
    buffer.writeln();
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln('共 ${transactions.length} 条记录');
    buffer.writeln('='.padRight(50, '='));
    
    return buffer.toString();
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}

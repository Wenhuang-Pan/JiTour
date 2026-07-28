import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ExportService {
  static String exportToCsv(
    List<Transaction> transactions, 
    DateTime startDate, 
    DateTime endDate, {
    String currency = 'CNY',
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券');
    
    final dateFormat = DateFormat('yyyy/M/d HH:mm');
    
    for (var transaction in transactions) {
      final dateTime = dateFormat.format(transaction.date);
      final type = transaction.isIncome ? '收入' : '支出';
      final amount = transaction.amount.toStringAsFixed(2);
      final note = _escapeCsvField(transaction.note ?? '');
      final subCategory = transaction.subCategory ?? '';
      final transCurrency = transaction.currency ?? currency;
      final account2 = transaction.account2 ?? '';
      final isReimbursed = transaction.isReimbursed ? '是' : '否';
      final fee = transaction.fee.toStringAsFixed(2);
      final coupon = transaction.coupon.toStringAsFixed(2);
      
      buffer.writeln('$dateTime,${transaction.category},$subCategory,$type,$amount,$transCurrency,${transaction.account},$account2,$note,$isReimbursed,$fee,$coupon');
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
        buffer.writeln('${t.category.padRight(8)} $type $amountStr');
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

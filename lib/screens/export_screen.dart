import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _exportType = 'csv';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Transaction> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    final transactions = DatabaseService.getAllTransactions();
    setState(() {
      _filteredTransactions = transactions
          .where((t) =>
              t.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(_endDate.add(const Duration(days: 1))))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出数据'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeCard(context, dateFormat),
            const SizedBox(height: AppTheme.spaceMedium),
            _buildFormatSelectionCard(context),
            const SizedBox(height: AppTheme.spaceMedium),
            _buildPreviewCard(context, dateFormat),
            const SizedBox(height: AppTheme.spaceXLarge),
            _buildExportButton(context),
            const SizedBox(height: AppTheme.spaceXXXLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeCard(BuildContext context, DateFormat dateFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                const Text(
                  '日期范围',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    context,
                    '开始日期',
                    dateFormat.format(_startDate),
                    () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: _buildDateButton(
                    context,
                    '结束日期',
                    dateFormat.format(_endDate),
                    () => _selectDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            Wrap(
              spacing: AppTheme.spaceSmall,
              runSpacing: AppTheme.spaceSmall,
              children: [
                _buildQuickDateChip(context, '最近7天', 7),
                _buildQuickDateChip(context, '最近30天', 30),
                _buildQuickDateChip(context, '本月', 0, isCurrentMonth: true),
                _buildQuickDateChip(context, '上月', 0, isLastMonth: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: AppTheme.neutral50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: AppTheme.neutral200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.neutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXSmall),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(
    BuildContext context,
    String label,
    int days,
    {bool isCurrentMonth = false, bool isLastMonth = false}
  ) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      backgroundColor: AppTheme.neutral100,
      side: BorderSide(
        color: AppTheme.neutral200,
        width: 1,
      ),
      onPressed: () {
        DateTime start, end = DateTime.now();

        if (isCurrentMonth) {
          final now = DateTime.now();
          start = DateTime(now.year, now.month, 1);
          end = now;
        } else if (isLastMonth) {
          final now = DateTime.now();
          start = DateTime(now.year, now.month - 1, 1);
          end = DateTime(now.year, now.month, 0);
        } else {
          start = DateTime.now().subtract(Duration(days: days));
          end = DateTime.now();
        }

        setState(() {
          _startDate = start;
          _endDate = end;
        });
        _loadTransactions();
      },
    );
  }

  Widget _buildFormatSelectionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.file_present_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                const Text(
                  '导出格式',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildFormatOption(
              context,
              'CSV 格式',
              '适合 Excel 打开，可进行数据分析',
              Icons.table_chart_rounded,
              'csv',
              AppTheme.successColor,
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            _buildFormatOption(
              context,
              'TXT 格式',
              '纯文本格式，便于阅读和打印',
              Icons.text_snippet_rounded,
              'txt',
              AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    String value,
    Color color,
  ) {
    final isSelected = _exportType == value;

    return InkWell(
      onTap: () => setState(() => _exportType = value),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.3) : AppTheme.neutral200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppTheme.neutral900,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, DateFormat dateFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceSmall),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        Icons.preview_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    const Text(
                      '数据预览',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSmall,
                    vertical: AppTheme.spaceXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '共 ${_filteredTransactions.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutral600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMedium),
            if (_filteredTransactions.isEmpty)
              _buildEmptyPreview(context)
            else
              _buildPreviewList(context, dateFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.neutral200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: AppTheme.neutral400,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            '该时间段内没有交易记录',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neutral600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList(BuildContext context, DateFormat dateFormat) {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.neutral50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.neutral200,
              width: 1,
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            itemCount: _filteredTransactions.length > 10 ? 10 : _filteredTransactions.length,
            itemBuilder: (context, index) {
              final t = _filteredTransactions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spaceXSmall),
                padding: const EdgeInsets.all(AppTheme.spaceSmall),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        dateFormat.format(t.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutral600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (t.isIncome ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          t.isIncome ? '收入' : '支出',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: t.isIncome ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${t.category} ¥${t.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutral900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_filteredTransactions.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSmall),
            child: Text(
              '... 还有 ${_filteredTransactions.length - 10} 条记录',
              style: TextStyle(
                color: AppTheme.neutral500,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _filteredTransactions.isEmpty ? null : AppTheme.primaryGradient,
        color: _filteredTransactions.isEmpty ? AppTheme.neutral300 : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: _filteredTransactions.isEmpty ? null : [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _filteredTransactions.isEmpty ? null : _exportData,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spaceSmall),
                Text(
                  '导出数据',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadTransactions();
    }
  }

  Future<void> _exportData() async {
    try {
      String content;
      String fileName;
      final dateFormat = DateFormat('yyyyMMdd');

      if (_exportType == 'csv') {
        content = ExportService.exportToCsv(_filteredTransactions, _startDate, _endDate);
        fileName = 'jitu_export_${dateFormat.format(DateTime.now())}.csv';
      } else {
        content = ExportService.exportToText(_filteredTransactions, _startDate, _endDate);
        fileName = 'jitu_export_${dateFormat.format(DateTime.now())}.txt';
      }

      // 获取临时目录并保存文件
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      // 使用 share_plus 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '记途记账数据导出',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('导出成功！'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }
}

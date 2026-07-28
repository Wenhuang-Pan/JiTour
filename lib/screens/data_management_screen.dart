import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/csv_importer.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../providers/currency_provider.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 导入相关状态
  List<Map<String, String>>? _csvData;
  List<Map<String, String>>? _mappedData;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // 导出相关状态
  DateTime _exportStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _exportEndDate = DateTime.now();
  String? _exportPreview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 导入功能
  Future<void> _pickAndParseFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _errorMessage = '无法读取文件内容';
          _isLoading = false;
        });
        return;
      }

      final content = String.fromCharCodes(bytes);
      final rows = CsvImporter.parseCsv(content);
      
      if (rows.isEmpty) {
        setState(() {
          _errorMessage = '未解析到数据，请检查CSV格式';
          _isLoading = false;
        });
        return;
      }

      final mapped = rows.map((row) => CsvImporter.mapFields(rows.first.keys.toList(), row)).toList();

      setState(() {
        _csvData = rows;
        _mappedData = mapped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
        _isLoading = false;
      });
    }
  }

  void _loadSampleData() {
    const sampleCsv = '''时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券
2026/6/27 19:17,三餐,,支出,40,CNY,,,,,,,
2026/6/28 10:30,交通,地铁,支出,6,CNY,支付宝,,通勤,,0,0
2026/6/28 14:00,工资,,收入,10000,CNY,,工资卡,六月工资,,0,0
''';

    try {
      final rows = CsvImporter.parseCsv(sampleCsv);
      if (rows.isEmpty) {
        setState(() => _errorMessage = '未解析到数据');
        return;
      }
      final mapped = rows.map((row) => CsvImporter.mapFields(rows.first.keys.toList(), row)).toList();
      setState(() {
        _csvData = rows;
        _mappedData = mapped;
      });
    } catch (e) {
      setState(() => _errorMessage = '解析失败: $e');
    }
  }

  void _confirmImport() {
    if (_mappedData == null || _mappedData!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: Text('确认导入 ${_mappedData!.length} 条记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doImport();
            },
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  void _doImport() {
    if (_mappedData == null) return;
    
    int imported = 0;
    for (var row in _mappedData!) {
      try {
        final amount = double.tryParse(row['amount'] ?? '');
        if (amount == null || amount <= 0) continue;
        
        final dateStr = row['date'];
        if (dateStr == null || dateStr.isEmpty) continue;
        
        final date = _parseDate(dateStr);
        final isIncome = row['isIncome'] == 'true';
        
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + imported.toString(),
          amount: amount,
          isIncome: isIncome,
          category: row['category'] ?? '其他',
          account: row['account']?.isNotEmpty == true ? row['account']! : '默认账户',
          date: date,
          note: row['note'],
        );
        
        DatabaseService.addTransaction(transaction);
        imported++;
      } catch (e) {
        // 跳过无效行
        continue;
      }
    }

    setState(() {
      _successMessage = '成功导入 $imported 条记录';
      _csvData = null;
      _mappedData = null;
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      // 尝试多种日期格式
      final formats = [
        'yyyy/M/d HH:mm',
        'yyyy/M/d H:mm',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd H:mm',
        'yyyy/M/d',
        'yyyy-M-d',
      ];
      
      for (var format in formats) {
        try {
          return DateFormat(format).parse(dateStr);
        } catch (e) {
          continue;
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  void _resetImport() {
    setState(() {
      _csvData = null;
      _mappedData = null;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  // 导出功能
  Future<void> _selectExportDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _exportStartDate, end: _exportEndDate),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.neutral900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _exportStartDate = picked.start;
        _exportEndDate = picked.end;
        _exportPreview = null;
      });
    }
  }

  void _generateExportPreview() {
    final currency = Provider.of<CurrencyProvider>(context, listen: false).code;
    final transactions = DatabaseService.getTransactionsInRange(_exportStartDate, _exportEndDate);
    final csv = ExportService.exportToCsv(transactions, _exportStartDate, _exportEndDate, currency: currency);
    setState(() => _exportPreview = csv);
  }

  Future<void> _exportToFile() async {
    if (_exportPreview == null) {
      _generateExportPreview();
    }
    
    final currency = Provider.of<CurrencyProvider>(context, listen: false).code;
    final transactions = DatabaseService.getTransactionsInRange(_exportStartDate, _exportEndDate);
    final csv = ExportService.exportToCsv(transactions, _exportStartDate, _exportEndDate, currency: currency);
    
    try {
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出CSV文件',
        fileName: 'simple_ledger_export_$dateStr.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(csv.codeUnits),
      );

      if (result != null) {
        setState(() => _successMessage = '导出成功！');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到: $result')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = '导出失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入导出'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '导入', icon: Icon(Icons.upload_file_rounded)),
            Tab(text: '导出', icon: Icon(Icons.download_rounded)),
          ],
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImportTab(),
          _buildExportTab(),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.successColor),
                  const SizedBox(width: AppTheme.spaceSmall),
                  Text(_successMessage!, style: const TextStyle(color: AppTheme.successColor)),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
          ],
          
          if (_csvData == null) ...[
            _buildUploadArea(),
            const SizedBox(height: AppTheme.spaceLarge),
            _buildFormatHelp(),
          ] else ...[
            _buildPreviewSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAndParseFile,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.upload_file_rounded,
                    color: AppTheme.primaryColor,
                    size: 48,
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  Text(
                    '点击选择CSV文件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceXSmall),
                  Text(
                    '支持微信、支付宝等账单',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndParseFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('选择文件'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXXLarge,
                    vertical: AppTheme.spaceLarge,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              OutlinedButton.icon(
                onPressed: _loadSampleData,
                icon: const Icon(Icons.science_rounded),
                label: const Text('加载示例'),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatHelp() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CSV格式说明',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Text(
              '时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券\n2026/6/27 19:17,三餐,,支出,40,CNY,,,,,,,',
              style: TextStyle(fontFamily: 'Monospace', fontSize: 11),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '支持的字段:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
          const Wrap(
            spacing: AppTheme.spaceSmall,
            runSpacing: AppTheme.spaceSmall,
            children: [
              Chip(label: Text('时间'), visualDensity: VisualDensity.compact),
              Chip(label: Text('分类'), visualDensity: VisualDensity.compact),
              Chip(label: Text('类型'), visualDensity: VisualDensity.compact),
              Chip(label: Text('金额'), visualDensity: VisualDensity.compact),
              Chip(label: Text('账户'), visualDensity: VisualDensity.compact),
              Chip(label: Text('备注'), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '导入预览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              '共 ${_mappedData?.length ?? 0} 条',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('时间')),
                DataColumn(label: Text('分类')),
                DataColumn(label: Text('类型')),
                DataColumn(label: Text('金额')),
                DataColumn(label: Text('账户')),
                DataColumn(label: Text('备注')),
              ],
              rows: (_mappedData ?? []).take(50).map((row) {
                final isIncome = row['isIncome'] == 'true';
                return DataRow(
                  cells: [
                    DataCell(Text(row['date'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(row['category'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        isIncome ? '收入' : '支出',
                        style: TextStyle(
                          color: isIncome ? AppTheme.successColor : AppTheme.warningColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${isIncome ? '+' : '-'}${row['amount'] ?? ''}',
                        style: TextStyle(
                          color: isIncome ? AppTheme.successColor : AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(Text(row['account'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(row['note'] ?? '', style: const TextStyle(fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        if ((_mappedData?.length ?? 0) > 50)
          const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spaceSmall),
            child: Text(
              '（仅显示前50条）',
              style: TextStyle(color: AppTheme.neutral500, fontSize: 12),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _confirmImport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
                ),
                child: const Text('确认导入'),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            OutlinedButton(
              onPressed: _resetImport,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
              ),
              child: const Text('重新选择'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMedium),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.successColor),
                  const SizedBox(width: AppTheme.spaceSmall),
                  Expanded(child: Text(_successMessage!, style: const TextStyle(color: AppTheme.successColor))),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMedium),
          ],

          // 日期范围选择
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择导出时间范围',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                InkWell(
                  onTap: _selectExportDateRange,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMedium),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.neutral200),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, color: AppTheme.primaryColor),
                        const SizedBox(width: AppTheme.spaceMedium),
                        Text(
                          '${DateFormat('yyyy/MM/dd').format(_exportStartDate)} - ${DateFormat('yyyy/MM/dd').format(_exportEndDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.neutral400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        final transactions = DatabaseService.getAllTransactions();
                        if (transactions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('暂无数据')),
                          );
                          return;
                        }
                        setState(() {
                          _exportStartDate = transactions.last.date;
                          _exportEndDate = transactions.first.date;
                        });
                        _exportToFile();
                      },
                      child: const Text('导出全部'),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _exportStartDate = DateTime.now().subtract(const Duration(days: 30));
                          _exportEndDate = DateTime.now();
                        });
                      },
                      child: const Text('近30天'),
                    ),
                    const SizedBox(width: AppTheme.spaceSmall),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _exportStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
                          _exportEndDate = DateTime.now();
                        });
                      },
                      child: const Text('本月'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spaceMedium),
          
          // 导出按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportToFile,
              icon: const Icon(Icons.download_rounded),
              label: const Text('导出CSV文件'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLarge),
              ),
            ),
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ],
          
          const SizedBox(height: AppTheme.spaceLarge),
          
          // 格式说明
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: AppTheme.neutral50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导出格式说明',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSmall),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Text(
                    '时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券\n2026/6/27 19:17,三餐,,支出,40,CNY,微信,,午餐,,,',
                    style: TextStyle(fontFamily: 'Monospace', fontSize: 11),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                const Text(
                  '导出的CSV格式与导入格式一致，可直接用于再次导入。',
                  style: TextStyle(color: AppTheme.neutral500, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

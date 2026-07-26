import 'package:flutter/material.dart';
import '../services/csv_importer.dart';
import '../theme/app_theme.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<Map<String, String>>? _csvData;
  List<String>? _detectedFormat;
  List<Map<String, String>>? _mappedData;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    final sampleCsv = '''时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券
2026/6/27 19:17,三餐,,支出,40,CNY,,,,,,,
2026/6/27 19:16,购物,,支出,3546,CNY,,,,,,,
2026/6/27 17:22,零食,,支出,48,CNY,,,,周大生,,
2026/6/26 12:30,停车费,,支出,13.5,CNY,,,,,,,
2026/6/24 17:40,停车费,,支出,10,CNY,,,,,,,
2026/6/24 12:43,三餐,,支出,13.5,CNY,,,,,,,
2026/6/24 12:43,三餐,,支出,12,CNY,,,,,,,
2026/6/23 12:42,停车费,,支出,14,CNY,,,,,,,
2026/6/21 9:14,零食,,支出,200,CNY,,,,,,,
2026/6/20 20:15,过路费,,支出,97,CNY,,,,,,,
2026/6/20 20:15,过路费,,支出,160,CNY,,,,,,,
2026/6/19 23:54,充电,,支出,18.57,CNY,,,,,,,
2026/6/19 23:53,三餐,,支出,218,CNY,,,,,,,
2026/6/19 23:53,彩票,,支出,36,CNY,,,,,,,
2026/6/19 23:53,收红包,,收入,25,CNY,,,,,,,
2026/6/19 23:53,收红包,,收入,25,CNY,,,,,,,
2026/6/19 23:53,收红包,,收入,117.86,CNY,,,,,,,
2026/6/19 23:53,请客送礼,,支出,200,CNY,,,,,,,
2026/6/19 23:51,停车费,,支出,10,CNY,,,,,,,
2026/6/19 23:51,零食,,支出,358,CNY,,,,,,,
2026/6/19 13:15,彩票,,支出,36,CNY,,,,,,,
2026/6/18 9:54,三餐,,支出,67.9,CNY,,,,,,,
2026/6/18 19:35,住房,,支出,5400,CNY,,,,,,,
2026/6/18 19:34,三餐,,支出,51,CNY,,,,,,,
2026/6/18 11:18,购物,,支出,34.9,CNY,,,,,,,
2026/6/18 11:18,购物,,支出,92.8,CNY,,,,,,,
2026/6/18 11:17,购物,,支出,92.8,CNY,,,,,,,
2026/6/18 11:17,购物,,支出,202.48,CNY,,,,,,,
2026/6/18 11:17,购物,,支出,67.06,CNY,,,,,,,
2026/6/17 11:17,零食,,支出,77.81,CNY,,,,,,,
2026/6/17 11:15,充电,,支出,50,CNY,,,,,,,
2026/6/17 17:07,彩票,,支出,36,CNY,,,,,,,
2026/6/17 17:07,三餐,,支出,15,CNY,,,,,,,
2026/6/16 22:13,三餐,,支出,33,CNY,,,,,,,
2026/6/16 22:13,三餐,,支出,33,CNY,,,,,,,
2026/6/16 22:13,水电煤,,支出,18.74,CNY,,,,,,,
2026/6/16 22:13,水电煤,,支出,18.74,CNY,,,,,,,
2026/6/15 23:32,日用品,,支出,280,CNY,,,,,,,
''';

    try {
      final rows = CsvImporter.parseCsv(sampleCsv);
      if (rows.isEmpty) {
        setState(() => _errorMessage = '未解析到数据，请检查CSV格式');
        return;
      }

      final format = CsvImporter.detectCsvFormat(rows);
      final mapped = rows.map((row) => CsvImporter.mapFields(format, row)).toList();

      setState(() {
        _csvData = rows;
        _detectedFormat = format;
        _mappedData = mapped;
      });
    } catch (e) {
      setState(() => _errorMessage = '解析失败: $e');
    } finally {
      setState(() => _isLoading = false);
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
              _showImportSuccess();
            },
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  void _showImportSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入成功'),
        content: Text('成功导入 ${_mappedData!.length} 条记录'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入数据'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_csvData == null) ...[
              _buildUploadArea(),
              const SizedBox(height: AppTheme.spaceLarge),
              _buildFormatHelp(),
            ] else ...[
              _buildPreviewSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
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
                  '支持微信、支付宝等账单格式',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          ElevatedButton(
            onPressed: _isLoading ? null : _pickFile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXXLarge,
                vertical: AppTheme.spaceLarge,
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('选择文件'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.errorColor),
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
          Text(
            '推荐格式:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXSmall),
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
          Wrap(
            spacing: AppTheme.spaceSmall,
            children: const [
              Chip(label: Text('时间')),
              Chip(label: Text('分类')),
              Chip(label: Text('二级分类')),
              Chip(label: Text('类型')),
              Chip(label: Text('金额')),
              Chip(label: Text('币种')),
              Chip(label: Text('账户1')),
              Chip(label: Text('账户2')),
              Chip(label: Text('备注')),
              Chip(label: Text('已报销')),
              Chip(label: Text('手续费')),
              Chip(label: Text('优惠券')),
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
              rows: (_mappedData ?? []).map((row) {
                final isIncome = row['isIncome'] == 'true';
                return DataRow(
                  cells: [
                    DataCell(Text(row['date'] ?? '')),
                    DataCell(Text(row['category'] ?? '')),
                    DataCell(
                      Text(
                        isIncome ? '收入' : '支出',
                        style: TextStyle(
                          color: isIncome ? AppTheme.successColor : AppTheme.warningColor,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${isIncome ? '+' : '-'}${row['amount'] ?? ''}',
                        style: TextStyle(
                          color: isIncome ? AppTheme.successColor : AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(Text(row['account'] ?? '')),
                    DataCell(Text(row['note'] ?? '')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLarge),
        ElevatedButton(
          onPressed: _confirmImport,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXXLarge,
              vertical: AppTheme.spaceLarge,
            ),
          ),
          child: const Text('确认导入'),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextButton(
          onPressed: () {
            setState(() {
              _csvData = null;
              _detectedFormat = null;
              _mappedData = null;
            });
          },
          child: const Text('重新选择文件'),
        ),
      ],
    );
  }
}

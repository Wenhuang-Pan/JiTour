import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:decimal/decimal.dart';
import '../services/csv_importer.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

/// CSV导入页面
///
/// 支持从本地选择CSV文件并导入交易数据
/// 支持多种格式：微信支付账单、支付宝账单、随手记、记途格式、通用CSV
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<Map<String, String>>? _csvData;
  List<Map<String, String>>? _mappedData;
  List<Transaction>? _transactions;
  bool _isLoading = false;
  String? _errorMessage;
  String? _fileName;
  String? _formatName;
  int _successCount = 0;
  int _failCount = 0;
  // WHY: 保存第一条失败记录的详细原因，用于 UI 显示，便于用户排查格式问题
  String? _firstFailReason;
  String? _firstFailMapping;

  /// 选择CSV文件
  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fileName = null;
      _formatName = null;
      _successCount = 0;
      _failCount = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _errorMessage = '未选择文件');
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() => _errorMessage = '无法读取文件内容');
        return;
      }

      // WHY: Flutter Web 端 FilePicker 返回的 bytes 可能被 JS 层按 Latin-1 解码，
      // 导致 utf8.decode 二次解码失败。直接传 bytes 给 parseCsv，由其内部处理编码。
      _processCsv(file.bytes!, file.name);
    } catch (e) {
      setState(() => _errorMessage = '选择文件失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 处理CSV内容
  void _processCsv(Uint8List bytes, String fileName) {
    try {
      debugPrint('[CsvImport] === 开始处理 CSV ===');
      debugPrint('[CsvImport] 文件名: $fileName');
      debugPrint('[CsvImport] bytes 长度: ${bytes.length}');

      final rows = CsvImporter.parseCsvFromBytes(bytes);
      debugPrint('[CsvImport] parseCsv 行数: ${rows.length}');
      if (rows.isEmpty) {
        debugPrint('[CsvImport] ❌ parseCsv 返回空');
        setState(() => _errorMessage = '未解析到数据，请检查CSV格式');
        return;
      }

      debugPrint('[CsvImport] 表头: ${rows[0].keys.toList()}');
      debugPrint('[CsvImport] 第1行数据: ${rows[0]}');

      final format = CsvImporter.detectCsvFormat(rows);
      final formatName = CsvImporter.getFormatName(format);
      debugPrint('[CsvImport] 检测格式: $formatName');

      // WHY: 用 for 循环而非 .map()，以便传入 debugRowIdx 输出前3行详细匹配日志
      final mapped = <Map<String, String>>[];
      for (int i = 0; i < rows.length; i++) {
        mapped.add(CsvImporter.mapFields(format, rows[i], i));
      }
      debugPrint('[CsvImport] mapFields 完成, 行数: ${mapped.length}');

      // 转换为交易对象
      final transactions = <Transaction>[];
      int failCount = 0;
      String? firstFailReason;
      String? firstFailMapping;
      for (int i = 0; i < mapped.length; i++) {
        final mapping = mapped[i];
        final transaction = CsvImporter.mappingToTransaction(mapping);
        if (transaction != null) {
          transactions.add(transaction);
        } else {
          failCount++;
          if (firstFailReason == null) {
            firstFailMapping = mapping.toString();
            final date = CsvImporter.parseDate(mapping['date'] ?? '');
            final amount = CsvImporter.parseAmount(mapping['amount'] ?? '');
            if (date == null) {
              firstFailReason = '日期解析失败: "${mapping['date']}"';
            } else if (amount <= Decimal.zero) {
              firstFailReason = '金额解析失败: "${mapping['amount']}" → $amount';
            } else {
              firstFailReason = '未知原因';
            }
          }
        }
      }
      debugPrint(
          '[CsvImport] 转换完成: 成功 ${transactions.length} 条, 失败 $failCount 条');

      setState(() {
        _csvData = rows;
        _mappedData = mapped;
        _transactions = transactions;
        _fileName = fileName;
        _formatName = formatName;
        _successCount = transactions.length;
        _failCount = failCount;
        _firstFailReason = firstFailReason;
        _firstFailMapping = firstFailMapping;
      });
    } catch (e, stack) {
      debugPrint('[CsvImport] ❌ 解析异常: $e');
      debugPrint('[CsvImport] 堆栈: $stack');
      setState(() => _errorMessage = '解析失败: $e');
    }
  }

  /// 确认导入到数据库
  void _confirmImport() {
    if (_transactions == null || _transactions!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将导入 ${_transactions!.length} 条记录到数据库'),
            const SizedBox(height: 8),
            Text('格式: $_formatName'),
            const SizedBox(height: 8),
            Text('文件名: $_fileName'),
          ],
        ),
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

  /// 执行导入操作
  void _doImport() async {
    if (_transactions == null || _transactions!.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      for (final transaction in _transactions!) {
        await DatabaseService.addTransaction(transaction);
      }

      _showImportSuccess();
    } catch (e) {
      setState(() => _errorMessage = '导入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 显示导入成功提示
  void _showImportSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功导入 ${_transactions!.length} 条记录'),
            if (_failCount > 0) Text('跳过 $_failCount 条无效记录'),
          ],
        ),
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

  /// 构建上传区域
  Widget _buildUploadArea() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  color: AppTheme.getPrimaryColor(context),
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
                  '支持微信、支付宝、随手记等账单格式',
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
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建格式帮助区域
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
            '支持的导入格式',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          const Wrap(
            spacing: AppTheme.spaceSmall,
            children: [
              Chip(label: Text('微信支付账单')),
              Chip(label: Text('支付宝账单')),
              Chip(label: Text('随手记')),
              Chip(label: Text('记途格式')),
              Chip(label: Text('通用CSV')),
            ],
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
              '时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,已报销,手续费,优惠券',
              style: TextStyle(fontFamily: 'Monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建预览区域
  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 文件信息
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            children: [
              Icon(Icons.file_copy_rounded,
                  color: AppTheme.getPrimaryColor(context)),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '检测格式: $_formatName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceLarge),

        // 统计信息
        Row(
          children: [
            Text(
              '导入预览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Wrap(
              spacing: AppTheme.spaceLarge,
              children: [
                Text(
                  '有效: $_successCount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (_failCount > 0)
                  Text(
                    '无效: $_failCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor,
                        ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMedium),

        // WHY: 失败时显示第一条失败记录的详细原因，便于用户排查
        if (_failCount > 0 && _firstFailReason != null) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMedium),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.errorColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppTheme.errorColor, size: 18),
                    const SizedBox(width: AppTheme.spaceSmall),
                    Text(
                      '失败原因（第1条）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Text(
                  _firstFailReason!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.errorColor,
                      ),
                ),
                if (_firstFailMapping != null) ...[
                  const SizedBox(height: AppTheme.spaceSmall),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSmall),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: SelectableText(
                      _firstFailMapping!,
                      style: TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 11,
                        // WHY: 改用 onSurfaceVariant，暗色模式下自动变为浅灰
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
        ],
        const SizedBox(height: AppTheme.spaceSmall),

        // 数据表格预览
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
                          color: isIncome
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${isIncome ? '+' : '-'}${row['amount'] ?? ''}',
                        style: TextStyle(
                          color: isIncome
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
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

        // 操作按钮
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmImport,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXXLarge,
              vertical: AppTheme.spaceLarge,
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('确认导入'),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextButton(
          onPressed: () {
            setState(() {
              _csvData = null;
              _mappedData = null;
              _transactions = null;
              _fileName = null;
              _formatName = null;
              _successCount = 0;
              _failCount = 0;
            });
          },
          child: const Text('重新选择文件'),
        ),
      ],
    );
  }
}

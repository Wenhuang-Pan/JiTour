import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../utils/icon_library.dart';
import '../utils/uuid_util.dart';

/// 拍照记账页面
/// 支持从相册选择图片或拍摄照片进行记账
class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _ocrController = TextEditingController();

  /// 选中的图片文件
  XFile? _selectedImage;

  /// 图片预览
  Image? _imagePreview;

  /// 收支类型（0: 支出, 1: 收入）
  int _currentTab = 0;

  /// 选中的分类
  Category? _selectedCategory;

  /// 选中的账户
  Account? _selectedAccount;

  /// 选中的日期
  DateTime _selectedDate = DateTime.now();

  /// 是否报销
  bool _isReimbursed = false;

  /// 是否正在处理
  bool _isProcessing = false;

  /// 是否正在执行OCR识别
  bool _isRecognizing = false;

  /// OCR识别文本
  String _ocrText = '';

  /// OCR提取的金额
  String _extractedAmount = '';

  /// OCR提取的项目
  String _extractedItem = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultValues();
    });
  }

  /// 加载默认值
  void _loadDefaultValues() {
    final accounts = AccountService.getActiveAccounts();
    if (accounts.isNotEmpty) {
      setState(() {
        _selectedAccount = accounts.first;
      });
    }
    _updateDefaultCategory();
  }

  /// 更新默认分类
  void _updateDefaultCategory() {
    final categories = _currentTab == 0
        ? CategoryService.getExpenseCategories()
        : CategoryService.getIncomeCategories();
    setState(() {
      _selectedCategory = categories.firstOrNull;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ocrController.dispose();
    super.dispose();
  }

  /// 从相册选择图片
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _imagePreview = Image.file(
          File(pickedFile.path),
          fit: BoxFit.contain,
        );
      });
      // 自动执行OCR识别
      await _recognizeTextFromImage(pickedFile.path);
    }
  }

  /// 拍照
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _imagePreview = Image.file(
          File(pickedFile.path),
          fit: BoxFit.contain,
        );
      });
      // 自动执行OCR识别
      await _recognizeTextFromImage(pickedFile.path);
    }
  }

  /// 使用 ML Kit 自动识别图片中的文字
  ///
  /// @param imagePath 图片文件路径
  /// @return Future<void> 无返回值，识别结果会更新 _ocrText 并触发 _extractOcrInfo
  /// @throws Exception 当OCR识别失败时弹出 SnackBar 提示
  Future<void> _recognizeTextFromImage(String imagePath) async {
    setState(() {
      _isRecognizing = true;
      _ocrText = '';
      _extractedAmount = '';
      _extractedItem = '';
      _ocrController.clear();
    });

    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      // WHY: 使用默认的 LatinTextRecognizer，对中英文小票识别效果最佳；
      // 若需纯中文识别可切换为 ChineseTextRecognizer
      final TextRecognizer textRecognizer = TextRecognizer();
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String recognizedString = recognizedText.text;

      if (recognizedString.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未识别到文字，请拍摄更清晰的小票或手动输入'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // WHY: 识别到文字后，同步更新 controller 和 _ocrText，再自动调用提取逻辑
      // 填入金额/分类/备注
      if (mounted) {
        setState(() {
          _ocrText = recognizedString;
          _ocrController.text = recognizedString;
        });
        _extractOcrInfo();
      }
    } catch (e) {
      debugPrint('OCR识别失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片识别失败，请手动输入小票内容'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  /// 删除选中的图片
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imagePreview = null;
      _ocrText = '';
      _extractedAmount = '';
      _extractedItem = '';
      _ocrController.clear();
    });
  }

  /// 选择日期
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        if (child == null) return const SizedBox();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              primary: AppTheme.getPrimaryColor(context),
              onPrimary: Colors.white,
              secondary: AppTheme.getPrimaryColor(context),
              onSecondary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
              error: AppTheme.errorColor,
              onError: Colors.white,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// 保存交易
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类和账户')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final amount = Decimal.parse(_amountController.text);
      final transaction = Transaction(
        id: UuidUtil.generate(),
        amount: amount,
        isIncome: _currentTab == 1,
        category: _selectedCategory!.name,
        account: _selectedAccount!.name,
        date: _selectedDate,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        isReimbursed: _isReimbursed,
        fee: Decimal.zero,
        coupon: Decimal.zero,
      );

      await DatabaseService.transactions.add(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记账成功'),
            duration: Duration(milliseconds: 800),
          ),
        );
        // 直接返回主页，弹出所有路由直到第一个
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片选择区域
              _buildImageSection(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // OCR识别区域
              _buildOcrSection(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 收支类型切换
              _buildTypeTabs(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 金额输入
              _buildAmountField(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 分类选择
              _buildCategorySection(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 账户选择
              _buildAccountSection(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 日期选择
              _buildDateSection(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 备注输入
              _buildNoteField(context),
              const SizedBox(height: AppTheme.spaceLarge),

              // 报销选项
              _buildReimbursedOption(context),
              const SizedBox(height: AppTheme.spaceXXXLarge),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// 构建 AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('拍照记账'),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// 构建OCR识别区域
  Widget _buildOcrSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '小票识别',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMedium),
          decoration: BoxDecoration(
            color: AppTheme.getSecondaryBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: AppTheme.getDividerColor(context),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _ocrController,
                onChanged: (value) {
                  setState(() {
                    _ocrText = value;
                  });
                },
                onFieldSubmitted: (_) {
                  _extractOcrInfo();
                },
                decoration: const InputDecoration(
                  hintText: '输入小票识别内容，系统会自动提取金额和项目...',
                  border: InputBorder.none,
                  filled: false,
                ),
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _ocrText.isNotEmpty ? _extractOcrInfo : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.getPrimaryColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMedium,
                        vertical: AppTheme.spaceXSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16),
                        SizedBox(width: 4),
                        Text('智能提取'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_extractedAmount.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSmall,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        '提取金额: ¥$_extractedAmount',
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_extractedItem.isNotEmpty)
                    const SizedBox(width: AppTheme.spaceSmall),
                  if (_extractedItem.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSmall,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        '项目: $_extractedItem',
                        style: const TextStyle(
                          color: AppTheme.successColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 从OCR文本中提取金额和项目信息
  void _extractOcrInfo() {
    final text = _ocrText;
    String processedText = text;

    // ========== 1. 金额识别（增强版，支持多种模式） ==========
    final List<Pattern> amountPatterns = [
      // ¥100, ￥100.50, ¥ 1,234.56
      RegExp(r'[¥￥]\s*([\d,]+\.?\d{0,2})'),
      // 100元, 50.50块, 99块钱, 1234.5元, 100圆
      RegExp(r'([\d,]+\.?\d{0,2})\s*[元块圆]'),
      // 合计:100, 总计 200.50, 金额 ￥300
      RegExp(
          r'(?:合计|总计|共计|应收|实收|实付|应付|金额|消费|支出|存入|收款)[^¥￥\d]{0,5}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      // 银行卡消费：100.00
      RegExp(r'消费[^¥￥\d]{0,10}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      RegExp(r'支出[^¥￥\d]{0,10}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      // 小票底部金额（总xxx:）
      RegExp(r'总[^¥￥\d]{0,3}[¥￥]?\s*([\d,]+\.?\d{0,2})'),
      // RMB 100.00
      RegExp(r'(?:RMB|人民币)\s*[¥￥]?\s*([\d,]+\.?\d{0,2})'),
    ];

    String extractedAmount = '';
    for (final pattern in amountPatterns) {
      final match = RegExp(pattern.toString()).firstMatch(processedText);
      if (match != null) {
        final amountRaw = match.group(1) ?? '';
        if (amountRaw.isNotEmpty) {
          final cleaned = amountRaw.replaceAll(',', '');
          final value = double.tryParse(cleaned);
          if (value != null && value > 0 && value < 100000000) {
            extractedAmount = cleaned;
            break;
          }
        }
      }
    }

    // 如果还是没找到，找最大的两位小数数字（通常是总金额）
    if (extractedAmount.isEmpty) {
      final allNumbers = RegExp(r'[\d,]+\.\d{1,2}').allMatches(processedText);
      double maxAmount = 0;
      for (final match in allNumbers) {
        final numStr = match.group(0)?.replaceAll(',', '') ?? '';
        final value = double.tryParse(numStr);
        if (value != null && value > maxAmount && value < 1000000) {
          maxAmount = value;
        }
      }
      if (maxAmount > 0) {
        extractedAmount = maxAmount
            .toStringAsFixed(maxAmount.truncateToDouble() == maxAmount ? 0 : 2);
      }
    }

    // 最后兜底：找任何数字
    if (extractedAmount.isEmpty) {
      final anyNumber = RegExp(r'[\d,]+\.?\d*').firstMatch(processedText);
      if (anyNumber != null) {
        final numStr = anyNumber.group(0)?.replaceAll(',', '') ?? '';
        final value = double.tryParse(numStr);
        if (value != null && value > 0 && value < 100000000) {
          extractedAmount = numStr;
        }
      }
    }

    // ========== 2. 分类识别 ==========
    final Map<String, List<String>> categoryKeywords = {
      '餐饮': [
        '餐',
        '饭',
        '吃',
        '喝',
        '美食',
        '餐厅',
        '饭店',
        '外卖',
        '早茶',
        '午餐',
        '晚餐',
        '早餐',
        '夜宵',
        '餐饮',
        '酒楼'
      ],
      '交通': [
        '车',
        '交通',
        '油',
        '打车',
        '出租',
        '滴滴',
        '地铁',
        '公交',
        '火车',
        '高铁',
        '机票',
        '加油',
        '停车',
        '高速',
        '出行'
      ],
      '购物': ['购物', '买', '超市', '商场', '淘宝', '京东', '网购', '快递', '便利店', '商店', '零售'],
      '娱乐': ['娱乐', '玩', '电影', '游戏', 'KTV', '旅游', '景区', '门票', '健身', '运动'],
      '居家': ['水电', '房租', '物业', '燃气', '网络', '电话', '手机', '家电', '家具', '维修', '生活'],
      '医疗': ['医院', '看病', '药', '体检', '挂号', '医疗', '诊所', '药店'],
      '教育': ['书', '学习', '课程', '培训', '学费', '考试', '教育'],
      '通讯': ['话费', '充值', '流量', '宽带', '通讯'],
      '人情': ['红包', '送礼', '份子', '礼物'],
      '投资': ['股票', '基金', '理财', '投资'],
      '工资': ['工资', '收入', '奖金', '薪资', '月薪', '年薪'],
      '奖金': ['奖金', '提成', '奖励', '分红'],
      '红包': ['红包', '转账收入', '收款'],
      '兼职': ['兼职', '外快', '副业'],
    };

    final expenseCategories = CategoryService.getExpenseCategories();
    final incomeCategories = CategoryService.getIncomeCategories();
    final allCategories = [...expenseCategories, ...incomeCategories];

    String matchedCategory = '';
    for (final category in allCategories) {
      if (processedText.contains(category.name)) {
        matchedCategory = category.name;
        break;
      }
    }
    if (matchedCategory.isEmpty) {
      for (final entry in categoryKeywords.entries) {
        for (final keyword in entry.value) {
          if (processedText.contains(keyword)) {
            final exists = allCategories.any((c) => c.name == entry.key);
            if (exists) {
              matchedCategory = entry.key;
              break;
            }
          }
        }
        if (matchedCategory.isNotEmpty) break;
      }
    }

    // 判断收支类型并更新分类
    if (matchedCategory.isNotEmpty) {
      final category = allCategories.firstWhere(
        (c) => c.name == matchedCategory,
        orElse: () => allCategories.first,
      );
      setState(() {
        _selectedCategory = category;
        _currentTab = category.isIncome ? 1 : 0;
      });
    }

    // ========== 3. 备注/项目提取 ==========
    String noteText = processedText;
    noteText = noteText.replaceAll(RegExp(r'[¥￥]'), '');
    noteText = noteText.replaceAll(RegExp(r'[\d,]+\.?\d*'), '');
    noteText = noteText.replaceAll(RegExp(r'[元块角分整圆RMB人民币]'), '');
    final removeKeywords = [
      '合计',
      '总计',
      '共计',
      '应收',
      '实收',
      '实付',
      '应付',
      '金额',
      '消费',
      '支出',
      '存入',
      '收款',
      '付款',
      '支付',
      '花费',
      '花了',
      '小票',
      '发票',
      '收据',
      '单号',
      '编号',
      '时间',
      '日期',
      '欢迎光临',
      '谢谢惠顾',
      '商品',
      '数量',
      '单价',
      '小计',
    ];
    for (final kw in removeKeywords) {
      noteText = noteText.replaceAll(kw, '');
    }
    if (matchedCategory.isNotEmpty) {
      noteText = noteText.replaceAll(matchedCategory, '');
      final keywords = categoryKeywords[matchedCategory] ?? [];
      for (final kw in keywords) {
        noteText = noteText.replaceAll(kw, '');
      }
    }
    noteText = noteText.replaceAll(RegExp(r'\s+'), ' ').trim();
    noteText = noteText
        .replaceAll(
            RegExp(r'[，。！？、；：""' '【】《》（）()[]{}<>/\\|@#\$%^&*-_=+`~]+'), ' ')
        .trim();
    if (noteText.length > 50) {
      noteText = noteText.substring(0, 50);
    }

    setState(() {
      _extractedAmount = extractedAmount;
      _extractedItem = noteText.length >= 2 ? noteText : '';

      if (extractedAmount.isNotEmpty && _amountController.text.isEmpty) {
        _amountController.text = extractedAmount;
      }

      if (_extractedItem.isNotEmpty && _noteController.text.isEmpty) {
        _noteController.text = _extractedItem;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          extractedAmount.isNotEmpty
              ? '已提取金额 ¥$extractedAmount${_extractedItem.isNotEmpty ? ' 和备注 "$_extractedItem"' : ''}${matchedCategory.isNotEmpty ? '，分类：$matchedCategory' : ''}'
              : '未识别到金额，请手动输入或检查OCR文本',
        ),
        backgroundColor: extractedAmount.isNotEmpty
            ? AppTheme.successColor
            : AppTheme.warningColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 构建图片选择区域
  Widget _buildImageSection(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.getDividerColor(context),
          width: 1,
        ),
      ),
      child: _selectedImage != null
          ? Stack(
              children: [
                _imagePreview ?? const SizedBox(),
                // WHY: OCR识别中时显示半透明遮罩和加载指示器，提升用户感知
                if (_isRecognizing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: AppTheme.spaceSmall),
                          Text(
                            '正在识别小票内容...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: AppTheme.spaceSmall,
                  right: AppTheme.spaceSmall,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isRecognizing ? null : _removeImage,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                Text(
                  '点击选择或拍摄图片',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.neutral500,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('相册'),
                    ),
                    const SizedBox(width: AppTheme.spaceLarge),
                    TextButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_rounded),
                      label: const Text('拍照'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  /// 构建收支类型切换
  Widget _buildTypeTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = 0;
                });
                _updateDefaultCategory();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceMedium),
                decoration: BoxDecoration(
                  color: _currentTab == 0
                      ? AppTheme.errorColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Text(
                  '支出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _currentTab == 0
                        ? AppTheme.errorColor
                        : AppTheme.neutral500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
                _updateDefaultCategory();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceMedium),
                decoration: BoxDecoration(
                  color: _currentTab == 1
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Text(
                  '收入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _currentTab == 1
                        ? AppTheme.successColor
                        : AppTheme.neutral500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建金额输入
  Widget _buildAmountField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '金额',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '¥',
            prefixStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _currentTab == 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
            hintText: '0.00',
            filled: true,
            fillColor: AppTheme.getSecondaryBackground(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: AppTheme.getPrimaryColor(context),
                width: 2,
              ),
            ),
          ),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _currentTab == 0
                    ? AppTheme.errorColor
                    : AppTheme.successColor,
              ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入金额';
            }
            final amount = Decimal.tryParse(value);
            if (amount == null || amount <= Decimal.zero) {
              return '请输入有效的金额';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// 构建分类选择
  Widget _buildCategorySection(BuildContext context) {
    final categories = _currentTab == 0
        ? CategoryService.getExpenseCategories()
        : CategoryService.getIncomeCategories();

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Wrap(
          spacing: AppTheme.spaceSmall,
          runSpacing: AppTheme.spaceSmall,
          children: categories.map((category) {
            final isSelected = _selectedCategory?.id == category.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMedium,
                  vertical: AppTheme.spaceSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.1)
                      : AppTheme.getSecondaryBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : AppTheme.getDividerColor(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconLibrary.getIconByName(category.iconName),
                      size: 16,
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.neutral500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.getPrimaryColor(context)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建账户选择
  Widget _buildAccountSection(BuildContext context) {
    final accounts = AccountService.getActiveAccounts();

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        Wrap(
          spacing: AppTheme.spaceSmall,
          runSpacing: AppTheme.spaceSmall,
          children: accounts.map((account) {
            final isSelected = _selectedAccount?.id == account.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAccount = account;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMedium,
                  vertical: AppTheme.spaceSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.getPrimaryColor(context).withValues(alpha: 0.1)
                      : AppTheme.getSecondaryBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : AppTheme.getDividerColor(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconLibrary.getIconByName(account.iconName),
                      size: 16,
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.neutral500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      account.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.getPrimaryColor(context)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建日期选择
  Widget _buildDateSection(BuildContext context) {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final weekDayFormatter = DateFormat('EEE', 'zh_CN');

    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMedium),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormatter.format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    weekDayFormatter.format(_selectedDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建备注输入
  Widget _buildNoteField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '备注',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          controller: _noteController,
          decoration: InputDecoration(
            hintText: '输入备注信息（可选）',
            filled: true,
            fillColor: AppTheme.getSecondaryBackground(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: AppTheme.getPrimaryColor(context),
                width: 2,
              ),
            ),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  /// 构建报销选项
  Widget _buildReimbursedOption(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '是否报销',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Switch(
          value: _isReimbursed,
          onChanged: (value) {
            setState(() {
              _isReimbursed = value;
            });
          },
          activeThumbColor: AppTheme.getPrimaryColor(context),
        ),
      ],
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: ElevatedButton(
          onPressed: _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.getPrimaryColor(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            minimumSize: const Size(double.infinity, 56),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

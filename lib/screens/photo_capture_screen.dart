import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
    }
  }

  /// 删除选中的图片
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imagePreview = null;
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
      final amount = double.parse(_amountController.text);
      final transaction = Transaction(
        id: UuidUtil.generate(),
        amount: amount,
        isIncome: _currentTab == 1,
        category: _selectedCategory!.name,
        account: _selectedAccount!.name,
        date: _selectedDate,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        isReimbursed: _isReimbursed,
        fee: 0.0,
        coupon: 0.0,
      );

      await DatabaseService.transactions.add(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记账成功')),
        );
        Navigator.pop(context);
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
              const SizedBox(height: AppTheme.spaceXLarge),

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
                Positioned(
                  top: AppTheme.spaceSmall,
                  right: AppTheme.spaceSmall,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _removeImage,
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
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
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

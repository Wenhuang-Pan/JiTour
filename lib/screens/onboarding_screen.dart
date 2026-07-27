import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.wallet_rounded,
      title: '欢迎使用记途',
      description: '一款简洁优雅的个人记账应用，帮助您轻松管理财务',
      gradient: const LinearGradient(
        colors: [Color(0xFF34D399), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      icon: Icons.pie_chart_rounded,
      title: '智能统计',
      description: '自动生成收支报表，一目了然掌握财务状况',
      gradient: const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      icon: Icons.flag_rounded,
      title: '存钱计划',
      description: '设定储蓄目标，养成良好的理财习惯',
      gradient: const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _goToSavingsSetup() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _pages.length,
        itemBuilder: (context, index) => _buildPage(context, _pages[index], index),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildPage(BuildContext context, OnboardingPage page, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXLarge),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: page.gradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXXLarge),
              boxShadow: [
                BoxShadow(
                  color: page.gradient.colors.first.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXXXLarge),
          Text(
            page.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutral500,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          if (index == _pages.length - 1) ...[
            const SizedBox(height: AppTheme.spaceXXXLarge),
            _buildSavingsPrompt(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSavingsPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.neutral100),
      ),
      child: Column(
        children: [
          Text(
            '设定您的第一个存钱目标',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSmall),
          Text(
            '设定目标金额和截止日期，开始您的储蓄计划',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: '目标金额',
                    prefixText: '¥',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.neutral100,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSmall),
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: '截止日期',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.neutral100,
                  ),
                  keyboardType: TextInputType.datetime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _goToSavingsSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              child: const Text('开始储蓄计划'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
        boxShadow: AppTheme.cardShadow,
        border: Border(top: BorderSide(color: AppTheme.neutral100)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _pages.asMap().entries.map((entry) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: entry.key == _currentPage
                      ? AppTheme.primaryColor
                      : AppTheme.neutral200,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Row(
            children: [
              if (_currentPage < _pages.length - 1)
                TextButton(
                  onPressed: _skipOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.neutral500,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('跳过'),
                ),
              const Spacer(),
              if (_currentPage < _pages.length - 1)
                SizedBox(
                  width: 120,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('下一步'),
                  ),
                )
              else
                SizedBox(
                  width: 140,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('开始使用'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;

  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

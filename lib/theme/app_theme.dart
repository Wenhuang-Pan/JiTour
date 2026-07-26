import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  AppTheme._();

  // ==================== 品牌主色 ====================
  static const Color primaryColor = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);

  // 动态获取主题主色（从 ThemeProvider）
  static Color getPrimaryColor(BuildContext context) {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      return themeProvider.primaryColor;
    } catch (e) {
      return primaryColor;
    }
  }

  // 动态获取主题渐变（从 ThemeProvider）
  static LinearGradient getPrimaryGradient(BuildContext context) {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      return themeProvider.primaryGradient;
    } catch (e) {
      return const LinearGradient(
        colors: [Color(0xFF34D399), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  // ==================== 功能色 ====================
  static const Color successColor = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);

  static const Color warningColor = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color errorColor = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color infoColor = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);

  // ==================== 中性色阶 ====================
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral950 = Color(0xFF030712);

  // ==================== 分类色板 ====================
  static const List<Color> categoryPalette = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF78350F),
    Color(0xFF6B7280),
    Color(0xFF14B8A6),
  ];

  // ==================== 圆角系统 ====================
  static const double radiusXS = 6.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 24.0;
  static const double radiusFull = 9999.0;

  // ==================== 间距系统 ====================
  static const double space0 = 0.0;
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 12.0;
  static const double spaceLarge = 16.0;
  static const double spaceXLarge = 20.0;
  static const double spaceXXLarge = 24.0;
  static const double spaceXXXLarge = 32.0;
  static const double spaceHuge = 48.0;

  // ==================== 字体系统 ====================
  static const String fontFamily = '';
  static const String fontFamilyFallback =
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

  static const double textDisplayLarge = 48.0;
  static const double textDisplayMedium = 36.0;
  static const double textDisplaySmall = 32.0;
  static const double textHeadlineLarge = 28.0;
  static const double textHeadlineMedium = 24.0;
  static const double textHeadlineSmall = 20.0;
  static const double textTitleLarge = 18.0;
  static const double textTitleMedium = 16.0;
  static const double textTitleSmall = 14.0;
  static const double textBodyLarge = 16.0;
  static const double textBodyMedium = 14.0;
  static const double textBodySmall = 13.0;
  static const double textLabelLarge = 14.0;
  static const double textLabelMedium = 12.0;
  static const double textLabelSmall = 11.0;

  // ==================== 动画时长 ====================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
  static const Duration animSlower = Duration(milliseconds: 600);

  // ==================== 阴影系统 ====================
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadowStrong = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x3310B981),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.25),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: color.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ==================== 渐变系统 ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDeep = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== 主题生成 ====================
  static ThemeData getTheme(BuildContext context, {required bool isDark}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.primaryColor;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: isDark
          ? _getDarkColorScheme(primaryColor)
          : _getLightColorScheme(primaryColor),
      scaffoldBackgroundColor: isDark ? neutral900 : neutral50,
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? neutral800 : neutral0,
        shadowColor: isDark ? const Color(0x33000000) : const Color(0x10000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? neutral900 : neutral50,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? neutral100 : neutral900,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: textTitleLarge,
          fontWeight: FontWeight.w700,
          color: isDark ? neutral100 : neutral900,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(
          color: isDark ? neutral400 : neutral600,
          size: 24,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        extendedTextStyle: const TextStyle(
          fontSize: textBodyMedium,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconSize: 24,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? neutral700 : neutral200,
          disabledForegroundColor: isDark ? neutral500 : neutral400,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXXLarge,
            vertical: spaceLarge,
          ),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(
            fontSize: textBodyLarge,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXXLarge,
            vertical: spaceLarge,
          ),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(
            fontSize: textBodyLarge,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spaceLarge,
            vertical: spaceSmall,
          ),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall)),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: textBodyMedium,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXXLarge,
            vertical: spaceLarge,
          ),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium)),
          side: BorderSide(color: primaryColor, width: 1.5),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: textBodyLarge,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? neutral800 : neutral100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceLarge,
          vertical: spaceMedium,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        hintStyle: TextStyle(color: neutral500, fontSize: textBodyMedium),
        labelStyle: TextStyle(color: neutral500, fontSize: textBodyMedium),
        floatingLabelStyle:
            TextStyle(color: primaryColor, fontSize: textBodyMedium),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? neutral800 : neutral0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXLarge)),
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: textTitleLarge,
          fontWeight: FontWeight.w700,
          color: isDark ? neutral100 : neutral900,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontSize: textBodyMedium,
          color: isDark ? neutral400 : neutral600,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? neutral800 : neutral0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 24,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusXLarge)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? neutral800 : neutral0,
        selectedItemColor: primaryColor,
        unselectedItemColor: neutral500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: textLabelMedium,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: textLabelMedium,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? neutral800 : neutral0,
        indicatorColor: primaryColor.withOpacity(0.10),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: textLabelMedium,
              fontWeight: FontWeight.w600,
              color: primaryColor,
              letterSpacing: 0.1,
            );
          }
          return TextStyle(
            fontSize: textLabelMedium,
            fontWeight: FontWeight.w500,
            color: neutral500,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return IconThemeData(color: neutral500, size: 24);
        }),
        height: 64,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? neutral700 : neutral200,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: isDark ? neutral400 : neutral600,
        size: 22,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: isDark ? neutral700 : neutral200,
        circularTrackColor: isDark ? neutral700 : neutral200,
        linearMinHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? neutral400 : neutral200;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return isDark ? neutral700 : neutral300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? neutral700 : neutral900,
        contentTextStyle: TextStyle(
          color: isDark ? neutral100 : neutral0,
          fontSize: textBodyMedium,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium)),
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? neutral700 : neutral100,
        selectedColor: primaryColor.withOpacity(0.12),
        secondarySelectedColor: primaryColor.withOpacity(0.12),
        labelStyle: TextStyle(
          fontSize: textLabelMedium,
          fontWeight: FontWeight.w500,
          color: isDark ? neutral100 : neutral800,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: textLabelMedium,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: spaceMedium, vertical: spaceXSmall),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull)),
        side: BorderSide.none,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: isDark ? neutral700 : neutral200,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.12),
        trackHeight: 4,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceLarge,
          vertical: spaceXSmall,
        ),
        minVerticalPadding: spaceSmall,
        iconColor: isDark ? neutral400 : neutral600,
        textColor: isDark ? neutral100 : neutral900,
        titleTextStyle: TextStyle(
          fontSize: textBodyLarge,
          fontWeight: FontWeight.w500,
          color: isDark ? neutral100 : neutral900,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: textBodySmall,
          color: isDark ? neutral400 : neutral500,
        ),
      ),
      textTheme: _getTextTheme(isDark),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }

  // ==================== 颜色方案 ====================
  static ColorScheme _getLightColorScheme(Color primaryColor) {
    return ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryColor.withOpacity(0.10),
      onPrimaryContainer: primaryColor,
      secondary: successColor,
      onSecondary: Colors.white,
      secondaryContainer: successColor.withOpacity(0.10),
      onSecondaryContainer: successDark,
      tertiary: infoColor,
      onTertiary: Colors.white,
      tertiaryContainer: infoColor.withOpacity(0.10),
      onTertiaryContainer: infoColor,
      error: errorColor,
      onError: Colors.white,
      errorContainer: errorColor.withOpacity(0.10),
      onErrorContainer: errorDark,
      surface: neutral50,
      onSurface: neutral900,
      onSurfaceVariant: neutral600,
      outline: neutral300,
      outlineVariant: neutral200,
      shadow: const Color(0x10000000),
      inverseSurface: neutral900,
      inversePrimary: primaryLight,
    );
  }

  static ColorScheme _getDarkColorScheme(Color primaryColor) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryColor.withOpacity(0.15),
      onPrimaryContainer: primaryLight,
      secondary: successLight,
      onSecondary: neutral900,
      secondaryContainer: successColor.withOpacity(0.15),
      onSecondaryContainer: successLight,
      tertiary: infoLight,
      onTertiary: neutral900,
      tertiaryContainer: infoColor.withOpacity(0.15),
      onTertiaryContainer: infoLight,
      error: errorLight,
      onError: neutral900,
      errorContainer: errorColor.withOpacity(0.15),
      onErrorContainer: errorLight,
      surface: neutral900,
      onSurface: neutral100,
      onSurfaceVariant: neutral400,
      outline: neutral700,
      outlineVariant: neutral800,
      shadow: const Color(0x33000000),
      inverseSurface: neutral50,
      inversePrimary: primaryDark,
    );
  }

  // ==================== 字体主题 ====================
  static TextTheme _getTextTheme(bool isDark) {
    final primaryText = isDark ? neutral100 : neutral900;
    final secondaryText = isDark ? neutral400 : neutral600;
    final tertiaryText = isDark ? neutral500 : neutral500;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: textDisplayLarge,
        fontWeight: FontWeight.w800,
        color: primaryText,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: textDisplayMedium,
        fontWeight: FontWeight.w800,
        color: primaryText,
        letterSpacing: -1.2,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontSize: textDisplaySmall,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.8,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: textHeadlineLarge,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.6,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: textHeadlineMedium,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: textHeadlineSmall,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: textTitleLarge,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.3,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: textTitleMedium,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: textTitleSmall,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: textBodyLarge,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.5,
        letterSpacing: -0.1,
      ),
      bodyMedium: TextStyle(
        fontSize: textBodyMedium,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: textBodySmall,
        fontWeight: FontWeight.w400,
        color: tertiaryText,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: textLabelLarge,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: -0.1,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: textLabelMedium,
        fontWeight: FontWeight.w500,
        color: secondaryText,
        letterSpacing: 0.1,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: textLabelSmall,
        fontWeight: FontWeight.w500,
        color: tertiaryText,
        letterSpacing: 0.2,
        height: 1.3,
      ),
    );
  }

  // ==================== 辅助方法 ====================
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? neutral800
        : neutral0;
  }

  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? neutral700
        : neutral200;
  }

  static Color getSecondaryBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? neutral800
        : neutral100;
  }

  static BoxDecoration get gradientCardDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radiusXLarge),
        boxShadow: glowShadow(primaryColor),
      );

  static BoxDecoration whiteCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: getCardColor(context),
      borderRadius: BorderRadius.circular(radiusLarge),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration elevatedCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: getCardColor(context),
      borderRadius: BorderRadius.circular(radiusLarge),
      boxShadow: cardShadowStrong,
    );
  }

  static Widget iconBadge({
    required BuildContext context,
    required IconData icon,
    required Color color,
    double size = 40,
    double iconSize = 20,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

// ==================== 扩展 ====================
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}

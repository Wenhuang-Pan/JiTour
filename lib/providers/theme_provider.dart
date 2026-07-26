import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption {
  light,
  dark,
  system,
}

enum ThemeColorOption {
  blue,
  green,
  purple,
  orange,
  pink,
}

class ThemeProvider extends ChangeNotifier {
  ThemeModeOption _themeMode = ThemeModeOption.system;
  ThemeColorOption _themeColor = ThemeColorOption.blue;
  late SharedPreferences _prefs;

  ThemeModeOption get themeMode => _themeMode;
  ThemeColorOption get themeColor => _themeColor;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }

  Color get primaryColor {
    switch (_themeColor) {
      case ThemeColorOption.blue:
        return const Color(0xFF6366F1);
      case ThemeColorOption.green:
        return const Color(0xFF10B981);
      case ThemeColorOption.purple:
        return const Color(0xFF8B5CF6);
      case ThemeColorOption.orange:
        return const Color(0xFFF59E0B);
      case ThemeColorOption.pink:
        return const Color(0xFFEC4899);
    }
  }

  LinearGradient get primaryGradient {
    switch (_themeColor) {
      case ThemeColorOption.blue:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        );
      case ThemeColorOption.green:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );
      case ThemeColorOption.purple:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
        );
      case ThemeColorOption.orange:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        );
      case ThemeColorOption.pink:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        );
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();
  }

  void _loadPreferences() {
    final modeIndex = _prefs.getInt('theme_mode') ?? 2;
    _themeMode = ThemeModeOption.values[modeIndex];

    final colorIndex = _prefs.getInt('theme_color') ?? 0;
    _themeColor = ThemeColorOption.values[colorIndex];
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    _themeMode = mode;
    await _prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setThemeColor(ThemeColorOption color) async {
    _themeColor = color;
    await _prefs.setInt('theme_color', color.index);
    notifyListeners();
  }

  String getThemeModeName(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return '亮色模式';
      case ThemeModeOption.dark:
        return '暗色模式';
      case ThemeModeOption.system:
        return '跟随系统';
    }
  }

  String getThemeColorName(ThemeColorOption color) {
    switch (color) {
      case ThemeColorOption.blue:
        return '蓝色';
      case ThemeColorOption.green:
        return '绿色';
      case ThemeColorOption.purple:
        return '紫色';
      case ThemeColorOption.orange:
        return '橙色';
      case ThemeColorOption.pink:
        return '粉色';
    }
  }

  Color getThemeColorOptionColor(ThemeColorOption option) {
    switch (option) {
      case ThemeColorOption.blue:
        return const Color(0xFF6366F1);
      case ThemeColorOption.green:
        return const Color(0xFF10B981);
      case ThemeColorOption.purple:
        return const Color(0xFF8B5CF6);
      case ThemeColorOption.orange:
        return const Color(0xFFF59E0B);
      case ThemeColorOption.pink:
        return const Color(0xFFEC4899);
    }
  }
}

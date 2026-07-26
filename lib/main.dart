import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/settings_screen.dart' as settings;
import 'services/database_service.dart';
import 'services/auto_backup_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final currencyProvider = CurrencyProvider();
  await currencyProvider.init();

  final prefs = await SharedPreferences.getInstance();
  final bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  if (isFirstLaunch) {
    await prefs.setBool('is_first_launch', false);
  }

  if (!kIsWeb) {
    await AutoBackupService.initializeNotifications();
    await AutoBackupService.initializeWorkmanager();

    final autoBackupEnabled = await AutoBackupService.isAutoBackupEnabled();
    if (autoBackupEnabled) {
      await AutoBackupService.checkBackupStatus();
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: currencyProvider),
      ],
      child: JituApp(isFirstLaunch: isFirstLaunch),
    ),
  );
}

class JituApp extends StatelessWidget {
  final bool isFirstLaunch;

  const JituApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '记途',
          theme: AppTheme.getTheme(context, isDark: false),
          darkTheme: AppTheme.getTheme(context, isDark: true),
          themeMode: themeProvider.flutterThemeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          initialRoute: isFirstLaunch ? '/onboarding' : '/home',
          routes: {
            '/home': (context) => const HomeScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/settings': (context) => const settings.SettingsScreen(),
            '/data': (context) => const DataManagementScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

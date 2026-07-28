import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/settings_screen.dart' as settings;
import 'services/database_service.dart';
import 'services/auto_backup_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/reminder_provider.dart';
import 'services/recurring_transaction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();
  
  // 检查并执行定期交易
  await RecurringTransactionService.checkAndExecute();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final currencyProvider = CurrencyProvider();
  await currencyProvider.init();

  final reminderProvider = ReminderProvider();
  await reminderProvider.init();

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
        ChangeNotifierProvider.value(value: reminderProvider),
      ],
      child: const JituApp(),
    ),
  );
}

class JituApp extends StatelessWidget {
  const JituApp({super.key});

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
          home: const HomeScreen(),
          routes: {
            '/settings': (context) => const settings.SettingsScreen(),
            '/data': (context) => const DataManagementScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

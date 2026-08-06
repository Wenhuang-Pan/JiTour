import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/csv_import_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_screen.dart' as settings;
import 'services/database_service.dart';
import 'services/auto_backup_service.dart';
import 'services/recurring_transaction_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/auto_accounting_provider.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
    };

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

    final autoAccountingProvider = AutoAccountingProvider();
    await autoAccountingProvider.init();

    if (!kIsWeb) {
      // 暂时禁用自动备份服务初始化，避免某些Android设备崩溃
      // 自动备份功能将在设置页面中手动启用
      debugPrint('Auto backup services skipped for mobile startup');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: currencyProvider),
          ChangeNotifierProvider.value(value: reminderProvider),
          ChangeNotifierProvider.value(value: autoAccountingProvider),
        ],
        child: const JituApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
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
            '/import': (context) => const CsvImportScreen(),
            '/export': (context) => const ExportScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

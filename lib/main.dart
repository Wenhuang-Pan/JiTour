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
import 'screens/app_lock_screen.dart';
import 'services/database_service.dart';
import 'services/balance_migration_service.dart';
import 'services/recurring_transaction_service.dart';
import 'services/app_lock_service.dart';
import 'services/webdav_backup_service.dart';
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

    // WHY: 回收站交易超过保留期后物理清除，启动时惰性执行即可，
    // 无需后台定时任务；box 为内存操作，不影响启动性能
    await DatabaseService.purgeExpiredDeletedTransactions();

    // WHY: 必须先补扣历史自动记账漏扣的余额，再执行当天定期交易，
    // 确保后续交易均走 v2.3.0 的余额联动逻辑，迁移不会重复处理新交易
    await BalanceMigrationService.runIfNeeded();

    // 检查并执行定期交易
    await RecurringTransactionService.checkAndExecute();

    // WHY: 应用锁开关需在 runApp 前加载，决定首帧展示锁屏页还是主页
    await AppLockService.init();

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

    // WHY: WebDAV 自动备份采用 fire-and-forget：不 await、不阻塞首帧渲染；
    // 内部自行判断开关与距上次备份的频率天数，失败仅记录日志。
    // 不使用 workmanager（部分设备有崩溃史），启动时惰性检查即可满足天级频率
    if (!kIsWeb) {
      unawaited(WebdavBackupService.performAutoBackupIfNeeded());
    }
  }, (error, stackTrace) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class JituApp extends StatefulWidget {
  const JituApp({super.key});

  @override
  State<JituApp> createState() => _JituAppState();
}

class _JituAppState extends State<JituApp> with WidgetsBindingObserver {
  /// 当前是否处于锁定状态；应用锁开启时初始为锁定
  bool _locked = AppLockService.isEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WHY: 退到后台即重新上锁，回到前台时要求重新验证（应用锁标准行为）；
    // 仅在 paused（真正离开前台）时锁定，下拉通知栏等 inactive 瞬态不锁
    if (state == AppLifecycleState.paused &&
        AppLockService.isEnabled &&
        !_locked) {
      setState(() => _locked = true);
    }
  }

  /// 锁屏页验证通过后的解锁回调
  void _onUnlocked() {
    setState(() => _locked = false);
  }

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
          home: _locked
              ? AppLockScreen(onUnlocked: _onUnlocked)
              : const HomeScreen(),
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

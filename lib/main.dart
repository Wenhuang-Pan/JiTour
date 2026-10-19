import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'screens/home_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/csv_import_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_screen.dart' as settings;
import 'screens/app_lock_screen.dart';
import 'services/database_service.dart';
import 'services/balance_migration_service.dart';
import 'services/recurring_transaction_service.dart';
import 'services/app_lock_service.dart';
import 'services/update_service.dart';
import 'services/webdav_backup_service.dart';
import 'services/auto_backup_service.dart';
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

    // WHY: 必须先补扣历史自动记账漏扣的余额，再执行当天定期交易，
    // 确保后续交易均走 v2.3.0 的余额联动逻辑，迁移不会重复处理新交易。
    // 迁移幂等且仅升级后首次启动执行，保留在首帧前同步完成，
    // 避免延后窗口期内用户看到未迁移的余额
    await BalanceMigrationService.runIfNeeded();

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

    // WHY: 以下初始化均无首帧依赖（回收站清理/定期交易/版本号），延后到
    // 首帧渲染完成后执行，缩短冷启动白屏时间：
    // - 回收站清理：晚几秒物理清除无影响
    // - 定期交易：每日最多执行一次，且首帧前迁移已完成，顺序依赖保持
    // - 版本号：仅抽屉/设置/关于页展示，用户实际打开远晚于此
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(DatabaseService.purgeExpiredDeletedTransactions());
      unawaited(RecurringTransactionService.checkAndExecute());
      unawaited(UpdateService.init());
    });

    // WHY: WebDAV 自动备份采用 fire-and-forget：不 await、不阻塞首帧渲染；
    // 内部自行判断开关与距上次备份的频率天数，失败仅记录日志。
    // 不使用 workmanager（部分设备有崩溃史），启动时惰性检查即可满足天级频率
    if (!kIsWeb) {
      unawaited(WebdavBackupService.performAutoBackupIfNeeded());
      // WHY: 本地自动备份同为 fire-and-forget 惰性检查，替代旧 workmanager
      // 方案（部分设备崩溃史）；开关与频率由服务内部自行判断
      unawaited(AutoBackupService.performAutoBackupIfNeeded());
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
  /// 全局导航 Key，用于应用外触发（如 App Shortcuts）时执行页面跳转
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// 当前是否处于锁定状态；应用锁开启时初始为锁定
  bool _locked = AppLockService.isEnabled;

  /// 待处理的 App Shortcut 类型；锁定时暂存，解锁后再跳转
  String? _pendingShortcutType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initQuickActions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 初始化 App Shortcuts（仅 Android/iOS，Web 跳过）
  ///
  /// WHY: 长按桌面图标弹出「记一笔」，冷启动或后台唤醒时回调直达；
  /// 应用锁开启时先锁定，跳转请求暂存至解锁后执行，防止未授权记账
  void _initQuickActions() {
    if (kIsWeb) return;
    const quickActions = QuickActions();
    quickActions.initialize((type) {
      if (type == 'add_transaction') {
        if (_locked) {
          _pendingShortcutType = type;
        } else {
          _openAddTransaction();
        }
      }
    });
    quickActions.setShortcutItems(const [
      ShortcutItem(
        type: 'add_transaction',
        localizedTitle: '记一笔',
        icon: 'ic_shortcut_add',
      ),
    ]);
  }

  /// 打开记账页
  void _openAddTransaction() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
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
    setState(() {
      _locked = false;
      // WHY: 解锁后消费暂存的 shortcut 跳转，避免用户在锁屏页反复触发
      if (_pendingShortcutType == 'add_transaction') {
        _pendingShortcutType = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openAddTransaction();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/auto_backup_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();
  
  // 初始化自动备份服务
  await AutoBackupService.initializeNotifications();
  await AutoBackupService.initializeWorkmanager();
  
  // 检查备份状态（仅当自动备份开启时）
  final autoBackupEnabled = await AutoBackupService.isAutoBackupEnabled();
  if (autoBackupEnabled) {
    await AutoBackupService.checkBackupStatus();
  }

  runApp(const JituApp());
}

class JituApp extends StatelessWidget {
  const JituApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记途',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

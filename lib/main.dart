import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/main_navigation_shell.dart';
import 'core/storage/app_storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app storage directories
  await AppStorageService.instance.init();

  runApp(
    const ProviderScope(
      child: ScaneliqApp(),
    ),
  );
}

class ScaneliqApp extends StatelessWidget {
  const ScaneliqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scaneliq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavigationShell(),
    );
  }
}

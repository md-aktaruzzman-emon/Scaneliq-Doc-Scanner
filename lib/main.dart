import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_compliance_config.dart';
import 'core/navigation/app_router.dart';
import 'core/services/scan_preferences_service.dart';
import 'core/storage/app_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/documents/data/app_database_service.dart';
import 'features/security/data/app_lock_service.dart';
import 'features/security/data/privacy_shield_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local vault storage and App Lock state BEFORE rendering the shell
  // so locked sessions never bypass PIN/biometric barriers on cold start.
  await AppStorageService.instance.init();
  await ScanPreferencesService.instance.init();
  await AppLockService.instance.init();
  await PrivacyShieldService.instance.init();

  AppComplianceConfig.logStartupDiagnostics();

  // Schedule non-blocking maintenance (temp files & expired trash > 30 days)
  unawaited(_runStartupHousekeeping());

  runApp(const ProviderScope(child: ScaneliqApp()));
}

Future<void> _runStartupHousekeeping() async {
  try {
    await AppStorageService.instance.cleanStaleTempFiles();
    await AppDatabaseService.instance.purgeExpiredTrash();
  } catch (e) {
    debugPrint('[Scaneliq Housekeeping] Deferred maintenance error: $e');
  }
}

class ScaneliqApp extends ConsumerWidget {
  final GoRouter? routerOverride;

  const ScaneliqApp({super.key, this.routerOverride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = routerOverride ?? ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Scaneliq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_router.dart';
import 'core/storage/app_storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local vault storage directories before rendering
  await AppStorageService.instance.init();

  runApp(const ProviderScope(child: ScaneliqApp()));
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

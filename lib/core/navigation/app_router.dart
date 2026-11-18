import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/features/documents/presentation/documents_library_screen.dart';
import 'package:scaneliq/features/documents/presentation/home_screen.dart';
import 'package:scaneliq/features/documents/presentation/trash_screen.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/settings/presentation/settings_screen.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';

import 'app_routes.dart';
import 'main_navigation_shell.dart';

/// Creates the Scaneliq `GoRouter` configuration anchored on Concept A's
/// 3-tab StatefulShell (`Scans`, `Folders`, `PDF Suite`).
GoRouter createScaneliqRouter({
  String initialLocation = AppRoutes.scans,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.scans,
                name: AppRoutes.scansName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.folders,
                name: AppRoutes.foldersName,
                builder: (context, state) => const DocumentsLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pdfSuite,
                name: AppRoutes.pdfSuiteName,
                builder: (context, state) => const ToolsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviewPages,
        name: AppRoutes.reviewPagesName,
        builder: (context, state) => const ReviewPagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.trash,
        name: AppRoutes.trashName,
        builder: (context, state) => const TrashScreen(),
      ),
    ],
    errorBuilder: (context, state) => _RouterErrorScreen(
      location: state.uri.toString(),
      onReturnHome: () => context.go(AppRoutes.scans),
    ),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createScaneliqRouter();
  ref.onDispose(router.dispose);
  return router;
});

class _RouterErrorScreen extends StatelessWidget {
  final String location;
  final VoidCallback onReturnHome;

  const _RouterErrorScreen({
    required this.location,
    required this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Not Found')),
      body: Padding(
        padding: const EdgeInsets.all(ScaneliqSpacing.xl),
        child: ScaneliqEmptyState(
          icon: Icons.alt_route_rounded,
          title: 'Destination unavailable',
          description: 'Could not open "$location".',
          primaryActionLabel: 'Return to Scans',
          onPrimaryAction: onReturnHome,
        ),
      ),
    );
  }
}

/// Safe helper supporting both GoRouter-hosted trees and isolated Navigator tests.
void navigateToSettings(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(AppRoutes.settings);
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
}

/// Safe helper supporting both GoRouter-hosted trees and isolated Navigator tests.
void navigateToReviewPages(BuildContext context, {bool replace = false}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (replace) {
      router.pushReplacement(AppRoutes.reviewPages);
    } else {
      router.push(AppRoutes.reviewPages);
    }
    return;
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => const ReviewPagesScreen(),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

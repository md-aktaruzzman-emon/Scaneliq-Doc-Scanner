import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scaneliq/app/main_navigation_shell.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/settings/presentation/settings_screen.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Navigation & Screen UI Tests', () {
    testWidgets(
      'MainNavigationShell renders Concept A 3 tabs and switches cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              documentsListProvider.overrideWith(
                (ref) async => const <ScannedDocument>[],
              ),
              foldersListProvider(null)
                  .overrideWith((ref) async => const <DocumentFolder>[]),
              latestDraftProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Concept A 3-tab bottom navigation destinations
        expect(find.text('Scans'), findsOneWidget);
        expect(find.text('Folders'), findsAtLeastNWidgets(1));
        expect(find.text('PDF Suite'), findsOneWidget);

        // Tap Folders bottom tab
        await tester.tap(find.text('Folders').last);
        await tester.pumpAndSettle();
        expect(find.text('Search documents...'), findsOneWidget);

        // Tap PDF Suite bottom tab
        await tester.tap(find.text('PDF Suite'));
        await tester.pumpAndSettle();
        expect(find.text('PDF Suite'), findsAtLeastNWidgets(2));
        expect(find.text('Instant Image OCR'), findsOneWidget);

        // Return to Scans tab
        await tester.tap(find.text('Scans'));
        await tester.pumpAndSettle();
        expect(find.text('Scaneliq'), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen displays brand name, version and local-first privacy',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

        expect(find.text('Scaneliq'), findsOneWidget);
        expect(
          find.text('Scan documents. Keep everything organized.'),
          findsOneWidget,
        );
        expect(find.text('Local-First Document Safety'), findsOneWidget);
        expect(find.text('English & Latin Scripts (Active)'), findsOneWidget);
      },
    );

    testWidgets(
      'ToolsScreen renders Instant Image OCR and PDF Productivity Tools',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: ToolsScreen()));

        expect(find.text('Productivity & OCR Tools'), findsOneWidget);
        expect(find.text('Instant Image OCR'), findsOneWidget);
        expect(find.text('Share & Export'), findsOneWidget);
        expect(find.text('PDF Productivity Tools'), findsOneWidget);
        expect(find.text('Upcoming Platform Integrations'), findsOneWidget);
      },
    );
  });
}

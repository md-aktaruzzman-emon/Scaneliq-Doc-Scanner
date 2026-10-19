import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/app/main_navigation_shell.dart';
import 'package:scaneliq/features/settings/presentation/settings_screen.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';

void main() {
  group('Navigation & Screen UI Tests', () {
    testWidgets('MainNavigationShell renders 4 tabs and allows switching', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MainNavigationShell())),
      );

      // Verify bottom navigation items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Tap Documents tab
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(find.text('Search files...'), findsOneWidget);

      // Tap Tools tab
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      expect(find.text('Document Tools'), findsOneWidget);
      expect(find.text('Instant Image OCR'), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Branding & About'), findsOneWidget);
      expect(find.text('Scaneliq'), findsAtLeastNWidgets(1));
    });

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

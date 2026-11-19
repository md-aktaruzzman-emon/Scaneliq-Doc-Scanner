import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scaneliq/app/main_navigation_shell.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/navigation/app_router.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/documents_library_screen.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_tools_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:scaneliq/features/security/presentation/app_lock_screen.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';
import 'package:scaneliq/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Future<void> pumpDb(WidgetTester tester, {Finder? waitFor}) async {
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (waitFor != null && waitFor.evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stage 1 — Folders & Document Library', () {
    late Database db;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scaneliq_p2_folders_');
      db = await databaseFactoryFfi.openDatabase(
        '${tempDir.path}/test_vault.db',
        options: OpenDatabaseOptions(
          version: 5,
          onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (d, _) async {
            await d.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL, page_count INTEGER NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0, is_draft INTEGER NOT NULL DEFAULT 0, export_path TEXT, folder_id TEXT, deleted_at INTEGER)',
            );
            await d.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_order INTEGER NOT NULL, original_path TEXT NOT NULL, processed_path TEXT, edit_recipe_json TEXT NOT NULL, width INTEGER, height INTEGER)',
            );
            await d.execute(
              'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, color INTEGER NOT NULL DEFAULT 4280391411, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, PRIMARY KEY (document_id, tag_id))',
            );
          },
        ),
      );
      AppDatabaseService.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await AppDatabaseService.instance.close();
      AppDatabaseService.instance.setDatabaseForTesting(null);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Renders folder list, creates, opens, and renames folder', (
      tester,
    ) async {
      final folder = (await tester.runAsync(
        () => AppDatabaseService.instance.createFolder('Tax FY26'),
      ))!;
      final now = DateTime.now();
      await tester.runAsync(
        () => AppDatabaseService.instance.saveDocument(
          ScannedDocument(
            id: 'doc-1',
            title: 'Tax Return Form',
            createdAt: now,
            modifiedAt: now,
            pageCount: 3,
            folderId: folder.id,
            exportPath: '/tmp/tax.pdf',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DocumentsLibraryScreen(),
          ),
        ),
      );
      await pumpDb(tester, waitFor: find.text('Tax FY26'));

      // Folder rendered with count
      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('Tax FY26'), findsOneWidget);
      expect(find.text('1 FILES'), findsOneWidget);

      // Open folder -> shows breadcrumb & document inside
      await tester.tap(find.text('Tax FY26'));
      await pumpDb(tester, waitFor: find.text('Folder Options'));
      expect(find.text('Tax Return Form'), findsWidgets);

      // Rename folder via Folder Options bottom sheet
      await tester.tap(find.text('Folder Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Tax Archive 2026');
      await tester.tap(find.text('Save Name'));
      await tester.pumpAndSettle();
      await pumpDb(tester, waitFor: find.text('TAX ARCHIVE 2026'));
      expect(find.text('Tax Archive 2026'), findsWidgets);

      // Navigate back to Vault Root so new folder sits alongside existing root folders
      await tester.tap(find.text('VAULT ROOT'));
      await pumpDb(tester, waitFor: find.text(' / ALL FOLDERS'));

      // Create folder via New Folder sheet
      await tester.tap(find.byTooltip('New Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Q4 Receipts');
      await tester.pump();
      await tester.ensureVisible(find.text('Create Folder'));
      await tester.tap(find.text('Create Folder'));
      await tester.pumpAndSettle();
      await pumpDb(tester, waitFor: find.text('Q4 Receipts'));
      expect(find.text('Q4 Receipts'), findsOneWidget);
    });

    testWidgets(
      'Empty folder state and batch selection dock work in Dark theme',
      (tester) async {
        final emptyFolder = (await tester.runAsync(
          () => AppDatabaseService.instance.createFolder('Empty Vault'),
        ))!;
        final now = DateTime.now();
        await tester.runAsync(
          () => AppDatabaseService.instance.saveDocument(
            ScannedDocument(
              id: 'root-doc',
              title: 'Root Contract',
              createdAt: now,
              modifiedAt: now,
              pageCount: 2,
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const DocumentsLibraryScreen(),
            ),
          ),
        );
        await pumpDb(tester, waitFor: find.text('Root Contract'));

        // Enter batch selection mode at root
        await tester.tap(find.text('Batch Select'));
        await tester.pumpAndSettle();
        expect(find.text('0 Selected'), findsOneWidget);
        await tester.tap(find.text('Root Contract').last);
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);
        await tester.tap(find.byTooltip('Cancel selection'));
        await tester.pumpAndSettle();

        // Open empty folder -> displays Concept A Empty state
        await tester.tap(find.text(emptyFolder.name));
        await pumpDb(tester, waitFor: find.text('Folder is empty'));
        expect(find.text('Folder is empty'), findsOneWidget);
      },
    );
  });

  group('Stage 2 — PDF Suite Consolidation', () {
    testWidgets(
      'Renders all tool categories, distinguishes planned tools, and navigates',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const ToolsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('PDF Suite'), findsOneWidget);
        expect(find.text('Organize'), findsOneWidget);
        expect(find.text('Edit & Protect'), findsOneWidget);
        expect(find.text('Optimize & Convert'), findsOneWidget);
        expect(find.text('Productivity & OCR Tools'), findsOneWidget);
        expect(find.text('Upcoming Platform Integrations'), findsOneWidget);

        // Planned / unavailable tools clearly distinguished
        expect(find.text('PDF to Word / Excel Conversion'), findsOneWidget);
        expect(find.text('UNAVAILABLE'), findsOneWidget);

        // Navigate into implemented PDF Workbench
        await tester.ensureVisible(find.text('PDF Productivity Tools'));
        await tester.tap(find.text('PDF Productivity Tools'));
        await tester.pumpAndSettle();
        expect(find.byType(PdfToolsScreen), findsOneWidget);
        expect(find.text('PDF Workbench'), findsOneWidget);
      },
    );

    testWidgets('PDF Suite supports Dark Theme (Carbon Studio)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const ToolsScreen()),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, const Color(0xFF0D0E11));
      expect(find.text('Compress PDF'), findsOneWidget);
    });
  });

  group('Stage 3 — Settings Theme Switching & Persistence', () {
    testWidgets(
      'Switches Light, Dark, and System Default and persists selection',
      (tester) async {
        final router = createScaneliqRouter(initialLocation: '/settings');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(child: ScaneliqApp(routerOverride: router)),
        );
        await tester.pumpAndSettle();

        // Switch to Dark
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        var scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
        expect(scaffold.backgroundColor, const Color(0xFF0D0E11));

        // Switch to Light
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
        expect(scaffold.backgroundColor, const Color(0xFFFAF9F6));

        // Switch to System Default
        await tester.tap(find.text('System Default'));
        await tester.pumpAndSettle();
        expect(
          find.text('System Default (Follows device appearance)'),
          findsOneWidget,
        );

        // Verify persisted Dark selection reloads on app restart
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('scaneliq_theme_mode'), 'dark');

        final restartRouter = createScaneliqRouter(
          initialLocation: '/settings',
        );
        addTearDown(restartRouter.dispose);
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('restarted-app'),
            child: ScaneliqApp(routerOverride: restartRouter),
          ),
        );
        await tester.pumpAndSettle();
        final restartedScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).last,
        );
        expect(restartedScaffold.backgroundColor, const Color(0xFF0D0E11));
      },
    );
  });

  group('Stage 4 — Full-Screen Security PIN Experience', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppLockService.instance.init();
      await AppLockService.instance.disableAppLock();
    });

    testWidgets(
      'Full-screen barrier rejects wrong PIN, blocks back nav, and unlocks on valid PIN',
      (tester) async {
        await AppLockService.instance.setPin('4321');
        AppLockService.instance.markSessionLocked();

        var unlockedResult = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    unlockedResult = await AppLockScreen.showUnlockBarrier(ctx);
                  },
                  child: const Text('Lock Vault'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Lock Vault'));
        await tester.pumpAndSettle();

        // Verify full-screen lock UI and back-navigation guard
        expect(find.byType(AppLockScreen), findsOneWidget);
        expect(find.text('Vault Locked'), findsOneWidget);
        final popScope = tester.widget<PopScope>(find.byType(PopScope));
        expect(popScope.canPop, isFalse);

        // Attempt system back route pop -> barrier remains open
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Vault Locked'), findsOneWidget);

        // Enter incorrect PIN -> displays remaining attempts error
        for (final d in ['1', '1', '1', '1']) {
          await tester.tap(find.text(d));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Incorrect PIN (4 attempts remaining)'),
          findsOneWidget,
        );
        expect(find.text('Vault Locked'), findsOneWidget);

        // Enter correct PIN '4321' -> unlocks cleanly
        for (final d in ['4', '3', '2', '1']) {
          await tester.tap(find.text(d));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Vault Locked'), findsNothing);
        expect(unlockedResult, isTrue);
      },
    );

    testWidgets(
      'AppLockScreen displays biometric button when biometrics enabled & lifecycle triggers lock on resume',
      (tester) async {
        await AppLockService.instance.setPin('1234');
        await AppLockService.instance.setBiometricsEnabled(true);
        await AppLockService.instance.setTimeoutSeconds(0);
        AppLockService.instance.markSessionUnlocked();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              documentsListProvider.overrideWith((ref) async => const []),
              searchedDocumentsProvider.overrideWith(
                (ref, q) async => const [],
              ),
              foldersListProvider(null).overrideWith((ref) async => const []),
              tagsListProvider.overrideWith((ref) async => const []),
              latestDraftProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Simulate valid Android/Flutter app background -> foreground lifecycle
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // Full-screen lock barrier appears with biometric button
        expect(find.text('Vault Locked'), findsOneWidget);
        expect(find.byTooltip('Unlock with Biometrics'), findsOneWidget);
      },
    );
  });
}

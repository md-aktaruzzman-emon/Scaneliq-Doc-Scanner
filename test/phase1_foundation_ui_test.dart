import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/navigation/app_router.dart';
import 'package:scaneliq/core/navigation/app_routes.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_bottom_nav.dart';
import 'package:scaneliq/core/widgets/scaneliq_buttons.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_document_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_mark.dart';
import 'package:scaneliq/features/documents/presentation/home_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 18, 14, 20);

  final sampleDocs = [
    ScannedDocument(
      id: 'doc-lease',
      title: 'Commercial Lease Agreement',
      createdAt: now,
      modifiedAt: now,
      pageCount: 12,
      isFavorite: true,
      exportPath: '/tmp/lease.pdf',
    ),
    ScannedDocument(
      id: 'doc-bangla',
      title: 'বাংলা জমির দলিল — খতিয়ান ৪১২',
      createdAt: now.subtract(const Duration(days: 1)),
      modifiedAt: now.subtract(const Duration(days: 1)),
      pageCount: 6,
      isFavorite: false,
    ),
    ScannedDocument(
      id: 'doc-invoice',
      title: 'Square Pharmaceuticals Invoice #884',
      createdAt: now.subtract(const Duration(days: 3)),
      modifiedAt: now.subtract(const Duration(days: 3)),
      pageCount: 2,
      isFavorite: true,
      exportPath: '/tmp/invoice.pdf',
    ),
  ];

  final sampleDraft = ScannedDocument(
    id: 'draft-tax',
    title: 'Tax Return FY2026 — Draft',
    createdAt: now.subtract(const Duration(minutes: 25)),
    modifiedAt: now.subtract(const Duration(minutes: 14)),
    pageCount: 4,
    isDraft: true,
    pages: const [
      DocumentPage(
        id: 'p1',
        documentId: 'draft-tax',
        pageOrder: 0,
        originalPath: '/nonexistent/p1.jpg',
      ),
      DocumentPage(
        id: 'p2',
        documentId: 'draft-tax',
        pageOrder: 1,
        originalPath: '/nonexistent/p2.jpg',
      ),
    ],
  );

  final sampleFolders = [
    DocumentFolder(
      id: 'f-tax',
      name: 'Tax & Finance FY26',
      createdAt: now,
      modifiedAt: now,
      documentCount: 4,
    ),
    DocumentFolder(
      id: 'f-legal',
      name: 'Legal & Property Deeds',
      createdAt: now,
      modifiedAt: now,
      documentCount: 8,
    ),
  ];

  List<dynamic> buildOverrides({List<ScannedDocument>? docs}) {
    final activeDocs = docs ?? sampleDocs;
    return [
      documentsListProvider.overrideWith((ref) async => activeDocs),
      searchedDocumentsProvider.overrideWith((ref, query) async {
        final q = query.trim().toLowerCase();
        return activeDocs
            .where((d) => d.title.toLowerCase().contains(q))
            .toList();
      }),
      foldersListProvider(null).overrideWith((ref) async => sampleFolders),
      latestDraftProvider.overrideWith((ref) async => sampleDraft),
    ];
  }

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 1 — Design Tokens & Theme Architecture', () {
    test(
      'Concept A Light (Gallery Alabaster) & Dark (Carbon Studio) palettes',
      () {
        expect(ScaneliqColorPalette.light.bg, const Color(0xFFFAF9F6));
        expect(ScaneliqColorPalette.light.surface, const Color(0xFFFFFFFF));
        expect(
          ScaneliqColorPalette.light.surfaceSubtle,
          const Color(0xFFF2F0EB),
        );
        expect(ScaneliqColorPalette.light.hairline, const Color(0xFFE6E4DD));
        expect(ScaneliqColorPalette.light.accent, const Color(0xFF0052FF));
        expect(ScaneliqColorPalette.light.textPrimary, const Color(0xFF141413));

        expect(ScaneliqColorPalette.dark.bg, const Color(0xFF0D0E11));
        expect(ScaneliqColorPalette.dark.surface, const Color(0xFF15171C));
        expect(
          ScaneliqColorPalette.dark.surfaceSubtle,
          const Color(0xFF1C1F26),
        );
        expect(ScaneliqColorPalette.dark.hairline, const Color(0xFF23262F));
        expect(ScaneliqColorPalette.dark.accent, const Color(0xFF3B82F6));
        expect(ScaneliqColorPalette.dark.textPrimary, const Color(0xFFF4F4F6));

        expect(ScaneliqSpacing.unit, 4.0);
        expect(ScaneliqSpacing.adaptiveHorizontalPadding(320), 16.0);
        expect(ScaneliqSpacing.adaptiveHorizontalPadding(393), 24.0);
        expect(ScaneliqRadius.sheet, 3.0);
        expect(ScaneliqRadius.folio, 14.0);
        expect(ScaneliqRadius.pill, 999.0);
        expect(
          ScaneliqTypography.monoStyle(color: Colors.black).fontSize,
          10.5,
        );
      },
    );

    testWidgets(
      'ThemeExtension exposes exact Light and Dark tokens via context',
      (tester) async {
        late ScaneliqTokens capturedLight;
        late ScaneliqTokens capturedDark;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) {
                capturedLight = ctx.tokens;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(capturedLight.bg, const Color(0xFFFAF9F6));
        expect(capturedLight.accent, const Color(0xFF0052FF));

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('dark-theme-check'),
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (ctx) {
                capturedDark = ctx.tokens;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(capturedDark.bg, const Color(0xFF0D0E11));
        expect(capturedDark.accent, const Color(0xFF3B82F6));
      },
    );

    testWidgets(
      'Live theme switching toggles Gallery Alabaster and Carbon Studio',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [...buildOverrides()],
            child: const ScaneliqApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Initially light under default ThemeMode.system in test harness
        final initialScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).last,
        );
        expect(initialScaffold.backgroundColor, const Color(0xFFFAF9F6));

        // Tap header theme toggle button -> Dark (Carbon Studio)
        await tester.tap(find.byTooltip('Switch theme'));
        await tester.pumpAndSettle();

        final darkScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).last,
        );
        expect(darkScaffold.backgroundColor, const Color(0xFF0D0E11));

        // Tap header theme toggle button again -> Light (Gallery Alabaster)
        await tester.tap(find.byTooltip('Switch theme'));
        await tester.pumpAndSettle();

        final backToLightScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).last,
        );
        expect(backToLightScaffold.backgroundColor, const Color(0xFFFAF9F6));
      },
    );
  });

  group('Phase 1 — Navigation Architecture (go_router & 3-Tab Shell)', () {
    testWidgets(
      'go_router switches branches and preserves selected tab state',
      (tester) async {
        final router = createScaneliqRouter();
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [...buildOverrides()],
            child: ScaneliqApp(routerOverride: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, AppRoutes.scans);

        // Navigate via bottom nav bar to Folders
        await tester.tap(find.text('Folders').last);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.folders,
        );
        expect(find.text('Search documents...'), findsOneWidget);

        // Navigate via bottom nav bar to PDF Suite
        await tester.tap(find.text('PDF Suite'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.pdfSuite,
        );
        expect(find.text('Merge PDF'), findsOneWidget);

        // Navigate back to Scans
        await tester.tap(find.text('Scans'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, AppRoutes.scans);
        expect(find.text('Commercial Lease Agreement'), findsOneWidget);
      },
    );

    testWidgets('Unknown route renders Scaneliq error screen with return CTA', (
      tester,
    ) async {
      final router = createScaneliqRouter(initialLocation: '/does-not-exist');
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...buildOverrides()],
          child: ScaneliqApp(routerOverride: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destination unavailable'), findsOneWidget);
      await tester.tap(find.text('Return to Scans'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.scans);
    });
  });

  group('Phase 1 — Approved Concept A Home Dashboard & Search', () {
    testWidgets('Renders Continue working folio, counts, and document stream', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...buildOverrides()],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Draft folio
      expect(find.text('Continue working'), findsOneWidget);
      expect(find.text('Tax Return FY2026 — Draft'), findsOneWidget);
      expect(find.text('UNFINISHED · 2 PAGES'), findsOneWidget);

      // Counts on scope strip (3 recent, 2 starred, 2 folders)
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));

      // Stream documents & metadata tags
      expect(find.text('Commercial Lease Agreement'), findsWidgets);
      expect(find.text('বাংলা জমির দলিল — খতিয়ান ৪১২'), findsWidgets);
      expect(find.text('Square Pharmaceuticals Invoice #884'), findsWidgets);
      expect(find.text('PDF · 12P'), findsOneWidget);
      expect(find.text('SCAN · 6P'), findsOneWidget);
    });

    testWidgets(
      'Search field filters document stream and clear button resets',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [...buildOverrides()],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Lease');
        await tester.pumpAndSettle();

        expect(find.text('Search Results'), findsOneWidget);
        expect(find.text('Commercial Lease Agreement'), findsWidgets);
        expect(find.text('Square Pharmaceuticals Invoice #884'), findsNothing);

        // Clear search restores full document list
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Commercial Lease Agreement'), findsWidgets);
        expect(find.text('Square Pharmaceuticals Invoice #884'), findsWidgets);
      },
    );

    testWidgets('Starred scope filters only favorite documents', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...buildOverrides()],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Starred'));
      await tester.pumpAndSettle();

      expect(find.text('Starred Documents'), findsOneWidget);
      expect(find.text('Commercial Lease Agreement'), findsWidgets);
      expect(find.text('Square Pharmaceuticals Invoice #884'), findsWidgets);
      expect(find.text('বাংলা জমির দলিল — খতিয়ান ৪১২'), findsNothing);
    });
  });

  group('Phase 1 — Reusable Component Library & Responsive Layout', () {
    testWidgets('Core reusable Concept A components render cleanly', (
      tester,
    ) async {
      var selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setLocal) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScaneliqMark(),
                    const SizedBox(height: 12),
                    ScaneliqScopeTabs(
                      items: const [
                        ScaneliqScopeItem(label: 'All', count: 10),
                        ScaneliqScopeItem(label: 'OCR', count: 6),
                      ],
                      selectedIndex: selectedIdx,
                      onSelected: (i) => setLocal(() => selectedIdx = i),
                    ),
                    const SizedBox(height: 12),
                    ScaneliqPrimaryButton(label: 'Save PDF', onPressed: () {}),
                    const SizedBox(height: 8),
                    ScaneliqSecondaryButton(label: 'Cancel', onPressed: () {}),
                    const SizedBox(height: 8),
                    ScaneliqDestructiveButton(
                      label: 'Delete',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 8),
                    const ScaneliqStatusLabel(
                      text: 'OCR · BN',
                      tone: ScaneliqStatusTone.accent,
                    ),
                    const SizedBox(height: 8),
                    ScaneliqDocumentRow(
                      document: sampleDocs.first,
                      onTap: () {},
                      onMoreTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: ScaneliqBottomNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ScaneliqMark), findsOneWidget);
      expect(find.text('Save PDF'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('OCR · BN'), findsOneWidget);
      expect(find.text('Commercial Lease Agreement'), findsWidgets);
    });

    testWidgets(
      'Home Dashboard adapts to compact phone, 393x852, tablet & a11y scaling without overflow',
      (tester) async {
        final sizes = <Size>[
          const Size(320, 640), // Small phone
          const Size(393, 852), // Primary Concept A reference viewport
          const Size(768, 1024), // Tablet viewport
        ];

        for (final size in sizes) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [...buildOverrides()],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: size.width == 320
                      ? const TextScaler.linear(1.35)
                      : TextScaler.noScaling,
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: const Scaffold(body: HomeScreen()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Scaneliq'), findsOneWidget);
          expect(find.text('Commercial Lease Agreement'), findsWidgets);
          expect(tester.takeException(), isNull);
        }

        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}

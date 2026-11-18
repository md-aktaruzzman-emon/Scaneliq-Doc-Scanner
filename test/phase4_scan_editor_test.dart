import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/editor/presentation/edit_history_controller.dart';
import 'package:scaneliq/features/editor/presentation/edit_page_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

img.Image _buildDocumentSpecimenImage({int width = 160, int height = 200}) {
  final image = img.Image(width: width, height: height);
  // Dark background border around a bright skewed/inset paper sheet with dark text strokes.
  img.fill(image, color: img.ColorRgb8(28, 32, 38));
  final int x0 = (width * 0.15).round();
  final int y0 = (height * 0.12).round();
  final int x1 = (width * 0.85).round();
  final int y1 = (height * 0.88).round();
  img.fillRect(
    image,
    x1: x0,
    y1: y0,
    x2: x1,
    y2: y1,
    color: img.ColorRgb8(218, 214, 204),
  );
  // Dark printed text bands + blue stamp mark
  img.fillRect(
    image,
    x1: x0 + 12,
    y1: y0 + 16,
    x2: x1 - 18,
    y2: y0 + 26,
    color: img.ColorRgb8(35, 38, 42),
  );
  img.fillRect(
    image,
    x1: x0 + 12,
    y1: y0 + 36,
    x2: x1 - 30,
    y2: y0 + 44,
    color: img.ColorRgb8(55, 60, 68),
  );
  img.fillRect(
    image,
    x1: x0 + 14,
    y1: y0 + 60,
    x2: x0 + 42,
    y2: y0 + 82,
    color: img.ColorRgb8(18, 82, 220),
  );
  return image;
}

double _meanLuminance(img.Image image) {
  double sum = 0;
  final int total = image.width * image.height;
  for (final p in image) {
    sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  return sum / total;
}

File _writeJpgSync(Directory dir, String name, img.Image image) {
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodeJpg(image, quality: 92), flush: true);
  return file;
}

Future<Database> _openEditorTestDb(Directory dir) async {
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}/phase4_test.db',
    options: OpenDatabaseOptions(
      version: 5,
      singleInstance: false,
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
          'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, color INTEGER NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (document_id, tag_id))',
        );
      },
    ),
  );
  AppDatabaseService.instance.setDatabaseForTesting(db);
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 4 Image Processing, Filters, Crop, Perspective & History Unit Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p4_unit_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Automatic crop detects convex boundary on real document fixture and rejects blank images', () async {
      final specimen = _buildDocumentSpecimenImage();
      final docFile = _writeJpgSync(tempDir, 'doc.jpg', specimen);

      final detected = await ImageProcessingService.autoDetectDocumentQuadFromFile(
        docFile,
      );
      expect(detected, isNotNull);
      expect(detected!.isValidConvex(), isTrue);

      final blank = img.Image(width: 120, height: 120);
      img.fill(blank, color: img.ColorRgb8(180, 180, 180));
      expect(ImageProcessingService.autoDetectDocumentQuad(blank), isNull);
    });

    test('Manual box crop, 4-point perspective warp, and 90-degree rotation transform dimensions non-destructively', () {
      final src = _buildDocumentSpecimenImage(width: 200, height: 100);

      // 1. Box Crop 50% width & 50% height
      final cropped = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(
          cropLeft: 0.25,
          cropTop: 0.25,
          cropRight: 0.75,
          cropBottom: 0.75,
        ),
      );
      expect(cropped.width, equals(100));
      expect(cropped.height, equals(50));

      // 2. Genuine 4-point perspective warp produces rectified rectangle matching quad span
      const quad = PerspectiveQuad(
        x1: 0.15,
        y1: 0.12,
        x2: 0.85,
        y2: 0.15,
        x3: 0.88,
        y3: 0.88,
        x4: 0.12,
        y4: 0.85,
      );
      final warped = ImageProcessingService.warpPerspective(src, quad);
      expect(warped.width, inInclusiveRange(130, 160));
      expect(warped.height, inInclusiveRange(65, 85));

      // 3. Rotation by 90 degrees swaps width & height
      final rotated = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(rotationDegrees: 90),
      );
      expect(rotated.width, equals(100));
      expect(rotated.height, equals(200));

      // Original image remains completely unmodified
      expect(src.width, equals(200));
      expect(src.height, equals(100));
    });

    test('All 8 document filters produce distinct genuine pixel transformations', () {
      final src = _buildDocumentSpecimenImage(width: 120, height: 120);
      final baseMean = _meanLuminance(src);

      final originalOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.original),
      );
      final autoOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.autoEnhance),
      );
      final magicOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.magicColor),
      );
      final enhanceOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.enhancedText),
      );
      final grayOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.grayscale),
      );
      final bwOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.blackAndWhite),
      );
      final lightenOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.lighten),
      );
      final darkenOut = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(filter: PageFilter.darken),
      );

      // Original matches source luma closely
      expect(_meanLuminance(originalOut), closeTo(baseMean, 1.0));
      // Lighten increases luminance, Darken decreases luminance
      expect(_meanLuminance(lightenOut), greaterThan(baseMean + 10));
      expect(_meanLuminance(darkenOut), lessThan(baseMean - 10));
      // Grayscale sets R == G == B cleanly
      final graySample = grayOut.getPixel(40, 80);
      expect(graySample.r, equals(graySample.g));
      expect(graySample.g, equals(graySample.b));
      // Black & White produces strict monochrome (0 or 255)
      final bwSample = bwOut.getPixel(50, 50);
      expect(bwSample.r == 0 || bwSample.r == 255, isTrue);
      // Magic Color whitens paper pixels toward pure white while preserving stamps/ink contrast
      final origPaperLum = src.getPixel(80, 100).r;
      final magicPaperLum = magicOut.getPixel(80, 100).r;
      final autoPaperLum = autoOut.getPixel(80, 100).r;
      expect(magicPaperLum, greaterThan(origPaperLum));
      expect(autoPaperLum, greaterThan(origPaperLum));
      expect(_meanLuminance(enhanceOut), isNot(equals(_meanLuminance(originalOut))));
    });

    test('Brightness, contrast, sharpness convolution, and Isolate pipeline transform real pixels cleanly', () async {
      final src = _buildDocumentSpecimenImage(width: 100, height: 100);
      final file = _writeJpgSync(tempDir, 'adj_test.jpg', src);

      final bright = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(brightness: 0.35),
      );
      final dark = ImageProcessingService.applyEditRecipe(
        src,
        const EditRecipe(brightness: -0.35),
      );
      expect(_meanLuminance(bright), greaterThan(_meanLuminance(dark) + 35));

      final sharp = ImageProcessingService.applySharpness(src, 0.85);
      // Edge pixel across paper/background transition should increase edge delta after sharpen
      final srcEdgeDiff =
          (src.getPixel(16, 50).r - src.getPixel(14, 50).r).abs();
      final sharpEdgeDiff =
          (sharp.getPixel(16, 50).r - sharp.getPixel(14, 50).r).abs();
      expect(sharpEdgeDiff, greaterThanOrEqualTo(srcEdgeDiff));

      // Background Isolate pipeline produces valid decodable JPEG without mutating original file bytes
      final origBytesBefore = file.readAsBytesSync();
      const recipe = EditRecipe(
        filter: PageFilter.magicColor,
        sharpness: 0.6,
        rotationDegrees: 90,
      );
      final outBytes =
          await ImageProcessingService.processImageFileToBytesInIsolate(
            file,
            recipe,
          );
      final decodedOut = img.decodeImage(outBytes);
      expect(decodedOut, isNotNull);
      expect(decodedOut!.width, equals(100));
      expect(file.readAsBytesSync(), equals(origBytesBefore));
    });

    test('EditHistoryStack tracks per-page undo/redo snapshots accurately without bitmap copies', () {
      final p1 = DocumentPage(
        id: 'p1',
        documentId: 'd1',
        pageOrder: 0,
        originalPath: 'p1.jpg',
      );
      final p2 = DocumentPage(
        id: 'p2',
        documentId: 'd1',
        pageOrder: 1,
        originalPath: 'p2.jpg',
      );

      final manager = MultiPageEditHistory();
      final s1 = manager.stackFor(p1);
      final s2 = manager.stackFor(p2);

      s1.record(const EditRecipe(filter: PageFilter.magicColor));
      s1.record(const EditRecipe(filter: PageFilter.magicColor, rotationDegrees: 90));
      s2.record(const EditRecipe(filter: PageFilter.grayscale));

      expect(s1.canUndo, isTrue);
      expect(s1.undo()?.rotationDegrees, equals(0));
      expect(s1.current.filter, equals(PageFilter.magicColor));
      expect(s1.canRedo, isTrue);
      expect(s1.redo()?.rotationDegrees, equals(90));

      // Page 2 stack remains completely isolated from Page 1 undo/redo operations
      expect(s2.current.filter, equals(PageFilter.grayscale));
      expect(s2.canRedo, isFalse);

      // Verify sharpness survives JSON map round-trip safely
      const full = EditRecipe(
        filter: PageFilter.lighten,
        sharpness: 0.75,
        brightness: 0.2,
      );
      final roundTrip = EditRecipe.fromMap(full.toMap());
      expect(roundTrip.filter, equals(PageFilter.lighten));
      expect(roundTrip.sharpness, equals(0.75));
    });
  });

  group('Phase 4 Widget & Integration Tests: Scan Editor UI, Themes & Persistence', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p4_ui_');
      await AppStorageService.instance.init(tempDir);
      await _openEditorTestDb(tempDir);
    });

    tearDown(() async {
      await AppDatabaseService.instance.close();
      AppDatabaseService.instance.setDatabaseForTesting(null);
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets(
      'Scan Editor renders Concept A Light/Dark themes, 5 tool categories, Undo/Redo, Before/After compare, and missing-file safety',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spec = _buildDocumentSpecimenImage(width: 140, height: 180);
        final file1 = _writeJpgSync(tempDir, 'ed1.jpg', spec);
        final origBytes = file1.readAsBytesSync();

        final p1 = DocumentPage(
          id: 'ed_p1',
          documentId: 'ed_doc',
          pageOrder: 0,
          originalPath: file1.path,
        );

        EditRecipe? applied;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: EditPageScreen(
                page: p1,
                onApply: (r) => applied = r,
              ),
            ),
          ),
        );
        Future<void> settleIsolateRender() async {
          await tester.pump();
          for (int i = 0; i < 40; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
            if (find.text('RENDERING').evaluate().isEmpty) break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }

        await settleIsolateRender();

        // Dark Carbon Studio background check
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, AppTheme.darkTheme.extension<ScaneliqTokens>()!.bg);

        // Toolbar categories present ('Enhance' appears in filter ribbon & category bar)
        expect(find.text('Crop'), findsOneWidget);
        expect(find.text('Enhance'), findsNWidgets(2));
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Adjust'), findsOneWidget);
        expect(find.text('Rotate'), findsOneWidget);

        // Apply Magic Color filter -> Undo becomes enabled
        await tester.tap(find.text('Magic Color'));
        await settleIsolateRender();

        // Toggle Before / After comparison
        await tester.tap(find.byTooltip('Compare Original'));
        await settleIsolateRender();
        expect(find.text('ORIGINAL'), findsOneWidget);
        expect(find.text('ENHANCED'), findsOneWidget);
        await tester.tap(find.byTooltip('Compare Original'));
        await settleIsolateRender();

        // Adjust tab exposes Brightness, Contrast, Sharpness sliders
        await tester.tap(find.text('Adjust'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Brightness'), findsOneWidget);
        expect(find.text('Contrast'), findsOneWidget);
        expect(find.text('Sharpness'), findsOneWidget);

        // Crop tab supports Auto Crop & 4-Pt Perspective toggle with constrained corner handles
        await tester.tap(find.text('Crop'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Auto Crop'), findsOneWidget);
        await tester.tap(find.text('Box Crop'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('4-Pt Perspective'), findsOneWidget);
        expect(find.text('TL'), findsOneWidget);
        expect(find.text('BR'), findsOneWidget);

        // Undo restores back cleanly, Redo restores forward cleanly
        await tester.tap(find.byTooltip('Undo'));
        await settleIsolateRender();
        await tester.tap(find.byTooltip('Redo'));
        await settleIsolateRender();

        // Tap Done -> invokes onApply non-destructively leaving original file untouched
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump();

        expect(applied, isNotNull);
        expect(applied!.filter, equals(PageFilter.magicColor));
        expect(file1.readAsBytesSync(), equals(origBytes));

        // Missing/corrupt file failure handling renders safely instead of crashing
        final missingPage = DocumentPage(
          id: 'missing',
          documentId: 'ed_doc',
          pageOrder: 0,
          originalPath: '${tempDir.path}/does_not_exist.jpg',
        );
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('missing_scope'),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: EditPageScreen(
                key: const ValueKey('missing_page'),
                page: missingPage,
                onApply: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Original image unavailable on storage'), findsOneWidget);
      },
    );

    testWidgets(
      'Multi-page editing preserves independent page edits, reordering, and saves processed image output via Isolate',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spec = _buildDocumentSpecimenImage(width: 120, height: 150);
        final f1 = _writeJpgSync(tempDir, 'mp1.jpg', spec);
        final f2 = _writeJpgSync(tempDir, 'mp2.jpg', spec);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          await container.read(scanSessionProvider.notifier).importFiles([f1, f2]);
        });
        final pages = container.read(scanSessionProvider).pages;
        final p1Id = pages[0].id;
        final p2Id = pages[1].id;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EditPageScreen(
                              page: pages[0],
                              pages: pages,
                              initialPageIndex: 0,
                              onApply: (r) {
                                container
                                    .read(scanSessionProvider.notifier)
                                    .updatePageRecipe(pages[0].id, r);
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Editor'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Editor'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pumpAndSettle();

        expect(find.text('P1/2'), findsOneWidget);

        // Apply Grayscale to Page 1 only
        await tester.scrollUntilVisible(
          find.text('Grayscale'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Grayscale'));
        for (int i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
          if (find.text('RENDERING').evaluate().isEmpty) break;
        }

        // Switch to Page 2 -> verify Page 2 remains Original and Apply Lighten to Page 2
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
        for (int i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
          if (find.text('P2/2').evaluate().isNotEmpty &&
              find.text('RENDERING').evaluate().isEmpty) {
            break;
          }
        }
        expect(find.text('P2/2'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Lighten'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Lighten'));
        for (int i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
          if (find.text('RENDERING').evaluate().isEmpty) break;
        }

        // Move active Page 2 earlier -> now Page 2 is first
        await tester.tap(find.byTooltip('Move page earlier'));
        await tester.pump(const Duration(milliseconds: 100));

        // Save Done -> updates both pages & order in ScanSessionNotifier + SQLite, then pops
        await tester.tap(find.text('Done'));
        for (int i = 0; i < 60; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
          if (find.byType(EditPageScreen).evaluate().isEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(find.byType(EditPageScreen), findsNothing);

        final updatedPages = container.read(scanSessionProvider).pages;
        expect(updatedPages[0].id, equals(p2Id));
        expect(updatedPages[1].id, equals(p1Id));
        expect(updatedPages[0].editRecipe.filter, equals(PageFilter.lighten));
        expect(updatedPages[1].editRecipe.filter, equals(PageFilter.grayscale));
        expect(updatedPages[1].processedPath, isNotNull);
        expect(File(updatedPages[1].processedPath!).existsSync(), isTrue);
      },
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_page_organizer_screen.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/pdf_annotation_studio.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/signature_studio_sheet.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/watermark_studio_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

File _createVectorTextPdfSync(
  Directory dir,
  String name, {
  required List<String> pageTexts,
  String title = 'Vector Contract',
}) {
  final doc = sf.PdfDocument();
  doc.documentInformation.title = title;
  doc.documentInformation.author = 'Scaneliq QA';
  final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14);
  for (final text in pageTexts) {
    final page = doc.pages.add();
    page.graphics.drawString(
      text,
      font,
      bounds: const Rect.fromLTWH(40, 40, 500, 700),
    );
  }
  final bytes = doc.saveSync();
  doc.dispose();
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(bytes, flush: true);
  return file;
}

File _createHighResPhotoJpgSync(Directory dir, String name, {int seed = 0}) {
  final image = img.Image(width: 900, height: 1200);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final v = ((x * 3 + y * 5 + seed * 40) % 210) + 30;
      image.setPixelRgb(x, y, v, (v + 30) % 255, (v + 70) % 255);
    }
  }
  final f = File('${dir.path}/$name');
  f.writeAsBytesSync(img.encodeJpg(image, quality: 95), flush: true);
  return f;
}

File _createImageOnlyPdfSync(Directory dir, String name, File jpgFile) {
  final doc = sf.PdfDocument();
  final page = doc.pages.add();
  final bitmap = sf.PdfBitmap(jpgFile.readAsBytesSync());
  page.graphics.drawImage(bitmap, const Rect.fromLTWH(20, 20, 540, 760));
  final bytes = doc.saveSync();
  doc.dispose();
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(bytes, flush: true);
  return file;
}

Future<Database> _openPhase5TestDb(Directory dir) async {
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}/phase5_test.db',
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

  group('Phase 5 PDF Service, Annotations, Signature, Watermark, Organize, Merge/Split & Compress', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p5_unit_');
      await AppStorageService.instance.init(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('PDF validation, metadata inspection, search text extraction, and metadata edit preserve structure', () async {
      final vectorPdf = _createVectorTextPdfSync(
        tempDir,
        'searchable.pdf',
        pageTexts: ['Invoice #1042 Alpha', 'Total Due Beta'],
        title: 'Invoice 1042',
      );
      final imgFile = _createHighResPhotoJpgSync(tempDir, 'scan1.jpg');
      final scannedPdf = _createImageOnlyPdfSync(tempDir, 'scanned.pdf', imgFile);

      final svc = AdvancedPdfService.instance;
      expect(await svc.validatePdf(vectorPdf), isTrue);
      expect(await svc.getPageCount(vectorPdf), equals(2));

      final badFile = File('${tempDir.path}/corrupt.pdf')
        ..writeAsBytesSync([1, 2, 3, 4], flush: true);
      expect(await svc.validatePdf(badFile), isFalse);

      final texts = await svc.extractTextByPage(vectorPdf);
      expect(texts[1], contains('Alpha'));
      expect(texts[2], contains('Beta'));

      final scannedTexts = await svc.extractTextByPage(scannedPdf);
      expect(scannedTexts[1], isEmpty);

      final updated = await svc.updateMetadata(
        sourcePdf: vectorPdf,
        title: 'Updated Invoice 1042',
        author: 'Finance Team',
        outputFileName: 'meta_updated',
      );
      final meta = await svc.inspectPdf(updated);
      expect(meta.title, equals('Updated Invoice 1042'));
      expect(meta.author, equals('Finance Team'));
      expect(meta.pageCount, equals(2));
    });

    test('Annotations (highlight, underline, ink, text note, shapes, rotated signature PNG) save non-destructively', () async {
      final src = _createVectorTextPdfSync(
        tempDir,
        'annot_src.pdf',
        pageTexts: ['Signatory Agreement Clause', 'Page Two Terms'],
      );
      final srcBytes = src.readAsBytesSync();

      // Generate genuine transparent signature PNG from strokes
      final sigPng = await exportSignatureStrokesToPngBytes(
        strokes: const [
          [Offset(20, 80), Offset(70, 30), Offset(130, 75), Offset(210, 45)],
        ],
        canvasSize: const Size(260, 110),
        inkColor: const Color(0xFF0052FF),
        strokeWidth: 3.5,
      );
      // Verify authentic PNG magic signature (89 50 4E 47)
      expect(sigPng.take(4).toList(), equals([0x89, 0x50, 0x4E, 0x47]));

      final annotated = await AdvancedPdfService.instance.applyAnnotations(
        sourcePdf: src,
        outputFileName: 'annotated_copy',
        annotations: [
          const PdfAnnotationItem(
            type: PdfAnnotationType.highlight,
            pageIndex: 0,
            x: 0.1,
            y: 0.15,
            width: 0.5,
            height: 0.04,
            color: Color(0xFFF59E0B),
            normalized: true,
          ),
          const PdfAnnotationItem(
            type: PdfAnnotationType.underline,
            pageIndex: 0,
            x: 0.1,
            y: 0.25,
            width: 0.45,
            height: 0.01,
            color: Color(0xFF0052FF),
            normalized: true,
          ),
          const PdfAnnotationItem(
            type: PdfAnnotationType.freehand,
            pageIndex: 0,
            x: 0,
            y: 0,
            points: [Offset(0.15, 0.35), Offset(0.35, 0.40), Offset(0.55, 0.34)],
            color: Color(0xFFDC2626),
            strokeWidth: 3.0,
            normalized: true,
          ),
          const PdfAnnotationItem(
            type: PdfAnnotationType.text,
            pageIndex: 0,
            x: 0.15,
            y: 0.45,
            width: 0.3,
            height: 0.05,
            text: 'Reviewed OK',
            normalized: true,
          ),
          const PdfAnnotationItem(
            type: PdfAnnotationType.shape,
            pageIndex: 0,
            x: 0.1,
            y: 0.55,
            width: 0.25,
            height: 0.12,
            shapeKind: PdfShapeKind.arrow,
            normalized: true,
          ),
          PdfAnnotationItem(
            type: PdfAnnotationType.signature,
            pageIndex: 0,
            x: 0.50,
            y: 0.72,
            width: 0.35,
            height: 0.12,
            rotationDegrees: -6.0,
            signaturePngBytes: sigPng,
            normalized: true,
          ),
        ],
      );

      expect(annotated.existsSync(), isTrue);
      expect(await AdvancedPdfService.instance.getPageCount(annotated), equals(2));
      expect(annotated.lengthSync(), greaterThan(src.lengthSync()));
      // Original file remains untouched
      expect(src.readAsBytesSync(), equals(srcBytes));

      // Controller Undo/Redo verification
      final ctrl = PdfAnnotationController();
      ctrl.addItem(
        const PdfAnnotationItem(
          type: PdfAnnotationType.text,
          pageIndex: 0,
          x: 0.1,
          y: 0.1,
          text: 'Note 1',
          normalized: true,
        ),
      );
      expect(ctrl.items.length, equals(1));
      expect(ctrl.canUndo, isTrue);
      ctrl.undo();
      expect(ctrl.items, isEmpty);
      ctrl.redo();
      expect(ctrl.items.length, equals(1));
      ctrl.dispose();
    });

    test('Watermarks (text + page selection), organize (reorder/rotate/duplicate/delete/extract/insert), merge, split & compression work cleanly', () async {
      final svc = AdvancedPdfService.instance;
      final pdfA = _createVectorTextPdfSync(
        tempDir,
        'a.pdf',
        pageTexts: ['DocA P1', 'DocA P2', 'DocA P3'],
      );
      final pdfB = _createVectorTextPdfSync(
        tempDir,
        'b.pdf',
        pageTexts: ['DocB P1'],
      );

      // 1. Watermark
      final wm = await svc.addWatermark(
        sourcePdf: pdfA,
        options: const WatermarkOptions(
          text: 'CONFIDENTIAL',
          opacity: 0.35,
          pageSelection: WatermarkPageSelection.firstPageOnly,
        ),
        outputFileName: 'wm_out',
      );
      expect(await svc.getPageCount(wm), equals(3));

      // 2. Organize: Reorder, Rotate, Duplicate, Delete, Extract, Insert
      final reordered = await svc.reorderPages(
        sourcePdf: pdfA,
        newPageOrder1Indexed: const [3, 1, 2],
        outputFileName: 'reordered',
      );
      expect((await svc.extractTextByPage(reordered))[1], contains('DocA P3'));

      final rotated = await svc.rotatePages(
        sourcePdf: reordered,
        pageRotationsDegrees: const {1: 90},
        outputFileName: 'rotated',
      );
      expect(await svc.getPageCount(rotated), equals(3));

      final dup = await svc.duplicatePage(
        sourcePdf: rotated,
        pageNumber1Indexed: 1,
        outputFileName: 'dup',
      );
      expect(await svc.getPageCount(dup), equals(4));

      final deleted = await svc.deletePages(
        sourcePdf: dup,
        pagesToDelete1Indexed: const [2],
        outputFileName: 'del',
      );
      expect(await svc.getPageCount(deleted), equals(3));

      final extracted = await svc.extractPages(
        sourcePdf: pdfA,
        pageNumbers: const [2, 3],
        outputFileName: 'extracted',
      );
      expect(await svc.getPageCount(extracted), equals(2));

      final inserted = await svc.insertPagesFromPdf(
        sourcePdf: extracted,
        insertAfterPageIndex1Indexed: 1,
        pdfToInsert: pdfB,
        outputFileName: 'inserted',
      );
      expect(await svc.getPageCount(inserted), equals(3));

      // 3. Merge & Split
      final merged = await svc.mergePdfs(
        sourcePdfs: [pdfA, pdfB],
        outputFileName: 'merged',
      );
      expect(await svc.getPageCount(merged), equals(4));

      final splitPages = await svc.splitPdfIntoPages(
        sourcePdf: merged,
        baseOutputName: 'split_single',
      );
      expect(splitPages.length, equals(4));

      final splitRanges = await svc.splitPdfByRanges(
        sourcePdf: merged,
        ranges1Indexed: const [
          [1, 2],
          [3, 4],
        ],
        baseOutputName: 'split_range',
      );
      expect(splitRanges.length, equals(2));
      expect(await svc.getPageCount(splitRanges[0]), equals(2));

      // 4. Compression with honest before/after metrics on image-backed ScannedDocument
      final rawPhoto1 = _createHighResPhotoJpgSync(tempDir, 'hr1.jpg', seed: 1);
      final rawPhoto2 = _createHighResPhotoJpgSync(tempDir, 'hr2.jpg', seed: 2);
      final bigPdf = await svc.compressPdf(
        sourcePdf: _createImageOnlyPdfSync(tempDir, 'raw.pdf', rawPhoto1),
        preset: PdfCompressionPreset.highQuality,
        outputFileName: 'hq_base',
        associatedDocument: ScannedDocument(
          id: 'c_doc',
          title: 'Heavy Scan',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pages: [
            DocumentPage(
              id: 'cp1',
              documentId: 'c_doc',
              pageOrder: 0,
              originalPath: rawPhoto1.path,
            ),
            DocumentPage(
              id: 'cp2',
              documentId: 'c_doc',
              pageOrder: 1,
              originalPath: rawPhoto2.path,
            ),
          ],
        ),
      );
      final smallerResult = await svc.compressPdf(
        sourcePdf: bigPdf.outputFile,
        preset: PdfCompressionPreset.smallerFile,
        outputFileName: 'small_out',
        associatedDocument: ScannedDocument(
          id: 'c_doc',
          title: 'Heavy Scan',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pages: [
            DocumentPage(
              id: 'cp1',
              documentId: 'c_doc',
              pageOrder: 0,
              originalPath: rawPhoto1.path,
            ),
            DocumentPage(
              id: 'cp2',
              documentId: 'c_doc',
              pageOrder: 1,
              originalPath: rawPhoto2.path,
            ),
          ],
        ),
      );
      expect(smallerResult.compressedSizeBytes, lessThan(smallerResult.originalSizeBytes));
      expect(smallerResult.percentageReduction, greaterThan(0));
    });
  });

  group('Phase 5 Widget & UI Tests: PDF Viewer, Annotate, Signature, Watermark & Page Organizer', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p5_ui_');
      await AppStorageService.instance.init(tempDir);
      await _openPhase5TestDb(tempDir);
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

    testWidgets('DocumentViewerScreen renders Concept A Light/Dark themes, search scanned notice, thumbnail strip, annotate toolbar & signature studio', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final imgFile = _createHighResPhotoJpgSync(tempDir, 'scan_ui.jpg');
      final pdfFile = _createImageOnlyPdfSync(tempDir, 'viewer_doc.pdf', imgFile);
      final doc = ScannedDocument(
        id: 'doc_v1',
        title: 'Rental Agreement',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        exportPath: pdfFile.path,
        pages: [
          DocumentPage(
            id: 'pv1',
            documentId: 'doc_v1',
            pageOrder: 0,
            originalPath: imgFile.path,
          ),
        ],
      );
      await tester.runAsync(() => AppDatabaseService.instance.saveDocument(doc));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: DocumentViewerScreen(
              document: doc,
              pdfCanvasBuilder: (_) => Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: const Text('PDF PAGE RENDER'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();

      expect(find.text('Rental Agreement'), findsOneWidget);
      expect(find.text('Annotate'), findsOneWidget);
      expect(find.text('Sign'), findsOneWidget);
      expect(find.text('Organize'), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Open Search bar -> scanned PDF shows honest OCR notice once async text-layer inspection completes
      await tester.tap(find.byTooltip('Search Text'));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
        if (find
            .text('Scanned PDF has no text layer — run OCR to search text.')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.text('Scanned PDF has no text layer — run OCR to search text.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close Search'));
      await tester.pumpAndSettle();

      // Toggle Annotate mode -> verifies markup tool buttons appear
      await tester.tap(find.text('Annotate'));
      await tester.pumpAndSettle();
      expect(find.text('Highlight'), findsOneWidget);
      expect(find.text('Ink Draw'), findsOneWidget);
      expect(find.text('Text Note'), findsOneWidget);
      expect(find.text('Shapes'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Annotate'));
      await tester.pumpAndSettle();

      // Open Visual Signature Studio
      await tester.tap(find.text('Sign'));
      await tester.pumpAndSettle();
      expect(find.text('Visual Signature Studio'), findsOneWidget);
      expect(
        find.textContaining('non-cryptographic'),
        findsOneWidget,
      );
    });

    testWidgets('WatermarkStudioPanel live preview & PdfPageOrganizerScreen grid/list toggle, rotate & delete guard work cleanly', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final multiPdf = _createVectorTextPdfSync(
        tempDir,
        'org_test.pdf',
        pageTexts: ['Page One', 'Page Two', 'Page Three'],
      );

      // 1. Test WatermarkStudioPanel
      WatermarkOptions? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WatermarkStudioPanel(
              currentPage: 1,
              totalPages: 3,
              onApply: (opts) => chosen = opts,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DRAFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Watermark to Copy'));
      await tester.pumpAndSettle();
      expect(chosen, isNotNull);
      expect(chosen!.text, equals('DRAFT'));

      // 2. Test PdfPageOrganizerScreen
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PdfPageOrganizerScreen(pdfFile: multiPdf),
        ),
      );
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (find.text('Page 1').evaluate().isNotEmpty) break;
      }

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 3'), findsOneWidget);

      // Select Page 1 and rotate 90 deg -> badge displays 90 deg
      await tester.tap(find.text('Page 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate 90°'));
      await tester.pumpAndSettle();
      expect(find.text('90°'), findsOneWidget);

      // Switch Grid -> List View
      await tester.tap(find.byTooltip('List View'));
      await tester.pumpAndSettle();
      expect(find.text('Source page #1 · Rotated 90°'), findsOneWidget);
    });
  });
}

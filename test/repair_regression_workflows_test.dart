import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/services/scan_preferences_service.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/data/batch_merge_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  Future<Database> openTestDb(String path) {
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (d, version) async {
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
          await d.execute(
            'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_number INTEGER NOT NULL, title TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await d.execute('''
            CREATE VIRTUAL TABLE documents_fts USING fts5(
              document_id UNINDEXED,
              title,
              full_text,
              tokenize='unicode61 remove_diacritics 1'
            )
          ''');
        },
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_repair_reg_');
    await AppStorageService.instance.init(tempDir);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ScanPreferencesService.instance.setPreferencesForTesting(prefs);
    await ScanPreferencesService.instance.init();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Repair Regression Suite', () {
    test('DEF-LIVE-01: Single-pass PDF & JPEG export never double-rotates processed pages and honors DPI/Format presets', () async {
      final db = await openTestDb('${tempDir.path}/single_pass.db');
      AppDatabaseService.instance.setDatabaseForTesting(db);

      // Landscape source image (800x400)
      final src = img.Image(width: 800, height: 400);
      img.fill(src, color: img.ColorRgb8(245, 245, 245));
      for (int y = 50; y < 350; y += 20) {
        img.drawLine(
          src,
          x1: 20,
          y1: y,
          x2: 780,
          y2: y,
          color: img.ColorRgb8(30, 30, 30),
        );
      }
      final origFile = File('${tempDir.path}/wide_scan.jpg');
      await origFile.writeAsBytes(img.encodeJpg(src, quality: 92));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scanSessionProvider.notifier);
      notifier.resetSession('Rotation Test');
      await notifier.addCapturedPage(origFile);
      final rawPage = container.read(scanSessionProvider).pages.single;

      // Rotate 90 degrees -> processedPath becomes 400x800 portrait.
      await notifier.updatePageRecipe(
        rawPage.id,
        const EditRecipe(rotationDegrees: 90),
      );
      final editedPage = container.read(scanSessionProvider).pages.single;
      expect(editedPage.processedPath, isNotNull);

      // Export JPEG must remain portrait (90°), NOT double-rotated back to landscape (180°)!
      final exportedJpg = await PdfService.exportPageAsJpeg(
        page: editedPage,
        baseName: 'SinglePassPortrait',
      );
      final decodedExport = img.decodeImage(await exportedJpg.readAsBytes())!;
      expect(decodedExport.height, greaterThan(decodedExport.width));

      // Quality & page format presets produce distinct valid PDFs.
      final doc = ScannedDocument(
        id: 'doc_presets',
        title: 'Presets Doc',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final compactPdf = await PdfService.generatePdf(
        document: doc,
        pages: [editedPage],
        customTitle: 'Compact_Test',
        qualityPreset: PdfQualityPreset.compact150,
        pageFormatOption: PdfPageFormatOption.a4,
      );
      final highLetterPdf = await PdfService.generatePdf(
        document: doc,
        pages: [editedPage],
        customTitle: 'High_Letter_Test',
        qualityPreset: PdfQualityPreset.high300,
        pageFormatOption: PdfPageFormatOption.letter,
      );

      expect(
        await compactPdf.length(),
        lessThanOrEqualTo(await highLetterPdf.length()),
      );
      final sfLetter = sf.PdfDocument(
        inputBytes: await highLetterPdf.readAsBytes(),
      );
      try {
        final size = sfLetter.pages[0].size;
        expect(size.width.round(), 612);
        expect(size.height.round(), 792);
      } finally {
        sfLetter.dispose();
      }

      await db.close();
    });

    test('DEF-LIVE-02: BatchMergeService isolates page files so deleting source docs never corrupts merged document', () async {
      final db = await openTestDb('${tempDir.path}/merge_isolation.db');
      AppDatabaseService.instance.setDatabaseForTesting(db);

      final canvas = img.Image(width: 200, height: 200);
      img.fill(canvas, color: img.ColorRgb8(230, 230, 230));
      final jpgBytes = img.encodeJpg(canvas, quality: 85);

      final pAFile = await AppStorageService.instance.saveOriginalPage(
        'src_page_a',
        jpgBytes,
      );
      final pBFile = await AppStorageService.instance.saveOriginalPage(
        'src_page_b',
        jpgBytes,
      );

      final now = DateTime.now();
      final docA = ScannedDocument(
        id: 'doc_src_a',
        title: 'Source A',
        createdAt: now,
        modifiedAt: now,
        pageCount: 1,
      );
      final docB = ScannedDocument(
        id: 'doc_src_b',
        title: 'Source B',
        createdAt: now,
        modifiedAt: now,
        pageCount: 1,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(docA, [
        DocumentPage(
          id: 'src_page_a',
          documentId: docA.id,
          pageOrder: 0,
          originalPath: pAFile.path,
        ),
      ]);
      await AppDatabaseService.instance.saveDocumentWithPages(docB, [
        DocumentPage(
          id: 'src_page_b',
          documentId: docB.id,
          pageOrder: 0,
          originalPath: pBFile.path,
        ),
      ]);

      final merged = await BatchMergeService.instance.mergeDocuments(
        sourceDocuments: [docA, docB],
        outputTitle: 'Merged_Isolated',
      );
      expect(merged.pages.length, 2);
      expect(merged.pages[0].originalPath, isNot(equals(pAFile.path)));

      // Permanently delete docA -> removes pAFile, must NOT touch mergedDoc's isolated file!
      await AppDatabaseService.instance.permanentlyDelete(docA.id);
      expect(pAFile.existsSync(), isFalse);
      expect(File(merged.pages[0].originalPath).existsSync(), isTrue);
      expect(File(merged.pages[1].originalPath).existsSync(), isTrue);

      await db.close();
    });

    test('DEF-LIVE-07: ScanPreferencesService persists settings and StorageBreakdown cleans temp safely', () async {
      final prefs = await SharedPreferences.getInstance();
      final scanPrefs = ScanPreferencesService.instance;
      scanPrefs.setPreferencesForTesting(prefs);

      await scanPrefs.setQualityPreset(PdfQualityPreset.high300);
      await scanPrefs.setPageFormat(PdfPageFormatOption.letter);
      await scanPrefs.setDefaultOcrScript(OcrScript.mixedBengaliEnglish);
      await scanPrefs.setAutoEmbedSearchableOcr(false);
      await scanPrefs.setSmartFilenameTemplate('[Date]_[Title]');

      await scanPrefs.init();
      expect(scanPrefs.qualityPreset, PdfQualityPreset.high300);
      expect(scanPrefs.pageFormat, PdfPageFormatOption.letter);
      expect(scanPrefs.defaultOcrScript, OcrScript.mixedBengaliEnglish);
      expect(scanPrefs.autoEmbedSearchableOcr, isFalse);
      expect(scanPrefs.smartFilenameTemplate, '[Date]_[Title]');

      final storage = AppStorageService.instance;
      await storage.saveOriginalPage('keep_me', [0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);
      final tmpFile = File('${storage.tempDir.path}/junk.tmp');
      await tmpFile.writeAsBytes(List<int>.filled(512, 9));

      final before = await storage.calculateStorageBreakdown();
      expect(before.originalsBytes, 6);
      expect(before.tempBytes, 512);

      final freed = await storage.clearTemporaryCache();
      expect(freed, 512);

      final after = await storage.calculateStorageBreakdown();
      expect(after.tempBytes, 0);
      expect(after.originalsBytes, 6);
    });

    testWidgets(
      'DEF-LIVE-05: ToolsScreen exposes specialized capture modes, PDF-to-Images, Redact Studio & WebDAV Sync',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: ToolsScreen()));

        expect(find.text('Specialized Capture Modes'), findsOneWidget);
        expect(find.text('ID Card 2-in-1 Sheet'), findsOneWidget);
        expect(find.text('Book Spread Split'), findsOneWidget);
        expect(find.text('PDF to Images (JPEG)'), findsOneWidget);
        expect(find.text('Redact & Mosaic Studio'), findsOneWidget);
        expect(find.text('Share & Export'), findsOneWidget);
        expect(find.text('WebDAV & Encrypted Vault Sync'), findsOneWidget);
      },
    );
  });
}

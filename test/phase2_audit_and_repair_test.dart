import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_repair_test_');
    await AppStorageService.instance.init(tempDir);
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 2 & 3 Functionality Audit & Repair Tests', () {
    test('F-07: splitBookSpread cleanly separates open spread into Left and Right pages', () {
      // Create synthetic wide book spread (width: 1000, height: 700)
      final spread = img.Image(width: 1000, height: 700);
      img.fill(spread, color: img.ColorRgb8(240, 240, 240));

      // Draw distinct markers on left and right sides
      img.fillRect(
        spread,
        x1: 100,
        y1: 100,
        x2: 200,
        y2: 200,
        color: img.ColorRgb8(255, 0, 0),
      );
      img.fillRect(
        spread,
        x1: 800,
        y1: 100,
        x2: 900,
        y2: 200,
        color: img.ColorRgb8(0, 0, 255),
      );

      final splitPages = ImageProcessingService.splitBookSpread(spread);

      expect(splitPages.length, equals(2));
      final leftPage = splitPages[0];
      final rightPage = splitPages[1];

      // Verify dimensions
      expect(leftPage.height, equals(700));
      expect(rightPage.height, equals(700));
      expect(leftPage.width, greaterThanOrEqualTo(500));
      expect(rightPage.width, greaterThanOrEqualTo(500));

      // Left page should contain red marker at ~100, 100
      final leftSample = leftPage.getPixel(150, 150);
      expect(leftSample.r, equals(255));
      expect(leftSample.b, equals(0));

      // Right page should contain blue marker
      // Since right starts around 480, x=850 in spread is x=(850 - 480)=370 in rightPage
      final rightSample = rightPage.getPixel(370, 150);
      expect(rightSample.b, equals(255));
      expect(rightSample.r, equals(0));
    });

    test(
      'F-07: splitBookSpreadFile creates two persistent image files on disk',
      () async {
        final spread = img.Image(width: 800, height: 600);
        img.fill(spread, color: img.ColorRgb8(250, 250, 250));
        final spreadPath = p.join(tempDir.path, 'test_spread.jpg');
        final spreadFile = File(spreadPath);
        await spreadFile.writeAsBytes(img.encodeJpg(spread, quality: 85));

        final resultFiles = await ImageProcessingService.splitBookSpreadFile(
          spreadFile: spreadFile,
          outputDir: tempDir,
          baseId: 'test_book',
        );

        expect(resultFiles.length, equals(2));
        expect(await resultFiles[0].exists(), isTrue);
        expect(await resultFiles[1].exists(), isTrue);
        expect(resultFiles[0].path.endsWith('_left.jpg'), isTrue);
        expect(resultFiles[1].path.endsWith('_right.jpg'), isTrue);

        final leftDecoded = img.decodeImage(await resultFiles[0].readAsBytes());
        expect(leftDecoded, isNotNull);
        expect(leftDecoded!.width, greaterThanOrEqualTo(400));
      },
    );

    test('F-06: PdfService.stitchIdCard2In1 generates standardized 200 DPI A4 composite', () async {
      // Create synthetic Front and Back cards (e.g. 800 x 500)
      final front = img.Image(width: 800, height: 500);
      img.fill(front, color: img.ColorRgb8(220, 230, 245));
      final back = img.Image(width: 800, height: 500);
      img.fill(back, color: img.ColorRgb8(245, 230, 220));

      final frontFile = File(p.join(tempDir.path, 'front.jpg'));
      final backFile = File(p.join(tempDir.path, 'back.jpg'));
      await frontFile.writeAsBytes(img.encodeJpg(front, quality: 85));
      await backFile.writeAsBytes(img.encodeJpg(back, quality: 85));

      final stitchedFile = await PdfService.stitchIdCard2In1(
        frontImage: frontFile,
        backImage: backFile,
        baseTitle: 'National_ID_Card',
      );

      expect(await stitchedFile.exists(), isTrue);
      final stitchedDecoded = img.decodeImage(await stitchedFile.readAsBytes());
      expect(stitchedDecoded, isNotNull);
      // Standard A4 at 200 DPI: 1654 x 2338
      expect(stitchedDecoded!.width, equals(1654));
      expect(stitchedDecoded.height, equals(2338));
    });

    test('F-12: EditRecipe.isDefault correctly detects default vs modified recipes', () {
      const defaultRecipe = EditRecipe();
      expect(defaultRecipe.isDefault, isTrue);

      const rotatedRecipe = EditRecipe(rotationDegrees: 90);
      expect(rotatedRecipe.isDefault, isFalse);

      const filterRecipe = EditRecipe(filter: PageFilter.blackAndWhite);
      expect(filterRecipe.isDefault, isFalse);

      const cropRecipe = EditRecipe(cropLeft: 0.1);
      expect(cropRecipe.isDefault, isFalse);

      const binarizedRecipe = EditRecipe(binarization: BinarizationMode.otsu);
      expect(binarizedRecipe.isDefault, isFalse);
    });

    test('F-22 & Database: AppDatabaseService.saveDocument persists PDF tools outputs to library', () async {
      final inMemoryDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await inMemoryDb.execute('''
        CREATE TABLE documents (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          modified_at INTEGER NOT NULL,
          page_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_draft INTEGER NOT NULL DEFAULT 0,
          export_path TEXT,
          folder_id TEXT,
          deleted_at INTEGER
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE pages (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          page_order INTEGER NOT NULL,
          original_path TEXT NOT NULL,
          processed_path TEXT,
          edit_recipe_json TEXT NOT NULL,
          width INTEGER,
          height INTEGER
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE document_ocr (
          document_id TEXT PRIMARY KEY,
          full_text TEXT NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          modified_at INTEGER NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE document_tags (
          document_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (document_id, tag_id)
        )
      ''');

      AppDatabaseService.instance.setDatabaseForTesting(inMemoryDb);

      final doc = ScannedDocument(
        id: 'merged_doc_101',
        title: 'Quarterly_Report_Merged',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 14,
        exportPath: '/test/exports/Quarterly_Report_Merged.pdf',
      );

      await AppDatabaseService.instance.saveDocument(doc);

      final retrieved = await AppDatabaseService.instance.getAllDocuments();
      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('merged_doc_101'));
      expect(retrieved.first.title, equals('Quarterly_Report_Merged'));
      expect(retrieved.first.pageCount, equals(14));
      expect(
        retrieved.first.exportPath,
        equals('/test/exports/Quarterly_Report_Merged.pdf'),
      );

      await inMemoryDb.close();
      AppDatabaseService.instance.setDatabaseForTesting(null);
    });
  });
}

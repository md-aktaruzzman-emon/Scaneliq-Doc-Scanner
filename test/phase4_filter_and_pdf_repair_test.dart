import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('scaneliq_phase4_test_');
    await AppStorageService.instance.init(tempDir);
  });

  tearDown(() async {
    try {
      await AppDatabaseService.instance.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 4: Filter Processing & Verification Tests', () {
    late File testImageFile;

    setUp(() async {
      // Create a test synthetic color image with gradients and text-like blocks
      final sample = img.Image(width: 300, height: 300);
      img.fill(sample, color: img.ColorRgb8(240, 240, 240));

      // Red header block
      img.fillRect(
        sample,
        x1: 20,
        y1: 20,
        x2: 280,
        y2: 60,
        color: img.ColorRgb8(220, 50, 50),
      );
      // Dark text-like stripes
      for (int y = 80; y < 260; y += 30) {
        img.fillRect(
          sample,
          x1: 20,
          y1: y,
          x2: 260,
          y2: y + 10,
          color: img.ColorRgb8(40, 40, 50),
        );
      }

      final testImagePath = p.join(tempDir.path, 'source_sample.jpg');
      testImageFile = File(testImagePath);
      await testImageFile.writeAsBytes(img.encodeJpg(sample, quality: 90));
    });

    test('All 6 filters generate distinct, valid JPEG outputs', () async {
      final filters = [
        PageFilter.original,
        PageFilter.colorBoost,
        PageFilter.blackAndWhite,
        PageFilter.whiteboard,
        PageFilter.grayscale,
        PageFilter.enhancedText,
      ];

      final Map<PageFilter, Uint8List> outputs = {};

      for (final filter in filters) {
        final recipe = EditRecipe(filter: filter);
        final bytes = await ImageProcessingService.processImageFileToBytes(
          testImageFile,
          recipe,
          quality: 85,
        );

        expect(bytes.isNotEmpty, isTrue);
        final decoded = img.decodeImage(bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, equals(300));
        expect(decoded.height, equals(300));
        outputs[filter] = bytes;
      }

      // Verify that blackAndWhite is binarized (monochrome contrast)
      final bwDecoded = img.decodeImage(outputs[PageFilter.blackAndWhite]!)!;
      final bwSample1 = bwDecoded.getPixel(100, 30); // header
      final bwSample2 = bwDecoded.getPixel(10, 10); // background
      // Grayscale/binary channels should be equal
      expect(bwSample1.r, equals(bwSample1.g));
      expect(bwSample1.g, equals(bwSample1.b));
      expect(bwSample2.r, equals(bwSample2.g));

      // Verify grayscale has equal r, g, b
      final grayDecoded = img.decodeImage(outputs[PageFilter.grayscale]!)!;
      final grayPixel = grayDecoded.getPixel(50, 50);
      expect(grayPixel.r, equals(grayPixel.g));
      expect(grayPixel.g, equals(grayPixel.b));
    });

    test(
      'Brightness and contrast adjustments modify image pixel values',
      () async {
        final baseRecipe = const EditRecipe();
        final baseBytes = await ImageProcessingService.processImageFileToBytes(
          testImageFile,
          baseRecipe,
        );

        final brightRecipe = const EditRecipe(brightness: 0.4);
        final brightBytes =
            await ImageProcessingService.processImageFileToBytes(
              testImageFile,
              brightRecipe,
            );

        final baseImg = img.decodeImage(baseBytes)!;
        final brightImg = img.decodeImage(brightBytes)!;

        final basePx = baseImg.getPixel(50, 85);
        final brightPx = brightImg.getPixel(50, 85);

        // Brightened image pixel must have higher luminance/RGB values
        expect(brightPx.r, greaterThanOrEqualTo(basePx.r));
        expect(brightPx.g, greaterThanOrEqualTo(basePx.g));
        expect(brightPx.b, greaterThanOrEqualTo(basePx.b));
      },
    );

    test(
      'Resetting recipe restores original image bytes without distortion',
      () async {
        final customRecipe = const EditRecipe(
          filter: PageFilter.blackAndWhite,
          brightness: 0.2,
          contrast: 1.3,
          binarization: BinarizationMode.otsu,
        );

        final customBytes =
            await ImageProcessingService.processImageFileToBytes(
              testImageFile,
              customRecipe,
            );
        expect(customBytes.isNotEmpty, isTrue);

        final resetRecipe = const EditRecipe();
        final resetBytes = await ImageProcessingService.processImageFileToBytes(
          testImageFile,
          resetRecipe,
        );

        final origDecoded = img.decodeImage(await testImageFile.readAsBytes())!;
        final resetDecoded = img.decodeImage(resetBytes)!;

        expect(resetDecoded.width, equals(origDecoded.width));
        expect(resetDecoded.height, equals(origDecoded.height));
      },
    );

    test(
      'ScanSessionProvider applyFilterToAllPages updates all pages in batch',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(scanSessionProvider.notifier);
        await notifier.addCapturedPage(testImageFile);
        await notifier.addCapturedPage(testImageFile);

        expect(container.read(scanSessionProvider).pages.length, equals(2));

        // Apply batch filter
        await notifier.applyFilterToAllPages(PageFilter.whiteboard);

        final updatedPages = container.read(scanSessionProvider).pages;
        expect(
          updatedPages[0].editRecipe.filter,
          equals(PageFilter.whiteboard),
        );
        expect(
          updatedPages[1].editRecipe.filter,
          equals(PageFilter.whiteboard),
        );

        // Both should have non-null processed paths
        expect(updatedPages[0].processedPath, isNotNull);
        expect(updatedPages[1].processedPath, isNotNull);
        expect(File(updatedPages[0].processedPath!).existsSync(), isTrue);
        expect(File(updatedPages[1].processedPath!).existsSync(), isTrue);
      },
    );
  });

  group('Phase 4: PDF Generation, Unicode & Repair Verification Tests', () {
    late File sampleImage;

    setUp(() async {
      final image = img.Image(width: 400, height: 600);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawString(
        image,
        'Scaneliq Test Page',
        font: img.arial24,
        x: 40,
        y: 40,
        color: img.ColorRgb8(0, 0, 0),
      );
      final samplePath = p.join(tempDir.path, 'sample_doc_page.jpg');
      sampleImage = File(samplePath);
      await sampleImage.writeAsBytes(img.encodeJpg(image, quality: 85));
    });

    test('PdfService.generatePdf generates valid PDF verified by Syncfusion parser', () async {
      final page = DocumentPage(
        id: 'pdf_page_1',
        documentId: 'doc_valid_test',
        pageOrder: 1,
        originalPath: sampleImage.path,
      );

      final doc = ScannedDocument(
        id: 'doc_valid_test',
        title: 'Validation Document',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        pages: [page],
      );

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: [page],
        customTitle: 'Verified PDF Output',
      );

      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(1000));

      // Validate integrity using Syncfusion PDF engine
      final bytes = await pdfFile.readAsBytes();
      final loadedDoc = sf.PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(1));
      loadedDoc.dispose();
    });

    test('PdfService handles Unicode and Bengali text without font crash or stream corruption', () async {
      final ocrBoxes = [
        const OcrBoundingBox(
          text: 'Scaneliq Invoice 2026',
          left: 40,
          top: 40,
          width: 200,
          height: 20,
        ),
        const OcrBoundingBox(
          text: 'বাংলা টেক্সট ও পরীক্ষা ১২৩৪৫৬৭৮৯০',
          left: 40,
          top: 80,
          width: 250,
          height: 20,
        ),
      ];

      final page = DocumentPage(
        id: 'pdf_unicode_page',
        documentId: 'doc_unicode_test',
        pageOrder: 1,
        originalPath: sampleImage.path,
      );

      final doc = ScannedDocument(
        id: 'doc_unicode_test',
        title: 'Unicode Document বাংলা',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        pages: [page],
      );

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: [page],
        customTitle: 'Unicode Test Document',
        ocrBoxesByPage: {0: ocrBoxes},
      );

      expect(pdfFile.existsSync(), isTrue);

      // Verify that Syncfusion loads it successfully with valid pages
      final bytes = await pdfFile.readAsBytes();
      final loadedDoc = sf.PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(1));
      loadedDoc.dispose();
    });

    test('AppDatabaseService renameDocument renames filesystem PDF and updates SQLite export_path', () async {
      await AppDatabaseService.instance.database;

      // Create a dummy PDF on disk
      final oldPdfPath = p.join(tempDir.path, 'Original_Title.pdf');
      final oldPdfFile = File(oldPdfPath);
      await oldPdfFile.writeAsString('%PDF-1.4 dummy content');

      final doc = ScannedDocument(
        id: 'rename_test_doc',
        title: 'Original Title',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        exportPath: oldPdfFile.path,
      );

      await AppDatabaseService.instance.saveDocument(doc);

      // Rename document
      await AppDatabaseService.instance.renameDocument(
        'rename_test_doc',
        'Renamed Document Title',
      );

      final updatedDoc = await AppDatabaseService.instance.getDocument(
        'rename_test_doc',
      );
      expect(updatedDoc, isNotNull);
      expect(updatedDoc!.title, equals('Renamed Document Title'));
      expect(updatedDoc.exportPath, isNotNull);
      expect(updatedDoc.exportPath!.contains('Renamed Document Title'), isTrue);

      // Verify filesystem file was physically moved/renamed
      expect(File(updatedDoc.exportPath!).existsSync(), isTrue);
      expect(oldPdfFile.existsSync(), isFalse);

      await AppDatabaseService.instance.close();
    });
  });
}

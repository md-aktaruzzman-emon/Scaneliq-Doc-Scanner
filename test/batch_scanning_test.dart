import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleImageFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_batch_test_');
    await AppStorageService.instance.init(tempDir);

    // Create a 100x100 synthetic JPEG image
    final sampleImg = img.Image(width: 100, height: 100);
    img.fill(sampleImg, color: img.ColorRgb8(255, 0, 0));
    final jpgBytes = img.encodeJpg(sampleImg);

    sampleImageFile = File('${tempDir.path}/batch_sample.jpg');
    await sampleImageFile.writeAsBytes(jpgBytes);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Batch Scanning & Multi-Page Output Tests', () {
    test('Simulates 5-page continuous capture, delete 1, reorder 2, and exports valid multi-page PDF', () async {
      // 1. Simulate capturing 5 pages
      final List<DocumentPage> pages = [];
      for (int i = 0; i < 5; i++) {
        pages.add(
          DocumentPage(
            id: 'page_$i',
            documentId: 'doc_batch_1',
            pageOrder: i,
            originalPath: sampleImageFile.path,
          ),
        );
      }
      expect(pages.length, equals(5));

      // 2. Delete 1 page (e.g. page at index 2)
      pages.removeAt(2);
      expect(pages.length, equals(4));

      // 3. Reorder 2 pages (swap index 0 and 1)
      final temp = pages[0];
      pages[0] = pages[1].copyWith(pageOrder: 0);
      pages[1] = temp.copyWith(pageOrder: 1);

      // Re-index remaining
      final reindexed = [
        for (int i = 0; i < pages.length; i++) pages[i].copyWith(pageOrder: i),
      ];

      expect(reindexed.length, equals(4));
      expect(reindexed[0].id, equals('page_1'));
      expect(reindexed[1].id, equals('page_0'));

      // 4. Generate multi-page PDF
      final doc = ScannedDocument(
        id: 'doc_batch_1',
        title: 'Batch_Test_Doc',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: reindexed.length,
      );

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: reindexed,
      );

      expect(pdfFile.existsSync(), isTrue);
      final pdfBytes = await pdfFile.readAsBytes();
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Batch export all pages as individual JPEG images succeeds', () async {
      final List<DocumentPage> pages = [
        DocumentPage(
          id: 'img_p0',
          documentId: 'doc_img_batch',
          pageOrder: 0,
          originalPath: sampleImageFile.path,
          editRecipe: const EditRecipe(filter: PageFilter.whiteboard),
        ),
        DocumentPage(
          id: 'img_p1',
          documentId: 'doc_img_batch',
          pageOrder: 1,
          originalPath: sampleImageFile.path,
          editRecipe: const EditRecipe(filter: PageFilter.enhancedText),
        ),
      ];

      final List<File> exportedJpegs = [];
      for (final p in pages) {
        final jpeg = await PdfService.exportPageAsJpeg(
          page: p,
          baseName: 'Batch_Export_Test',
        );
        expect(jpeg.existsSync(), isTrue);
        exportedJpegs.add(jpeg);
      }

      expect(exportedJpegs.length, equals(2));
      for (final jFile in exportedJpegs) {
        final bytes = await jFile.readAsBytes();
        // Check JPEG SOI marker 0xFF 0xD8
        expect(bytes[0], equals(0xFF));
        expect(bytes[1], equals(0xD8));
      }
    });

    test('Whiteboard and enhancedText filters transform image pixels cleanly', () {
      final testImg = img.Image(width: 50, height: 50);
      img.fill(testImg, color: img.ColorRgb8(120, 150, 180));

      final wbResult = PdfService.applyEditRecipe(
        testImg,
        const EditRecipe(filter: PageFilter.whiteboard),
      );
      expect(wbResult.width, equals(50));
      expect(wbResult.height, equals(50));

      final textResult = PdfService.applyEditRecipe(
        testImg,
        const EditRecipe(filter: PageFilter.enhancedText),
      );
      expect(textResult.width, equals(50));
      expect(textResult.height, equals(50));
    });
  });
}

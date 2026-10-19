import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File samplePdf1;
  late File samplePdf2;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_adv_pdf_test_');
    await AppStorageService.instance.init(tempDir);

    // Create 2-page sample PDF 1
    final doc1 = sf.PdfDocument();
    doc1.pages.add().graphics.drawString(
      'Doc 1 Page 1',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
    doc1.pages.add().graphics.drawString(
      'Doc 1 Page 2',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
    samplePdf1 = File('${tempDir.path}/sample1.pdf');
    await samplePdf1.writeAsBytes(doc1.saveSync());
    doc1.dispose();

    // Create 1-page sample PDF 2
    final doc2 = sf.PdfDocument();
    doc2.pages.add().graphics.drawString(
      'Doc 2 Page 1',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
    samplePdf2 = File('${tempDir.path}/sample2.pdf');
    await samplePdf2.writeAsBytes(doc2.saveSync());
    doc2.dispose();
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AdvancedPdfService Tests', () {
    test(
      'mergePdfs combines multiple PDFs into one with exact page count',
      () async {
        final merged = await AdvancedPdfService.instance.mergePdfs(
          sourcePdfs: [samplePdf1, samplePdf2],
          outputFileName: 'merged_test',
        );

        expect(merged.existsSync(), isTrue);
        final count = await AdvancedPdfService.instance.getPageCount(merged);
        expect(count, equals(3)); // 2 from doc1 + 1 from doc2

        // Verify header
        final bytes = await merged.readAsBytes();
        final header = String.fromCharCodes(bytes.sublist(0, 5));
        expect(header, equals('%PDF-'));
      },
    );

    test(
      'splitPdfIntoPages splits multi-page PDF into single page files',
      () async {
        final splitPages = await AdvancedPdfService.instance.splitPdfIntoPages(
          sourcePdf: samplePdf1,
          baseOutputName: 'split_doc1',
        );

        expect(splitPages.length, equals(2));
        for (final pageFile in splitPages) {
          expect(pageFile.existsSync(), isTrue);
          final count = await AdvancedPdfService.instance.getPageCount(
            pageFile,
          );
          expect(count, equals(1));
        }
      },
    );

    test('extractPages extracts selected pages into new PDF', () async {
      final extracted = await AdvancedPdfService.instance.extractPages(
        sourcePdf: samplePdf1,
        pageNumbers: [2],
        outputFileName: 'extracted_page2',
      );

      expect(extracted.existsSync(), isTrue);
      final count = await AdvancedPdfService.instance.getPageCount(extracted);
      expect(count, equals(1));
    });

    test('encryptPdf password protects PDF and verifies encryption', () async {
      final encrypted = await AdvancedPdfService.instance.encryptPdf(
        sourcePdf: samplePdf2,
        userPassword: 'secretPassword123',
        outputFileName: 'encrypted_test',
      );

      expect(encrypted.existsSync(), isTrue);
      final bytes = await encrypted.readAsBytes();

      // Trying to open without password throws ArgumentError
      expect(() => sf.PdfDocument(inputBytes: bytes), throwsA(anything));

      // Opening with correct password succeeds
      final openDoc = sf.PdfDocument(
        inputBytes: bytes,
        password: 'secretPassword123',
      );
      expect(openDoc.pages.count, equals(1));
      openDoc.dispose();
    });

    test(
      'addWatermark successfully writes watermark onto document pages',
      () async {
        final watermarked = await AdvancedPdfService.instance.addWatermark(
          sourcePdf: samplePdf1,
          watermarkText: 'CONFIDENTIAL',
          outputFileName: 'watermarked_test',
        );

        expect(watermarked.existsSync(), isTrue);
        final count = await AdvancedPdfService.instance.getPageCount(
          watermarked,
        );
        expect(count, equals(2));
      },
    );
  });
}

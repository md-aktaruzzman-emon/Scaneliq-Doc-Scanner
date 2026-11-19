import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_stage6_bn_');
    await AppStorageService.instance.init(tempDir);
    OcrService.instance.nativeTesseractOverrideForTesting = null;
  });

  tearDown(() async {
    OcrService.instance.nativeTesseractOverrideForTesting = null;
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Stage 6 — Genuine Bengali & Mixed OCR + Searchable UTF-8 PDF', () {
    test('OcrService routes Bengali & Mixed Bn-En scripts to Tesseract preprocessing pipeline and normalizes numerals/punctuation', () async {
      // Create a low-contrast synthetic document specimen
      final canvas = img.Image(width: 400, height: 240);
      img.fill(canvas, color: img.ColorRgb8(215, 215, 215));
      for (int y = 40; y < 80; y++) {
        for (int x = 30; x < 340; x++) {
          canvas.setPixelRgb(x, y, 50, 50, 50);
        }
      }
      final imgFile = File('${tempDir.path}/bn_doc.jpg');
      await imgFile.writeAsBytes(img.encodeJpg(canvas, quality: 92));

      OcrScript? invokedScript;
      bool receivedPreprocessedPng = false;
      OcrService.instance.nativeTesseractOverrideForTesting =
          (processedFile, script) async {
            invokedScript = script;
            receivedPreprocessedPng =
                processedFile.existsSync() &&
                processedFile.path != imgFile.path;
            return const PageOcrResult(
              fullText: r'গণপ্রজাতন্ত্রী বাংলাদেশ সরকার ।' '\r\n' r'নম্বর: ১২৩৪  Tax: $50.00',
              boxes: [
                OcrBoundingBox(
                  text: 'গণপ্রজাতন্ত্রী বাংলাদেশ সরকার ।',
                  left: 20,
                  top: 20,
                  width: 300,
                  height: 24,
                ),
                OcrBoundingBox(
                  text: r'নম্বর: ১২৩৪  Tax: $50.00',
                  left: 20,
                  top: 60,
                  width: 280,
                  height: 22,
                ),
              ],
              script: OcrScript.mixedBengaliEnglish,
              engine: 'tesseract4android:ben+eng',
            );
          };

      final res = await OcrService.instance.extractPageOcr(
        imgFile,
        script: OcrScript.mixedBengaliEnglish,
      );

      expect(invokedScript, equals(OcrScript.mixedBengaliEnglish));
      expect(receivedPreprocessedPng, isTrue);
      expect(OcrService.containsBengali(res.fullText), isTrue);
      expect(res.fullText, contains('বাংলাদেশ সরকার।'));
      expect(res.fullText, contains('Tax:'));
      expect(
        OcrService.convertBanglaToAsciiDigits('নম্বর: ১২৩৪'),
        equals('নম্বর: 1234'),
      );
      expect(
        OcrService.normalizeBanglaNumerals(
          'তারিখ: ১২/০৫/২০২৬ ।',
          convertBanglaDigitsToAscii: true,
        ),
        equals('তারিখ: 12/05/2026।'),
      );
    });

    test('OcrTableExtractor builds CSV and Markdown tables from bounding boxes', () async {
      const ocr = PageOcrResult(
        fullText: 'বিবরণ মূল্য\nকলম ৫০ টাকা\nখাতা ১২০ টাকা',
        boxes: [
          OcrBoundingBox(text: 'বিবরণ', left: 20, top: 20, width: 80, height: 18),
          OcrBoundingBox(text: 'মূল্য', left: 220, top: 21, width: 60, height: 18),
          OcrBoundingBox(text: 'কলম', left: 20, top: 60, width: 60, height: 18),
          OcrBoundingBox(text: '৫০ টাকা', left: 220, top: 62, width: 70, height: 18),
          OcrBoundingBox(text: 'খাতা', left: 20, top: 100, width: 60, height: 18),
          OcrBoundingBox(text: '১২০ টাকা', left: 220, top: 101, width: 80, height: 18),
        ],
      );

      final table = OcrTableExtractor.extract(ocr);
      expect(table.rows.length, equals(3));
      expect(table.rows[0], equals(['বিবরণ', 'মূল্য']));
      expect(table.rows[1], equals(['কলম', '৫০ টাকা']));
      expect(table.toCsv(), contains('কলম,৫০ টাকা'));
      expect(table.toMarkdown(), contains('| খাতা | ১২০ টাকা |'));

      final csvFile = await OcrService.instance.exportTextFile(
        content: table.toCsv(),
        baseName: 'bn_table',
        extension: 'csv',
      );
      expect(csvFile.existsSync(), isTrue);
      expect(await csvFile.readAsString(), contains('১২০ টাকা'));
    });

    test('PdfService.generatePdf embeds UTF-8 NotoSansBengali font so Bengali OCR text is genuinely searchable in PDF', () async {
      final pageImg = img.Image(width: 600, height: 800);
      img.fill(pageImg, color: img.ColorRgb8(255, 255, 255));
      final imgFile = File('${tempDir.path}/scan_bn_p1.jpg');
      await imgFile.writeAsBytes(img.encodeJpg(pageImg, quality: 85));

      final doc = ScannedDocument(
        id: 'doc_bn_pdf',
        title: 'Bengali Searchable Test',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final page = DocumentPage(
        id: 'p1_bn',
        documentId: 'doc_bn_pdf',
        pageOrder: 0,
        originalPath: imgFile.path,
        editRecipe: const EditRecipe(),
      );

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: [page],
        ocrBoxesByPage: {
          0: const [
            OcrBoundingBox(
              text: 'বাংলাদেশ জাতীয় দলিল ২০২৬ Tax Receipt',
              left: 40,
              top: 60,
              width: 480,
              height: 28,
            ),
          ],
        },
      );

      expect(pdfFile.existsSync(), isTrue);
      final sfDoc = sf.PdfDocument(inputBytes: await pdfFile.readAsBytes());
      try {
        final extracted = sf.PdfTextExtractor(sfDoc).extractText();
        final normalizedExtracted = extracted.replaceAll(RegExp(r'\s+'), ' ').trim();
        debugPrint('Extracted PDF Unicode text: $normalizedExtracted');
        expect(normalizedExtracted, contains('Tax'));
        expect(normalizedExtracted, contains('Receipt'));
        // Verify Bengali Unicode characters are preserved (not stripped to spaces)
        expect(OcrService.containsBengali(normalizedExtracted), isTrue);
      } finally {
        sfDoc.dispose();
      }
    });
  });
}

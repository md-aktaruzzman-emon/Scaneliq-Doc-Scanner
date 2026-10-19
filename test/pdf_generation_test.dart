import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Generation & Validation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_pdf_test_');
      await AppStorageService.instance.init(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'Throws Exception when attempting to generate PDF from 0 pages',
      () async {
        final doc = ScannedDocument(
          id: 'doc_empty',
          title: 'Empty Document',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 0,
        );

        expect(
          () async => await PdfService.generatePdf(document: doc, pages: []),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('0 pages'),
            ),
          ),
        );
      },
    );

    test('Throws Exception when a page image file is missing', () async {
      final doc = ScannedDocument(
        id: 'doc_missing_img',
        title: 'Missing File Doc',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final pages = [
        DocumentPage(
          id: 'p_nonexistent',
          documentId: doc.id,
          pageOrder: 0,
          originalPath: '${tempDir.path}/does_not_exist.jpg',
        ),
      ];

      expect(
        () async => await PdfService.generatePdf(document: doc, pages: pages),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('missing'),
          ),
        ),
      );
    });

    test(
      'Throws Exception when exporting JPEG with missing source file',
      () async {
        final page = DocumentPage(
          id: 'p_missing_jpeg',
          documentId: 'doc_x',
          pageOrder: 0,
          originalPath: '${tempDir.path}/ghost.jpg',
        );

        expect(
          () async =>
              await PdfService.exportPageAsJpeg(page: page, baseName: 'Ghost'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('does not exist'),
            ),
          ),
        );
      },
    );

    test('Generate multi-page PDF from synthetic test images with filter and rotation', () async {
      final originalsDir = AppStorageService.instance.originalsDir;
      final page1File = File('${originalsDir.path}/page_1.jpg');
      final page2File = File('${originalsDir.path}/page_2.jpg');
      final page3File = File('${originalsDir.path}/page_3.jpg');

      // Create 3 test bitmap images
      final image1 = img.Image(width: 400, height: 600);
      img.fill(image1, color: img.ColorRgb8(255, 255, 255));
      img.drawString(
        image1,
        'Scaneliq Page 1',
        font: img.arial24,
        x: 50,
        y: 50,
        color: img.ColorRgb8(0, 0, 0),
      );
      await page1File.writeAsBytes(img.encodeJpg(image1));

      final image2 = img.Image(width: 400, height: 600);
      img.fill(image2, color: img.ColorRgb8(240, 240, 240));
      img.drawString(
        image2,
        'Scaneliq Page 2',
        font: img.arial24,
        x: 50,
        y: 50,
        color: img.ColorRgb8(0, 0, 0),
      );
      await page2File.writeAsBytes(img.encodeJpg(image2));

      final image3 = img.Image(width: 400, height: 600);
      img.fill(image3, color: img.ColorRgb8(230, 230, 230));
      img.drawString(
        image3,
        'Scaneliq Page 3',
        font: img.arial24,
        x: 50,
        y: 50,
        color: img.ColorRgb8(0, 0, 0),
      );
      await page3File.writeAsBytes(img.encodeJpg(image3));

      final doc = ScannedDocument(
        id: 'test-doc-id-123',
        title: 'Test Invoice Scan',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 3,
      );

      final pages = [
        DocumentPage(
          id: 'p1',
          documentId: doc.id,
          pageOrder: 0,
          originalPath: page1File.path,
          editRecipe: const EditRecipe(filter: PageFilter.blackAndWhite),
        ),
        DocumentPage(
          id: 'p2',
          documentId: doc.id,
          pageOrder: 1,
          originalPath: page2File.path,
          editRecipe: const EditRecipe(
            rotationDegrees: 90,
            filter: PageFilter.grayscale,
          ),
        ),
        DocumentPage(
          id: 'p3',
          documentId: doc.id,
          pageOrder: 2,
          originalPath: page3File.path,
          editRecipe: const EditRecipe(brightness: 0.1, contrast: 1.2),
        ),
      ];

      // Generate PDF
      final generatedFile = await PdfService.generatePdf(
        document: doc,
        pages: pages,
        customTitle: 'Test Invoice Scan',
      );

      expect(await generatedFile.exists(), isTrue);
      final fileBytes = await generatedFile.readAsBytes();
      // Validate PDF magic header '%PDF-'
      expect(fileBytes.length, greaterThan(1000));
      final header = String.fromCharCodes(fileBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test(
      'Generates Searchable PDF embedding invisible selectable OCR text layer',
      () async {
        final originalsDir = AppStorageService.instance.originalsDir;
        final pageFile = File('${originalsDir.path}/searchable_test.jpg');

        final image = img.Image(width: 600, height: 800);
        img.fill(image, color: img.ColorRgb8(255, 255, 255));
        img.drawString(
          image,
          'INVOICE #98765',
          font: img.arial24,
          x: 50,
          y: 50,
        );
        await pageFile.writeAsBytes(img.encodeJpg(image));

        final doc = ScannedDocument(
          id: 'searchable-doc-1',
          title: 'Searchable Invoice',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 1,
        );

        final pages = [
          DocumentPage(
            id: 'p1',
            documentId: doc.id,
            pageOrder: 0,
            originalPath: pageFile.path,
          ),
        ];

        final ocrBoxes = {
          0: [
            const OcrBoundingBox(
              text: 'INVOICE #98765',
              left: 50,
              top: 50,
              width: 250,
              height: 30,
            ),
          ],
        };

        final pdfFile = await PdfService.generatePdf(
          document: doc,
          pages: pages,
          customTitle: 'Searchable Invoice',
          ocrBoxesByPage: ocrBoxes,
        );

        expect(await pdfFile.exists(), isTrue);
        final pdfBytes = await pdfFile.readAsBytes();

        // Extract text from the generated PDF using Syncfusion to verify it is searchable
        final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
        try {
          final extractor = sf.PdfTextExtractor(sfDoc);
          final extractedText = extractor.extractText();
          expect(extractedText, contains('INVOICE'));
          expect(extractedText, contains('98765'));
        } finally {
          sfDoc.dispose();
        }
      },
    );

    test('stitchIdCard2In1 composites front and back card images into a single A4 layout', () async {
      final originalsDir = AppStorageService.instance.originalsDir;
      final frontFile = File('${originalsDir.path}/card_front.jpg');
      final backFile = File('${originalsDir.path}/card_back.jpg');

      final frontImg = img.Image(width: 800, height: 500);
      img.fill(frontImg, color: img.ColorRgb8(220, 240, 255));
      img.drawString(
        frontImg,
        'NATIONAL ID - FRONT',
        font: img.arial24,
        x: 20,
        y: 20,
      );
      await frontFile.writeAsBytes(img.encodeJpg(frontImg));

      final backImg = img.Image(width: 800, height: 500);
      img.fill(backImg, color: img.ColorRgb8(255, 240, 220));
      img.drawString(
        backImg,
        'NATIONAL ID - BACK',
        font: img.arial24,
        x: 20,
        y: 20,
      );
      await backFile.writeAsBytes(img.encodeJpg(backImg));

      final stitched = await PdfService.stitchIdCard2In1(
        frontImage: frontFile,
        backImage: backFile,
        baseTitle: 'National_ID_JohnDoe',
      );

      expect(await stitched.exists(), isTrue);
      final decoded = img.decodeImage(await stitched.readAsBytes());
      expect(decoded, isNotNull);
      // Dimensions should match standard A4 200 DPI canvas
      expect(decoded!.width, equals(1654));
      expect(decoded.height, equals(2338));
    });
  });
}

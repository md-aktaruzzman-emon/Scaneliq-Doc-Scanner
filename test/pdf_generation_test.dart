import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate multi-page PDF from synthetic test images with filter and rotation', () async {
    // 1. Create temporary directory for testing
    final tempDir = Directory.systemTemp.createTempSync('scaneliq_test_');

    // Initialize storage with temp directory
    await AppStorageService.instance.init(tempDir);
    final originalsDir = AppStorageService.instance.originalsDir;
    final page1File = File('${originalsDir.path}/page_1.jpg');
    final page2File = File('${originalsDir.path}/page_2.jpg');

    // Create 2 test bitmap images
    final image1 = img.Image(width: 400, height: 600);
    img.fill(image1, color: img.ColorRgb8(255, 255, 255));
    img.drawString(image1, 'Scaneliq Page 1', font: img.arial24, x: 50, y: 50, color: img.ColorRgb8(0, 0, 0));
    await page1File.writeAsBytes(img.encodeJpg(image1));

    final image2 = img.Image(width: 400, height: 600);
    img.fill(image2, color: img.ColorRgb8(240, 240, 240));
    img.drawString(image2, 'Scaneliq Page 2', font: img.arial24, x: 50, y: 50, color: img.ColorRgb8(0, 0, 0));
    await page2File.writeAsBytes(img.encodeJpg(image2));

    final doc = ScannedDocument(
      id: 'test-doc-id-123',
      title: 'Test Invoice Scan',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      pageCount: 2,
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
        editRecipe: const EditRecipe(rotationDegrees: 90, filter: PageFilter.grayscale),
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
    expect(fileBytes.length, greaterThan(500));
    final header = String.fromCharCodes(fileBytes.sublist(0, 5));
    expect(header, equals('%PDF-'));

    // Clean up
    tempDir.deleteSync(recursive: true);
  });
}

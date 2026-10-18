import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditRecipe & Image Processing Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_edit_test_');
      await AppStorageService.instance.init(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('applyEditRecipe rotates image correctly', () {
      final source = img.Image(width: 200, height: 100);
      img.fill(source, color: img.ColorRgb8(100, 150, 200));

      const recipe = EditRecipe(rotationDegrees: 90);
      final result = PdfService.applyEditRecipe(source, recipe);

      expect(result.width, equals(100));
      expect(result.height, equals(200));
    });

    test('applyEditRecipe applies grayscale and brightness/contrast adjustments', () {
      final source = img.Image(width: 100, height: 100);
      // Fill with colorful pixel
      img.fill(source, color: img.ColorRgb8(200, 50, 50));

      const recipe = EditRecipe(
        filter: PageFilter.grayscale,
        brightness: 0.1,
        contrast: 1.2,
      );
      final result = PdfService.applyEditRecipe(source, recipe);

      expect(result.width, equals(100));
      expect(result.height, equals(100));
      // In grayscale, red, green, and blue channels of any pixel must be identical
      final pixel = result.getPixel(10, 10);
      expect(pixel.r, equals(pixel.g));
      expect(pixel.g, equals(pixel.b));
    });

    test('exportPageAsJpeg produces valid JPEG with correct SOI header', () async {
      final source = img.Image(width: 300, height: 400);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));
      img.drawString(source, 'Export Sample', font: img.arial24, x: 20, y: 20, color: img.ColorRgb8(0, 0, 0));

      final testFile = File('${AppStorageService.instance.originalsDir.path}/sample_page.jpg');
      await testFile.writeAsBytes(img.encodeJpg(source));

      final page = DocumentPage(
        id: 'export_p1',
        documentId: 'doc_exp',
        pageOrder: 0,
        originalPath: testFile.path,
        editRecipe: const EditRecipe(rotationDegrees: 0, filter: PageFilter.original),
      );

      final exportedFile = await PdfService.exportPageAsJpeg(page: page, baseName: 'Receipt_Page');
      expect(await exportedFile.exists(), isTrue);

      final bytes = await exportedFile.readAsBytes();
      // JPEG standard magic bytes: 0xFF, 0xD8, 0xFF
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], equals(0xFF));
      expect(bytes[1], equals(0xD8));
      expect(bytes[2], equals(0xFF));
    });
  });
}

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_img_proc_test_');
    await AppStorageService.instance.init(tempDir);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('PerspectiveQuad & Homography Tests', () {
    test(
      'PerspectiveQuad detects convex and degenerate quadrilaterals correctly',
      () {
        const validQuad = PerspectiveQuad(
          x1: 0.1,
          y1: 0.1,
          x2: 0.9,
          y2: 0.1,
          x3: 0.9,
          y3: 0.9,
          x4: 0.1,
          y4: 0.9,
        );
        expect(validQuad.isValidConvex(), isTrue);
        expect(validQuad.isStandard, isFalse);

        const standardQuad = PerspectiveQuad.standard;
        expect(standardQuad.isStandard, isTrue);
        expect(standardQuad.isValidConvex(), isTrue);

        // Self-intersecting / Bowtie quad
        const bowtieQuad = PerspectiveQuad(
          x1: 0.1,
          y1: 0.1,
          x2: 0.9,
          y2: 0.9, // Crossed
          x3: 0.9,
          y3: 0.1,
          x4: 0.1,
          y4: 0.9,
        );
        expect(bowtieQuad.isValidConvex(), isFalse);

        // Out of bounds coordinate
        const outOfBoundsQuad = PerspectiveQuad(
          x1: -0.2,
          y1: 0.1,
          x2: 0.9,
          y2: 0.1,
          x3: 0.9,
          y3: 0.9,
          x4: 0.1,
          y4: 0.9,
        );
        expect(outOfBoundsQuad.isValidConvex(), isFalse);
      },
    );

    test('PerspectiveQuad serializes and deserializes accurately', () {
      const quad = PerspectiveQuad(
        x1: 0.12,
        y1: 0.15,
        x2: 0.88,
        y2: 0.14,
        x3: 0.85,
        y3: 0.92,
        x4: 0.10,
        y4: 0.90,
      );
      final map = quad.toMap();
      final restored = PerspectiveQuad.fromMap(map);

      expect(restored.x1, closeTo(0.12, 1e-5));
      expect(restored.y1, closeTo(0.15, 1e-5));
      expect(restored.x2, closeTo(0.88, 1e-5));
      expect(restored.y2, closeTo(0.14, 1e-5));
      expect(restored.x3, closeTo(0.85, 1e-5));
      expect(restored.y3, closeTo(0.92, 1e-5));
      expect(restored.x4, closeTo(0.10, 1e-5));
      expect(restored.y4, closeTo(0.90, 1e-5));
    });

    test('warpPerspective rectifies skewed quadrilateral into clean rectangular output', () {
      final source = img.Image(width: 400, height: 400);
      img.fill(source, color: img.ColorRgb8(240, 240, 240));

      // Draw distinctive colored rectangle in center (x: 100..300, y: 100..300)
      for (int y = 100; y < 300; y++) {
        for (int x = 100; x < 300; x++) {
          source.setPixelRgb(x, y, 20, 40, 200); // Blue card
        }
      }

      // Quad covering the blue card (normalized 0.25 to 0.75)
      const quad = PerspectiveQuad(
        x1: 0.25,
        y1: 0.25,
        x2: 0.75,
        y2: 0.25,
        x3: 0.75,
        y3: 0.75,
        x4: 0.25,
        y4: 0.75,
      );

      final warped = ImageProcessingService.warpPerspective(source, quad);

      expect(warped.width, greaterThan(180));
      expect(warped.height, greaterThan(180));

      // Center of warped image must be the blue card color
      final centerP = warped.getPixel(warped.width ~/ 2, warped.height ~/ 2);
      expect(centerP.b, greaterThan(180));
      expect(centerP.r, lessThan(50));
    });

    test('warpPerspective safely handles degenerate quad without throwing', () {
      final source = img.Image(width: 100, height: 100);
      img.fill(source, color: img.ColorRgb8(128, 128, 128));

      const degenerateQuad = PerspectiveQuad(
        x1: 0.5,
        y1: 0.5,
        x2: 0.5,
        y2: 0.5,
        x3: 0.5,
        y3: 0.5,
        x4: 0.5,
        y4: 0.5,
      );

      final result = ImageProcessingService.warpPerspective(
        source,
        degenerateQuad,
      );
      expect(result.width, equals(100));
      expect(result.height, equals(100));
    });
  });

  group('Otsu Binarization Tests', () {
    test(
      'computeOtsuThreshold computes optimal threshold on bimodal distribution',
      () {
        final source = img.Image(width: 100, height: 100);
        // Half dark text (val 30), half light paper (val 230)
        for (int y = 0; y < 100; y++) {
          for (int x = 0; x < 100; x++) {
            final val = x < 50 ? 30 : 230;
            source.setPixelRgb(x, y, val, val, val);
          }
        }

        final threshold = ImageProcessingService.computeOtsuThreshold(source);
        // Optimal threshold separating 30 and 230 should be around ~128
        expect(threshold, greaterThanOrEqualTo(80));
        expect(threshold, lessThanOrEqualTo(180));

        final binarized = ImageProcessingService.applyOtsuBinarization(source);
        final darkPixel = binarized.getPixel(10, 50);
        final lightPixel = binarized.getPixel(80, 50);

        expect(darkPixel.r, equals(0));
        expect(darkPixel.g, equals(0));
        expect(darkPixel.b, equals(0));

        expect(lightPixel.r, equals(255));
        expect(lightPixel.g, equals(255));
        expect(lightPixel.b, equals(255));
      },
    );
  });

  group('Sauvola Adaptive Binarization Tests', () {
    test('applySauvolaBinarization segments text across uneven gradient background', () {
      final source = img.Image(width: 200, height: 100);

      // Create uneven gradient background: 240 on left, 90 on right
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 200; x++) {
          final bg = (240 - (x / 200.0) * 150).round();
          source.setPixelRgb(x, y, bg, bg, bg);
        }
      }

      // Add dark text strokes on both bright side (x=20) and dark side (x=180)
      for (int y = 40; y < 60; y++) {
        source.setPixelRgb(20, y, 15, 15, 15);
        source.setPixelRgb(180, y, 15, 15, 15);
      }

      final sauvola = ImageProcessingService.applySauvolaBinarization(
        source,
        k: 0.2,
        windowRadius: 15,
      );

      expect(sauvola.width, equals(200));
      expect(sauvola.height, equals(100));

      // Text pixel on bright side (x=20, y=50) should be segmented as black (0)
      final brightSideText = sauvola.getPixel(20, 50);
      expect(brightSideText.r, equals(0));

      // Text pixel on dark shadow side (x=180, y=50) should ALSO be segmented as black (0)
      final darkSideText = sauvola.getPixel(180, 50);
      expect(darkSideText.r, equals(0));

      // Background near the text on bright side (x=30, y=50) should be white (255)
      final brightBg = sauvola.getPixel(30, 50);
      expect(brightBg.r, equals(255));
    });
  });

  group('Shadow Correction & Document Color Tests', () {
    test(
      'applyShadowCorrection equalizes dark shadow gradient across paper',
      () {
        final source = img.Image(width: 100, height: 100);

        // Dark shadow gradient across y (top: 240, bottom: 80)
        for (int y = 0; y < 100; y++) {
          for (int x = 0; x < 100; x++) {
            final val = (240 - (y / 100.0) * 160).round();
            source.setPixelRgb(x, y, val, val, val);
          }
        }

        final corrected = ImageProcessingService.applyShadowCorrection(source);
        final topP = corrected.getPixel(50, 5);
        final bottomP = corrected.getPixel(50, 95);

        // Both top and bottom paper brightness should be boosted toward white (>= 200)
        expect(topP.r, greaterThanOrEqualTo(200));
        expect(bottomP.r, greaterThanOrEqualTo(190));
      },
    );

    test('applyWhiteboard whitens background while keeping colored markers saturated', () {
      final source = img.Image(width: 100, height: 100);
      // Off-white whiteboard background (210, 210, 210)
      img.fill(source, color: img.ColorRgb8(210, 210, 210));

      // Draw red marker text in center
      for (int y = 40; y < 60; y++) {
        for (int x = 40; x < 60; x++) {
          source.setPixelRgb(x, y, 220, 20, 20); // Vivid Red
        }
      }

      final wb = ImageProcessingService.applyWhiteboard(source);

      // Background should be whitened to pure white (255)
      final bg = wb.getPixel(10, 10);
      expect(bg.r, equals(255));
      expect(bg.g, equals(255));
      expect(bg.b, equals(255));

      // Red marker stroke should remain saturated red (R much higher than G/B)
      final marker = wb.getPixel(50, 50);
      expect(marker.r, greaterThan(150));
      expect(marker.g, lessThan(80));
    });
  });

  group('Manual Cleanup Patches Tests', () {
    test('applyCleanupPatches in-paints dark hole-punch with surrounding paper color', () {
      final source = img.Image(width: 100, height: 100);
      // Clean white paper background
      img.fill(source, color: img.ColorRgb8(245, 245, 245));

      // Simulate black hole punch at center (x: 50, y: 50) with radius 6
      for (int y = 44; y <= 56; y++) {
        for (int x = 44; x <= 56; x++) {
          final dist = math.sqrt(math.pow(x - 50, 2) + math.pow(y - 50, 2));
          if (dist <= 6) {
            source.setPixelRgb(x, y, 10, 10, 10); // Dark hole punch
          }
        }
      }

      const patch = CleanupPatch(
        x: 0.5,
        y: 0.5,
        radius: 0.08,
        type: 'holePunch',
      );
      final cleaned = ImageProcessingService.applyCleanupPatches(source, [
        patch,
      ]);

      // Original source must remain untouched (non-destructive)
      final rawCenter = source.getPixel(50, 50);
      expect(rawCenter.r, equals(10));

      // Cleaned center should be inpainted with surrounding paper color (>= 220)
      final cleanedCenter = cleaned.getPixel(50, 50);
      expect(cleanedCenter.r, greaterThanOrEqualTo(220));
      expect(cleanedCenter.g, greaterThanOrEqualTo(220));
      expect(cleanedCenter.b, greaterThanOrEqualTo(220));
    });
  });

  group('EditRecipe Serialization & Backward Compatibility Tests', () {
    test('Legacy v1 recipe map without Phase 3 keys deserializes with safe defaults', () {
      final legacyMap = {
        'rotationDegrees': 90,
        'filter': 'grayscale',
        'brightness': 0.1,
        'contrast': 1.2,
        'cropLeft': 0.05,
        'cropTop': 0.05,
        'cropRight': 0.95,
        'cropBottom': 0.95,
      };

      final recipe = EditRecipe.fromMap(legacyMap);

      expect(recipe.rotationDegrees, equals(90));
      expect(recipe.filter, equals(PageFilter.grayscale));
      expect(recipe.recipeVersion, equals(1));
      expect(recipe.perspectiveQuad, isNull);
      expect(recipe.hasPerspective, isFalse);
      expect(recipe.binarization, equals(BinarizationMode.none));
      expect(recipe.shadowCorrection, isFalse);
      expect(recipe.cleanupPatches, isEmpty);
      expect(recipe.hasCleanup, isFalse);
    });

    test('Full v2 recipe with perspective quad, sauvola, and cleanup patches round-trips correctly', () {
      const fullRecipe = EditRecipe(
        rotationDegrees: 180,
        filter: PageFilter.colorBoost,
        brightness: 0.05,
        contrast: 1.1,
        cropLeft: 0.02,
        cropTop: 0.02,
        cropRight: 0.98,
        cropBottom: 0.98,
        perspectiveQuad: PerspectiveQuad(
          x1: 0.1,
          y1: 0.1,
          x2: 0.9,
          y2: 0.1,
          x3: 0.85,
          y3: 0.85,
          x4: 0.15,
          y4: 0.85,
        ),
        binarization: BinarizationMode.sauvola,
        shadowCorrection: true,
        cleanupPatches: [
          CleanupPatch(x: 0.2, y: 0.2, radius: 0.04, type: 'holePunch'),
          CleanupPatch(x: 0.8, y: 0.8, radius: 0.07, type: 'finger'),
        ],
        recipeVersion: 2,
      );

      final map = fullRecipe.toMap();
      final restored = EditRecipe.fromMap(map);

      expect(restored.rotationDegrees, equals(180));
      expect(restored.filter, equals(PageFilter.colorBoost));
      expect(restored.recipeVersion, equals(2));
      expect(restored.hasPerspective, isTrue);
      expect(restored.perspectiveQuad!.x1, closeTo(0.1, 1e-4));
      expect(restored.binarization, equals(BinarizationMode.sauvola));
      expect(restored.shadowCorrection, isTrue);
      expect(restored.cleanupPatches.length, equals(2));
      expect(restored.cleanupPatches.first.type, equals('holePunch'));
      expect(restored.cleanupPatches.last.type, equals('finger'));
    });
  });

  group('PDF & JPEG Export Parity Tests', () {
    test(
      'PdfService.exportPageAsJpeg applies full Phase 3 recipe cleanly',
      () async {
        // 1. Create source test page file
        final srcImage = img.Image(width: 200, height: 200);
        img.fill(srcImage, color: img.ColorRgb8(240, 240, 240));
        for (int y = 50; y < 150; y++) {
          for (int x = 50; x < 150; x++) {
            srcImage.setPixelRgb(x, y, 20, 20, 20); // Dark text box
          }
        }

        final rawFile = File('${tempDir.path}/test_source.jpg');
        await rawFile.writeAsBytes(img.encodeJpg(srcImage, quality: 90));

        final testPage = DocumentPage(
          id: 'test_p1',
          documentId: 'doc_1',
          pageOrder: 0,
          originalPath: rawFile.path,
          editRecipe: const EditRecipe(
            binarization: BinarizationMode.otsu,
            shadowCorrection: true,
            cleanupPatches: [
              CleanupPatch(x: 0.5, y: 0.5, radius: 0.05, type: 'holePunch'),
            ],
          ),
        );

        final exportedJpeg = await PdfService.exportPageAsJpeg(
          page: testPage,
          baseName: 'ExportParityTest',
        );

        expect(await exportedJpeg.exists(), isTrue);
        final exportedBytes = await exportedJpeg.readAsBytes();
        expect(AppStorageService.isValidImageBytes(exportedBytes), isTrue);

        // Verify JPEG SOI marker (0xFF, 0xD8, 0xFF)
        expect(exportedBytes[0], equals(0xFF));
        expect(exportedBytes[1], equals(0xD8));
        expect(exportedBytes[2], equals(0xFF));
      },
    );

    test(
      'PdfService.generatePdf applies EditRecipe via ImageProcessingService',
      () async {
        final srcImage = img.Image(width: 200, height: 200);
        img.fill(srcImage, color: img.ColorRgb8(240, 240, 240));

        final rawFile = File('${tempDir.path}/pdf_page1.jpg');
        await rawFile.writeAsBytes(img.encodeJpg(srcImage, quality: 90));

        final doc = ScannedDocument(
          id: 'doc_pdf_test',
          title: 'Phase3PdfTest',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 1,
        );

        final page = DocumentPage(
          id: 'p1',
          documentId: doc.id,
          pageOrder: 0,
          originalPath: rawFile.path,
          editRecipe: const EditRecipe(
            filter: PageFilter.colorBoost,
            binarization: BinarizationMode.sauvola,
          ),
        );

        final pdfFile = await PdfService.generatePdf(
          document: doc,
          pages: [page],
        );

        expect(await pdfFile.exists(), isTrue);
        final pdfBytes = await pdfFile.readAsBytes();
        expect(pdfBytes.length, greaterThan(100));

        // Standard %PDF- magic header check
        final header = String.fromCharCodes(pdfBytes.take(5));
        expect(header, equals('%PDF-'));
      },
    );
  });
}

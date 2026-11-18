import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';

void main() {
  group('CamScanner Architecture & Feature Upgrades Tests', () {
    test('Magic Color Filter: Whitens paper background while preserving colored ink vibrancy', () {
      // Create a test image with white/gray background, dark text, and blue signature
      final bitmap = img.Image(width: 100, height: 100);
      img.fill(bitmap, color: img.ColorRgb8(190, 190, 190)); // grayish paper

      // Add dark text in [10, 10, 20, 20]
      for (int y = 10; y < 30; y++) {
        for (int x = 10; x < 30; x++) {
          bitmap.setPixelRgb(x, y, 40, 40, 40);
        }
      }

      // Add blue signature stamp in [50, 50, 20, 20]
      for (int y = 50; y < 70; y++) {
        for (int x = 50; x < 70; x++) {
          bitmap.setPixelRgb(x, y, 20, 50, 220); // Blue ink
        }
      }

      final recipe = const EditRecipe(filter: PageFilter.magicColor);
      final enhanced = ImageProcessingService.applyEditRecipe(bitmap, recipe);

      // 1. Paper background should be whitened significantly (> 240)
      final bgPixel = enhanced.getPixel(2, 2);
      expect(bgPixel.r, greaterThan(235));
      expect(bgPixel.g, greaterThan(235));
      expect(bgPixel.b, greaterThan(235));

      // 2. Dark text should remain dark / high-contrast (< 60)
      final textPixel = enhanced.getPixel(15, 15);
      expect(textPixel.r, lessThan(60));
      expect(textPixel.g, lessThan(60));

      // 3. Blue signature ink should retain high blue dominance (blue channel >> red channel)
      final bluePixel = enhanced.getPixel(55, 55);
      expect(bluePixel.b, greaterThan(bluePixel.r + 50));
    });

    test('Mosaic Redaction: Irreversibly pixelates sensitive regions into averaged tiles', () {
      final bitmap = img.Image(width: 80, height: 80);
      img.fill(bitmap, color: img.ColorRgb8(255, 255, 255));

      // Draw high-frequency alternating pattern inside region [20, 20, 40, 40]
      for (int y = 20; y < 60; y++) {
        for (int x = 20; x < 60; x++) {
          if ((x + y) % 2 == 0) {
            bitmap.setPixelRgb(x, y, 255, 0, 0); // Red
          } else {
            bitmap.setPixelRgb(x, y, 0, 0, 255); // Blue
          }
        }
      }

      final mosaiced = ImageProcessingService.permanentlyMosaicImage(
        src: bitmap,
        normX: 0.25, // 20 / 80
        normY: 0.25,
        normW: 0.5, // 40 / 80
        normH: 0.5,
        blockSize: 10,
      );

      // Verify that individual pixels inside a block have been averaged into uniform solid tiles
      final p1 = mosaiced.getPixel(22, 22);
      final p2 = mosaiced.getPixel(23, 23);
      expect(p1.r, equals(p2.r));
      expect(p1.g, equals(p2.g));
      expect(p1.b, equals(p2.b));

      // Outside pixel remains untouched (white)
      final outside = mosaiced.getPixel(5, 5);
      expect(outside.r, equals(255));
      expect(outside.g, equals(255));
      expect(outside.b, equals(255));
    });

    test('Long Image Stitching: Combines multiple page images vertically with spacing', () {
      final img1 = img.Image(width: 100, height: 150);
      img.fill(img1, color: img.ColorRgb8(255, 0, 0)); // Red page 1

      final img2 = img.Image(width: 120, height: 180);
      img.fill(img2, color: img.ColorRgb8(0, 255, 0)); // Green page 2

      final img3 = img.Image(width: 90, height: 120);
      img.fill(img3, color: img.ColorRgb8(0, 0, 255)); // Blue page 3

      const spacing = 10;
      final stitched = ImageProcessingService.stitchImagesVertically(
        [img1, img2, img3],
        spacing: spacing,
      );

      // Max width should be 120 (max of 100, 120, 90)
      expect(stitched.width, equals(120));

      // Total height should be 150 + 10 + 180 + 10 + 120 = 470
      expect(stitched.height, equals(150 + 10 + 180 + 10 + 120));
    });
  });
}

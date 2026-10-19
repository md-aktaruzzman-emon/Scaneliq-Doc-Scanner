import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';

/// Unified image processing engine for Scaneliq.
/// Provides genuine 4-point perspective homography warp, Otsu & Sauvola binarization,
/// shadow removal, document color boost, and non-destructive manual cleanup.
class ImageProcessingService {
  /// Master entry point to apply an EditRecipe to an img.Image in strict pipeline order
  static img.Image applyEditRecipe(img.Image source, EditRecipe recipe) {
    img.Image working = source;

    // 1. Perspective homography correction (if non-standard convex quad is specified)
    if (recipe.hasPerspective) {
      working = warpPerspective(working, recipe.perspectiveQuad!);
    }

    // 2. Non-destructive axis-aligned crop (applied if customized)
    if (recipe.hasCrop) {
      final x = (recipe.cropLeft * working.width).round().clamp(
        0,
        working.width - 1,
      );
      final y = (recipe.cropTop * working.height).round().clamp(
        0,
        working.height - 1,
      );
      final w = ((recipe.cropRight - recipe.cropLeft) * working.width)
          .round()
          .clamp(10, working.width - x);
      final h = ((recipe.cropBottom - recipe.cropTop) * working.height)
          .round()
          .clamp(10, working.height - y);
      working = img.copyCrop(working, x: x, y: y, width: w, height: h);
    }

    // 3. Rotation
    if (recipe.rotationDegrees != 0) {
      working = img.copyRotate(working, angle: recipe.rotationDegrees);
    }

    // 4. Background and shadow illumination correction
    if (recipe.shadowCorrection) {
      working = applyShadowCorrection(working);
    }

    // 5. Filter / Color Enhancement
    switch (recipe.filter) {
      case PageFilter.grayscale:
        working = img.grayscale(working);
        break;
      case PageFilter.blackAndWhite:
        // Default high-contrast document mode
        working = applyOtsuBinarization(working);
        break;
      case PageFilter.whiteboard:
        working = applyWhiteboard(working);
        break;
      case PageFilter.enhancedText:
        working = applyEnhancedText(working);
        break;
      case PageFilter.colorBoost:
        working = applyColorBoost(working);
        break;
      case PageFilter.original:
        break;
    }

    // 6. Explicit Binarization mode (Otsu or Sauvola adaptive threshold)
    if (recipe.binarization == BinarizationMode.otsu) {
      working = applyOtsuBinarization(working);
    } else if (recipe.binarization == BinarizationMode.sauvola) {
      working = applySauvolaBinarization(working);
    }

    // 7. Manual cleanup patches (hole punches, finger artifacts)
    if (recipe.hasCleanup) {
      working = applyCleanupPatches(working, recipe.cleanupPatches);
    }

    // 8. Brightness and contrast fine-tuning
    if (recipe.contrast != 1.0 || recipe.brightness != 0.0) {
      working = img.adjustColor(
        working,
        brightness: 1.0 + recipe.brightness,
        contrast: recipe.contrast,
      );
    }

    return working;
  }

  // ===========================================================================
  // 1. GENUINE 4-POINT PERSPECTIVE TRANSFORMATION (HOMOGRAPHY WARP)
  // ===========================================================================

  /// Warps an arbitrary convex 4-point quadrilateral into a rectified rectangular image
  /// using inverse projective mapping with bilinear interpolation.
  static img.Image warpPerspective(img.Image src, PerspectiveQuad quad) {
    if (!quad.isValidConvex() || quad.isStandard) {
      return src;
    }

    final double sw = src.width.toDouble();
    final double sh = src.height.toDouble();

    // Corner points in source pixel coordinates
    // P0: Top-Left, P1: Top-Right, P2: Bottom-Right, P3: Bottom-Left
    final double x0 = quad.x1 * sw;
    final double y0 = quad.y1 * sh;
    final double x1 = quad.x2 * sw;
    final double y1 = quad.y2 * sh;
    final double x2 = quad.x3 * sw;
    final double y2 = quad.y3 * sh;
    final double x3 = quad.x4 * sw;
    final double y3 = quad.y4 * sh;

    // Calculate rectified destination dimensions from edge lengths
    final double wTop = math.sqrt(math.pow(x1 - x0, 2) + math.pow(y1 - y0, 2));
    final double wBottom = math.sqrt(
      math.pow(x2 - x3, 2) + math.pow(y2 - y3, 2),
    );
    final double hLeft = math.sqrt(math.pow(x3 - x0, 2) + math.pow(y3 - y0, 2));
    final double hRight = math.sqrt(
      math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2),
    );

    final int dstW = math.max(20, math.max(wTop, wBottom).round());
    final int dstH = math.max(20, math.max(hLeft, hRight).round());

    // Compute coefficients for mapping normalized unit square [0,1]^2 to quad (x0..x3, y0..y3)
    // Reference: Paul Heckbert (1989), "Fundamentals of Texture Mapping and Image Warping"
    final double dx1 = x1 - x2;
    final double dx2 = x3 - x2;
    final double dx3 = x0 - x1 + x2 - x3;
    final double dy1 = y1 - y2;
    final double dy2 = y3 - y2;
    final double dy3 = y0 - y1 + y2 - y3;

    double a, b, c, d, e, f, g, h;

    if (dx3.abs() < 1e-7 && dy3.abs() < 1e-7) {
      // Affine mapping (parallelogram)
      a = x1 - x0;
      b = x2 - x1;
      c = x0;
      d = y1 - y0;
      e = y2 - y1;
      f = y0;
      g = 0.0;
      h = 0.0;
    } else {
      // General projective mapping
      final double det = dx1 * dy2 - dx2 * dy1;
      if (det.abs() < 1e-9) {
        return src; // Degenerate quadrilateral
      }
      g = (dx3 * dy2 - dx2 * dy3) / det;
      h = (dx1 * dy3 - dx3 * dy1) / det;
      a = x1 - x0 + g * x1;
      b = x3 - x0 + h * x3;
      c = x0;
      d = y1 - y0 + g * y1;
      e = y3 - y0 + h * y3;
      f = y0;
    }

    final img.Image dst = img.Image(width: dstW, height: dstH);

    final double normW = (dstW > 1) ? (dstW - 1).toDouble() : 1.0;
    final double normH = (dstH > 1) ? (dstH - 1).toDouble() : 1.0;

    for (int y = 0; y < dstH; y++) {
      final double v = y / normH;
      for (int x = 0; x < dstW; x++) {
        final double u = x / normW;

        final double den = g * u + h * v + 1.0;
        if (den.abs() < 1e-9) continue;

        final double sx = (a * u + b * v + c) / den;
        final double sy = (d * u + e * v + f) / den;

        // Bilinear interpolation in source image
        final pixel = _sampleBilinear(src, sx, sy);
        dst.setPixel(x, y, pixel);
      }
    }

    return dst;
  }

  /// Bilinear sampling helper for fractional pixel coordinates
  static img.Pixel _sampleBilinear(img.Image src, double sx, double sy) {
    final int w = src.width;
    final int h = src.height;

    final double clampedX = sx.clamp(0.0, (w - 1).toDouble());
    final double clampedY = sy.clamp(0.0, (h - 1).toDouble());

    final int x0 = clampedX.floor();
    final int y0 = clampedY.floor();
    final int x1 = math.min(w - 1, x0 + 1);
    final int y1 = math.min(h - 1, y0 + 1);

    final double fx = clampedX - x0;
    final double fy = clampedY - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final double r0 = p00.r * (1.0 - fx) + p10.r * fx;
    final double r1 = p01.r * (1.0 - fx) + p11.r * fx;
    final int r = (r0 * (1.0 - fy) + r1 * fy).round().clamp(0, 255);

    final double g0 = p00.g * (1.0 - fx) + p10.g * fx;
    final double g1 = p01.g * (1.0 - fx) + p11.g * fx;
    final int g = (g0 * (1.0 - fy) + g1 * fy).round().clamp(0, 255);

    final double b0 = p00.b * (1.0 - fx) + p10.b * fx;
    final double b1 = p01.b * (1.0 - fx) + p11.b * fx;
    final int b = (b0 * (1.0 - fy) + b1 * fy).round().clamp(0, 255);

    final double a0 = p00.a * (1.0 - fx) + p10.a * fx;
    final double a1 = p01.a * (1.0 - fx) + p11.a * fx;
    final int a = (a0 * (1.0 - fy) + a1 * fy).round().clamp(0, 255);

    final temp = img.Image(width: 1, height: 1);
    temp.setPixelRgba(0, 0, r, g, b, a);
    return temp.getPixel(0, 0);
  }

  // ===========================================================================
  // 2. GENUINE OTSU BINARIZATION
  // ===========================================================================

  /// Computes the optimal global binarization threshold using Otsu's variance maximization
  static int computeOtsuThreshold(img.Image src) {
    final hist = List<int>.filled(256, 0);
    final int total = src.width * src.height;

    for (final pixel in src) {
      final int gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round()
          .clamp(0, 255);
      hist[gray]++;
    }

    double sumAll = 0.0;
    for (int i = 0; i < 256; i++) {
      sumAll += i * hist[i];
    }

    double sumB = 0.0;
    int wB = 0;
    double varMax = 0.0;
    int tMin = 128;
    int tMax = 128;

    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final int wF = total - wB;
      if (wF == 0) break;

      sumB += t * hist[t];
      final double mB = sumB / wB;
      final double mF = (sumAll - sumB) / wF;

      final double varBetween =
          wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
      if (varBetween > varMax) {
        varMax = varBetween;
        tMin = t;
        tMax = t;
      } else if (varMax > 0 && (varBetween - varMax).abs() < 1e-4) {
        tMax = t;
      }
    }

    return ((tMin + tMax) / 2.0).round();
  }

  /// Converts image to black and white using genuine Otsu thresholding
  static img.Image applyOtsuBinarization(img.Image src) {
    final int threshold = computeOtsuThreshold(src);
    final dst = img.Image(width: src.width, height: src.height);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final int gray = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
        if (gray >= threshold) {
          dst.setPixelRgb(x, y, 255, 255, 255);
        } else {
          dst.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }
    return dst;
  }

  // ===========================================================================
  // 3. GENUINE SAUVOLA ADAPTIVE BINARIZATION
  // ===========================================================================

  /// Implements fast Sauvola adaptive thresholding:
  /// T(x,y) = m(x,y) * (1 + k * (s(x,y)/128 - 1))
  /// using Integral Images for O(1) local mean and standard deviation.
  static img.Image applySauvolaBinarization(
    img.Image src, {
    double k = 0.2,
    int? windowRadius,
  }) {
    final int w = src.width;
    final int h = src.height;
    final int r = windowRadius ?? math.max(15, math.min(35, w ~/ 40));

    // 1. Build grayscale array
    final Uint8List gray = Uint8List(w * h);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        gray[idx++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(
          0,
          255,
        );
      }
    }

    // 2. Build Integral Image (sum) and Integral Image of Squares (Float64List to avoid overflow)
    final Float64List integralSum = Float64List((w + 1) * (h + 1));
    final Float64List integralSqSum = Float64List((w + 1) * (h + 1));

    for (int y = 0; y < h; y++) {
      double rowSum = 0.0;
      double rowSqSum = 0.0;
      for (int x = 0; x < w; x++) {
        final double g = gray[y * w + x].toDouble();
        rowSum += g;
        rowSqSum += g * g;

        final int tableIdx = (y + 1) * (w + 1) + (x + 1);
        final int aboveIdx = y * (w + 1) + (x + 1);

        integralSum[tableIdx] = integralSum[aboveIdx] + rowSum;
        integralSqSum[tableIdx] = integralSqSum[aboveIdx] + rowSqSum;
      }
    }

    final dst = img.Image(width: w, height: h);

    // 3. Compute local threshold per pixel in O(1)
    for (int y = 0; y < h; y++) {
      final int y1 = math.max(0, y - r);
      final int y2 = math.min(h - 1, y + r);

      for (int x = 0; x < w; x++) {
        final int x1 = math.max(0, x - r);
        final int x2 = math.min(w - 1, x + r);

        final double count = ((x2 - x1 + 1) * (y2 - y1 + 1)).toDouble();

        // 2D integral rectangle sum: D - B - C + A
        final int idxA = y1 * (w + 1) + x1;
        final int idxB = y1 * (w + 1) + (x2 + 1);
        final int idxC = (y2 + 1) * (w + 1) + x1;
        final int idxD = (y2 + 1) * (w + 1) + (x2 + 1);

        final double sum =
            integralSum[idxD] -
            integralSum[idxB] -
            integralSum[idxC] +
            integralSum[idxA];
        final double sqSum =
            integralSqSum[idxD] -
            integralSqSum[idxB] -
            integralSqSum[idxC] +
            integralSqSum[idxA];

        final double mean = sum / count;
        final double variance = math.max(0.0, (sqSum / count) - (mean * mean));
        final double stdDev = math.sqrt(variance);

        final double threshold = mean * (1.0 + k * ((stdDev / 128.0) - 1.0));

        final int g = gray[y * w + x];
        if (g >= threshold) {
          dst.setPixelRgb(x, y, 255, 255, 255);
        } else {
          dst.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    return dst;
  }

  // ===========================================================================
  // 4. SHADOW & BACKGROUND ILLUMINATION CORRECTION
  // ===========================================================================

  /// Estimates document background illumination gradient and equalizes paper brightness,
  /// eliminating phone and arm shadows across the document page.
  static img.Image applyShadowCorrection(img.Image src) {
    final int w = src.width;
    final int h = src.height;

    // 1. Create a downsampled background estimate grid (approx 48x48)
    const int gridDim = 48;
    final int gw = math.min(gridDim, w);
    final int gh = math.min(gridDim, h);
    final Float64List bgGrid = Float64List(gw * gh);

    final double stepX = w / gw;
    final double stepY = h / gh;

    for (int gy = 0; gy < gh; gy++) {
      final int startY = (gy * stepY).floor();
      final int endY = math.min(h, ((gy + 1) * stepY).ceil());

      for (int gx = 0; gx < gw; gx++) {
        final int startX = (gx * stepX).floor();
        final int endX = math.min(w, ((gx + 1) * stepX).ceil());

        // Find the 90th percentile luminance in the block to approximate paper color without dark text
        final List<int> blockGrays = [];
        for (int y = startY; y < endY; y += 2) {
          for (int x = startX; x < endX; x += 2) {
            final p = src.getPixel(x, y);
            final int gray = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
            blockGrays.add(gray);
          }
        }

        if (blockGrays.isEmpty) {
          bgGrid[gy * gw + gx] = 200.0;
        } else {
          blockGrays.sort();
          final int p90 =
              blockGrays[(blockGrays.length * 0.9).floor().clamp(
                0,
                blockGrays.length - 1,
              )];
          bgGrid[gy * gw + gx] = math.max(40.0, p90.toDouble());
        }
      }
    }

    final dst = img.Image(width: w, height: h);

    // 2. Correct each pixel by dividing by the locally interpolated background brightness
    const double targetWhite = 248.0;

    for (int y = 0; y < h; y++) {
      final double gy = (y / stepY).clamp(0.0, (gh - 1).toDouble());
      final int gy0 = gy.floor();
      final int gy1 = math.min(gh - 1, gy0 + 1);
      final double fy = gy - gy0;

      for (int x = 0; x < w; x++) {
        final double gx = (x / stepX).clamp(0.0, (gw - 1).toDouble());
        final int gx0 = gx.floor();
        final int gx1 = math.min(gw - 1, gx0 + 1);
        final double fx = gx - gx0;

        final double b00 = bgGrid[gy0 * gw + gx0];
        final double b10 = bgGrid[gy0 * gw + gx1];
        final double b01 = bgGrid[gy1 * gw + gx0];
        final double b11 = bgGrid[gy1 * gw + gx1];

        final double bTop = b00 * (1.0 - fx) + b10 * fx;
        final double bBottom = b01 * (1.0 - fx) + b11 * fx;
        final double localBg = bTop * (1.0 - fy) + bBottom * fy;

        final double gain = (targetWhite / localBg).clamp(0.8, 3.2);

        final p = src.getPixel(x, y);
        final int r = (p.r * gain).round().clamp(0, 255);
        final int g = (p.g * gain).round().clamp(0, 255);
        final int b = (p.b * gain).round().clamp(0, 255);

        dst.setPixelRgb(x, y, r, g, b);
      }
    }

    return dst;
  }

  // ===========================================================================
  // 5. COLOR ENHANCEMENT & WHITEBOARD PRESETS
  // ===========================================================================

  /// Enhances document color vibrancy and readability while preserving colored signatures & stamps
  static img.Image applyColorBoost(img.Image src) {
    // 1. Boost saturation by 25% and stretch contrast
    final boosted = img.adjustColor(
      src,
      brightness: 1.05,
      contrast: 1.25,
      saturation: 1.3,
    );
    return boosted;
  }

  /// Whiteboard mode: whitens dry-erase board background while keeping markers saturated
  static img.Image applyWhiteboard(img.Image src) {
    final dst = img.Image(width: src.width, height: src.height);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final double r = p.r.toDouble();
        final double g = p.g.toDouble();
        final double b = p.b.toDouble();

        final double gray = 0.299 * r + 0.587 * g + 0.114 * b;
        final double maxC = math.max(r, math.max(g, b));
        final double minC = math.min(r, math.min(g, b));
        final double chroma = maxC - minC;

        // If high lightness and low chroma -> paper background -> whiten to pure white
        if (gray > 170 && chroma < 35) {
          final double t = ((gray - 170) / 85.0).clamp(0.0, 1.0);
          final int nr = (r + (255 - r) * t).round().clamp(0, 255);
          final int ng = (g + (255 - g) * t).round().clamp(0, 255);
          final int nb = (b + (255 - b) * t).round().clamp(0, 255);
          dst.setPixelRgb(x, y, nr, ng, nb);
        } else {
          // Marker or text: boost contrast and saturation
          final int nr = (r * 0.9).round().clamp(0, 255);
          final int ng = (g * 0.9).round().clamp(0, 255);
          final int nb = (b * 0.9).round().clamp(0, 255);
          dst.setPixelRgb(x, y, nr, ng, nb);
        }
      }
    }

    return img.adjustColor(dst, brightness: 1.08, contrast: 1.3);
  }

  /// Enhanced text preset: Grayscale with sharpened mid-tone thresholding
  static img.Image applyEnhancedText(img.Image src) {
    final gray = img.grayscale(src);
    return img.adjustColor(gray, brightness: 1.1, contrast: 1.45);
  }

  // ===========================================================================
  // 6. SAFE MANUAL CLEANUP (HOLE PUNCHES & FINGERS)
  // ===========================================================================

  /// Seamlessly in-paints and patches hole-punch and finger artifacts non-destructively
  /// by sampling surrounding paper color and blending over the mask.
  static img.Image applyCleanupPatches(
    img.Image src,
    List<CleanupPatch> patches,
  ) {
    if (patches.isEmpty) return src;

    final dst = img.Image.from(src);
    final int w = dst.width;
    final int h = dst.height;

    for (final patch in patches) {
      final int cx = (patch.x * w).round().clamp(0, w - 1);
      final int cy = (patch.y * h).round().clamp(0, h - 1);
      final int radius = (patch.radius * w).round().clamp(3, w ~/ 4);

      // 1. Sample surrounding background color in annulus [radius * 1.1 .. radius * 1.5]
      final int sampleR1 = (radius * 1.1).round();
      final int sampleR2 = (radius * 1.5).round();

      double bgR = 0;
      double bgG = 0;
      double bgB = 0;
      int sampleCount = 0;

      for (int dy = -sampleR2; dy <= sampleR2; dy += 2) {
        final int py = cy + dy;
        if (py < 0 || py >= h) continue;

        for (int dx = -sampleR2; dx <= sampleR2; dx += 2) {
          final int px = cx + dx;
          if (px < 0 || px >= w) continue;

          final double d = math.sqrt((dx * dx + dy * dy).toDouble());
          if (d >= sampleR1 && d <= sampleR2) {
            final p = dst.getPixel(px, py);
            bgR += p.r;
            bgG += p.g;
            bgB += p.b;
            sampleCount++;
          }
        }
      }

      final int targetR = sampleCount > 0 ? (bgR / sampleCount).round() : 255;
      final int targetG = sampleCount > 0 ? (bgG / sampleCount).round() : 255;
      final int targetB = sampleCount > 0 ? (bgB / sampleCount).round() : 255;

      // 2. Inpaint the circular patch with smooth edge feathering
      final double innerR = radius * 0.7;
      final double outerR = radius.toDouble();

      for (int dy = -radius; dy <= radius; dy++) {
        final int py = cy + dy;
        if (py < 0 || py >= h) continue;

        for (int dx = -radius; dx <= radius; dx++) {
          final int px = cx + dx;
          if (px < 0 || px >= w) continue;

          final double d = math.sqrt((dx * dx + dy * dy).toDouble());
          if (d <= innerR) {
            dst.setPixelRgb(px, py, targetR, targetG, targetB);
          } else if (d < outerR) {
            final double t =
                (d - innerR) / (outerR - innerR); // 0 at inner, 1 at outer
            final p = dst.getPixel(px, py);
            final int r = (targetR * (1.0 - t) + p.r * t).round().clamp(0, 255);
            final int g = (targetG * (1.0 - t) + p.g * t).round().clamp(0, 255);
            final int b = (targetB * (1.0 - t) + p.b * t).round().clamp(0, 255);
            dst.setPixelRgb(px, py, r, g, b);
          }
        }
      }
    }

    return dst;
  }

  // ===========================================================================
  // 7. FILE PROCESSING & PARITY HELPERS
  // ===========================================================================

  /// Reads a file from disk, applies the complete EditRecipe, and returns the processed img.Image
  static Future<img.Image> processImageFile(
    File file,
    EditRecipe recipe,
  ) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image from path: ${file.path}');
    }
    return applyEditRecipe(decoded, recipe);
  }

  /// Processes an image and encodes it into JPEG bytes
  static Future<Uint8List> processImageFileToBytes(
    File file,
    EditRecipe recipe, {
    int quality = 90,
  }) async {
    final processed = await processImageFile(file, recipe);
    return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }

  /// Splits an open book spread into Left and Right pages down the vertical center spine
  /// with a 2% inner gutter margin overlap to preserve text near the binding.
  static List<img.Image> splitBookSpread(img.Image spread) {
    final int w = spread.width;
    final int h = spread.height;

    // Gutter overlap: ~2% of width
    final int overlap = (w * 0.02).round();
    final int halfW = w ~/ 2;

    // Left page: from 0 to halfW + overlap
    final int leftW = math.min(w, halfW + overlap);
    final leftPage = img.copyCrop(spread, x: 0, y: 0, width: leftW, height: h);

    // Right page: from halfW - overlap to w
    final int rightX = math.max(0, halfW - overlap);
    final int rightW = w - rightX;
    final rightPage = img.copyCrop(
      spread,
      x: rightX,
      y: 0,
      width: rightW,
      height: h,
    );

    return [leftPage, rightPage];
  }

  /// Splits a book spread image file on disk into two discrete JPEG files (left and right page)
  static Future<List<File>> splitBookSpreadFile({
    required File spreadFile,
    required Directory outputDir,
    required String baseId,
  }) async {
    final bytes = await spreadFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode book spread image: ${spreadFile.path}');
    }

    final pages = splitBookSpread(decoded);

    final leftPath = '${outputDir.path}/${baseId}_left.jpg';
    final rightPath = '${outputDir.path}/${baseId}_right.jpg';

    final leftFile = File(leftPath);
    final rightFile = File(rightPath);

    await leftFile.writeAsBytes(
      img.encodeJpg(pages[0], quality: 90),
      flush: true,
    );
    await rightFile.writeAsBytes(
      img.encodeJpg(pages[1], quality: 90),
      flush: true,
    );

    return [leftFile, rightFile];
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';

/// Grayscale luminance frame used for fast on-device document detection.
class CameraFrameData {
  final int width;
  final int height;
  final Uint8List lumaBytes;
  final DateTime timestamp;

  CameraFrameData({
    required this.width,
    required this.height,
    required this.lumaBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Extracts a compact luma frame directly from a live [CameraImage].
  static CameraFrameData? fromCameraImage(CameraImage image) {
    if (image.planes.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }

    final int w = image.width;
    final int h = image.height;
    final Plane primary = image.planes.first;

    if (image.format.group == ImageFormatGroup.bgra8888) {
      final int rowStride = primary.bytesPerRow;
      final out = Uint8List(w * h);
      final src = primary.bytes;
      for (int y = 0; y < h; y++) {
        final int rowBase = y * rowStride;
        final int outBase = y * w;
        for (int x = 0; x < w; x++) {
          final int idx = rowBase + x * 4;
          if (idx + 2 >= src.length) break;
          final int b = src[idx];
          final int g = src[idx + 1];
          final int r = src[idx + 2];
          out[outBase + x] = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
        }
      }
      return CameraFrameData(width: w, height: h, lumaBytes: out);
    }

    // YUV420 / NV21 / Y888: plane 0 stores Y luminance.
    final int rowStride = primary.bytesPerRow;
    final int pixelStride = primary.bytesPerPixel ?? 1;
    final Uint8List src = primary.bytes;
    final out = Uint8List(w * h);

    if (pixelStride == 1 && rowStride == w && src.length >= w * h) {
      out.setRange(0, w * h, src);
    } else {
      for (int y = 0; y < h; y++) {
        final int rowBase = y * rowStride;
        final int outBase = y * w;
        for (int x = 0; x < w; x++) {
          final int idx = rowBase + x * pixelStride;
          if (idx >= src.length) break;
          out[outBase + x] = src[idx];
        }
      }
    }
    return CameraFrameData(width: w, height: h, lumaBytes: out);
  }

  /// Decodes image bytes into a downsampled [CameraFrameData] for boundary analysis.
  static CameraFrameData? fromImageBytes(
    Uint8List bytes, {
    int maxDimension = 160,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }

    final img.Image working;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        working = img.copyResize(decoded, width: maxDimension);
      } else {
        working = img.copyResize(decoded, height: maxDimension);
      }
    } else {
      working = decoded;
    }

    final int w = working.width;
    final int h = working.height;
    final luma = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      final int rowBase = y * w;
      for (int x = 0; x < w; x++) {
        final pixel = working.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        luma[rowBase + x] = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
      }
    }
    return CameraFrameData(width: w, height: h, lumaBytes: luma);
  }

  /// Decodes an image file into a [CameraFrameData] safely.
  static Future<CameraFrameData?> fromImageFile(
    File file, {
    int maxDimension = 160,
  }) async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return fromImageBytes(bytes, maxDimension: maxDimension);
  }
}

/// Real-time status produced by on-device document detection.
enum DocumentDetectionStatus {
  idle,
  searching,
  lowLight,
  unstableMotion,
  partialOrTooClose,
  alignedHoldSteady,
  readyToCapture,
}

/// Output of a single frame's edge/quadrilateral + lighting + motion analysis.
class DocumentDetectionResult {
  final DocumentDetectionStatus status;
  final PerspectiveQuad? quad;
  final double areaFraction;
  final double meanLuminance;
  final double stabilityProgress;
  final String guidanceText;

  const DocumentDetectionResult({
    required this.status,
    this.quad,
    this.areaFraction = 0.0,
    this.meanLuminance = 0.0,
    this.stabilityProgress = 0.0,
    this.guidanceText = 'Position document inside frame',
  });

  bool get hasValidBoundary => quad != null;

  static const idle = DocumentDetectionResult(
    status: DocumentDetectionStatus.idle,
    guidanceText: 'Manual capture active',
  );
}

/// Pure-Dart on-device document boundary detector operating on downsampled luma frames.
///
/// Uses border-luminance foreground segmentation, Sobel edge magnitude,
/// neighborhood denoising, and convex quadrilateral fitting — never emitting
/// decorative rectangles on blank or uniform scenes.
class DocumentEdgeDetector {
  static const int _targetMaxDim = 88;
  static const double _lowLightThreshold = 34.0;
  static const double _motionDeltaThreshold = 19.0;
  static const double _minAreaFraction = 0.14;
  static const double _maxAreaFraction = 0.94;

  const DocumentEdgeDetector();

  /// Analyzes [frame] (and optional [previousFrame] for motion check).
  DocumentDetectionResult detect(
    CameraFrameData frame, {
    CameraFrameData? previousFrame,
  }) {
    if (frame.width < 16 ||
        frame.height < 16 ||
        frame.lumaBytes.length < frame.width * frame.height) {
      return const DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        guidanceText: 'Waiting for camera frame',
      );
    }

    // 1. Downsample to fast analysis grid while preserving aspect ratio.
    final double scale = _targetMaxDim / math.max(frame.width, frame.height);
    final int gw = math.max(24, (frame.width * scale).round());
    final int gh = math.max(24, (frame.height * scale).round());
    final grid = Uint8List(gw * gh);

    double lumaSum = 0;
    int minLuma = 255;
    int maxLuma = 0;

    for (int gy = 0; gy < gh; gy++) {
      final int sy = (gy * frame.height / gh).floor().clamp(
        0,
        frame.height - 1,
      );
      final int srcRow = sy * frame.width;
      final int dstRow = gy * gw;
      for (int gx = 0; gx < gw; gx++) {
        final int sx = (gx * frame.width / gw).floor().clamp(
          0,
          frame.width - 1,
        );
        final int val = frame.lumaBytes[srcRow + sx];
        grid[dstRow + gx] = val;
        lumaSum += val;
        if (val < minLuma) minLuma = val;
        if (val > maxLuma) maxLuma = val;
      }
    }

    final double meanLuma = lumaSum / (gw * gh);
    if (meanLuma < _lowLightThreshold) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.lowLight,
        meanLuminance: meanLuma,
        guidanceText: 'Low light · Enable torch or move near light',
      );
    }

    // 2. Reject flat / blank frames with insufficient tonal dynamic range.
    final int dynamicRange = maxLuma - minLuma;
    if (dynamicRange < 28) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Looking for document edges',
      );
    }

    // 3. Evaluate camera shake / scene motion against previous frame.
    if (previousFrame != null &&
        previousFrame.width == frame.width &&
        previousFrame.height == frame.height &&
        previousFrame.lumaBytes.length == frame.lumaBytes.length) {
      final double motion = _computeNormalizedMotion(
        grid,
        gw,
        gh,
        previousFrame,
      );
      if (motion > _motionDeltaThreshold) {
        return DocumentDetectionResult(
          status: DocumentDetectionStatus.unstableMotion,
          meanLuminance: meanLuma,
          guidanceText: 'Hold camera steady',
        );
      }
    }

    // 4. Estimate outer frame background luminance vs inner candidate paper surface.
    double borderSum = 0;
    int borderCount = 0;
    final int marginX = math.max(2, (gw * 0.07).round());
    final int marginY = math.max(2, (gh * 0.07).round());
    for (int y = 0; y < gh; y++) {
      for (int x = 0; x < gw; x++) {
        if (x < marginX || x >= gw - marginX || y < marginY || y >= gh - marginY) {
          borderSum += grid[y * gw + x];
          borderCount++;
        }
      }
    }
    final double borderMean = borderCount > 0 ? borderSum / borderCount : meanLuma;

    // Also inspect inner center region mean to determine light-on-dark or dark-on-light.
    double centerSum = 0;
    int centerCount = 0;
    for (int y = gh ~/ 4; y < (gh * 3) ~/ 4; y++) {
      for (int x = gw ~/ 4; x < (gw * 3) ~/ 4; x++) {
        centerSum += grid[y * gw + x];
        centerCount++;
      }
    }
    final double centerMean = centerCount > 0 ? centerSum / centerCount : meanLuma;
    final bool brightForeground = centerMean >= borderMean;
    final double contrastDelta = (centerMean - borderMean).abs();

    // 5. Compute Sobel edge energy and contrast foreground mask.
    final edgeMag = Int32List(gw * gh);
    int strongEdgeCount = 0;
    for (int y = 1; y < gh - 1; y++) {
      for (int x = 1; x < gw - 1; x++) {
        final int tl = grid[(y - 1) * gw + (x - 1)];
        final int tc = grid[(y - 1) * gw + x];
        final int tr = grid[(y - 1) * gw + (x + 1)];
        final int ml = grid[y * gw + (x - 1)];
        final int mr = grid[y * gw + (x + 1)];
        final int bl = grid[(y + 1) * gw + (x - 1)];
        final int bc = grid[(y + 1) * gw + x];
        final int br = grid[(y + 1) * gw + (x + 1)];

        final int gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl);
        final int gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr);
        final int mag = gx.abs() + gy.abs();
        edgeMag[y * gw + x] = mag;
        if (mag > 85) strongEdgeCount++;
      }
    }

    if (strongEdgeCount < math.max(18, (gw + gh) ~/ 4)) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Looking for document edges',
      );
    }

    // Build binary foreground mask:
    // If border vs center has clear tonal separation (>= 22), threshold midway;
    // otherwise require strong edge magnitude enclosure.
    final mask = Uint8List(gw * gh);
    if (contrastDelta >= 22.0) {
      final double splitThreshold = (borderMean + centerMean) * 0.5;
      for (int i = 0; i < grid.length; i++) {
        final bool isFg = brightForeground
            ? grid[i] >= splitThreshold
            : grid[i] <= splitThreshold;
        if (isFg) mask[i] = 1;
      }
    } else {
      for (int i = 0; i < grid.length; i++) {
        if (edgeMag[i] >= 95) mask[i] = 1;
      }
    }

    // 6. Denoise mask using 3x3 neighbor support count (>= 4 neighbors) and find boundary points.
    final cleaned = Uint8List(gw * gh);
    final perimeterX = <int>[];
    final perimeterY = <int>[];
    int fgAreaCount = 0;

    for (int y = 1; y < gh - 1; y++) {
      for (int x = 1; x < gw - 1; x++) {
        final int idx = y * gw + x;
        if (mask[idx] == 0) continue;
        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            neighbors += mask[(y + dy) * gw + (x + dx)];
          }
        }
        if (neighbors >= 4) {
          cleaned[idx] = 1;
          fgAreaCount++;
        }
      }
    }

    if (fgAreaCount < (gw * gh * 0.08)) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Move document clearly into view',
      );
    }

    for (int y = 1; y < gh - 1; y++) {
      for (int x = 1; x < gw - 1; x++) {
        final int idx = y * gw + x;
        if (cleaned[idx] == 0) continue;
        if (cleaned[idx - 1] == 0 ||
            cleaned[idx + 1] == 0 ||
            cleaned[idx - gw] == 0 ||
            cleaned[idx + gw] == 0) {
          perimeterX.add(x);
          perimeterY.add(y);
        }
      }
    }

    if (perimeterX.length < 16) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Looking for document edges',
      );
    }

    // 7. Fit 4-corner quadrilateral via extremal diagonal projections:
    // TL minimizes (x + y), BR maximizes (x + y),
    // TR maximizes (x - y), BL minimizes (x - y).
    int tlIdx = 0;
    int brIdx = 0;
    int trIdx = 0;
    int blIdx = 0;

    int minSum = 1 << 30;
    int maxSum = -(1 << 30);
    int maxDiff = -(1 << 30);
    int minDiff = 1 << 30;

    for (int i = 0; i < perimeterX.length; i++) {
      final int x = perimeterX[i];
      final int y = perimeterY[i];
      final int sum = x + y;
      final int diff = x - y;
      if (sum < minSum) {
        minSum = sum;
        tlIdx = i;
      }
      if (sum > maxSum) {
        maxSum = sum;
        brIdx = i;
      }
      if (diff > maxDiff) {
        maxDiff = diff;
        trIdx = i;
      }
      if (diff < minDiff) {
        minDiff = diff;
        blIdx = i;
      }
    }

    final quad = PerspectiveQuad(
      x1: (perimeterX[tlIdx] / (gw - 1)).clamp(0.0, 1.0),
      y1: (perimeterY[tlIdx] / (gh - 1)).clamp(0.0, 1.0),
      x2: (perimeterX[trIdx] / (gw - 1)).clamp(0.0, 1.0),
      y2: (perimeterY[trIdx] / (gh - 1)).clamp(0.0, 1.0),
      x3: (perimeterX[brIdx] / (gw - 1)).clamp(0.0, 1.0),
      y3: (perimeterY[brIdx] / (gh - 1)).clamp(0.0, 1.0),
      x4: (perimeterX[blIdx] / (gw - 1)).clamp(0.0, 1.0),
      y4: (perimeterY[blIdx] / (gh - 1)).clamp(0.0, 1.0),
    );

    if (!quad.isValidConvex()) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Align all 4 corners inside frame',
      );
    }

    final double area = _polygonArea(quad);
    if (area < _minAreaFraction) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.partialOrTooClose,
        areaFraction: area,
        meanLuminance: meanLuma,
        guidanceText: 'Move closer to document',
      );
    }
    if (area > _maxAreaFraction) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.partialOrTooClose,
        areaFraction: area,
        meanLuminance: meanLuma,
        guidanceText: 'Step back slightly to fit margins',
      );
    }

    // Verify all 4 quad sides have non-trivial span.
    final double topLen = _dist(quad.x1, quad.y1, quad.x2, quad.y2);
    final double rightLen = _dist(quad.x2, quad.y2, quad.x3, quad.y3);
    final double bottomLen = _dist(quad.x3, quad.y3, quad.x4, quad.y4);
    final double leftLen = _dist(quad.x4, quad.y4, quad.x1, quad.y1);
    if (math.min(math.min(topLen, bottomLen), math.min(rightLen, leftLen)) <
        0.16) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.searching,
        meanLuminance: meanLuma,
        guidanceText: 'Align document cleanly in view',
      );
    }

    return DocumentDetectionResult(
      status: DocumentDetectionStatus.alignedHoldSteady,
      quad: quad,
      areaFraction: area,
      meanLuminance: meanLuma,
      guidanceText: 'Document locked · Hold steady',
    );
  }

  double _computeNormalizedMotion(
    Uint8List currentGrid,
    int gw,
    int gh,
    CameraFrameData previousFrame,
  ) {
    double diffSum = 0;
    int samples = 0;
    final int stepY = math.max(1, gh ~/ 16);
    final int stepX = math.max(1, gw ~/ 16);
    for (int gy = 0; gy < gh; gy += stepY) {
      final int sy = (gy * previousFrame.height / gh).floor().clamp(
        0,
        previousFrame.height - 1,
      );
      final int pRow = sy * previousFrame.width;
      final int cRow = gy * gw;
      for (int gx = 0; gx < gw; gx += stepX) {
        final int sx = (gx * previousFrame.width / gw).floor().clamp(
          0,
          previousFrame.width - 1,
        );
        diffSum += (currentGrid[cRow + gx] - previousFrame.lumaBytes[pRow + sx])
            .abs();
        samples++;
      }
    }
    return samples > 0 ? diffSum / samples : 0.0;
  }

  static double _dist(double x1, double y1, double x2, double y2) =>
      math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));

  /// Shoelace normalized area in [0, 1].
  static double _polygonArea(PerspectiveQuad q) {
    final double sum =
        (q.x1 * q.y2 - q.y1 * q.x2) +
        (q.x2 * q.y3 - q.y2 * q.x3) +
        (q.x3 * q.y4 - q.y3 * q.x4) +
        (q.x4 * q.y1 - q.y4 * q.x1);
    return (sum.abs() * 0.5).clamp(0.0, 1.0);
  }
}

/// Evaluates frame-to-frame quadrilateral stability for safe auto-capture.
class DocumentStabilityTracker {
  final int requiredStableFrames;
  final double maxCornerDrift;
  final Duration captureCooldown;

  PerspectiveQuad? _lastQuad;
  int _stableCount = 0;
  DateTime? _lastCaptureAt;
  bool _awaitingSceneChangeAfterCapture = false;

  DocumentStabilityTracker({
    this.requiredStableFrames = 4,
    this.maxCornerDrift = 0.038,
    this.captureCooldown = const Duration(milliseconds: 2500),
  });

  int get stableFrames => _stableCount;

  /// Records a capture and prevents duplicate auto-captures until cooldown elapses
  /// and either scene resets or document shifts cleanly.
  void markCaptured([DateTime? now]) {
    _lastCaptureAt = now ?? DateTime.now();
    _stableCount = 0;
    _awaitingSceneChangeAfterCapture = true;
  }

  /// Resets accumulated stability (e.g., mode switch, manual shutter, or camera pause).
  void reset() {
    _lastQuad = null;
    _stableCount = 0;
    _awaitingSceneChangeAfterCapture = false;
  }

  /// Enriches [rawResult] with stability progress and [DocumentDetectionStatus.readyToCapture]
  /// when all stability thresholds are satisfied.
  DocumentDetectionResult evaluate(
    DocumentDetectionResult rawResult, {
    DateTime? now,
  }) {
    final DateTime currentNow = now ?? DateTime.now();
    final quad = rawResult.quad;

    if (rawResult.status != DocumentDetectionStatus.alignedHoldSteady ||
        quad == null) {
      _stableCount = 0;
      _lastQuad = null;
      _awaitingSceneChangeAfterCapture = false;
      return rawResult;
    }

    // Check cooldown + ensure user actually moved to a new page or lifted document briefly.
    if (_lastCaptureAt != null) {
      final elapsed = currentNow.difference(_lastCaptureAt!);
      if (elapsed < captureCooldown) {
        return DocumentDetectionResult(
          status: DocumentDetectionStatus.alignedHoldSteady,
          quad: quad,
          areaFraction: rawResult.areaFraction,
          meanLuminance: rawResult.meanLuminance,
          stabilityProgress: 0.0,
          guidanceText: 'Captured · Present next page',
        );
      }
      if (_awaitingSceneChangeAfterCapture) {
        final double driftSinceCapture = _lastQuad == null
            ? 1.0
            : _maxDrift(_lastQuad!, quad);
        if (driftSinceCapture < maxCornerDrift * 1.4) {
          return DocumentDetectionResult(
            status: DocumentDetectionStatus.alignedHoldSteady,
            quad: quad,
            areaFraction: rawResult.areaFraction,
            meanLuminance: rawResult.meanLuminance,
            stabilityProgress: 0.0,
            guidanceText: 'Move to next page to auto-capture',
          );
        }
        _awaitingSceneChangeAfterCapture = false;
      }
    }

    if (_lastQuad != null) {
      final double drift = _maxDrift(_lastQuad!, quad);
      if (drift <= maxCornerDrift) {
        _stableCount = (_stableCount + 1).clamp(1, requiredStableFrames);
      } else {
        _stableCount = 1;
      }
    } else {
      _stableCount = 1;
    }
    _lastQuad = quad;

    final double progress = (_stableCount / requiredStableFrames).clamp(
      0.0,
      1.0,
    );
    if (_stableCount >= requiredStableFrames) {
      return DocumentDetectionResult(
        status: DocumentDetectionStatus.readyToCapture,
        quad: quad,
        areaFraction: rawResult.areaFraction,
        meanLuminance: rawResult.meanLuminance,
        stabilityProgress: 1.0,
        guidanceText: 'Capturing page...',
      );
    }

    return DocumentDetectionResult(
      status: DocumentDetectionStatus.alignedHoldSteady,
      quad: quad,
      areaFraction: rawResult.areaFraction,
      meanLuminance: rawResult.meanLuminance,
      stabilityProgress: progress,
      guidanceText: 'Hold steady · Locking boundary',
    );
  }

  static double _maxDrift(PerspectiveQuad a, PerspectiveQuad b) {
    final deltas = [
      (a.x1 - b.x1).abs(),
      (a.y1 - b.y1).abs(),
      (a.x2 - b.x2).abs(),
      (a.y2 - b.y2).abs(),
      (a.x3 - b.x3).abs(),
      (a.y3 - b.y3).abs(),
      (a.x4 - b.x4).abs(),
      (a.y4 - b.y4).abs(),
    ];
    return deltas.reduce(math.max);
  }
}

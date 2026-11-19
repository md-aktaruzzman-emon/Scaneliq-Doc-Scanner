import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;

enum CountDetectionPreset {
  autoHybrid,
  denseCluster,
  prominentObjects,
  smallItems,
}

class DetectedCountObject {
  final int index;

  /// Normalized [0..1] bounding box relative to source image width & height.
  final Rect normalizedRect;
  final Offset normalizedCenter;
  final String label;
  final double confidence;
  final bool isManual;

  const DetectedCountObject({
    required this.index,
    required this.normalizedRect,
    required this.normalizedCenter,
    this.label = 'Object',
    this.confidence = 0.85,
    this.isManual = false,
  });

  DetectedCountObject copyWith({int? index}) => DetectedCountObject(
    index: index ?? this.index,
    normalizedRect: normalizedRect,
    normalizedCenter: normalizedCenter,
    label: label,
    confidence: confidence,
    isManual: isManual,
  );
}

class CountCamResult {
  final List<DetectedCountObject> objects;
  final int imageWidth;
  final int imageHeight;
  final String engineUsed;

  const CountCamResult({
    required this.objects,
    required this.imageWidth,
    required this.imageHeight,
    required this.engineUsed,
  });

  int get count => objects.length;
}

/// Real on-device physical object counter combining:
/// 1. Google ML Kit Object Detection (for prominent labeled objects on Android)
/// 2. Isolate-based morphological connected-component cluster segmentation (for dense
///    repetitive objects such as boxes, coins, bottles, rods, or notebooks without text).
class ObjectCounterService {
  ObjectCounterService._();
  static final ObjectCounterService instance = ObjectCounterService._();

  @visibleForTesting
  Future<List<DetectedObject>> Function(File imageFile)?
  mlKitOverrideForTesting;

  Future<CountCamResult> detectObjects(
    File imageFile, {
    CountDetectionPreset preset = CountDetectionPreset.autoHybrid,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file not found: ${imageFile.path}');
    }

    final bytes = await imageFile.readAsBytes();
    final dims = await Isolate.run(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return <int>[0, 0];
      return <int>[decoded.width, decoded.height];
    });
    final imgW = dims[0];
    final imgH = dims[1];
    if (imgW <= 0 || imgH <= 0) {
      throw Exception('Failed to decode image for object counting');
    }

    List<DetectedCountObject> mlKitObjects = const [];
    if (preset != CountDetectionPreset.denseCluster &&
        preset != CountDetectionPreset.smallItems) {
      mlKitObjects = await _runMlKitDetector(imageFile, imgW, imgH);
    }

    // If ML Kit is only configured or returned prominent objects, keep them when >= 2;
    // otherwise run connected-component visual cluster detection in a background isolate.
    if (preset == CountDetectionPreset.prominentObjects &&
        mlKitObjects.isNotEmpty) {
      return CountCamResult(
        objects: mlKitObjects,
        imageWidth: imgW,
        imageHeight: imgH,
        engineUsed: 'mlkit_object_detector',
      );
    }

    final minAreaRatio = preset == CountDetectionPreset.smallItems
        ? 0.0012
        : 0.0035;
    final maxAreaRatio = preset == CountDetectionPreset.smallItems
        ? 0.18
        : 0.42;

    final clusterObjects = await detectVisualObjectClusters(
      bytes,
      minAreaRatio: minAreaRatio,
      maxAreaRatio: maxAreaRatio,
    );

    if (clusterObjects.length > mlKitObjects.length || mlKitObjects.isEmpty) {
      return CountCamResult(
        objects: clusterObjects,
        imageWidth: imgW,
        imageHeight: imgH,
        engineUsed: clusterObjects.isEmpty && mlKitObjects.isNotEmpty
            ? 'mlkit_object_detector'
            : 'morphological_cluster_detector',
      );
    }

    return CountCamResult(
      objects: mlKitObjects,
      imageWidth: imgW,
      imageHeight: imgH,
      engineUsed: 'mlkit_object_detector',
    );
  }

  Future<List<DetectedCountObject>> _runMlKitDetector(
    File imageFile,
    int imgW,
    int imgH,
  ) async {
    ObjectDetector? detector;
    try {
      List<DetectedObject> detected;
      if (mlKitOverrideForTesting != null) {
        detected = await mlKitOverrideForTesting!(imageFile);
      } else {
        detector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: DetectionMode.single,
            classifyObjects: true,
            multipleObjects: true,
          ),
        );
        final inputImage = InputImage.fromFile(imageFile);
        detected = await detector.processImage(inputImage);
      }

      final out = <DetectedCountObject>[];
      for (int i = 0; i < detected.length; i++) {
        final box = detected[i].boundingBox;
        final nx = (box.left / imgW).clamp(0.0, 1.0);
        final ny = (box.top / imgH).clamp(0.0, 1.0);
        final nw = (box.width / imgW).clamp(0.01, 1.0 - nx);
        final nh = (box.height / imgH).clamp(0.01, 1.0 - ny);
        final topLabel = detected[i].labels.isNotEmpty
            ? detected[i].labels.first.text
            : 'Object';
        final conf = detected[i].labels.isNotEmpty
            ? detected[i].labels.first.confidence
            : 0.75;
        out.add(
          DetectedCountObject(
            index: i + 1,
            normalizedRect: Rect.fromLTWH(nx, ny, nw, nh),
            normalizedCenter: Offset(nx + nw / 2.0, ny + nh / 2.0),
            label: topLabel.isEmpty ? 'Object' : topLabel,
            confidence: conf,
          ),
        );
      }
      return out;
    } on MissingPluginException {
      return const [];
    } catch (_) {
      return const [];
    } finally {
      try {
        await detector?.close();
      } catch (_) {}
    }
  }

  /// Pure-Dart background Isolate connected-component detector that segments distinct
  /// physical objects separated against a background surface (without OCR).
  static Future<List<DetectedCountObject>> detectVisualObjectClusters(
    Uint8List encodedBytes, {
    double minAreaRatio = 0.0035,
    double maxAreaRatio = 0.42,
  }) async {
    final rawList = await Isolate.run(() {
      final decoded = img.decodeImage(encodedBytes);
      if (decoded == null) return <List<double>>[];

      const int targetMaxDim = 240;
      final img.Image work =
          (decoded.width > targetMaxDim || decoded.height > targetMaxDim)
          ? (decoded.width >= decoded.height
                ? img.copyResize(decoded, width: targetMaxDim)
                : img.copyResize(decoded, height: targetMaxDim))
          : decoded;

      final int w = work.width;
      final int h = work.height;
      final int total = w * h;
      if (total == 0) return <List<double>>[];

      // Estimate dominant background tone from border ring (RGB distance handles light/dark/colored backgrounds)
      final borderSamplesR = <int>[];
      final borderSamplesG = <int>[];
      final borderSamplesB = <int>[];
      for (int x = 0; x < w; x++) {
        final pTop = work.getPixel(x, 0);
        final pBot = work.getPixel(x, h - 1);
        borderSamplesR
          ..add(pTop.r.toInt())
          ..add(pBot.r.toInt());
        borderSamplesG
          ..add(pTop.g.toInt())
          ..add(pBot.g.toInt());
        borderSamplesB
          ..add(pTop.b.toInt())
          ..add(pBot.b.toInt());
      }
      for (int y = 1; y < h - 1; y++) {
        final pL = work.getPixel(0, y);
        final pR = work.getPixel(w - 1, y);
        borderSamplesR
          ..add(pL.r.toInt())
          ..add(pR.r.toInt());
        borderSamplesG
          ..add(pL.g.toInt())
          ..add(pR.g.toInt());
        borderSamplesB
          ..add(pL.b.toInt())
          ..add(pR.b.toInt());
      }
      borderSamplesR.sort();
      borderSamplesG.sort();
      borderSamplesB.sort();
      final bgR = borderSamplesR[borderSamplesR.length ~/ 2];
      final bgG = borderSamplesG[borderSamplesG.length ~/ 2];
      final bgB = borderSamplesB[borderSamplesB.length ~/ 2];

      // Foreground color distance map + dynamic Otsu-like threshold
      final dist = Float64List(total);
      double maxDist = 0.0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = work.getPixel(x, y);
          final dr = p.r - bgR;
          final dg = p.g - bgG;
          final db = p.b - bgB;
          final d = math.sqrt((dr * dr + dg * dg + db * db).toDouble());
          dist[y * w + x] = d;
          if (d > maxDist) maxDist = d;
        }
      }

      if (maxDist < 24.0) {
        // Uniform empty frame -> 0 objects
        return <List<double>>[];
      }

      final double fgThresh = math.max(26.0, maxDist * 0.28);
      final mask = Uint8List(total);
      for (int i = 0; i < total; i++) {
        mask[i] = dist[i] >= fgThresh ? 1 : 0;
      }

      // Light 3x3 morphological majority cleanup to drop single-pixel grain without merging nearby items
      final clean = Uint8List(total);
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final idx = y * w + x;
          if (mask[idx] == 0) continue;
          int neighbors = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              neighbors += mask[(y + dy) * w + (x + dx)];
            }
          }
          if (neighbors >= 4) clean[idx] = 1;
        }
      }

      // BFS 8-connected component labeling
      final visited = Uint8List(total);
      final queue = Queue<int>();
      final components = <List<double>>[];
      final int minPixels = math.max(12, (total * minAreaRatio).round());
      final int maxPixels = (total * maxAreaRatio).round();

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final startIdx = y * w + x;
          if (clean[startIdx] == 0 || visited[startIdx] == 1) continue;

          visited[startIdx] = 1;
          queue.add(startIdx);

          int area = 0;
          int minX = x, maxX = x, minY = y, maxY = y;
          while (queue.isNotEmpty) {
            final cur = queue.removeFirst();
            final cx = cur % w;
            final cy = cur ~/ w;
            area++;
            if (cx < minX) minX = cx;
            if (cx > maxX) maxX = cx;
            if (cy < minY) minY = cy;
            if (cy > maxY) maxY = cy;

            for (int dy = -1; dy <= 1; dy++) {
              final ny = cy + dy;
              if (ny < 0 || ny >= h) continue;
              for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                final nx = cx + dx;
                if (nx < 0 || nx >= w) continue;
                final nIdx = ny * w + nx;
                if (clean[nIdx] == 1 && visited[nIdx] == 0) {
                  visited[nIdx] = 1;
                  queue.add(nIdx);
                }
              }
            }
          }

          if (area >= minPixels && area <= maxPixels) {
            final double nx = minX / w;
            final double ny = minY / h;
            final double nw = math.max(1, (maxX - minX + 1)) / w;
            final double nh = math.max(1, (maxY - minY + 1)) / h;
            components.add([nx, ny, nw, nh, area / total]);
          }
        }
      }

      // Sort top-to-bottom, left-to-right for natural counting order
      components.sort((a, b) {
        final rowDiff = (a[1] - b[1]);
        if (rowDiff.abs() > 0.05) return rowDiff.compareTo(0.0);
        return a[0].compareTo(b[0]);
      });

      return components;
    });

    return [
      for (int i = 0; i < rawList.length; i++)
        DetectedCountObject(
          index: i + 1,
          normalizedRect: Rect.fromLTWH(
            rawList[i][0],
            rawList[i][1],
            rawList[i][2],
            rawList[i][3],
          ),
          normalizedCenter: Offset(
            rawList[i][0] + rawList[i][2] / 2.0,
            rawList[i][1] + rawList[i][3] / 2.0,
          ),
          label: 'Item #${i + 1}',
          confidence: 0.82,
        ),
    ];
  }
}

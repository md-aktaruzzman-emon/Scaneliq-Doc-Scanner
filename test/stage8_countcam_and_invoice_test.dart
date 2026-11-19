import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/intelligence/data/receipt_parser_service.dart';
import 'package:scaneliq/features/scanner/data/object_counter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_stage8_');
    await AppStorageService.instance.init(tempDir);
    ObjectCounterService.instance.mlKitOverrideForTesting = null;
  });

  tearDown(() async {
    ObjectCounterService.instance.mlKitOverrideForTesting = null;
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Stage 8 — Real Object CountCam & Dedicated Invoice Parser', () {
    test('ObjectCounterService detects exact count of separated physical objects with zero text and returns 0 on blank surface', () async {
      // 1. Uniform surface -> 0 objects
      final blank = img.Image(width: 300, height: 300);
      img.fill(blank, color: img.ColorRgb8(240, 240, 238));
      final blankFile = File('${tempDir.path}/blank.jpg');
      await blankFile.writeAsBytes(img.encodeJpg(blank));

      final blankRes = await ObjectCounterService.instance.detectObjects(
        blankFile,
        preset: CountDetectionPreset.denseCluster,
      );
      expect(blankRes.count, equals(0));

      // 2. 6 distinct objects (circles/boxes) on neutral surface -> must detect 6 objects without OCR
      final scene = img.Image(width: 480, height: 360);
      img.fill(scene, color: img.ColorRgb8(242, 240, 235));
      final centers = [
        [90, 90],
        [240, 90],
        [390, 90],
        [90, 250],
        [240, 250],
        [390, 250],
      ];
      for (final c in centers) {
        img.fillCircle(
          scene,
          x: c[0],
          y: c[1],
          radius: 36,
          color: img.ColorRgb8(28, 72, 165),
        );
      }
      final objectsFile = File('${tempDir.path}/six_items.jpg');
      await objectsFile.writeAsBytes(img.encodeJpg(scene, quality: 95));

      final denseRes = await ObjectCounterService.instance.detectObjects(
        objectsFile,
        preset: CountDetectionPreset.denseCluster,
      );
      expect(denseRes.count, equals(6));
      expect(denseRes.engineUsed, equals('morphological_cluster_detector'));
      expect(denseRes.objects.first.normalizedRect.width, greaterThan(0.05));

      // 3. ML Kit prominent object detector preset integration
      ObjectCounterService.instance.mlKitOverrideForTesting = (_) async => [
        DetectedObject(
          boundingBox: const Rect.fromLTWH(20, 20, 120, 120),
          labels: [Label(text: 'Package', confidence: 0.91, index: 0)],
          trackingId: 1,
        ),
        DetectedObject(
          boundingBox: const Rect.fromLTWH(200, 40, 140, 140),
          labels: [Label(text: 'Package', confidence: 0.88, index: 1)],
          trackingId: 2,
        ),
      ];
      final mlRes = await ObjectCounterService.instance.detectObjects(
        objectsFile,
        preset: CountDetectionPreset.prominentObjects,
      );
      expect(mlRes.count, equals(2));
      expect(mlRes.engineUsed, equals('mlkit_object_detector'));
      expect(mlRes.objects.first.label, equals('Package'));
    });

    test('ReceiptParserService extracts Invoice #, PO #, Tax ID, Due Date, Discount & Bengali numerals cleanly', () {
      const invoiceText = '''
Apex Logistics Ltd
Invoice # INV-2026-091
PO Number: PO-77412
TIN: TIN-8829104
Date: 2026-11-10
Due Date: 2026-12-10
Thermal Paper Rolls 2 x 250.00  500.00
Shipping Fee                    100.00
Subtotal                        600.00
Discount                         50.00
VAT (15%)                        90.00
Grand Total                BDT 640.00
''';

      final parsed = ReceiptParserService.instance.parseText(invoiceText);
      expect(parsed.documentKind, equals('Invoice'));
      expect(parsed.merchantName, equals('Apex Logistics Ltd'));
      expect(parsed.invoiceNumber, equals('INV-2026-091'));
      expect(parsed.poNumber, equals('PO-77412'));
      expect(parsed.vendorTaxId, equals('TIN-8829104'));
      expect(parsed.date, equals('2026-11-10'));
      expect(parsed.dueDate, equals('2026-12-10'));
      expect(parsed.currency, equals('BDT'));
      expect(parsed.subtotal, equals(600.00));
      expect(parsed.discount, equals(50.00));
      expect(parsed.tax, equals(90.00));
      expect(parsed.total, equals(640.00));
      expect(parsed.isMathConsistent, isTrue);
      expect(parsed.toCsv(), contains('INV-2026-091,PO-77412,TIN-8829104'));

      // Verify Bengali digit parsing
      const bnReceipt = '''
ঢাকা বুক হাউস
তারিখ: ১৮/১১/২০২৬
নোটবুক       ২০০.০০ টাকা
ভ্যাট        ৩০.০০ টাকা
মোট          ২৩০.০০ টাকা
''';
      final parsedBn = ReceiptParserService.instance.parseText(bnReceipt);
      expect(parsedBn.currency, equals('৳'));
      expect(parsedBn.date, equals('18/11/2026'));
      expect(parsedBn.tax, equals(30.00));
      expect(parsedBn.total, equals(230.00));
      expect(parsedBn.isMathConsistent, isTrue);
    });
  });
}

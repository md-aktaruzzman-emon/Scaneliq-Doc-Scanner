import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/scanner/data/camera_studio_controller.dart';
import 'package:scaneliq/features/scanner/data/document_edge_detector.dart';
import 'package:scaneliq/features/scanner/data/gallery_import_service.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeScannerCameraBackend implements ScannerCameraBackend {
  List<CameraDescription> camerasToReturn;
  Exception? errorOnDiscover;
  Exception? errorOnInitialize;
  Completer<void>? pendingInitCompleter;
  Completer<File>? pendingCaptureCompleter;
  File? nextCapturedFile;

  int initializeCount = 0;
  int disposeCount = 0;
  int takePictureCount = 0;
  FlashMode lastFlashMode = FlashMode.off;
  Offset? lastFocusPoint;
  void Function(CameraFrameData frame)? _frameListener;
  bool _initialized = false;
  bool _streaming = false;

  FakeScannerCameraBackend({
    List<CameraDescription>? cameras,
    this.nextCapturedFile,
  }) : camerasToReturn =
           cameras ??
           const [
             CameraDescription(
               name: 'rear_0',
               lensDirection: CameraLensDirection.back,
               sensorOrientation: 90,
             ),
             CameraDescription(
               name: 'front_1',
               lensDirection: CameraLensDirection.front,
               sensorOrientation: 270,
             ),
           ];

  @override
  bool get isInitialized => _initialized;

  @override
  double get previewAspectRatio => 3 / 4;

  @override
  bool get supportsImageStream => true;

  @override
  Future<List<CameraDescription>> getAvailableCameras() async {
    if (errorOnDiscover != null) throw errorOnDiscover!;
    return camerasToReturn;
  }

  @override
  Future<void> initialize(
    CameraDescription camera, {
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    initializeCount++;
    if (pendingInitCompleter != null) {
      await pendingInitCompleter!.future;
    }
    if (errorOnInitialize != null) {
      _initialized = false;
      throw errorOnInitialize!;
    }
    _initialized = true;
  }

  @override
  Future<void> disposeCamera() async {
    disposeCount++;
    _streaming = false;
    _frameListener = null;
    _initialized = false;
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    lastFlashMode = mode;
  }

  @override
  Future<void> setFocusAndExposurePoint(Offset normalizedPoint) async {
    lastFocusPoint = normalizedPoint;
  }

  @override
  Future<File> takePicture() async {
    takePictureCount++;
    if (pendingCaptureCompleter != null) {
      return await pendingCaptureCompleter!.future;
    }
    if (nextCapturedFile == null) {
      throw StateError('No synthetic image staged for capture');
    }
    return nextCapturedFile!;
  }

  @override
  Future<void> startFrameStream(
    void Function(CameraFrameData frame) onFrame,
  ) async {
    _streaming = true;
    _frameListener = onFrame;
  }

  @override
  Future<void> stopFrameStream() async {
    _streaming = false;
    _frameListener = null;
  }

  void pushSyntheticFrame(CameraFrameData frame) {
    if (_streaming && _frameListener != null) {
      _frameListener!(frame);
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    return Container(
      color: const Color(0xFF191D26),
      child: Center(
        child: Container(
          width: 190,
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F5F0),
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INVOICE #2026-88',
                style: TextStyle(
                  color: Color(0xFF141413),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Divider(height: 1, color: Color(0xFFD6D3CB)),
              SizedBox(height: 10),
              ColoredBox(
                color: Color(0xFFDDE2EB),
                child: SizedBox(width: 120, height: 8),
              ),
              SizedBox(height: 6),
              ColoredBox(
                color: Color(0xFFE5E8EE),
                child: SizedBox(width: 95, height: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

CameraFrameData buildSyntheticDocumentFrame({
  int width = 120,
  int height = 160,
  int backgroundLuma = 35,
  int documentLuma = 230,
}) {
  final luma = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final bool insideDoc =
          x >= (width * 0.16).round() &&
          x <= (width * 0.84).round() &&
          y >= (height * 0.14).round() &&
          y <= (height * 0.86).round();
      luma[y * width + x] = insideDoc ? documentLuma : backgroundLuma;
    }
  }
  return CameraFrameData(width: width, height: height, lumaBytes: luma);
}

Future<Database> _openTestDb(Directory dir) async {
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}/phase3_test.db',
    options: OpenDatabaseOptions(
      version: 5,
      singleInstance: false,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON;'),
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');
        await d.execute('''
          CREATE TABLE tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL
          )
        ''');
        await d.execute('''
          CREATE TABLE document_tags (
            document_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (document_id, tag_id),
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
          )
        ''');
        await d.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            page_count INTEGER NOT NULL DEFAULT 0,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_draft INTEGER NOT NULL DEFAULT 0,
            export_path TEXT,
            folder_id TEXT,
            deleted_at INTEGER,
            FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
          )
        ''');
        await d.execute('''
          CREATE TABLE pages (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            page_order INTEGER NOT NULL,
            original_path TEXT NOT NULL,
            processed_path TEXT,
            edit_recipe_json TEXT NOT NULL,
            width INTEGER,
            height INTEGER,
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');
        await d.execute('''
          CREATE TABLE document_ocr (
            document_id TEXT PRIMARY KEY,
            full_text TEXT NOT NULL,
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );
  AppDatabaseService.instance.setDatabaseForTesting(db);
  return db;
}

File _writeSampleJpgSync(
  Directory dir,
  String name, {
  int width = 120,
  int height = 160,
  int r = 240,
  int g = 240,
  int b = 235,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodeJpg(image, quality: 92), flush: true);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 3 Unit Tests: Edge Detection, Stability & Gallery Validation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p3_unit_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'DocumentEdgeDetector detects genuine document quad and rejects blank/dark frames',
      () {
        const detector = DocumentEdgeDetector();

        // 1. Dark frame triggers lowLight with NO fake quad.
        final darkFrame = CameraFrameData(
          width: 120,
          height: 160,
          lumaBytes: Uint8List.fromList(List.filled(120 * 160, 12)),
        );
        final darkResult = detector.detect(darkFrame);
        expect(darkResult.status, DocumentDetectionStatus.lowLight);
        expect(darkResult.quad, isNull);

        // 2. Uniform bright blank wall emits NO fake quad.
        final blankFrame = CameraFrameData(
          width: 120,
          height: 160,
          lumaBytes: Uint8List.fromList(List.filled(120 * 160, 180)),
        );
        final blankResult = detector.detect(blankFrame);
        expect(blankResult.status, DocumentDetectionStatus.searching);
        expect(blankResult.quad, isNull);

        // 3. Synthetic paper sheet on dark background returns valid convex quad.
        final docFrame = buildSyntheticDocumentFrame();
        final docResult = detector.detect(docFrame);
        expect(docResult.status, DocumentDetectionStatus.alignedHoldSteady);
        expect(docResult.quad, isNotNull);
        expect(docResult.quad!.isValidConvex(), isTrue);
        expect(docResult.areaFraction, greaterThan(0.35));
      },
    );

    test(
      'DocumentStabilityTracker locks after 4 steady frames and enforces post-capture cooldown',
      () {
        const detector = DocumentEdgeDetector();
        final tracker = DocumentStabilityTracker(
          requiredStableFrames: 4,
          captureCooldown: const Duration(milliseconds: 2000),
        );
        final docFrame = buildSyntheticDocumentFrame();
        final raw = detector.detect(docFrame);
        final t0 = DateTime(2026, 11, 19, 12, 0, 0);

        final r1 = tracker.evaluate(raw, now: t0);
        expect(r1.status, DocumentDetectionStatus.alignedHoldSteady);
        expect(r1.stabilityProgress, closeTo(0.25, 0.01));

        final r2 = tracker.evaluate(
          raw,
          now: t0.add(const Duration(milliseconds: 200)),
        );
        expect(r2.stabilityProgress, closeTo(0.50, 0.01));

        final r3 = tracker.evaluate(
          raw,
          now: t0.add(const Duration(milliseconds: 400)),
        );
        expect(r3.stabilityProgress, closeTo(0.75, 0.01));

        final r4 = tracker.evaluate(
          raw,
          now: t0.add(const Duration(milliseconds: 600)),
        );
        expect(r4.status, DocumentDetectionStatus.readyToCapture);
        expect(r4.stabilityProgress, equals(1.0));

        // After marking captured, immediate subsequent frames do NOT re-trigger.
        tracker.markCaptured(t0.add(const Duration(milliseconds: 600)));
        final rCooldown = tracker.evaluate(
          raw,
          now: t0.add(const Duration(milliseconds: 1000)),
        );
        expect(rCooldown.status, DocumentDetectionStatus.alignedHoldSteady);
        expect(rCooldown.stabilityProgress, equals(0.0));
      },
    );

    test(
      'GalleryImportService validates formats, magic bytes, corrupt files, and cancellation',
      () async {
        final validJpg = _writeSampleJpgSync(tempDir, 'good.jpg');
        final fakeJpg = File('${tempDir.path}/corrupt.jpg');
        await fakeJpg.writeAsBytes([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
        final unsupported = File('${tempDir.path}/notes.txt');
        await unsupported.writeAsString('not an image');

        final cancelService = GalleryImportService(picker: () async => null);
        final cancelResult = await cancelService.pickAndValidateImages();
        expect(cancelResult.cancelled, isTrue);

        final mixedService = GalleryImportService(
          picker: () async => [validJpg, fakeJpg, unsupported],
        );
        final mixedResult = await mixedService.pickAndValidateImages();
        expect(mixedResult.cancelled, isFalse);
        expect(mixedResult.accepted.length, equals(1));
        expect(mixedResult.accepted.first.width, equals(120));
        expect(mixedResult.rejections.length, equals(2));
      },
    );
  });

  group('Phase 3 Widget & Integration Tests: Camera Studio & Capture Review', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('scaneliq_p3_widget_');
      await AppStorageService.instance.init(tempDir);
      await _openTestDb(tempDir);
    });

    tearDown(() async {
      await AppDatabaseService.instance.close();
      AppDatabaseService.instance.setDatabaseForTesting(null);
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets(
      'Camera initializing state transitions cleanly to Dark Camera Studio (#090A0D)',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final initCompleter = Completer<void>();
        final backend = FakeScannerCameraBackend()
          ..pendingInitCompleter = initCompleter;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(backend),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ContinuousCameraScreen(mode: ScanMode.batch),
            ),
          ),
        );
        await tester.pump();

        // Initializing indicator shown while controller init pending.
        expect(find.text('INITIALIZING CAMERA STUDIO'), findsOneWidget);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, ScaneliqColorPalette.cameraStudioBg);

        // Complete initialization -> transitions cleanly to preview & shutter.
        initCompleter.complete();
        await tester.pumpAndSettle();

        expect(find.text('AUTO'), findsOneWidget);
        expect(find.byTooltip('Flash mode'), findsOneWidget);
        expect(find.bySemanticsLabel('Capture document page'), findsOneWidget);
      },
    );

    testWidgets(
      'Permission denied and Camera error states render recovery controls cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Permission Denied state
        final deniedBackend = FakeScannerCameraBackend()
          ..errorOnInitialize = CameraException(
            'CameraAccessDeniedWithoutPrompt',
            'Permission disabled in Android settings',
          );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(deniedBackend),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ContinuousCameraScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PERMISSION RESTRICTED'), findsOneWidget);
        expect(find.text('Camera Access Required'), findsOneWidget);
        expect(find.text('Import from Gallery Instead'), findsOneWidget);

        // 2. Hardware unavailable / error state
        final errorBackend = FakeScannerCameraBackend(cameras: const []);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(errorBackend),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ContinuousCameraScreen(
                key: ValueKey('error_camera_studio'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CAMERA UNAVAILABLE'), findsOneWidget);
        expect(find.text('No Camera Detected'), findsOneWidget);
        expect(find.text('Retry Camera'), findsOneWidget);
        expect(find.text('Pick Images from Gallery'), findsOneWidget);
      },
    );

    testWidgets(
      'Manual capture, Auto/Manual toggle, repeated-tap protection, multi-page, and Gallery import',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final sample1 = _writeSampleJpgSync(tempDir, 'cap1.jpg', r: 245);
        final gallerySample = _writeSampleJpgSync(tempDir, 'gal1.jpg', g: 220);

        final backend = FakeScannerCameraBackend(nextCapturedFile: sample1);
        final galleryService = GalleryImportService(
          picker: () async => [gallerySample],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(backend),
              galleryImportServiceProvider.overrideWithValue(galleryService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ContinuousCameraScreen(mode: ScanMode.batch),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle Auto -> Manual mode.
        expect(find.text('AUTO'), findsOneWidget);
        await tester.tap(find.text('AUTO'));
        await tester.pumpAndSettle();
        expect(find.text('MANUAL'), findsOneWidget);
        expect(find.text('MANUAL MODE · TAP SHUTTER'), findsOneWidget);

        // Slow capture verifies rapid double-tap protection.
        final slowCapture = Completer<File>();
        backend.pendingCaptureCompleter = slowCapture;

        await tester.tap(find.bySemanticsLabel('Capture document page'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Capture document page'));
        await tester.pump();
        expect(backend.takePictureCount, equals(1));

        slowCapture.complete(sample1);
        for (int i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.text('Review (1)').evaluate().isNotEmpty &&
              find.text('CAPTURING FRAME...').evaluate().isEmpty) {
            break;
          }
        }
        backend.pendingCaptureCompleter = null;
        expect(find.text('Review (1)'), findsOneWidget);

        // Capture second page manually.
        await tester.tap(find.bySemanticsLabel('Capture document page'));
        for (int i = 0; i < 40; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.text('Review (2)').evaluate().isNotEmpty &&
              find.text('CAPTURING FRAME...').evaluate().isEmpty) {
            break;
          }
        }
        expect(find.text('Review (2)'), findsOneWidget);

        // Import third page from Gallery.
        await tester.tap(find.bySemanticsLabel('Import from gallery'));
        for (int i = 0; i < 40; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.text('Review (3)').evaluate().isNotEmpty &&
              find.text('IMPORTING GALLERY IMAGES...').evaluate().isEmpty) {
            break;
          }
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(find.text('Review (3)'), findsOneWidget);
        expect(find.text('03'), findsOneWidget);
      },
    );

    testWidgets(
      'Camera lifecycle pause/dispose and resume re-initializes cleanly without leaks',
      (tester) async {
        final backend = FakeScannerCameraBackend();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(backend),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ContinuousCameraScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(backend.initializeCount, equals(1));

        // Simulate app moving inactive -> paused.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        expect(backend.disposeCount, greaterThanOrEqualTo(1));
        expect(backend.isInitialized, isFalse);

        // Simulate returning to foreground -> resumed.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.hidden,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pumpAndSettle();
        expect(backend.initializeCount, equals(2));
        expect(backend.isInitialized, isTrue);
      },
    );

    testWidgets(
      'ReviewPagesScreen displays multi-page strip, supports delete, retake replacement, and Finish Capture PDF save',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final p1 = _writeSampleJpgSync(tempDir, 'rev1.jpg');
        final p2 = _writeSampleJpgSync(tempDir, 'rev2.jpg');
        final replacement = _writeSampleJpgSync(tempDir, 'rev_retake.jpg');

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          await container.read(scanSessionProvider.notifier).importFiles([
            p1,
            p2,
          ]);
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ReviewPagesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PAGE 01 OF 02'), findsOneWidget);
        expect(find.text('Finish Capture'), findsOneWidget);
        expect(find.text('Retake'), findsOneWidget);
        expect(find.text('Continue Editing'), findsOneWidget);

        // Programmatic retake updates page image cleanly while keeping page count = 2.
        final firstPageId = container.read(scanSessionProvider).pages.first.id;
        await tester.runAsync(() async {
          final ok = await container
              .read(scanSessionProvider.notifier)
              .retakePageWithFile(firstPageId, replacement);
          expect(ok, isTrue);
        });
        await tester.pumpAndSettle();
        expect(container.read(scanSessionProvider).pages.length, equals(2));

        // Delete page via Review UI confirmation dialog.
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Page 1?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        for (int i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.text('PAGE 01 OF 01').evaluate().isNotEmpty) break;
        }

        expect(container.read(scanSessionProvider).pages.length, equals(1));
        expect(find.text('PAGE 01 OF 01'), findsOneWidget);

        // Finish Capture saves non-draft PDF into SQLite and disk.
        await tester.tap(find.text('Finish Capture'));
        await tester.pump();
        for (int i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
          if (find.text('Saved to Scaneliq').evaluate().isNotEmpty) break;
        }

        expect(find.text('Saved to Scaneliq'), findsOneWidget);
        final docs = await tester.runAsync(
          () => AppDatabaseService.instance.getAllDocuments(),
        );
        expect(docs!.length, equals(1));
        expect(docs.first.isDraft, isFalse);
        expect(docs.first.exportPath, isNotNull);
        expect(File(docs.first.exportPath!).existsSync(), isTrue);
      },
    );

    testWidgets(
      'Narrow 320x640 responsive camera studio renders with zero overflow at 1.25x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final p1 = _writeSampleJpgSync(tempDir, 'narrow1.jpg');
        final backend = FakeScannerCameraBackend(nextCapturedFile: p1);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scannerCameraBackendProvider.overrideWithValue(backend),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.25),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const ContinuousCameraScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Capture document page'), findsOneWidget);
      },
    );

    testWidgets(
      'Auto detection evaluates live frames, renders DocumentBoundaryOverlay, and attaches convex PerspectiveQuad on capture',
      timeout: const Timeout(Duration(seconds: 8)),
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final capFile = _writeSampleJpgSync(tempDir, 'auto_cap.jpg');
        final backend = FakeScannerCameraBackend(nextCapturedFile: capFile);
        final container = ProviderContainer(
          overrides: [
            scannerCameraBackendProvider.overrideWithValue(backend),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ContinuousCameraScreen(mode: ScanMode.batch),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final docFrame = buildSyntheticDocumentFrame();
        final notifier = container.read(scannerStudioProvider.notifier);

        // Push 1 frame -> quad detected & stability overlay active.
        await tester.runAsync(() async {
          await notifier.processFrame(docFrame);
        });
        await tester.pump();
        expect(
          container.read(scannerStudioProvider).detection.quad,
          isNotNull,
        );
        expect(
          container.read(scannerStudioProvider).detection.stabilityProgress,
          closeTo(0.25, 0.01),
        );

        // Trigger capture with detected quad -> attaches non-destructive quad to EditRecipe.
        await tester.runAsync(() async {
          await notifier.capturePhoto();
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final session = container.read(scanSessionProvider);
        expect(session.pages.length, equals(1));
        expect(session.pages.first.editRecipe.hasPerspective, isTrue);
      },
    );
  });
}

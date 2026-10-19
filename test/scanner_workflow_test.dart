import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Phase 2: Scanner & Page Workflow Tests', () {
    late Database db;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_scanner_test_');
      await AppStorageService.instance.init(tempDir);

      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE folders (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                parent_id TEXT,
                created_at INTEGER NOT NULL,
                modified_at INTEGER NOT NULL,
                FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE tags (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                color INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                modified_at INTEGER NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE document_tags (
                document_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                PRIMARY KEY (document_id, tag_id),
                FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
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

            await db.execute('''
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

            await db.execute('''
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
    });

    tearDown(() async {
      await AppDatabaseService.instance.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'Image byte validation accurately identifies valid and corrupted headers',
      () {
        // Valid JPEG header: FF D8 FF
        final validJpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
        expect(AppStorageService.isValidImageBytes(validJpeg), isTrue);

        // Valid PNG header: 89 50 4E 47
        final validPng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        expect(AppStorageService.isValidImageBytes(validPng), isTrue);

        // Valid WebP header: RIFF .... WEBP
        final validWebp = [
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00,
          0x57, 0x45, 0x42, 0x50, // WEBP
        ];
        expect(AppStorageService.isValidImageBytes(validWebp), isTrue);

        // Corrupted / invalid headers
        expect(
          AppStorageService.isValidImageBytes([0x00, 0x01, 0x02]),
          isFalse,
        );
        expect(
          AppStorageService.isValidImageBytes([
            0xFF,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
          ]),
          isFalse,
        );
        expect(AppStorageService.isValidImageBytes([]), isFalse);
      },
    );

    test('AppStorageService saves original page atomically and rejects corrupt data', () async {
      final validJpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      final savedFile = await AppStorageService.instance.saveOriginalPage(
        'page_test_1',
        validJpegBytes,
      );

      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.path.contains('originals'), isTrue);
      expect(await savedFile.readAsBytes(), equals(validJpegBytes));

      expect(
        () => AppStorageService.instance.saveOriginalPage('corrupt_page', [
          1,
          2,
          3,
        ], validateHeader: true),
        throwsException,
      );
    });

    test(
      'EditRecipe supports non-destructive crop bounds and serialization',
      () {
        const defaultRecipe = EditRecipe();
        expect(defaultRecipe.hasCrop, isFalse);
        expect(defaultRecipe.cropLeft, 0.0);
        expect(defaultRecipe.cropRight, 1.0);

        const croppedRecipe = EditRecipe(
          cropLeft: 0.1,
          cropTop: 0.15,
          cropRight: 0.85,
          cropBottom: 0.9,
          rotationDegrees: 90,
          filter: PageFilter.whiteboard,
        );
        expect(croppedRecipe.hasCrop, isTrue);

        final map = croppedRecipe.toMap();
        final restored = EditRecipe.fromMap(map);

        expect(restored.cropLeft, equals(0.1));
        expect(restored.cropTop, equals(0.15));
        expect(restored.cropRight, equals(0.85));
        expect(restored.cropBottom, equals(0.9));
        expect(restored.rotationDegrees, equals(90));
        expect(restored.filter, equals(PageFilter.whiteboard));
      },
    );

    test(
      'PdfService.applyEditRecipe non-destructively crops and enhances image',
      () {
        // Create a test 200x200 image
        final original = img.Image(width: 200, height: 200);
        img.fill(original, color: img.ColorRgb8(240, 240, 240));

        // Apply 50% horizontal and vertical crop
        const recipe = EditRecipe(
          cropLeft: 0.25,
          cropTop: 0.25,
          cropRight: 0.75,
          cropBottom: 0.75,
          filter: PageFilter.blackAndWhite,
        );

        final processed = PdfService.applyEditRecipe(original, recipe);
        expect(processed.width, equals(100));
        expect(processed.height, equals(100));

        // Verify original image dimensions were not mutated (non-destructive safety)
        expect(original.width, equals(200));
        expect(original.height, equals(200));
      },
    );

    test('ScanSessionNotifier manages full multi-page workflow with draft recovery', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scanSessionProvider.notifier);

      // Create synthetic test image file
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(100, 150, 200));
      final testFile = File('${tempDir.path}/test_capture_1.jpg');
      await testFile.writeAsBytes(img.encodeJpg(testImage));

      // 1. Add first page
      final added1 = await notifier.addCapturedPage(testFile);
      expect(added1, isTrue);
      expect(container.read(scanSessionProvider).pages.length, equals(1));

      // 2. Add second page with whiteboard preset
      final testFile2 = File('${tempDir.path}/test_capture_2.jpg');
      await testFile2.writeAsBytes(img.encodeJpg(testImage));
      final added2 = await notifier.addCapturedPage(
        testFile2,
        recipe: const EditRecipe(filter: PageFilter.whiteboard),
      );
      expect(added2, isTrue);
      expect(container.read(scanSessionProvider).pages.length, equals(2));
      expect(
        container.read(scanSessionProvider).pages[1].editRecipe.filter,
        equals(PageFilter.whiteboard),
      );

      // 3. Verify SQLite draft persistence
      final draft = await AppDatabaseService.instance.getLatestDraft();
      expect(draft, isNotNull);
      expect(draft!.pageCount, equals(2));
      expect(draft.isDraft, isTrue);

      // 4. Retake page 1 with replacement image
      final testFile3 = File('${tempDir.path}/test_capture_3.jpg');
      await testFile3.writeAsBytes(img.encodeJpg(testImage));
      final page1Id = container.read(scanSessionProvider).pages[0].id;
      final retaken = await notifier.retakePageWithFile(page1Id, testFile3);
      expect(retaken, isTrue);

      // 5. Reorder pages
      await notifier.reorderPages(1, 0);
      expect(
        container.read(scanSessionProvider).pages[0].id,
        isNot(equals(page1Id)),
      );

      // 6. Remove page
      await notifier.removePage(page1Id);
      expect(container.read(scanSessionProvider).pages.length, equals(1));

      // Verify draft state updated
      final updatedDraft = await AppDatabaseService.instance.getLatestDraft();
      expect(updatedDraft!.pageCount, equals(1));
    });

    test(
      'ID Card 2-in-1 replacement replaces pages with single composite sheet',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(scanSessionProvider.notifier);

        // Create test stitched image
        final cardImage = img.Image(width: 300, height: 200);
        img.fill(cardImage, color: img.ColorRgb8(255, 255, 255));
        final cardFile = File('${tempDir.path}/test_id_stitched.jpg');
        await cardFile.writeAsBytes(img.encodeJpg(cardImage));

        // Replace with single composite page
        await notifier.replaceWithSinglePage(cardFile);

        final session = container.read(scanSessionProvider);
        expect(session.pages.length, equals(1));
        expect(session.pages.first.pageOrder, equals(0));
        expect(File(session.pages.first.originalPath).existsSync(), isTrue);
      },
    );
  });
}

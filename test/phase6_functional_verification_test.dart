import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Database testDb;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_phase6_test_');
    await AppStorageService.instance.init(tempDir);

    final dbPath = p.join(tempDir.path, 'test_scaneliq_p6.db');
    testDb = await openDatabase(
      dbPath,
      version: 5,
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
      },
    );

    AppDatabaseService.instance.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    await AppDatabaseService.instance.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 6 Functional Verification Tests', () {
    test(
      'ScanSessionNotifier.removePage deletes processed cache file from disk',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(scanSessionProvider.notifier);

        // Create dummy image file
        final sample = img.Image(width: 50, height: 50);
        img.fill(sample, color: img.ColorRgb8(100, 150, 200));
        final testImageFile = File(p.join(tempDir.path, 'sample_page.jpg'));
        await testImageFile.writeAsBytes(img.encodeJpg(sample));

        // Add captured page
        await notifier.addCapturedPage(testImageFile);
        final sessionState = container.read(scanSessionProvider);
        expect(sessionState.pages.length, 1);
        final pageId = sessionState.pages.first.id;

        // Simulate a processed file created for this page
        final processedFile = File(
          p.join(
            AppStorageService.instance.processedDir.path,
            '${pageId}_proc.jpg',
          ),
        );
        await processedFile.writeAsBytes([1, 2, 3, 4, 5]);
        expect(await processedFile.exists(), isTrue);

        // Remove the page
        await notifier.removePage(pageId);

        // Verify page is removed from session
        final updatedState = container.read(scanSessionProvider);
        expect(updatedState.pages.isEmpty, isTrue);

        // Verify processed file is deleted from disk
        expect(await processedFile.exists(), isFalse);
      },
    );

    test(
      'Unicode and Special Character Search retrieves matching documents',
      () async {
        final db = AppDatabaseService.instance;
        final now = DateTime.now();

        final doc1 = ScannedDocument(
          id: 'doc_unicode_1',
          title: 'বাংলা নথি চুক্তিপত্র ২০২৬',
          createdAt: now,
          modifiedAt: now,
          pageCount: 1,
        );
        final doc2 = ScannedDocument(
          id: 'doc_ascii_2',
          title: 'English Business Invoice #4092',
          createdAt: now,
          modifiedAt: now,
          pageCount: 1,
        );

        await db.saveDocument(doc1);
        await db.saveDocument(doc2);

        // Search with Bengali term
        final bengaliResults = await db.getAllDocuments(
          searchQuery: 'চুক্তিপত্র',
        );
        expect(bengaliResults.length, 1);
        expect(bengaliResults.first.id, 'doc_unicode_1');

        // Search with English number / symbol
        final numResults = await db.getAllDocuments(searchQuery: '#4092');
        expect(numResults.length, 1);
        expect(numResults.first.id, 'doc_ascii_2');
      },
    );

    test(
      'Soft delete to Trash, batch restore, and permanent deletion cleanups',
      () async {
        final db = AppDatabaseService.instance;
        final now = DateTime.now();

        // Create a document with a physical page file
        final pageFile = File(
          p.join(
            AppStorageService.instance.originalsDir.path,
            'p_trash_test.jpg',
          ),
        );
        await pageFile.writeAsBytes([10, 20, 30, 40]);

        final doc = ScannedDocument(
          id: 'doc_to_trash',
          title: 'Confidential Tax Record',
          createdAt: now,
          modifiedAt: now,
          pageCount: 1,
        );
        final page = DocumentPage(
          id: 'p_trash_test',
          documentId: 'doc_to_trash',
          pageOrder: 0,
          originalPath: pageFile.path,
        );

        await db.saveDocumentWithPages(doc, [page]);

        // Move to trash
        await db.moveToTrash(doc.id);
        var activeDocs = await db.getAllDocuments();
        expect(activeDocs.any((d) => d.id == doc.id), isFalse);

        var trashDocs = await db.getAllDocuments(onlyTrashed: true);
        expect(trashDocs.any((d) => d.id == doc.id), isTrue);

        // Restore
        await db.restoreFromTrash(doc.id);
        activeDocs = await db.getAllDocuments();
        expect(activeDocs.any((d) => d.id == doc.id), isTrue);

        trashDocs = await db.getAllDocuments(onlyTrashed: true);
        expect(trashDocs.any((d) => d.id == doc.id), isFalse);

        // Permanently delete
        await db.permanentlyDelete(doc.id);
        activeDocs = await db.getAllDocuments();
        trashDocs = await db.getAllDocuments(onlyTrashed: true);
        expect(activeDocs.any((d) => d.id == doc.id), isFalse);
        expect(trashDocs.any((d) => d.id == doc.id), isFalse);
        expect(await pageFile.exists(), isFalse);
      },
    );

    test(
      'Path basename handles mixed and platform-specific separators reliably',
      () {
        final winPath = r'C:\Users\Scaneliq\Documents\backup_20261019.scaneliq';
        final posixPath =
            '/data/user/0/com.scaneliq.app/files/backup_20261019.scaneliq';

        expect(
          p.basename(winPath.replaceAll(r'\', '/')),
          'backup_20261019.scaneliq',
        );
        expect(p.basename(posixPath), 'backup_20261019.scaneliq');
      },
    );
  });
}

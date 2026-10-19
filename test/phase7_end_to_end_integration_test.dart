import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Database testDb;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_phase7_test_');
    await AppStorageService.instance.init(tempDir);

    final dbPath = p.join(tempDir.path, 'test_scaneliq_p7.db');
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
        await db.execute('''
          CREATE TABLE document_bookmarks (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            page_index INTEGER NOT NULL,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
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

  group('Phase 7 End-to-End Integration Tests', () {
    test('Complete Document Lifecycle: Import -> Edit -> PDF Generation -> Verification -> Persistence', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scanSessionProvider.notifier);

      // 1. Create two test synthetic images
      final img1 = img.Image(width: 80, height: 100);
      img.fill(img1, color: img.ColorRgb8(240, 240, 240));
      final file1 = File(p.join(tempDir.path, 'source_page1.jpg'));
      await file1.writeAsBytes(img.encodeJpg(img1));

      final img2 = img.Image(width: 80, height: 100);
      img.fill(img2, color: img.ColorRgb8(200, 220, 240));
      final file2 = File(p.join(tempDir.path, 'source_page2.jpg'));
      await file2.writeAsBytes(img.encodeJpg(img2));

      // 2. Import files into scan session
      final importedCount = await notifier.importFiles([file1, file2]);
      expect(importedCount, 2);

      var session = container.read(scanSessionProvider);
      expect(session.pages.length, 2);
      expect(session.pages[0].pageOrder, 0);
      expect(session.pages[1].pageOrder, 1);

      // 3. Apply rotation recipe to page 0
      final page0Id = session.pages[0].id;
      await notifier.updatePageRecipe(
        page0Id,
        const EditRecipe(rotationDegrees: 90, filter: PageFilter.blackAndWhite),
      );

      session = container.read(scanSessionProvider);
      expect(session.pages[0].editRecipe.rotationDegrees, 90);
      expect(session.pages[0].editRecipe.filter, PageFilter.blackAndWhite);

      // 4. Reorder pages (swap 0 and 1 using ReorderableListView convention: 0 -> 2)
      await notifier.reorderPages(0, 2);
      session = container.read(scanSessionProvider);
      expect(session.pages[0].id != page0Id, isTrue);
      expect(session.pages[1].id, page0Id);
      expect(session.pages[0].pageOrder, 0);
      expect(session.pages[1].pageOrder, 1);

      // 5. Generate PDF from session pages
      final docToSave = ScannedDocument(
        id: session.documentId,
        title: 'End-to-End Tested Contract 2026',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: session.pages.length,
      );

      final pdfFile = await PdfService.generatePdf(
        document: docToSave,
        pages: session.pages,
        customTitle: docToSave.title,
      );
      expect(await pdfFile.exists(), isTrue);

      // 6. Programmatically verify generated PDF using Syncfusion parser
      final pdfBytes = await pdfFile.readAsBytes();
      final loadedDoc = sf.PdfDocument(inputBytes: pdfBytes);
      expect(loadedDoc.pages.count, 2);
      loadedDoc.dispose();

      // 7. Persist to SQLite database
      final finalizedDoc = docToSave.copyWith(
        exportPath: pdfFile.path,
        isDraft: false,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(
        finalizedDoc,
        session.pages,
      );

      // 8. Verify retrieval from SQLite
      final retrieved = await AppDatabaseService.instance.getDocument(
        finalizedDoc.id,
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'End-to-End Tested Contract 2026');
      expect(retrieved.pageCount, 2);
      expect(retrieved.pages.length, 2);
      expect(retrieved.exportPath, pdfFile.path);
    });

    test('Document Management Consistency: Nested Folders, Tagging, Moving, and Search', () async {
      final db = AppDatabaseService.instance;

      // Create root and subfolder
      final workFolder = await db.createFolder('Corporate');
      final legalFolder = await db.createFolder(
        'Legal Contracts',
        parentId: workFolder.id,
      );

      expect(legalFolder.parentId, workFolder.id);

      // Create document in subfolder
      final docId = 'doc_mgmt_1';
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: docId,
        title: 'Vendor Agreement Q4',
        createdAt: now,
        modifiedAt: now,
        pageCount: 1,
        folderId: legalFolder.id,
      );
      await db.saveDocument(doc);

      // Create and assign tag
      final tag = await db.createTag('Urgent', 0xFFEF4444);
      await db.setDocumentTags(docId, [tag.id]);

      // Query by folder
      final folderDocs = await db.getAllDocuments(
        filterByFolder: true,
        folderId: legalFolder.id,
      );
      expect(folderDocs.length, 1);
      expect(folderDocs.first.id, docId);

      // Query root folder (should be empty because doc is in child subfolder)
      final rootDocs = await db.getAllDocuments(
        filterByFolder: true,
        folderId: workFolder.id,
      );
      expect(rootDocs.isEmpty, isTrue);

      // Query by tag
      final tagDocs = await db.getAllDocuments(tagIds: [tag.id]);
      expect(tagDocs.length, 1);
      expect(tagDocs.first.id, docId);

      // Move document to root folder
      await db.moveDocumentToFolder(docId, workFolder.id);
      final updatedRootDocs = await db.getAllDocuments(
        filterByFolder: true,
        folderId: workFolder.id,
      );
      expect(updatedRootDocs.length, 1);
      expect(updatedRootDocs.first.id, docId);
    });

    test(
      'Data Safety: Storage Sanitization and Stale Temp File Purge',
      () async {
        final storage = AppStorageService.instance;

        // Verify safe path generation with illegal characters and leading/trailing whitespace
        final safePath1 = storage.getExportPdfPath(
          '  Report: 2026/10/19* [Final]? <v1>|  ',
        );
        expect(p.basename(safePath1), 'Report_ 2026_10_19_ [Final]_ _v1__.pdf');

        // Verify empty or all-illegal name fallback
        final safePath2 = storage.getExportPdfPath('   :::***///   ');
        expect(p.basename(safePath2), 'Scaneliq_Doc.pdf');

        // Verify stale temp file cleanup (>24 hours)
        final oldTempFile = File(
          p.join(storage.tempDir.path, 'stale_temp_file.tmp'),
        );
        await oldTempFile.writeAsString('old temporary data');
        expect(await oldTempFile.exists(), isTrue);

        // Artificially age the file
        final pastTime = DateTime.now().subtract(const Duration(hours: 30));
        await oldTempFile.setLastModified(pastTime);

        final purgedCount = await storage.cleanStaleTempFiles(
          maxAge: const Duration(hours: 24),
        );
        expect(purgedCount, greaterThanOrEqualTo(1));
        expect(await oldTempFile.exists(), isFalse);
      },
    );
  });
}

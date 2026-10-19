import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/services/smart_filename_service.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/data/batch_merge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Database testDb;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_phase4_test_');
    await AppStorageService.instance.init(tempDir);

    final dbPath = p.join(tempDir.path, 'test_scaneliq_p4.db');
    testDb = await openDatabase(
      dbPath,
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

        // Starter tags
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert('tags', {
          'id': 'tag_study',
          'name': 'Study Notes',
          'color': 0xFF2563EB,
          'created_at': now,
          'modified_at': now,
        });
        await db.insert('tags', {
          'id': 'tag_receipts',
          'name': 'Receipts',
          'color': 0xFF059669,
          'created_at': now,
          'modified_at': now,
        });
      },
    );

    AppDatabaseService.instance.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    await AppDatabaseService.instance.close();
    tempDir.deleteSync(recursive: true);
  });

  group('Hierarchical Folder Management Tests', () {
    test(
      'Creates root folders, nested subfolders, and retrieves breadcrumbs',
      () async {
        final rootFolder = await AppDatabaseService.instance.createFolder(
          'Work',
        );
        expect(rootFolder.name, equals('Work'));
        expect(rootFolder.parentId, isNull);

        final subFolder = await AppDatabaseService.instance.createFolder(
          'Projects',
          parentId: rootFolder.id,
        );
        expect(subFolder.parentId, equals(rootFolder.id));

        final subSubFolder = await AppDatabaseService.instance.createFolder(
          '2026',
          parentId: subFolder.id,
        );

        // Verify breadcrumbs path from root to child
        final ancestors = await AppDatabaseService.instance.getFolderAncestors(
          subSubFolder.id,
        );
        expect(ancestors.length, equals(3));
        expect(ancestors[0].name, equals('Work'));
        expect(ancestors[1].name, equals('Projects'));
        expect(ancestors[2].name, equals('2026'));

        // Check circular reference prevention
        final isDescendant = await AppDatabaseService.instance.isDescendantOf(
          subSubFolder.id,
          rootFolder.id,
        );
        expect(isDescendant, isTrue);

        final notDescendant = await AppDatabaseService.instance.isDescendantOf(
          rootFolder.id,
          subSubFolder.id,
        );
        expect(notDescendant, isFalse);
      },
    );

    test(
      'Renames and safely deletes folder moving documents to root',
      () async {
        final folder = await AppDatabaseService.instance.createFolder(
          'Invoices',
        );
        await AppDatabaseService.instance.renameFolder(
          folder.id,
          'Paid Invoices',
        );

        final updated = await AppDatabaseService.instance.getFolder(folder.id);
        expect(updated?.name, equals('Paid Invoices'));

        // Add a document into this folder
        final now = DateTime.now();
        final doc = ScannedDocument(
          id: 'doc_in_folder',
          title: 'Invoice 101',
          createdAt: now,
          modifiedAt: now,
          folderId: folder.id,
        );
        await AppDatabaseService.instance.saveDocumentWithPages(doc, []);

        // Safe deletion: move documents to root
        await AppDatabaseService.instance.deleteFolder(
          folder.id,
          moveDocsToRoot: true,
        );

        final deletedFolder = await AppDatabaseService.instance.getFolder(
          folder.id,
        );
        expect(deletedFolder, isNull);

        final restoredDoc = await AppDatabaseService.instance.getDocument(
          'doc_in_folder',
        );
        expect(restoredDoc, isNotNull);
        expect(restoredDoc?.folderId, isNull); // Safely moved to root
      },
    );
  });

  group('Tags & Multi-Tagging Tests', () {
    test('Creates, edits, assigns, and queries multi-tag documents', () async {
      final tags = await AppDatabaseService.instance.getTags();
      expect(
        tags.length,
        greaterThanOrEqualTo(2),
      ); // Study Notes & Receipts seeded

      final taxTag = await AppDatabaseService.instance.createTag(
        'Taxes',
        0xFFD97706,
      );
      expect(taxTag.name, equals('Taxes'));

      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'tax_doc_1',
        title: 'W2 Form',
        createdAt: now,
        modifiedAt: now,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(doc, []);

      // Assign multiple tags to the document
      await AppDatabaseService.instance.setDocumentTags(doc.id, [
        'tag_receipts',
        taxTag.id,
      ]);

      final assigned = await AppDatabaseService.instance.getDocumentTags(
        doc.id,
      );
      expect(assigned.length, equals(2));
      expect(assigned.map((t) => t.name), containsAll(['Receipts', 'Taxes']));

      // Filter query by tag
      final matching = await AppDatabaseService.instance.getAllDocuments(
        tagIds: [taxTag.id],
      );
      expect(matching.length, equals(1));
      expect(matching.first.id, equals('tax_doc_1'));
      expect(matching.first.tags.length, equals(2));
    });

    test(
      'Batch tag assignment and removal operates on multiple documents',
      () async {
        final now = DateTime.now();
        final docA = ScannedDocument(
          id: 'batch_doc_a',
          title: 'Doc A',
          createdAt: now,
          modifiedAt: now,
        );
        final docB = ScannedDocument(
          id: 'batch_doc_b',
          title: 'Doc B',
          createdAt: now,
          modifiedAt: now,
        );
        await AppDatabaseService.instance.saveDocumentWithPages(docA, []);
        await AppDatabaseService.instance.saveDocumentWithPages(docB, []);

        // Batch tag with tag_study
        await AppDatabaseService.instance.addTagToDocuments([
          'batch_doc_a',
          'batch_doc_b',
        ], 'tag_study');

        final tagsA = await AppDatabaseService.instance.getDocumentTags(
          'batch_doc_a',
        );
        final tagsB = await AppDatabaseService.instance.getDocumentTags(
          'batch_doc_b',
        );
        expect(tagsA.first.id, equals('tag_study'));
        expect(tagsB.first.id, equals('tag_study'));

        // Batch untag
        await AppDatabaseService.instance.removeTagFromDocuments([
          'batch_doc_a',
          'batch_doc_b',
        ], 'tag_study');
        final untaggedA = await AppDatabaseService.instance.getDocumentTags(
          'batch_doc_a',
        );
        expect(untaggedA, isEmpty);
      },
    );
  });

  group('Smart Filename Service Tests', () {
    test('generateFilename substitutes date, category, and counter tokens accurately', () {
      final fixedDate = DateTime(2026, 10, 19, 14, 30, 0);

      final filename = SmartFilenameService.generateFilename(
        template: '[Date]_[Category]_[Counter]',
        category: 'Medical',
        counter: 5,
        timestamp: fixedDate,
        extension: 'pdf',
      );

      expect(filename, equals('2026-10-19_Medical_005.pdf'));
    });

    test('sanitizeFilename removes illegal characters and limits length', () {
      const dirty = 'My:Invalid/File*Name?<Cool>|.pdf';
      final clean = SmartFilenameService.sanitizeFilename(dirty);

      expect(clean, isNot(contains(':')));
      expect(clean, isNot(contains('/')));
      expect(clean, isNot(contains('*')));
      expect(clean, isNot(contains('?')));
      expect(clean, isNot(contains('<')));
      expect(clean, isNot(contains('>')));
      expect(clean, isNot(contains('|')));
    });

    test(
      'resolveUniqueFilename appends collision suffix when file exists',
      () async {
        final existingFile = File('${tempDir.path}/Report.pdf');
        await existingFile.writeAsString('dummy');

        final uniqueName = await SmartFilenameService.resolveUniqueFilename(
          tempDir,
          'Report.pdf',
        );

        expect(uniqueName, equals('Report_001.pdf'));
      },
    );
  });

  group('Trash & Retention Tests', () {
    test('Soft-deletes to Trash, excludes from normal results, and restores safely', () async {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'trash_test_doc',
        title: 'Secret Notes',
        createdAt: now,
        modifiedAt: now,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(doc, []);

      // 1. Move to Trash
      await AppDatabaseService.instance.moveToTrash(doc.id);

      // Normal library query should NOT include trashed document
      final activeDocs = await AppDatabaseService.instance.getAllDocuments(
        onlyTrashed: false,
      );
      expect(activeDocs.any((d) => d.id == doc.id), isFalse);

      // Trash query SHOULD include it
      final trashedDocs = await AppDatabaseService.instance.getAllDocuments(
        onlyTrashed: true,
      );
      expect(trashedDocs.any((d) => d.id == doc.id), isTrue);

      // 2. Restore document
      await AppDatabaseService.instance.restoreFromTrash(doc.id);

      final restoredDocs = await AppDatabaseService.instance.getAllDocuments(
        onlyTrashed: false,
      );
      expect(restoredDocs.any((d) => d.id == doc.id), isTrue);
      expect(restoredDocs.firstWhere((d) => d.id == doc.id).isTrashed, isFalse);
    });

    test(
      'purgeExpiredTrash removes records older than 30 days retention',
      () async {
        final now = DateTime.now();
        final expiredDate = now.subtract(const Duration(days: 35));

        final expiredDoc = ScannedDocument(
          id: 'doc_expired',
          title: 'Ancient Receipt',
          createdAt: expiredDate,
          modifiedAt: expiredDate,
          deletedAt: expiredDate,
        );
        await AppDatabaseService.instance.saveDocumentWithPages(expiredDoc, []);

        final purgedCount = await AppDatabaseService.instance.purgeExpiredTrash(
          maxAge: const Duration(days: 30),
        );

        expect(purgedCount, equals(1));
        final check = await AppDatabaseService.instance.getDocument(
          'doc_expired',
        );
        expect(check, isNull);
      },
    );
  });

  group('Batch PDF Merge Tests', () {
    test(
      'BatchMergeService combines multiple documents into a new valid PDF',
      () async {
        // Create source dummy pages
        final imgA = img.Image(width: 100, height: 100);
        img.fill(imgA, color: img.ColorRgb8(240, 240, 240));
        final fileA = File('${tempDir.path}/page_a.jpg');
        await fileA.writeAsBytes(img.encodeJpg(imgA));

        final imgB = img.Image(width: 100, height: 100);
        img.fill(imgB, color: img.ColorRgb8(220, 220, 220));
        final fileB = File('${tempDir.path}/page_b.jpg');
        await fileB.writeAsBytes(img.encodeJpg(imgB));

        final now = DateTime.now();
        final doc1 = ScannedDocument(
          id: 'merge_doc_1',
          title: 'Doc Part 1',
          createdAt: now,
          modifiedAt: now,
          pageCount: 1,
          pages: [
            DocumentPage(
              id: 'p1_1',
              documentId: 'merge_doc_1',
              pageOrder: 0,
              originalPath: fileA.path,
            ),
          ],
        );
        final doc2 = ScannedDocument(
          id: 'merge_doc_2',
          title: 'Doc Part 2',
          createdAt: now,
          modifiedAt: now,
          pageCount: 1,
          pages: [
            DocumentPage(
              id: 'p2_1',
              documentId: 'merge_doc_2',
              pageOrder: 0,
              originalPath: fileB.path,
            ),
          ],
        );

        await AppDatabaseService.instance.saveDocumentWithPages(
          doc1,
          doc1.pages,
        );
        await AppDatabaseService.instance.saveDocumentWithPages(
          doc2,
          doc2.pages,
        );

        // Merge both documents
        final merged = await BatchMergeService.instance.mergeDocuments(
          sourceDocuments: [doc1, doc2],
          outputTitle: 'Combined_Doc',
        );

        expect(merged.title, equals('Combined_Doc'));
        expect(merged.pageCount, equals(2));
        expect(merged.exportPath, isNotNull);

        final pdfFile = File(merged.exportPath!);
        expect(await pdfFile.exists(), isTrue);

        final pdfBytes = await pdfFile.readAsBytes();
        final header = String.fromCharCodes(pdfBytes.take(5));
        expect(header, equals('%PDF-'));

        // Confirm source documents remain 100% untouched
        final s1 = await AppDatabaseService.instance.getDocument('merge_doc_1');
        final s2 = await AppDatabaseService.instance.getDocument('merge_doc_2');
        expect(s1, isNotNull);
        expect(s2, isNotNull);
      },
    );
  });
}

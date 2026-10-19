import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Database Persistence & Relations Tests', () {
    late Database db;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_db_test_');
      await AppStorageService.instance.init(tempDir);

      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE documents (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                modified_at INTEGER NOT NULL,
                page_count INTEGER NOT NULL DEFAULT 0,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                is_draft INTEGER NOT NULL DEFAULT 0,
                export_path TEXT
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

            await db.execute(
              'CREATE INDEX idx_pages_doc_order ON pages (document_id, page_order)',
            );
            await db.execute(
              'CREATE INDEX idx_docs_modified ON documents (modified_at DESC)',
            );
            await db.execute(
              'CREATE INDEX idx_ocr_doc ON document_ocr (document_id)',
            );
          },
        ),
      );

      AppDatabaseService.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      AppDatabaseService.instance.setDatabaseForTesting(null);
      tempDir.deleteSync(recursive: true);
    });

    test(
      'Persists document and related pages with correct page orders',
      () async {
        final doc = ScannedDocument(
          id: 'doc_persist_1',
          title: 'Invoice Q3',
          createdAt: DateTime(2026, 10, 1),
          modifiedAt: DateTime(2026, 10, 1),
          pageCount: 2,
        );

        final pages = [
          DocumentPage(
            id: 'p_1',
            documentId: doc.id,
            pageOrder: 0,
            originalPath: '/storage/originals/p_1.jpg',
          ),
          DocumentPage(
            id: 'p_2',
            documentId: doc.id,
            pageOrder: 1,
            originalPath: '/storage/originals/p_2.jpg',
          ),
        ];

        await AppDatabaseService.instance.saveDocumentWithPages(doc, pages);

        final fetched = await AppDatabaseService.instance.getDocument(
          'doc_persist_1',
        );
        expect(fetched, isNotNull);
        expect(fetched!.title, equals('Invoice Q3'));
        expect(fetched.pages.length, equals(2));
        expect(fetched.pages[0].id, equals('p_1'));
        expect(fetched.pages[0].pageOrder, equals(0));
        expect(fetched.pages[1].id, equals('p_2'));
        expect(fetched.pages[1].pageOrder, equals(1));
      },
    );

    test(
      'Reordering pages updates SQLite and retains new visual order on reload',
      () async {
        final doc = ScannedDocument(
          id: 'doc_reorder_1',
          title: 'Report Reorder Test',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 3,
        );

        final pages = [
          DocumentPage(
            id: 'page_a',
            documentId: doc.id,
            pageOrder: 0,
            originalPath: '/path/a.jpg',
          ),
          DocumentPage(
            id: 'page_b',
            documentId: doc.id,
            pageOrder: 1,
            originalPath: '/path/b.jpg',
          ),
          DocumentPage(
            id: 'page_c',
            documentId: doc.id,
            pageOrder: 2,
            originalPath: '/path/c.jpg',
          ),
        ];

        await AppDatabaseService.instance.saveDocumentWithPages(doc, pages);

        // Reorder: Move page_c to front: [page_c, page_a, page_b]
        final reordered = [pages[2], pages[0], pages[1]];
        await AppDatabaseService.instance.saveDocumentWithPages(doc, reordered);

        final reloaded = await AppDatabaseService.instance.getDocument(
          'doc_reorder_1',
        );
        expect(reloaded, isNotNull);
        expect(reloaded!.pages.length, equals(3));
        expect(reloaded.pages[0].id, equals('page_c'));
        expect(reloaded.pages[0].pageOrder, equals(0));
        expect(reloaded.pages[1].id, equals('page_a'));
        expect(reloaded.pages[1].pageOrder, equals(1));
        expect(reloaded.pages[2].id, equals('page_b'));
        expect(reloaded.pages[2].pageOrder, equals(2));
      },
    );

    test(
      'Draft recovery: getLatestDraft retrieves only unfinished draft sessions',
      () async {
        final finalizedDoc = ScannedDocument(
          id: 'final_doc',
          title: 'Finalized Document',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          modifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
          pageCount: 1,
          isDraft: false,
        );
        final draftDoc = ScannedDocument(
          id: 'active_draft',
          title: 'Unfinished Scan Session',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 1,
          isDraft: true,
        );

        await AppDatabaseService.instance.saveDocumentWithPages(finalizedDoc, [
          DocumentPage(
            id: 'p_fin',
            documentId: 'final_doc',
            pageOrder: 0,
            originalPath: '/f.jpg',
          ),
        ]);
        await AppDatabaseService.instance.saveDocumentWithPages(draftDoc, [
          DocumentPage(
            id: 'p_drf',
            documentId: 'active_draft',
            pageOrder: 0,
            originalPath: '/d.jpg',
          ),
        ]);

        final latestDraft = await AppDatabaseService.instance.getLatestDraft();
        expect(latestDraft, isNotNull);
        expect(latestDraft!.id, equals('active_draft'));
        expect(latestDraft.isDraft, isTrue);
        expect(latestDraft.title, equals('Unfinished Scan Session'));
      },
    );

    test('Favorites toggle updates SQLite flag', () async {
      final doc = ScannedDocument(
        id: 'fav_doc',
        title: 'Important Tax Form',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        isFavorite: false,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(doc, [
        DocumentPage(
          id: 'fav_p',
          documentId: 'fav_doc',
          pageOrder: 0,
          originalPath: '/fav.jpg',
        ),
      ]);

      await AppDatabaseService.instance.toggleFavorite('fav_doc', true);
      final updated = await AppDatabaseService.instance.getDocument('fav_doc');
      expect(updated!.isFavorite, isTrue);

      await AppDatabaseService.instance.toggleFavorite('fav_doc', false);
      final unfaved = await AppDatabaseService.instance.getDocument('fav_doc');
      expect(unfaved!.isFavorite, isFalse);
    });

    test('Search query filters documents by title in SQLite', () async {
      final docA = ScannedDocument(
        id: 'd_a',
        title: 'Electricity Bill',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final docB = ScannedDocument(
        id: 'd_b',
        title: 'Passport Copy',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );

      await AppDatabaseService.instance.saveDocumentWithPages(docA, []);
      await AppDatabaseService.instance.saveDocumentWithPages(docB, []);

      final results = await AppDatabaseService.instance.getAllDocuments(
        searchQuery: 'Passport',
      );
      expect(results.length, equals(1));
      expect(results.first.title, equals('Passport Copy'));
    });

    test('Document deletion cascades and removes records', () async {
      final doc = ScannedDocument(
        id: 'del_cascade_doc',
        title: 'Delete Me',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 2,
      );
      final pages = [
        DocumentPage(
          id: 'p_c1',
          documentId: doc.id,
          pageOrder: 0,
          originalPath: '/c1.jpg',
        ),
        DocumentPage(
          id: 'p_c2',
          documentId: doc.id,
          pageOrder: 1,
          originalPath: '/c2.jpg',
        ),
      ];

      await AppDatabaseService.instance.saveDocumentWithPages(doc, pages);
      expect(
        await AppDatabaseService.instance.getDocument('del_cascade_doc'),
        isNotNull,
      );

      await AppDatabaseService.instance.deleteDocument('del_cascade_doc');
      expect(
        await AppDatabaseService.instance.getDocument('del_cascade_doc'),
        isNull,
      );

      final remainingPages = await db.query(
        'pages',
        where: 'document_id = ?',
        whereArgs: ['del_cascade_doc'],
      );
      expect(remainingPages.isEmpty, isTrue);
    });

    test('Saves and searches OCR full text across documents', () async {
      final doc1 = ScannedDocument(
        id: 'doc_ocr_1',
        title: 'Document Alpha',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final doc2 = ScannedDocument(
        id: 'doc_ocr_2',
        title: 'Document Beta',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );

      await AppDatabaseService.instance.saveDocumentWithPages(doc1, []);
      await AppDatabaseService.instance.saveDocumentWithPages(doc2, []);

      await AppDatabaseService.instance.saveDocumentOcr(
        'doc_ocr_1',
        'Invoice for consulting services rendered by Dr. John Watson in London.',
      );
      await AppDatabaseService.instance.saveDocumentOcr(
        'doc_ocr_2',
        'Official prescription for penicillin from St. Jude Hospital.',
      );

      // Search by OCR content: 'Watson' matches doc1, not doc2
      final resultsWatson = await AppDatabaseService.instance.getAllDocuments(
        searchQuery: 'Watson',
      );
      expect(resultsWatson.length, equals(1));
      expect(resultsWatson.first.id, equals('doc_ocr_1'));

      // Search by OCR content: 'penicillin' matches doc2, not doc1
      final resultsPenicillin = await AppDatabaseService.instance
          .getAllDocuments(searchQuery: 'penicillin');
      expect(resultsPenicillin.length, equals(1));
      expect(resultsPenicillin.first.id, equals('doc_ocr_2'));

      // Search by title still works
      final resultsAlpha = await AppDatabaseService.instance.getAllDocuments(
        searchQuery: 'Alpha',
      );
      expect(resultsAlpha.length, equals(1));
      expect(resultsAlpha.first.id, equals('doc_ocr_1'));

      // Deleting doc1 removes OCR record
      await AppDatabaseService.instance.deleteDocument('doc_ocr_1');
      final ocrRecord = await AppDatabaseService.instance.getDocumentOcr(
        'doc_ocr_1',
      );
      expect(ocrRecord, isNull);
    });
  });
}

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';

/// Database service using SQLite with schema versioning and transactional operations
class AppDatabaseService {
  static AppDatabaseService? _instance;
  static AppDatabaseService get instance =>
      _instance ??= AppDatabaseService._();
  AppDatabaseService._();

  Database? _db;

  /// Sets an explicit database instance for testing
  void setDatabaseForTesting(Database? db) {
    _db = db;
  }

  /// Closes database connection
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'scaneliq.db');

    return await openDatabase(
      path,
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE documents ADD COLUMN is_draft INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS document_ocr (
              document_id TEXT PRIMARY KEY,
              full_text TEXT NOT NULL,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_ocr_doc ON document_ocr (document_id)',
          );
        }
      },
    );
  }

  /// Saves or updates the OCR text for a document
  Future<void> saveDocumentOcr(String documentId, String fullText) async {
    if (fullText.trim().isEmpty) return;
    final db = await database;
    await db.insert(
      'document_ocr',
      {'document_id': documentId, 'full_text': fullText.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves the OCR text for a document if available
  Future<String?> getDocumentOcr(String documentId) async {
    final db = await database;
    final rows = await db.query(
      'document_ocr',
      columns: ['full_text'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['full_text'] as String?;
  }

  /// Inserts or updates a document and its pages atomically in a transaction
  Future<void> saveDocumentWithPages(
    ScannedDocument doc,
    List<DocumentPage> pages,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'documents',
        doc.copyWith(pageCount: pages.length).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Re-insert ordered pages
      await txn.delete('pages', where: 'document_id = ?', whereArgs: [doc.id]);
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i].copyWith(pageOrder: i);
        await txn.insert(
          'pages',
          page.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Retrieves all documents sorted by modified_at descending, supporting full-text search
  Future<List<ScannedDocument>> getAllDocuments({String? searchQuery}) async {
    final db = await database;
    List<Map<String, dynamic>> docRows;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      docRows = await db.rawQuery('''
        SELECT DISTINCT d.* FROM documents d
        LEFT JOIN document_ocr o ON d.id = o.document_id
        WHERE d.title LIKE ? OR o.full_text LIKE ?
        ORDER BY d.modified_at DESC
      ''', [term, term]);
    } else {
      docRows = await db.query('documents', orderBy: 'modified_at DESC');
    }

    final List<ScannedDocument> results = [];
    for (final row in docRows) {
      final docId = row['id'] as String;
      final pageRows = await db.query(
        'pages',
        where: 'document_id = ?',
        whereArgs: [docId],
        orderBy: 'page_order ASC',
      );
      final pages = pageRows.map((p) => DocumentPage.fromMap(p)).toList();
      results.add(ScannedDocument.fromMap(row, pages: pages));
    }
    return results;
  }

  /// Retrieves the latest unfinished draft document if one exists
  Future<ScannedDocument?> getLatestDraft() async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      where: 'is_draft = 1',
      orderBy: 'modified_at DESC',
      limit: 1,
    );
    if (docRows.isEmpty) return null;

    final docId = docRows.first['id'] as String;
    final pageRows = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [docId],
      orderBy: 'page_order ASC',
    );
    final pages = pageRows.map((p) => DocumentPage.fromMap(p)).toList();
    if (pages.isEmpty) return null;

    return ScannedDocument.fromMap(docRows.first, pages: pages);
  }

  /// Retrieves a single document with all its ordered pages
  Future<ScannedDocument?> getDocument(String id) async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (docRows.isEmpty) return null;

    final pageRows = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [id],
      orderBy: 'page_order ASC',
    );
    final pages = pageRows.map((p) => DocumentPage.fromMap(p)).toList();
    return ScannedDocument.fromMap(docRows.first, pages: pages);
  }

  /// Deletes a document, cleans up associated storage files, and cascades to pages
  Future<void> deleteDocument(String id) async {
    final doc = await getDocument(id);
    if (doc != null) {
      await AppStorageService.instance.deleteDocumentFiles(doc);
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('pages', where: 'document_id = ?', whereArgs: [id]);
      await txn.delete('document_ocr', where: 'document_id = ?', whereArgs: [id]);
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Toggles favorite status
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'documents',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

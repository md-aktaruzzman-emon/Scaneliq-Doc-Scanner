import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';

/// Database service using SQLite with schema versioning, hierarchical folders,
/// tags, soft deletion (Trash), and batch management operations.
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
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        // 1. Folders table
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

        // 2. Documents table
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

        // 3. Pages table
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

        // 4. OCR text index table
        await db.execute('''
          CREATE TABLE document_ocr (
            document_id TEXT PRIMARY KEY,
            full_text TEXT NOT NULL,
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');

        // 5. Tags table
        await db.execute('''
          CREATE TABLE tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL
          )
        ''');

        // 6. Document-Tags join table
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

        // 6. Bookmarks table
        await db.execute('''
          CREATE TABLE document_bookmarks (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            page_number INTEGER NOT NULL,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');

        // Indexes
        await db.execute(
          'CREATE INDEX idx_pages_doc_order ON pages (document_id, page_order)',
        );
        await db.execute(
          'CREATE INDEX idx_docs_modified ON documents (modified_at DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_docs_folder ON documents (folder_id)',
        );
        await db.execute(
          'CREATE INDEX idx_docs_deleted ON documents (deleted_at)',
        );
        await db.execute(
          'CREATE INDEX idx_folders_parent ON folders (parent_id)',
        );
        await db.execute(
          'CREATE INDEX idx_doc_tags_doc ON document_tags (document_id)',
        );
        await db.execute(
          'CREATE INDEX idx_doc_tags_tag ON document_tags (tag_id)',
        );
        await db.execute(
          'CREATE INDEX idx_ocr_doc ON document_ocr (document_id)',
        );
        await db.execute(
          'CREATE INDEX idx_bookmarks_doc ON document_bookmarks (document_id)',
        );

        // Seed default starter categories
        await _seedStarterTags(db);
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
        if (oldVersion < 4) {
          // Folders table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parent_id TEXT,
              created_at INTEGER NOT NULL,
              modified_at INTEGER NOT NULL,
              FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders (parent_id)',
          );

          // Tags table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tags (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL UNIQUE,
              color INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              modified_at INTEGER NOT NULL
            )
          ''');

          // Document Tags table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS document_tags (
              document_id TEXT NOT NULL,
              tag_id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY (document_id, tag_id),
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
              FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_doc_tags_doc ON document_tags (document_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_doc_tags_tag ON document_tags (tag_id)',
          );

          // Alter documents table with folder_id and deleted_at
          try {
            await db.execute('ALTER TABLE documents ADD COLUMN folder_id TEXT');
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE documents ADD COLUMN deleted_at INTEGER',
            );
          } catch (_) {}

          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_docs_folder ON documents (folder_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_docs_deleted ON documents (deleted_at)',
          );

          await _seedStarterTags(db);
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS document_bookmarks (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              page_number INTEGER NOT NULL,
              title TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bookmarks_doc ON document_bookmarks (document_id)',
          );
        }
      },
    );
  }

  /// Seeds default starter tags if none exist
  static Future<void> _seedStarterTags(DatabaseExecutor db) async {
    final existing = await db.query('tags', limit: 1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final starters = [
      {'name': 'Study Notes', 'color': 0xFF2563EB},
      {'name': 'Receipts', 'color': 0xFF059669},
      {'name': 'Invoices', 'color': 0xFFD97706},
      {'name': 'Certificates', 'color': 0xFF7C3AED},
      {'name': 'Personal', 'color': 0xFFEC4899},
      {'name': 'Work', 'color': 0xFF0284C7},
      {'name': 'Legal', 'color': 0xFFDC2626},
    ];

    for (final s in starters) {
      await db.insert('tags', {
        'id': const Uuid().v4(),
        'name': s['name'],
        'color': s['color'],
        'created_at': now,
        'modified_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ===========================================================================
  // FOLDER MANAGEMENT
  // ===========================================================================

  /// Creates a new folder or subfolder
  Future<DocumentFolder> createFolder(String name, {String? parentId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name cannot be empty');

    final db = await database;
    final now = DateTime.now();
    final folder = DocumentFolder(
      id: const Uuid().v4(),
      name: trimmed,
      parentId: parentId,
      createdAt: now,
      modifiedAt: now,
    );

    await db.insert('folders', folder.toMap());
    return folder;
  }

  /// Renames an existing folder
  Future<void> renameFolder(String folderId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name cannot be empty');

    final db = await database;
    await db.update(
      'folders',
      {'name': trimmed, 'modified_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  /// Retrieves folders with their active document counts
  Future<List<DocumentFolder>> getFolders({String? parentId}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (parentId == null) {
      rows = await db.query(
        'folders',
        where: 'parent_id IS NULL',
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query(
        'folders',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC',
      );
    }

    final List<DocumentFolder> result = [];
    for (final row in rows) {
      final fId = row['id'] as String;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM documents WHERE folder_id = ? AND deleted_at IS NULL',
        [fId],
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      result.add(DocumentFolder.fromMap(row, documentCount: count));
    }

    return result;
  }

  /// Retrieves a single folder by ID
  Future<DocumentFolder?> getFolder(String folderId) async {
    final db = await database;
    final rows = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM documents WHERE folder_id = ? AND deleted_at IS NULL',
      [folderId],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    return DocumentFolder.fromMap(rows.first, documentCount: count);
  }

  /// Retrieves hierarchical breadcrumb ancestors (from root folder down to immediate parent)
  Future<List<DocumentFolder>> getFolderAncestors(String folderId) async {
    final List<DocumentFolder> ancestors = [];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = await getFolder(currentId);
      if (folder == null) break;
      ancestors.insert(0, folder);
      currentId = folder.parentId;
    }

    return ancestors;
  }

  /// Checks if childId is a descendant of parentId (prevents circular loops)
  Future<bool> isDescendantOf(
    String potentialChildId,
    String potentialAncestorId,
  ) async {
    if (potentialChildId == potentialAncestorId) return true;

    final db = await database;
    String? currentParentId = potentialChildId;

    while (currentParentId != null) {
      final rows = await db.query(
        'folders',
        columns: ['parent_id'],
        where: 'id = ?',
        whereArgs: [currentParentId],
        limit: 1,
      );
      if (rows.isEmpty) break;
      currentParentId = rows.first['parent_id'] as String?;
      if (currentParentId == potentialAncestorId) return true;
    }

    return false;
  }

  /// Safely deletes a folder, updating documents according to user policy
  Future<void> deleteFolder(
    String folderId, {
    bool moveDocsToRoot = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (moveDocsToRoot) {
        // Move documents to root (folder_id = NULL)
        await txn.update(
          'documents',
          {'folder_id': null, 'modified_at': now},
          where: 'folder_id = ?',
          whereArgs: [folderId],
        );
      } else {
        // Move documents to Trash
        await txn.update(
          'documents',
          {'deleted_at': now, 'modified_at': now},
          where: 'folder_id = ?',
          whereArgs: [folderId],
        );
      }

      // Reparent child subfolders to deleted folder's parent
      final folderRows = await txn.query(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
        limit: 1,
      );
      final parentId = folderRows.isNotEmpty
          ? folderRows.first['parent_id']
          : null;

      await txn.update(
        'folders',
        {'parent_id': parentId, 'modified_at': now},
        where: 'parent_id = ?',
        whereArgs: [folderId],
      );

      // Delete folder record
      await txn.delete('folders', where: 'id = ?', whereArgs: [folderId]);
    });
  }

  // ===========================================================================
  // TAGS & CATEGORIES MANAGEMENT
  // ===========================================================================

  /// Retrieves all configured tags
  Future<List<DocumentTag>> getTags() async {
    final db = await database;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map((r) => DocumentTag.fromMap(r)).toList();
  }

  /// Creates a new tag
  Future<DocumentTag> createTag(String name, int colorValue) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tag name cannot be empty');

    final db = await database;
    final now = DateTime.now();
    final tag = DocumentTag(
      id: const Uuid().v4(),
      name: trimmed,
      colorValue: colorValue,
      createdAt: now,
      modifiedAt: now,
    );

    await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return tag;
  }

  /// Renames or changes color of a tag
  Future<void> updateTag(String tagId, String newName, int newColor) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tag name cannot be empty');

    final db = await database;
    await db.update(
      'tags',
      {
        'name': trimmed,
        'color': newColor,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [tagId],
    );
  }

  /// Deletes a tag globally and removes its associations from documents
  Future<void> deleteTag(String tagId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'document_tags',
        where: 'tag_id = ?',
        whereArgs: [tagId],
      );
      await txn.delete('tags', where: 'id = ?', whereArgs: [tagId]);
    });
  }

  /// Retrieves all tags assigned to a specific document
  Future<List<DocumentTag>> getDocumentTags(String documentId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tags t
      INNER JOIN document_tags dt ON t.id = dt.tag_id
      WHERE dt.document_id = ?
      ORDER BY t.name ASC
    ''',
      [documentId],
    );
    return rows.map((r) => DocumentTag.fromMap(r)).toList();
  }

  /// Sets the exact list of tags assigned to a document
  Future<void> setDocumentTags(String documentId, List<String> tagIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'document_tags',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final tId in tagIds) {
        await txn.insert('document_tags', {
          'document_id': documentId,
          'tag_id': tId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Adds a tag to multiple documents (Batch Tag)
  Future<void> addTagToDocuments(List<String> documentIds, String tagId) async {
    if (documentIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final dId in documentIds) {
        await txn.insert('document_tags', {
          'document_id': dId,
          'tag_id': tagId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Removes a tag from multiple documents (Batch Untag)
  Future<void> removeTagFromDocuments(
    List<String> documentIds,
    String tagId,
  ) async {
    if (documentIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final dId in documentIds) {
        await txn.delete(
          'document_tags',
          where: 'document_id = ? AND tag_id = ?',
          whereArgs: [dId, tagId],
        );
      }
    });
  }

  // ===========================================================================
  // SOFT DELETION, TRASH & RESTORATION
  // ===========================================================================

  /// Moves a document to Trash (soft delete)
  Future<void> moveToTrash(String documentId) async {
    final db = await database;
    await db.update(
      'documents',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Moves multiple documents to Trash (Batch Trash)
  Future<void> moveDocumentsToTrash(List<String> documentIds) async {
    if (documentIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in documentIds) {
        await txn.update(
          'documents',
          {'deleted_at': now, 'modified_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Restores a soft-deleted document from Trash
  Future<void> restoreFromTrash(String documentId) async {
    final db = await database;
    // Check if original folder still exists
    final docRows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    String? validFolderId;
    if (docRows.isNotEmpty) {
      final fId = docRows.first['folder_id'] as String?;
      if (fId != null) {
        final folderCheck = await db.query(
          'folders',
          where: 'id = ?',
          whereArgs: [fId],
          limit: 1,
        );
        if (folderCheck.isNotEmpty) {
          validFolderId = fId;
        }
      }
    }

    await db.update(
      'documents',
      {
        'deleted_at': null,
        'folder_id': validFolderId,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Restores multiple documents from Trash (Batch Restore)
  Future<void> restoreDocumentsFromTrash(List<String> documentIds) async {
    for (final id in documentIds) {
      await restoreFromTrash(id);
    }
  }

  /// Permanently deletes a document and all its original files from disk
  Future<void> permanentlyDelete(String id) async {
    final doc = await getDocument(id);
    if (doc != null) {
      await AppStorageService.instance.deleteDocumentFiles(doc);
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'document_tags',
        where: 'document_id = ?',
        whereArgs: [id],
      );
      await txn.delete('pages', where: 'document_id = ?', whereArgs: [id]);
      await txn.delete(
        'document_ocr',
        where: 'document_id = ?',
        whereArgs: [id],
      );
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Backward-compatible alias for permanently deleting a document
  Future<void> deleteDocument(String id) => permanentlyDelete(id);

  /// Permanently deletes multiple documents (Batch Permanent Delete)
  Future<void> permanentlyDeleteDocuments(List<String> documentIds) async {
    for (final id in documentIds) {
      await permanentlyDelete(id);
    }
  }

  /// Automatically purges trashed documents older than maxAge (default: 30 days)
  Future<int> purgeExpiredTrash({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    final expiredRows = await db.query(
      'documents',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff],
    );

    int count = 0;
    for (final row in expiredRows) {
      final docId = row['id'] as String;
      await permanentlyDelete(docId);
      count++;
    }

    return count;
  }

  // ===========================================================================
  // DOCUMENT MOVING & BATCH FOLDER ASSIGNMENT
  // ===========================================================================

  /// Moves a document to a folder (or root if folderId is null)
  Future<void> moveDocumentToFolder(String documentId, String? folderId) async {
    final db = await database;
    await db.update(
      'documents',
      {
        'folder_id': folderId,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Moves multiple documents to a folder (Batch Move)
  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  ) async {
    if (documentIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in documentIds) {
        await txn.update(
          'documents',
          {'folder_id': folderId, 'modified_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  // ===========================================================================
  // DOCUMENT SAVING & RETRIEVAL WITH FILTERS
  // ===========================================================================

  /// Inserts or updates a document record directly (e.g. for PDF tools exports or imports)
  Future<void> saveDocument(ScannedDocument doc) async {
    final db = await database;
    await db.insert(
      'documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
        doc
            .copyWith(
              pageCount: pages.isNotEmpty ? pages.length : doc.pageCount,
            )
            .toMap(),
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

  /// Retrieves documents supporting multi-criteria filtering (folder, tags, favorites, search, trash)
  Future<List<ScannedDocument>> getAllDocuments({
    String? searchQuery,
    String? folderId,
    bool filterByFolder = false,
    List<String>? tagIds,
    bool? isFavorite,
    bool onlyTrashed = false,
  }) async {
    final db = await database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    // Trash state filter
    if (onlyTrashed) {
      whereClauses.add('d.deleted_at IS NOT NULL');
    } else {
      whereClauses.add('d.deleted_at IS NULL');
    }

    // Folder filter
    if (filterByFolder) {
      if (folderId == null) {
        whereClauses.add('d.folder_id IS NULL');
      } else {
        whereClauses.add('d.folder_id = ?');
        whereArgs.add(folderId);
      }
    }

    // Favorite filter
    if (isFavorite == true) {
      whereClauses.add('d.is_favorite = 1');
    }

    // Title / OCR full-text search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      whereClauses.add('(d.title LIKE ? OR o.full_text LIKE ?)');
      whereArgs.add(term);
      whereArgs.add(term);
    }

    // Tag filter (must have at least one of selected tags)
    String tagJoin = '';
    if (tagIds != null && tagIds.isNotEmpty) {
      final placeholders = List.filled(tagIds.length, '?').join(',');
      tagJoin =
          'INNER JOIN document_tags dt ON d.id = dt.document_id AND dt.tag_id IN ($placeholders)';
      whereArgs.addAll(tagIds);
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final query =
        '''
      SELECT DISTINCT d.* FROM documents d
      LEFT JOIN document_ocr o ON d.id = o.document_id
      $tagJoin
      $whereSql
      ORDER BY d.modified_at DESC
    ''';

    final docRows = await db.rawQuery(query, whereArgs);

    final List<ScannedDocument> results = [];
    for (final row in docRows) {
      final docId = row['id'] as String;

      // Load pages
      final pageRows = await db.query(
        'pages',
        where: 'document_id = ?',
        whereArgs: [docId],
        orderBy: 'page_order ASC',
      );
      final pages = pageRows.map((p) => DocumentPage.fromMap(p)).toList();

      // Load tags
      final tagRows = await db.rawQuery(
        '''
        SELECT t.* FROM tags t
        INNER JOIN document_tags dt ON t.id = dt.tag_id
        WHERE dt.document_id = ?
        ORDER BY t.name ASC
      ''',
        [docId],
      );
      final tags = tagRows.map((t) => DocumentTag.fromMap(t)).toList();

      results.add(ScannedDocument.fromMap(row, pages: pages, tags: tags));
    }

    return results;
  }

  /// Retrieves a single document with all its ordered pages and tags
  Future<ScannedDocument?> getDocument(String id) async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (docRows.isEmpty) return null;

    final pageRows = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [id],
      orderBy: 'page_order ASC',
    );
    final pages = pageRows.map((p) => DocumentPage.fromMap(p)).toList();
    final tags = await getDocumentTags(id);

    return ScannedDocument.fromMap(docRows.first, pages: pages, tags: tags);
  }

  /// Retrieves the latest unfinished draft document if one exists
  Future<ScannedDocument?> getLatestDraft() async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      where: 'is_draft = 1 AND deleted_at IS NULL',
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

    final tags = await getDocumentTags(docId);
    return ScannedDocument.fromMap(docRows.first, pages: pages, tags: tags);
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

  /// Renames a document
  Future<void> renameDocument(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    await db.update(
      'documents',
      {'title': trimmed, 'modified_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Saves or updates the OCR text for a document
  Future<void> saveDocumentOcr(String documentId, String fullText) async {
    if (fullText.trim().isEmpty) return;
    final db = await database;
    await db.insert('document_ocr', {
      'document_id': documentId,
      'full_text': fullText.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  // ===========================================================================
  // DOCUMENT BOOKMARKS
  // ===========================================================================

  Future<void> _ensureBookmarksTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_bookmarks (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_doc ON document_bookmarks (document_id)',
    );
  }

  /// Adds a bookmark for a document page
  Future<DocumentBookmark> addBookmark({
    required String documentId,
    required int pageNumber,
    required String title,
  }) async {
    final db = await database;
    await _ensureBookmarksTable(db);
    final id = const Uuid().v4();
    final bookmark = DocumentBookmark(
      id: id,
      documentId: documentId,
      pageNumber: pageNumber,
      title: title.trim().isEmpty ? 'Page $pageNumber' : title.trim(),
      createdAt: DateTime.now(),
    );
    await db.insert('document_bookmarks', bookmark.toMap());
    return bookmark;
  }

  /// Retrieves all bookmarks for a document, ordered by page number
  Future<List<DocumentBookmark>> getBookmarks(String documentId) async {
    final db = await database;
    await _ensureBookmarksTable(db);
    final rows = await db.query(
      'document_bookmarks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
    return rows.map((r) => DocumentBookmark.fromMap(r)).toList();
  }

  /// Deletes a bookmark by ID
  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await _ensureBookmarksTable(db);
    await db.delete('document_bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  /// Updates a bookmark's title
  Future<void> updateBookmarkTitle(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    await _ensureBookmarksTable(db);
    await db.update(
      'document_bookmarks',
      {'title': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

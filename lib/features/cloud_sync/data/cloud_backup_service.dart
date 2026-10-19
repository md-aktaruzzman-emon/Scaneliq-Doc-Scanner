import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';

class BackupMetadata {
  final int version;
  final DateTime createdAt;
  final int documentCount;
  final int folderCount;
  final String checksumSha256;

  const BackupMetadata({
    required this.version,
    required this.createdAt,
    required this.documentCount,
    required this.folderCount,
    required this.checksumSha256,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'documentCount': documentCount,
    'folderCount': folderCount,
    'checksumSha256': checksumSha256,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    version: json['version'] as int? ?? 1,
    createdAt: DateTime.parse(json['createdAt'] as String),
    documentCount: json['documentCount'] as int? ?? 0,
    folderCount: json['folderCount'] as int? ?? 0,
    checksumSha256: json['checksumSha256'] as String? ?? '',
  );
}

class BackupRestoreResult {
  final bool success;
  final int restoredDocuments;
  final int restoredFolders;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.restoredDocuments = 0,
    this.restoredFolders = 0,
    this.errorMessage,
  });
}

/// Service providing Automated Cloud Backup (.scaneliq ZIP packages) and non-destructive restore (F-42).
class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const int currentBackupVersion = 1;

  /// Creates a complete .scaneliq ZIP backup archive of SQLite database and documents
  Future<File> createBackupArchive({String? customFileName}) async {
    final db = await AppDatabaseService.instance.database;

    // 1. Export database tables
    final folders = await db.query('folders');
    final documents = await db.query('documents');
    final pages = await db.query('pages');
    final documentOcr = await db.query('document_ocr');
    final tags = await db.query('tags');
    final documentTags = await db.query('document_tags');
    final bookmarks = await db.query('document_bookmarks');

    final dbDump = {
      'folders': folders,
      'documents': documents,
      'pages': pages,
      'document_ocr': documentOcr,
      'tags': tags,
      'document_tags': documentTags,
      'document_bookmarks': bookmarks,
    };

    final dbJsonStr = jsonEncode(dbDump);
    final dbBytes = utf8.encode(dbJsonStr);
    final checksum = sha256.convert(dbBytes).toString();

    final metadata = BackupMetadata(
      version: currentBackupVersion,
      createdAt: DateTime.now(),
      documentCount: documents.length,
      folderCount: folders.length,
      checksumSha256: checksum,
    );

    // 2. Build ZIP Archive
    final archive = Archive();
    final metaJsonStr = jsonEncode(metadata.toJson());
    final metaBytes = utf8.encode(metaJsonStr);

    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
    archive.addFile(ArchiveFile('database.json', dbBytes.length, dbBytes));

    // Include exported document PDFs if they exist
    for (final doc in documents) {
      final exportPath = doc['export_path'] as String?;
      if (exportPath != null && exportPath.isNotEmpty) {
        final expFile = File(exportPath);
        if (await expFile.exists()) {
          final bytes = await expFile.readAsBytes();
          archive.addFile(
            ArchiveFile(
              'exports/${p.basename(exportPath)}',
              bytes.length,
              bytes,
            ),
          );
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);

    final outDir = AppStorageService.instance.exportsDir;
    final fileName =
        customFileName ??
        'Scaneliq_Backup_${DateTime.now().millisecondsSinceEpoch}.scaneliq';
    final backupFile = File(p.join(outDir.path, fileName));
    await backupFile.writeAsBytes(zipData);

    return backupFile;
  }

  /// Restores documents, folders, tags, and data from a .scaneliq backup archive non-destructively
  Future<BackupRestoreResult> restoreBackupArchive(File backupFile) async {
    if (!await backupFile.exists()) {
      return const BackupRestoreResult(
        success: false,
        errorMessage: 'Backup file does not exist on disk',
      );
    }

    try {
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify metadata & database entries
      final metaFile = archive.findFile('metadata.json');
      final dbFile = archive.findFile('database.json');

      if (metaFile == null || dbFile == null) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Invalid Scaneliq backup format: missing metadata or database payload',
        );
      }

      final metaContent = utf8.decode(metaFile.content as List<int>);
      final metadata = BackupMetadata.fromJson(
        jsonDecode(metaContent) as Map<String, dynamic>,
      );

      final dbContentBytes = dbFile.content as List<int>;
      final computedSha = sha256.convert(dbContentBytes).toString();
      if (metadata.checksumSha256.isNotEmpty &&
          computedSha != metadata.checksumSha256) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Integrity check failed: backup archive database checksum mismatch',
        );
      }

      final dbMap =
          jsonDecode(utf8.decode(dbContentBytes)) as Map<String, dynamic>;
      final db = await AppDatabaseService.instance.database;

      int restoredDocs = 0;
      int restoredFolders = 0;

      // Extract exported PDFs into local exports directory
      final exportsDir = AppStorageService.instance.exportsDir;
      for (final file in archive.files) {
        if (file.name.startsWith('exports/') && !file.isDirectory) {
          final outFile = File(p.join(exportsDir.path, p.basename(file.name)));
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Restore inside a transaction
      await db.transaction((txn) async {
        // 1. Folders
        final folders = (dbMap['folders'] as List<dynamic>?) ?? [];
        for (final f in folders) {
          final map = Map<String, dynamic>.from(f as Map);
          await txn.insert(
            'folders',
            map,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          restoredFolders++;
        }

        // 2. Documents
        final documents = (dbMap['documents'] as List<dynamic>?) ?? [];
        for (final d in documents) {
          final map = Map<String, dynamic>.from(d as Map);
          await txn.insert(
            'documents',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          restoredDocs++;
        }

        // 3. Pages
        final pages = (dbMap['pages'] as List<dynamic>?) ?? [];
        for (final pg in pages) {
          final map = Map<String, dynamic>.from(pg as Map);
          await txn.insert(
            'pages',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 4. OCR
        final ocrList = (dbMap['document_ocr'] as List<dynamic>?) ?? [];
        for (final o in ocrList) {
          final map = Map<String, dynamic>.from(o as Map);
          await txn.insert(
            'document_ocr',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 5. Tags
        final tags = (dbMap['tags'] as List<dynamic>?) ?? [];
        for (final t in tags) {
          final map = Map<String, dynamic>.from(t as Map);
          await txn.insert(
            'tags',
            map,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // 6. Document Tags
        final docTags = (dbMap['document_tags'] as List<dynamic>?) ?? [];
        for (final dt in docTags) {
          final map = Map<String, dynamic>.from(dt as Map);
          await txn.insert(
            'document_tags',
            map,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // 7. Bookmarks
        final bookmarks = (dbMap['document_bookmarks'] as List<dynamic>?) ?? [];
        for (final b in bookmarks) {
          final map = Map<String, dynamic>.from(b as Map);
          await txn.insert(
            'document_bookmarks',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return BackupRestoreResult(
        success: true,
        restoredDocuments: restoredDocs,
        restoredFolders: restoredFolders,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        errorMessage: 'Failed to restore backup: $e',
      );
    }
  }
}

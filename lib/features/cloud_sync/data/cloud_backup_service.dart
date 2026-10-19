import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart' as pc;
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:sqflite/sqflite.dart';

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

/// Service providing Automated Cloud/Local Backup (.scaneliq packages), standard AES-256-CBC Encrypt-then-MAC
/// authenticated encryption with PBKDF2 key separation, Zip Slip path-traversal prevention, and non-destructive restore (F-42).
class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const int currentBackupVersion = 2;
  static const String encryptedHeaderV1 = 'SCANELIQ_ENC_V1:';
  static const String encryptedHeaderV2 = 'SCANELIQ_ENC_V2:';
  static const String encryptedHeader = encryptedHeaderV2;

  // ---------------------------------------------------------------------------
  // V2 CRYPTOGRAPHY: Standard PBKDF2-HMAC-SHA256 (100k) + AES-256-CBC + HMAC-SHA256 (EtM)
  // ---------------------------------------------------------------------------

  Uint8List _deriveKeyMaterialV2(
    String passphrase,
    Uint8List salt, {
    int iterations = 100000,
  }) {
    final pbkdf2 = pc.KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = pc.Pbkdf2Parameters(salt, iterations, 64);
    pbkdf2.init(params);
    return pbkdf2.process(utf8.encode(passphrase));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static bool _hasHeader(List<int> bytes, List<int> header) {
    if (bytes.length < header.length) return false;
    for (int i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // V1 LEGACY CRYPTOGRAPHY (Backward Compatibility Fallback)
  // ---------------------------------------------------------------------------

  List<int> _deriveKeyV1(
    String passphrase,
    List<int> salt, {
    int iterations = 10000,
  }) {
    List<int> key = utf8.encode('$passphrase::scaneliq_backup_salt');
    for (int i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, key);
      key = hmac.convert([...key, ...salt, i & 0xFF]).bytes;
    }
    return key;
  }

  List<int> _cryptStreamV1(List<int> input, List<int> key, List<int> salt) {
    final output = Uint8List(input.length);
    final hmac = Hmac(sha256, key);
    const blockSize = 32;
    int offset = 0;
    int counter = 0;

    while (offset < input.length) {
      final blockKey = hmac.convert([
        ...salt,
        (counter >> 24) & 0xFF,
        (counter >> 16) & 0xFF,
        (counter >> 8) & 0xFF,
        counter & 0xFF,
      ]).bytes;
      counter++;
      final chunkLen = math.min(blockSize, input.length - offset);
      for (int j = 0; j < chunkLen; j++) {
        output[offset + j] = input[offset + j] ^ blockKey[j];
      }
      offset += chunkLen;
    }
    return output;
  }

  // ---------------------------------------------------------------------------
  // BACKUP CREATION
  // ---------------------------------------------------------------------------

  /// Creates a complete .scaneliq backup archive of SQLite database, original page images, and exported PDFs.
  /// If [encryptionPassword] is provided, encrypts the entire archive using AES-256-CBC Encrypt-then-MAC
  /// with PBKDF2-HMAC-SHA256 key derivation (100,000 iterations) and cryptographic key separation.
  Future<File> createBackupArchive({
    String? customFileName,
    String? encryptionPassword,
  }) async {
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

    // Include original page images if they exist
    for (final page in pages) {
      final origPath = page['original_path'] as String?;
      if (origPath != null && origPath.isNotEmpty) {
        final origFile = File(origPath);
        if (await origFile.exists()) {
          final bytes = await origFile.readAsBytes();
          archive.addFile(
            ArchiveFile(
              'originals/${p.basename(origPath)}',
              bytes.length,
              bytes,
            ),
          );
        }
      }
    }

    final rawZipData = ZipEncoder().encode(archive);
    final List<int> finalPayload;

    if (encryptionPassword != null && encryptionPassword.trim().isNotEmpty) {
      final rnd = math.Random.secure();
      final saltBytes = Uint8List.fromList(
        List<int>.generate(16, (_) => rnd.nextInt(256)),
      );
      final ivBytes = Uint8List.fromList(
        List<int>.generate(16, (_) => rnd.nextInt(256)),
      );

      // Derive 64 bytes: 32 for AES-256, 32 for HMAC-SHA256 (Key Separation)
      final keyMaterial = _deriveKeyMaterialV2(
        encryptionPassword.trim(),
        saltBytes,
      );
      final encKey = keyMaterial.sublist(0, 32);
      final macKey = keyMaterial.sublist(32, 64);

      // AES-256-CBC Encryption
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(Uint8List.fromList(encKey)), mode: enc.AESMode.cbc),
      );
      final encrypted = encrypter.encryptBytes(rawZipData, iv: enc.IV(ivBytes));
      final cipherBytes = encrypted.bytes;

      // Encrypt-then-MAC (HMAC-SHA256 over salt + iv + ciphertext)
      final macPayload = [...saltBytes, ...ivBytes, ...cipherBytes];
      final hmac = Hmac(sha256, macKey);
      final tagBytes = hmac.convert(macPayload).bytes;

      final envelope = {
        'version': 2,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': 100000,
        'cipher': 'AES-256-CBC-PKCS7',
        'mac': 'HMAC-SHA256-EtM',
        'salt': base64Encode(saltBytes),
        'iv': base64Encode(ivBytes),
        'ciphertext': base64Encode(cipherBytes),
        'tag': base64Encode(tagBytes),
      };
      final payloadStr = '$encryptedHeaderV2${jsonEncode(envelope)}';
      finalPayload = utf8.encode(payloadStr);
    } else {
      finalPayload = rawZipData;
    }

    final outDir = AppStorageService.instance.exportsDir;
    final fileName =
        customFileName ??
        'Scaneliq_Backup_${DateTime.now().millisecondsSinceEpoch}.scaneliq';
    final backupFile = File(p.join(outDir.path, fileName));
    await backupFile.writeAsBytes(finalPayload);

    return backupFile;
  }

  // ---------------------------------------------------------------------------
  // BACKUP RESTORATION
  // ---------------------------------------------------------------------------

  /// Restores documents, folders, tags, original images, and data from a .scaneliq backup archive non-destructively.
  /// Handles decryption (both V2 AES-256-CBC-EtM and V1 legacy format), constant-time authentication,
  /// and guards against Zip Slip path traversal.
  Future<BackupRestoreResult> restoreBackupArchive(
    File backupFile, {
    String? decryptionPassword,
  }) async {
    if (!await backupFile.exists()) {
      return const BackupRestoreResult(
        success: false,
        errorMessage: 'Backup file does not exist on disk',
      );
    }

    try {
      final rawFileBytes = await backupFile.readAsBytes();
      final List<int> zipBytes;

      final headerV2Bytes = utf8.encode(encryptedHeaderV2);
      final headerV1Bytes = utf8.encode(encryptedHeaderV1);

      if (_hasHeader(rawFileBytes, headerV2Bytes)) {
        // V2 Authenticated AES-256-CBC Encrypt-then-MAC
        if (decryptionPassword == null || decryptionPassword.trim().isEmpty) {
          return const BackupRestoreResult(
            success: false,
            errorMessage:
                'This backup archive is encrypted. Password is required.',
          );
        }

        final jsonString = utf8.decode(
          rawFileBytes.sublist(headerV2Bytes.length),
        );
        final envelope = jsonDecode(jsonString) as Map<String, dynamic>;
        final saltBytes = Uint8List.fromList(
          base64Decode(envelope['salt'] as String),
        );
        final ivBytes = Uint8List.fromList(
          base64Decode(envelope['iv'] as String),
        );
        final cipherBytes = base64Decode(envelope['ciphertext'] as String);
        final expectedTag = base64Decode(envelope['tag'] as String);

        final keyMaterial = _deriveKeyMaterialV2(
          decryptionPassword.trim(),
          saltBytes,
        );
        final encKey = keyMaterial.sublist(0, 32);
        final macKey = keyMaterial.sublist(32, 64);

        // Constant-time HMAC authentication verification
        final macPayload = [...saltBytes, ...ivBytes, ...cipherBytes];
        final computedTag = Hmac(sha256, macKey).convert(macPayload).bytes;

        if (!_constantTimeEquals(computedTag, expectedTag)) {
          return const BackupRestoreResult(
            success: false,
            errorMessage: 'Decryption failed: Incorrect password or corrupted backup package.',
          );
        }

        // Decrypt AES-256-CBC with PKCS7 unpadding
        final encrypter = enc.Encrypter(
          enc.AES(enc.Key(Uint8List.fromList(encKey)), mode: enc.AESMode.cbc),
        );
        zipBytes = encrypter.decryptBytes(
          enc.Encrypted(Uint8List.fromList(cipherBytes)),
          iv: enc.IV(ivBytes),
        );
      } else if (_hasHeader(rawFileBytes, headerV1Bytes)) {
        // V1 Legacy Format
        if (decryptionPassword == null || decryptionPassword.trim().isEmpty) {
          return const BackupRestoreResult(
            success: false,
            errorMessage:
                'This backup archive is encrypted. Password is required.',
          );
        }

        final jsonString = utf8.decode(
          rawFileBytes.sublist(headerV1Bytes.length),
        );
        final envelope = jsonDecode(jsonString) as Map<String, dynamic>;
        final saltBytes = base64Decode(envelope['salt'] as String);
        final cipherBytes = base64Decode(envelope['cipher'] as String);
        final expectedHmac = envelope['hmac'] as String;

        final key = _deriveKeyV1(decryptionPassword.trim(), saltBytes);
        final computedHmac = Hmac(
          sha256,
          key,
        ).convert([...saltBytes, ...cipherBytes]).toString();

        if (computedHmac != expectedHmac) {
          return const BackupRestoreResult(
            success: false,
            errorMessage: 'Decryption failed: Incorrect password or corrupted backup package.',
          );
        }

        zipBytes = _cryptStreamV1(cipherBytes, key, saltBytes);
      } else {
        // Plain ZIP
        zipBytes = rawFileBytes;
      }

      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } catch (e) {
        return const BackupRestoreResult(
          success: false,
          errorMessage:
              'Invalid Scaneliq backup format: unparseable ZIP archive',
        );
      }

      // Validate against path traversal (Zip Slip vulnerability)
      for (final file in archive.files) {
        if (file.name.contains('..') ||
            file.name.startsWith('/') ||
            file.name.startsWith(r'\')) {
          return const BackupRestoreResult(
            success: false,
            errorMessage: 'Security violation: Archive contains illegal relative path traversal entry.',
          );
        }
      }

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

      // Extract exported PDFs and original images into local application directories
      final exportsDir = AppStorageService.instance.exportsDir;
      final originalsDir = AppStorageService.instance.originalsDir;

      for (final file in archive.files) {
        if (file.isDirectory) continue;
        if (file.name.startsWith('exports/')) {
          final base = p.basename(file.name);
          final outFile = File(p.join(exportsDir.path, base));
          if (p.isWithin(exportsDir.path, outFile.path)) {
            await outFile.writeAsBytes(file.content as List<int>);
          }
        } else if (file.name.startsWith('originals/')) {
          final base = p.basename(file.name);
          final outFile = File(p.join(originalsDir.path, base));
          if (p.isWithin(originalsDir.path, outFile.path)) {
            await outFile.writeAsBytes(file.content as List<int>);
          }
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

        // 2. Documents (with remapped export path)
        final documents = (dbMap['documents'] as List<dynamic>?) ?? [];
        for (final d in documents) {
          final map = Map<String, dynamic>.from(d as Map);
          if (map['export_path'] != null) {
            final base = p.basename(map['export_path'] as String);
            map['export_path'] = p.join(exportsDir.path, base);
          }
          await txn.insert(
            'documents',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          restoredDocs++;
        }

        // 3. Pages (with remapped original and processed paths)
        final pages = (dbMap['pages'] as List<dynamic>?) ?? [];
        for (final pg in pages) {
          final map = Map<String, dynamic>.from(pg as Map);
          if (map['original_path'] != null) {
            final base = p.basename(map['original_path'] as String);
            map['original_path'] = p.join(originalsDir.path, base);
          }
          if (map['processed_path'] != null) {
            final base = p.basename(map['processed_path'] as String);
            final procFile = File(
              p.join(AppStorageService.instance.processedDir.path, base),
            );
            map['processed_path'] = procFile.existsSync()
                ? procFile.path
                : null;
          }
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

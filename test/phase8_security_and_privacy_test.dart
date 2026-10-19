import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/cloud_sync/data/cloud_backup_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Database testDb;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_phase8_sec_');
    await AppStorageService.instance.init(tempDir);
    SharedPreferences.setMockInitialValues({});

    final dbPath = p.join(tempDir.path, 'test_scaneliq_sec.db');
    testDb = await openDatabase(
      dbPath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT, parent_id TEXT, created_at INTEGER, modified_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER, modified_at INTEGER, page_count INTEGER, is_favorite INTEGER, is_draft INTEGER, export_path TEXT, folder_id TEXT, deleted_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_order INTEGER, original_path TEXT, processed_path TEXT, edit_recipe_json TEXT, width INTEGER, height INTEGER)',
        );
        await db.execute(
          'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, color INTEGER, created_at INTEGER, modified_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_index INTEGER, title TEXT, created_at INTEGER)',
        );
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

  group('Phase 8: Security & Privacy Verification Tests', () {
    test('PIN Security: PBKDF2 stretching, lockout after 5 attempts, and legacy auto-upgrade', () async {
      final lockService = AppLockService.instance;
      await lockService.init();

      // 1. Set new PIN with hardened PBKDF2-HMAC-SHA256 stretching
      await lockService.setPin('4321');
      expect(lockService.isAppLockEnabled, isTrue);
      expect(lockService.hasPinSet, isTrue);

      // Verify correct PIN
      final ok = await lockService.verifyPin('4321');
      expect(ok.success, isTrue);
      expect(ok.isLockedOut, isFalse);

      // Verify wrong PIN fails
      final fail1 = await lockService.verifyPin('0000');
      expect(fail1.success, isFalse);
      expect(fail1.remainingAttempts, 4);

      // Trigger 4 more failed attempts to reach maxFailedAttempts (5)
      await lockService.verifyPin('0001');
      await lockService.verifyPin('0002');
      await lockService.verifyPin('0003');
      final lockoutResult = await lockService.verifyPin('0004');

      expect(lockoutResult.success, isFalse);
      expect(lockoutResult.isLockedOut, isTrue);
      expect(lockoutResult.remainingCooldownSeconds, greaterThan(0));

      // Attempt during lockout is blocked immediately
      final blocked = await lockService.verifyPin('4321');
      expect(blocked.success, isFalse);
      expect(blocked.isLockedOut, isTrue);

      // 2. Test legacy hash backward compatibility and auto-upgrade
      final prefs = await SharedPreferences.getInstance();
      const legacyPin = '9876';
      const testSalt = 'test_legacy_salt_123';
      final legacyBytes = utf8.encode(
        '$testSalt::$legacyPin::scaneliq_security_salt',
      );
      final legacyHash = sha256.convert(legacyBytes).toString();

      await prefs.setString('app_lock_pin_hash', legacyHash);
      await prefs.setString('app_lock_pin_salt', testSalt);
      await prefs.remove('app_lock_lockout_until_epoch');
      await prefs.setInt('app_lock_failed_attempts', 0);

      // Verify legacy PIN succeeds
      final legacyVerify = await lockService.verifyPin('9876');
      expect(legacyVerify.success, isTrue);

      // Confirm stored hash was transparently upgraded to hardened iterative hash
      final upgradedHash = prefs.getString('app_lock_pin_hash');
      expect(upgradedHash, isNotNull);
      expect(upgradedHash != legacyHash, isTrue);
    });

    test(
      'Backup Security: Authenticated AES encryption and password rejection',
      () async {
        final backupService = CloudBackupService.instance;

        // Insert dummy document
        await testDb.insert('documents', {
          'id': 'doc_secret',
          'title': 'Confidential Financial Report',
          'created_at': 1000,
          'modified_at': 1000,
        });

        // 1. Create encrypted backup
        const password = 'SuperSecretBackupPassword2026!';
        final encryptedFile = await backupService.createBackupArchive(
          encryptionPassword: password,
        );

        expect(await encryptedFile.exists(), isTrue);

        // Inspect file header directly
        final fileBytes = await encryptedFile.readAsBytes();
        final headerStr = utf8.decode(
          fileBytes.sublist(0, CloudBackupService.encryptedHeader.length),
        );
        expect(headerStr, CloudBackupService.encryptedHeader);

        // Verify file does NOT reveal any archive files as plain ZIP
        final plainZipAttempt = ZipDecoder().decodeBytes(fileBytes);
        expect(plainZipAttempt.files.isEmpty, isTrue);
        expect(plainZipAttempt.findFile('metadata.json'), isNull);

        // 2. Attempt restore with WRONG password
        final failRestore = await backupService.restoreBackupArchive(
          encryptedFile,
          decryptionPassword: 'WrongPassword!',
        );
        expect(failRestore.success, isFalse);
        expect(failRestore.errorMessage, contains('Incorrect password'));

        // 3. Attempt restore with MISSING password
        final missingPassRestore = await backupService.restoreBackupArchive(
          encryptedFile,
        );
        expect(missingPassRestore.success, isFalse);
        expect(
          missingPassRestore.errorMessage,
          contains('Password is required'),
        );

        // 4. Restore with CORRECT password
        final freshDb = await openDatabase(
          p.join(tempDir.path, 'fresh_restore.db'),
          version: 5,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT, parent_id TEXT, created_at INTEGER, modified_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER, modified_at INTEGER, page_count INTEGER, is_favorite INTEGER, is_draft INTEGER, export_path TEXT, folder_id TEXT, deleted_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_order INTEGER, original_path TEXT, processed_path TEXT, edit_recipe_json TEXT, width INTEGER, height INTEGER)',
            );
            await db.execute(
              'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, color INTEGER, created_at INTEGER, modified_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_index INTEGER, title TEXT, created_at INTEGER)',
            );
          },
        );
        AppDatabaseService.instance.setDatabaseForTesting(freshDb);

        final okRestore = await backupService.restoreBackupArchive(
          encryptedFile,
          decryptionPassword: password,
        );
        expect(okRestore.success, isTrue);
        expect(okRestore.restoredDocuments, 1);

        final restoredDocs = await freshDb.query('documents');
        expect(restoredDocs.length, 1);
        expect(restoredDocs.first['title'], 'Confidential Financial Report');

        await freshDb.close();
      },
    );

    test('Zip Slip Protection: Rejects malicious path traversal in backup archives', () async {
      final backupService = CloudBackupService.instance;

      // Construct a malicious ZIP with a path traversal entry
      final maliciousArchive = Archive();
      maliciousArchive.addFile(
        ArchiveFile('metadata.json', 2, utf8.encode('{}')),
      );
      maliciousArchive.addFile(
        ArchiveFile('database.json', 2, utf8.encode('{}')),
      );
      maliciousArchive.addFile(
        ArchiveFile(
          'exports/../../../../evil_overwrite.txt',
          12,
          utf8.encode('pwned payload'),
        ),
      );

      final evilZipBytes = ZipEncoder().encode(maliciousArchive);
      final evilZipFile = File(p.join(tempDir.path, 'evil_backup.scaneliq'));
      await evilZipFile.writeAsBytes(evilZipBytes);

      final result = await backupService.restoreBackupArchive(evilZipFile);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Security violation'));

      // Ensure evil file was never written outside
      final evilTarget = File(p.join(tempDir.path, 'evil_overwrite.txt'));
      expect(await evilTarget.exists(), isFalse);
    });

    test(
      'PDF Redaction: Sanitizes metadata completely from exported document',
      () async {
        // Create sample PDF with sensitive metadata
        final doc = sf.PdfDocument();
        doc.documentInformation.title = 'Top Secret Strategic Analysis';
        doc.documentInformation.author = 'Special Agent Smith';
        doc.documentInformation.subject = 'Classified Operations';
        doc.documentInformation.keywords = 'classified, secret, confidential';

        final page = doc.pages.add();
        page.graphics.drawString(
          'Account Number: 1234-5678-9012',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );

        final sourceFile = File(p.join(tempDir.path, 'source_metadata.pdf'));
        await sourceFile.writeAsBytes(doc.saveSync());
        doc.dispose();

        // Apply redaction with metadata sanitization
        final redactedFile = await AdvancedPdfService.instance.applyRedaction(
          sourcePdf: sourceFile,
          redactions: [
            const PdfRedactionArea(
              pageIndex: 0,
              x: 20,
              y: 20,
              width: 200,
              height: 30,
              overlayText: '[CONFIDENTIAL]',
            ),
          ],
          outputFileName: 'redacted_metadata_clean',
          sanitizeMetadata: true,
        );

        expect(await redactedFile.exists(), isTrue);

        // Verify metadata is completely wiped
        final redactedDoc = sf.PdfDocument(
          inputBytes: await redactedFile.readAsBytes(),
        );
        expect(redactedDoc.documentInformation.title, isEmpty);
        expect(redactedDoc.documentInformation.author, isEmpty);
        expect(redactedDoc.documentInformation.subject, isEmpty);
        expect(redactedDoc.documentInformation.keywords, isEmpty);
        expect(
          redactedDoc.documentInformation.producer,
          'Scaneliq Redaction Engine',
        );
        redactedDoc.dispose();
      },
    );

    test('Storage Validation: Rejects corrupted image headers when validateHeader is true', () async {
      final storage = AppStorageService.instance;

      // Corrupted 4-byte header (not JPEG/PNG/WebP)
      final corruptBytes = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77];

      expect(
        () => storage.saveOriginalPage(
          'corrupted_page',
          corruptBytes,
          validateHeader: true,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

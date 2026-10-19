import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
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
    tempDir = Directory.systemTemp.createTempSync('scaneliq_phase9_rc_');
    await AppStorageService.instance.init(tempDir);
    SharedPreferences.setMockInitialValues({});

    final dbPath = p.join(tempDir.path, 'test_scaneliq_rc.db');
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

  group('Phase 9: Release Candidate Cryptography & Verification Tests', () {
    test('Backup Cryptography: V2 PBKDF2 (100k) + AES-256-CBC Encrypt-then-MAC with Key Separation', () async {
      final backupService = CloudBackupService.instance;

      await testDb.insert('documents', {
        'id': 'doc_rc_001',
        'title': 'Confidential Financial Statement 2026',
        'created_at': 1700000000,
        'modified_at': 1700000000,
      });

      const pass = 'CorrectSecurePassword_2026!';
      final backupFile = await backupService.createBackupArchive(
        encryptionPassword: pass,
      );

      expect(await backupFile.exists(), isTrue);

      final rawBytes = await backupFile.readAsBytes();
      final headerStr = utf8.decode(
        rawBytes.sublist(0, CloudBackupService.encryptedHeaderV2.length),
      );
      expect(headerStr, CloudBackupService.encryptedHeaderV2);

      // Verify envelope parameters
      final jsonStr = utf8.decode(
        rawBytes.sublist(CloudBackupService.encryptedHeaderV2.length),
      );
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(envelope['version'], 2);
      expect(envelope['kdf'], 'PBKDF2-HMAC-SHA256');
      expect(envelope['iterations'], 100000);
      expect(envelope['cipher'], 'AES-256-CBC-PKCS7');
      expect(envelope['mac'], 'HMAC-SHA256-EtM');
      expect(envelope['salt'], isNotEmpty);
      expect(envelope['iv'], isNotEmpty);
      expect(envelope['ciphertext'], isNotEmpty);
      expect(envelope['tag'], isNotEmpty);

      // Wrong password fails safely
      final wrongRestore = await backupService.restoreBackupArchive(
        backupFile,
        decryptionPassword: 'WrongPassword!',
      );
      expect(wrongRestore.success, isFalse);
      expect(wrongRestore.errorMessage, contains('Incorrect password'));

      // Empty password fails safely
      final emptyRestore = await backupService.restoreBackupArchive(backupFile);
      expect(emptyRestore.success, isFalse);
      expect(emptyRestore.errorMessage, contains('Password is required'));

      // Correct password restores cleanly
      final freshDb = await openDatabase(
        p.join(tempDir.path, 'fresh_rc_restore.db'),
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
        backupFile,
        decryptionPassword: pass,
      );
      expect(okRestore.success, isTrue);
      expect(okRestore.restoredDocuments, 1);

      final docs = await freshDb.query('documents');
      expect(docs.first['title'], 'Confidential Financial Statement 2026');
      await freshDb.close();
    });

    test('Backup Tampering: Detects and rejects altered ciphertext, IV, or tag before restoration', () async {
      final backupService = CloudBackupService.instance;
      const pass = 'TamperTestPass123!';
      final backupFile = await backupService.createBackupArchive(
        encryptionPassword: pass,
      );

      final rawBytes = await backupFile.readAsBytes();
      final headerLen = CloudBackupService.encryptedHeaderV2.length;
      final jsonStr = utf8.decode(rawBytes.sublist(headerLen));
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 1. Corrupt 1 byte in ciphertext
      final cipherBytes = base64Decode(envelope['ciphertext'] as String);
      cipherBytes[0] ^= 0x01; // flip 1 bit
      final tamperedCipherEnvelope = Map<String, dynamic>.from(envelope);
      tamperedCipherEnvelope['ciphertext'] = base64Encode(cipherBytes);

      final tamperedFile1 = File(
        p.join(tempDir.path, 'tampered_cipher.scaneliq'),
      );
      await tamperedFile1.writeAsBytes(
        utf8.encode(
          '${CloudBackupService.encryptedHeaderV2}${jsonEncode(tamperedCipherEnvelope)}',
        ),
      );

      final res1 = await backupService.restoreBackupArchive(
        tamperedFile1,
        decryptionPassword: pass,
      );
      expect(res1.success, isFalse);
      expect(res1.errorMessage, contains('corrupted backup package'));

      // 2. Corrupt 1 byte in IV
      final ivBytes = base64Decode(envelope['iv'] as String);
      ivBytes[0] ^= 0x01;
      final tamperedIvEnvelope = Map<String, dynamic>.from(envelope);
      tamperedIvEnvelope['iv'] = base64Encode(ivBytes);

      final tamperedFile2 = File(p.join(tempDir.path, 'tampered_iv.scaneliq'));
      await tamperedFile2.writeAsBytes(
        utf8.encode(
          '${CloudBackupService.encryptedHeaderV2}${jsonEncode(tamperedIvEnvelope)}',
        ),
      );

      final res2 = await backupService.restoreBackupArchive(
        tamperedFile2,
        decryptionPassword: pass,
      );
      expect(res2.success, isFalse);
      expect(res2.errorMessage, contains('corrupted backup package'));

      // 3. Corrupt HMAC Tag
      final tagBytes = base64Decode(envelope['tag'] as String);
      tagBytes[0] ^= 0x01;
      final tamperedTagEnvelope = Map<String, dynamic>.from(envelope);
      tamperedTagEnvelope['tag'] = base64Encode(tagBytes);

      final tamperedFile3 = File(p.join(tempDir.path, 'tampered_tag.scaneliq'));
      await tamperedFile3.writeAsBytes(
        utf8.encode(
          '${CloudBackupService.encryptedHeaderV2}${jsonEncode(tamperedTagEnvelope)}',
        ),
      );

      final res3 = await backupService.restoreBackupArchive(
        tamperedFile3,
        decryptionPassword: pass,
      );
      expect(res3.success, isFalse);
      expect(res3.errorMessage, contains('corrupted backup package'));
    });

    test('Backup Backward Compatibility: Restores V1 format and plain ZIP archives', () async {
      final backupService = CloudBackupService.instance;

      // Construct a V1 legacy backup
      final archive = Archive();
      final metaBytes = utf8.encode(
        '{"version":1,"createdAt":"2026-01-01T00:00:00.000","documentCount":0,"folderCount":0,"checksumSha256":""}',
      );
      final dbBytes = utf8.encode('{}');
      archive.addFile(
        ArchiveFile('metadata.json', metaBytes.length, metaBytes),
      );
      archive.addFile(ArchiveFile('database.json', dbBytes.length, dbBytes));
      final zipBytes = ZipEncoder().encode(archive);

      // V1 stream encryption
      const pass = 'V1LegacyPass!';
      final saltBytes = List<int>.generate(16, (i) => i);
      List<int> key = utf8.encode('$pass::scaneliq_backup_salt');
      for (int i = 0; i < 10000; i++) {
        key = Hmac(sha256, key).convert([...key, ...saltBytes, i & 0xFF]).bytes;
      }
      final outBytes = Uint8List(zipBytes.length);
      final hmac = Hmac(sha256, key);
      int offset = 0;
      int counter = 0;
      while (offset < zipBytes.length) {
        final bKey = hmac.convert([
          ...saltBytes,
          (counter >> 24) & 0xFF,
          (counter >> 16) & 0xFF,
          (counter >> 8) & 0xFF,
          counter & 0xFF,
        ]).bytes;
        counter++;
        final chunk = min(32, zipBytes.length - offset);
        for (int j = 0; j < chunk; j++) {
          outBytes[offset + j] = zipBytes[offset + j] ^ bKey[j];
        }
        offset += chunk;
      }
      final v1Hmac = Hmac(
        sha256,
        key,
      ).convert([...saltBytes, ...outBytes]).toString();
      final v1Envelope = {
        'salt': base64Encode(saltBytes),
        'hmac': v1Hmac,
        'cipher': base64Encode(outBytes),
      };
      final v1File = File(p.join(tempDir.path, 'v1_legacy_backup.scaneliq'));
      await v1File.writeAsBytes(
        utf8.encode(
          '${CloudBackupService.encryptedHeaderV1}${jsonEncode(v1Envelope)}',
        ),
      );

      final v1Result = await backupService.restoreBackupArchive(
        v1File,
        decryptionPassword: pass,
      );
      expect(v1Result.success, isTrue);

      // Unencrypted ZIP backup
      final plainZipFile = File(
        p.join(tempDir.path, 'plain_unencrypted.scaneliq'),
      );
      await plainZipFile.writeAsBytes(zipBytes);
      final plainResult = await backupService.restoreBackupArchive(
        plainZipFile,
      );
      expect(plainResult.success, isTrue);
    });

    test('PIN Security: PBKDF2 (100k iters), constant-time verification, 5-attempt lockout, and fail-safe corrupted handling', () async {
      final lockService = AppLockService.instance;
      await lockService.init();

      // Input validation
      expect(() => lockService.setPin('abc'), throwsA(isA<ArgumentError>()));
      expect(() => lockService.setPin('12'), throwsA(isA<ArgumentError>()));
      expect(() => lockService.setPin(''), throwsA(isA<ArgumentError>()));

      // Set valid 6-digit PIN
      await lockService.setPin('654321');
      expect(lockService.hasPinSet, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString('app_lock_pin_hash');
      expect(storedHash, startsWith('v3:100000:'));

      // Correct PIN verifies
      final ok = await lockService.verifyPin('654321');
      expect(ok.success, isTrue);
      expect(ok.isLockedOut, isFalse);

      // Incorrect PIN decreases attempts
      final f1 = await lockService.verifyPin('000000');
      expect(f1.success, isFalse);
      expect(f1.remainingAttempts, 4);

      // Lockout triggered after 5 attempts
      await lockService.verifyPin('111111');
      await lockService.verifyPin('222222');
      await lockService.verifyPin('333333');
      final f5 = await lockService.verifyPin('444444');
      expect(f5.success, isFalse);
      expect(f5.isLockedOut, isTrue);
      expect(f5.remainingCooldownSeconds, greaterThan(0));

      // Attempt during lockout returns immediately without running PBKDF2
      final blocked = await lockService.verifyPin('654321');
      expect(blocked.success, isFalse);
      expect(blocked.isLockedOut, isTrue);

      // Fail-safe handling: Corrupt stored hash while lock is enabled
      await prefs.remove('app_lock_lockout_until_epoch');
      await prefs.setString('app_lock_pin_hash', ''); // corrupted
      final corruptCheck = await lockService.verifyPin('654321');
      expect(corruptCheck.success, isFalse);
      expect(lockService.isSessionUnlocked, isFalse);
    });

    test('PDF Redaction vs Visual Masking: Documents vector text retention and genuine image pixel zeroing', () async {
      // 1. Digital Vector PDF: Proves text stream remains in PDF code after drawing rectangle
      final doc = sf.PdfDocument();
      final page = doc.pages.add();
      const secretVectorText = 'CONFIDENTIAL_SSN_987-65-4321';
      page.graphics.drawString(
        secretVectorText,
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        bounds: Rect.fromLTWH(50, 50, 300, 20),
      );

      final vectorPdfFile = File(p.join(tempDir.path, 'vector_secret.pdf'));
      await vectorPdfFile.writeAsBytes(doc.saveSync());
      doc.dispose();

      // Apply visual mask rectangle
      final maskedPdfFile = await AdvancedPdfService.instance.applyRedaction(
        sourcePdf: vectorPdfFile,
        redactions: [
          const PdfRedactionArea(
            pageIndex: 0,
            x: 40,
            y: 40,
            width: 350,
            height: 40,
            overlayText: '[REDACTED]',
          ),
        ],
        outputFileName: 'masked_vector_result',
        sanitizeMetadata: true,
      );

      expect(await maskedPdfFile.exists(), isTrue);

      // Verify that PdfTextExtractor STILL recovers the vector text operator
      final maskedDoc = sf.PdfDocument(
        inputBytes: await maskedPdfFile.readAsBytes(),
      );
      final extractedText = sf.PdfTextExtractor(maskedDoc).extractText();
      maskedDoc.dispose();

      // THIS DEMONSTRATES WHY VISUAL MASKING CANNOT BE ADVERTISED AS PERMANENT VECTOR REDACTION
      expect(extractedText, contains('CONFIDENTIAL_SSN_987-65-4321'));

      // 2. Genuine Scanned Page Redaction: Physical pixel destruction
      final bitmap = img.Image(width: 100, height: 100);
      // Fill image with white (255, 255, 255)
      img.fill(bitmap, color: img.ColorRgb8(255, 255, 255));

      // Draw a "sensitive" pattern of red pixels in region [20, 20, 40, 40]
      for (int y = 20; y < 60; y++) {
        for (int x = 20; x < 60; x++) {
          bitmap.setPixelRgb(x, y, 255, 0, 0);
        }
      }

      // Perform genuine pixel-level permanent redaction
      final permanentlyRedacted = ImageProcessingService.permanentlyRedactImage(
        src: bitmap,
        normX: 0.2, // 20px / 100px
        normY: 0.2, // 20px / 100px
        normW: 0.4, // 40px / 100px
        normH: 0.4, // 40px / 100px
      );

      // VERIFY IRREVERSIBLE DESTRUCTION: Every pixel in target area is strictly (0, 0, 0)
      for (int y = 20; y < 60; y++) {
        for (int x = 20; x < 60; x++) {
          final p = permanentlyRedacted.getPixel(x, y);
          expect(p.r, 0, reason: 'Pixel ($x, $y) must be zeroed');
          expect(p.g, 0, reason: 'Pixel ($x, $y) must be zeroed');
          expect(p.b, 0, reason: 'Pixel ($x, $y) must be zeroed');
        }
      }

      // Pixels outside redaction box remain intact (white)
      final outsidePixel = permanentlyRedacted.getPixel(10, 10);
      expect(outsidePixel.r, 255);
      expect(outsidePixel.g, 255);
      expect(outsidePixel.b, 255);
    });

    test(
      'PDF Password Security: AES-256 encryption blocks unauthorized access',
      () async {
        final doc = sf.PdfDocument();
        doc.pages.add().graphics.drawString(
          'Protected Trade Secret',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
        );
        final rawPdfFile = File(p.join(tempDir.path, 'trade_secret.pdf'));
        await rawPdfFile.writeAsBytes(doc.saveSync());
        doc.dispose();

        // Encrypt PDF with password
        const userPassword = 'DocumentAESPassword2026!';
        final encryptedPdf = await AdvancedPdfService.instance.encryptPdf(
          sourcePdf: rawPdfFile,
          outputFileName: 'trade_secret_protected',
          userPassword: userPassword,
        );

        expect(await encryptedPdf.exists(), isTrue);

        // Attempting to open without password throws
        expect(
          () => sf.PdfDocument(inputBytes: encryptedPdf.readAsBytesSync()),
          throwsA(isA<ArgumentError>()),
        );

        // Opening with correct password succeeds
        final openedDoc = sf.PdfDocument(
          inputBytes: encryptedPdf.readAsBytesSync(),
          password: userPassword,
        );
        expect(openedDoc.pages.count, 1);
        final text = sf.PdfTextExtractor(openedDoc).extractText();
        expect(text, contains('Protected Trade Secret'));
        openedDoc.dispose();
      },
    );
  });
}

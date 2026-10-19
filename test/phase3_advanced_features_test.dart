import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/cloud_sync/data/cloud_backup_service.dart';
import 'package:scaneliq/features/cloud_sync/data/device_sync_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/intelligence/data/ai_document_service.dart';
import 'package:scaneliq/features/intelligence/data/business_card_service.dart';
import 'package:scaneliq/features/intelligence/data/receipt_parser_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_phase3_test_');
    await AppStorageService.instance.init(tempDir);

    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('F-46: AppLockService & PIN Security Tests', () {
    test('Sets PIN, hashes with salt, and verifies correct PIN', () async {
      final service = AppLockService.instance;
      await service.init();

      expect(service.isAppLockEnabled, isFalse);
      expect(service.hasPinSet, isFalse);

      await service.setPin('1234');
      expect(service.isAppLockEnabled, isTrue);
      expect(service.hasPinSet, isTrue);

      final okResult = await service.verifyPin('1234');
      expect(okResult.success, isTrue);
      expect(okResult.isLockedOut, isFalse);

      final failResult = await service.verifyPin('9999');
      expect(failResult.success, isFalse);
      expect(failResult.remainingAttempts, 4);
    });

    test(
      'Locks out after 5 consecutive failed attempts with 30s cooldown',
      () async {
        final service = AppLockService.instance;
        await service.init();
        await service.setPin('4321');

        for (int i = 0; i < 4; i++) {
          final res = await service.verifyPin('0000');
          expect(res.success, isFalse);
          expect(res.isLockedOut, isFalse);
        }

        // 5th failed attempt triggers lockout
        final lockoutRes = await service.verifyPin('0000');
        expect(lockoutRes.success, isFalse);
        expect(lockoutRes.isLockedOut, isTrue);
        expect(lockoutRes.remainingCooldownSeconds, greaterThan(0));

        // Attempt during cooldown fails immediately
        final duringLockout = await service.verifyPin('4321');
        expect(duringLockout.success, isFalse);
        expect(duringLockout.isLockedOut, isTrue);
      },
    );

    test('Disables app lock completely and clears PIN', () async {
      final service = AppLockService.instance;
      await service.init();
      await service.setPin('5555');
      expect(service.isAppLockEnabled, isTrue);

      await service.disableAppLock();
      expect(service.isAppLockEnabled, isFalse);
      expect(service.hasPinSet, isFalse);
    });
  });

  group('F-33: BusinessCardService Tests', () {
    test('Parses name, company, title, phone, email, website and generates vCard 3.0', () {
      const sampleText = '''
John Doe
Senior Software Architect
Apex Global Technologies Inc.
Phone: +1 (555) 234-5678
Email: john.doe@apexglobal.com
Web: https://www.apexglobal.com
123 Innovation Blvd, Suite 400
New York, NY 10001
''';

      final contact = BusinessCardService.instance.parseText(sampleText);
      expect(contact.name, 'John Doe');
      expect(contact.jobTitle, contains('Architect'));
      expect(contact.company, contains('Apex Global Technologies'));
      expect(contact.phone, contains('555'));
      expect(contact.email, 'john.doe@apexglobal.com');
      expect(contact.website, 'https://www.apexglobal.com');
      expect(contact.address, contains('123 Innovation Blvd'));

      final vcard = contact.toVCard();
      expect(vcard, contains('BEGIN:VCARD'));
      expect(vcard, contains('VERSION:3.0'));
      expect(vcard, contains('FN:John Doe'));
      expect(
        vcard,
        contains('EMAIL;TYPE=PREF,INTERNET:john.doe@apexglobal.com'),
      );
      expect(vcard, contains('END:VCARD'));
    });
  });

  group('F-34: ReceiptParserService Tests', () {
    test(
      'Parses receipt totals, tax, items, and verifies math consistency',
      () {
        const receiptText = '''
BLUE STAR COFFEE ROASTERS
Date: 2026-10-15
Espresso Roast    4.50
Blueberry Muffin  3.50
Subtotal: 8.00
Tax (10%): 0.80
Tip: 1.20
Total: \$10.00
''';

        final receipt = ReceiptParserService.instance.parseText(receiptText);
        expect(receipt.merchantName, 'BLUE STAR COFFEE ROASTERS');
        expect(receipt.date, '2026-10-15');
        expect(receipt.subtotal, 8.00);
        expect(receipt.tax, 0.80);
        expect(receipt.tip, 1.20);
        expect(receipt.total, 10.00);
        expect(receipt.isMathConsistent, isTrue);

        final csv = receipt.toCsv();
        expect(csv, contains('BLUE STAR COFFEE ROASTERS'));
        expect(csv, contains('8.00,0.80,1.20,10.00,\$,true'));
      },
    );

    test('Detects inconsistent receipt math', () {
      const badReceiptText = '''
Corner Market
Subtotal: 10.00
Tax: 1.00
Total: \$25.00
''';

      final receipt = ReceiptParserService.instance.parseText(badReceiptText);
      expect(receipt.subtotal, 10.00);
      expect(receipt.tax, 1.00);
      expect(receipt.total, 25.00);
      expect(receipt.isMathConsistent, isFalse);
    });
  });

  group('F-35: AiDocumentService Tests', () {
    test('Produces extractive bullet points and extracts key topics', () {
      const documentText = '''
Antigravity is a next-generation agentic AI framework engineered for high autonomy pair programming.
It provides advanced code intelligence, continuous terminal execution, and comprehensive document inspection.
Users can create automated workflows, run background tasks, and develop mobile apps using modern design systems.
The architecture preserves documentation integrity and delivers verifiable enterprise-grade quality.
''';

      final summary = AiDocumentService.instance.summarize(
        documentText,
        maxBulletPoints: 2,
      );
      expect(summary.totalSentences, 4);
      expect(summary.bulletPoints.length, 2);
      expect(summary.topKeywords, isNotEmpty);
      expect(summary.executiveSummary, isNotEmpty);
    });

    test('Semantic Q&A answers user query with relevant passage and confidence score', () {
      const documentText = '''
Antigravity is a next-generation agentic AI framework engineered for high autonomy pair programming.
The system features on-device OCR, PDF encryption with AES-256 bit keys, and instant multi-script support.
Local database backups are packaged into secure .scaneliq archives with SHA-256 checksum verification.
''';

      final answer = AiDocumentService.instance.answerQuestion(
        documentText,
        'How is PDF encryption handled?',
      );

      expect(answer.confidence, greaterThan(0.3));
      expect(
        answer.bestAnswer,
        contains('PDF encryption with AES-256 bit keys'),
      );
    });
  });

  group('F-42 & F-43: Cloud Backup & Device Sync Tests', () {
    test(
      'Encrypted Sync creates envelope and successfully merges on peer device',
      () async {
        final syncService = DeviceSyncService.instance;
        const passphrase = 'MySuperSecretPassphrase123!';

        // Create test SQLite database
        final db = await openDatabase(
          '${tempDir.path}/test_db.db',
          version: 1,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, modified_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
            );
            await db.execute('CREATE TABLE pages (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE document_tags (id TEXT)');
            await db.insert('documents', {
              'id': 'doc_1',
              'title': 'Test Doc 1',
              'modified_at': 1000,
            });
          },
        );
        AppDatabaseService.instance.setDatabaseForTesting(db);

        final envelope = await syncService.createEncryptedEnvelope(
          encryptionPassphrase: passphrase,
        );

        expect(envelope.ciphertext, isNotEmpty);
        expect(envelope.hmacTag, isNotEmpty);
        expect(envelope.salt, isNotEmpty);

        // Decrypt on a second peer DB (where doc_1 is not present yet)
        final peerDb = await openDatabase(
          '${tempDir.path}/peer_db.db',
          version: 1,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, modified_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
            );
            await db.execute('CREATE TABLE pages (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE document_tags (id TEXT)');
          },
        );
        AppDatabaseService.instance.setDatabaseForTesting(peerDb);

        final merged = await syncService.processIncomingEnvelope(
          envelope: envelope,
          decryptionPassphrase: passphrase,
        );
        expect(merged, 1);

        // Verify document was inserted into peer
        final peerDocs = await peerDb.query('documents');
        expect(peerDocs.length, 1);
        expect(peerDocs.first['title'], 'Test Doc 1');

        // Verify wrong passphrase fails HMAC check
        expect(
          () => syncService.processIncomingEnvelope(
            envelope: envelope,
            decryptionPassphrase: 'WrongPassphrase',
          ),
          throwsA(isA<Exception>()),
        );

        await db.close();
        await peerDb.close();
      },
    );
  });

  group('F-31: Bangla & Indic OCR Script & Numeral Tests', () {
    test('Converts between ASCII and Bangla numerals accurately', () {
      expect(OcrService.convertAsciiToBanglaDigits('1234567890'), '১২৩৪৫৬৭৮৯০');
      expect(OcrService.convertBanglaToAsciiDigits('১২৩৪৫৬৭৮৯০'), '1234567890');
      expect(OcrService.containsBanglaOrIndic('দলিল নং ১২৩'), isTrue);
      expect(OcrService.containsBanglaOrIndic('Only English text'), isFalse);
    });
  });

  group('F-26 & F-27: PDF Annotations & Permanent Redaction Tests', () {
    test('Applies text annotation stamp and redaction on PDF', () async {
      // Create sample PDF
      final doc = sf.PdfDocument();
      doc.pages.add().graphics.drawString(
        'Confidential Account Number: 9876-5432-1098',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
      );
      final samplePdf = File('${tempDir.path}/test_source.pdf');
      await samplePdf.writeAsBytes(doc.saveSync());
      doc.dispose();

      // 1. Apply Annotation
      final annotated = await AdvancedPdfService.instance.applyAnnotations(
        sourcePdf: samplePdf,
        annotations: [
          PdfAnnotationItem(
            type: PdfAnnotationType.text,
            pageIndex: 0,
            x: 50,
            y: 50,
            width: 200,
            height: 30,
            text: 'APPROVED STAMP',
            fontSize: 16,
            color: const Color(0xFF059669),
          ),
        ],
        outputFileName: 'annotated_test',
      );
      expect(await annotated.exists(), isTrue);

      // 2. Apply Permanent Redaction
      final redacted = await AdvancedPdfService.instance.applyRedaction(
        sourcePdf: samplePdf,
        redactions: [
          PdfRedactionArea(
            pageIndex: 0,
            x: 40,
            y: 40,
            width: 300,
            height: 50,
            overlayText: '[REDACTED]',
          ),
        ],
        outputFileName: 'redacted_test',
        sanitizeMetadata: true,
      );
      expect(await redacted.exists(), isTrue);
    });
  });

  group('F-42: CloudBackupService Tests', () {
    test('Packages database into .scaneliq archive and restores it', () async {
      final db = await openDatabase(
        '${tempDir.path}/backup_test.db',
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, export_path TEXT)',
          );
          await db.execute(
            'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT)',
          );
          await db.execute(
            'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_tags (document_id TEXT, tag_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT)',
          );
          await db.insert('folders', {'id': 'f_1', 'name': 'Invoices'});
          await db.insert('documents', {'id': 'd_1', 'title': 'Invoice 101'});
        },
      );
      AppDatabaseService.instance.setDatabaseForTesting(db);

      final archiveFile = await CloudBackupService.instance
          .createBackupArchive();
      expect(await archiveFile.exists(), isTrue);
      expect(archiveFile.path, endsWith('.scaneliq'));

      // Test Restore into fresh database
      final restoreDb = await openDatabase(
        '${tempDir.path}/restore_test.db',
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, export_path TEXT)',
          );
          await db.execute(
            'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT)',
          );
          await db.execute(
            'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_tags (document_id TEXT, tag_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT)',
          );
        },
      );
      AppDatabaseService.instance.setDatabaseForTesting(restoreDb);

      final res = await CloudBackupService.instance.restoreBackupArchive(
        archiveFile,
      );
      expect(res.success, isTrue);
      expect(res.restoredDocuments, 1);
      expect(res.restoredFolders, 1);

      await db.close();
      await restoreDb.close();
    });
  });
}

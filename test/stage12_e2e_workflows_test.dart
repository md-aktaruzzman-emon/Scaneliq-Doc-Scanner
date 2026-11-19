import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/cloud_sync/data/cloud_backup_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/intelligence/data/ai_document_service.dart';
import 'package:scaneliq/features/intelligence/data/receipt_parser_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  Future<Database> openSchemaV6Db(String path) {
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (d, version) async {
          await d.execute(
            'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL, page_count INTEGER NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0, is_draft INTEGER NOT NULL DEFAULT 0, export_path TEXT, folder_id TEXT, deleted_at INTEGER)',
          );
          await d.execute(
            'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_order INTEGER NOT NULL, original_path TEXT NOT NULL, processed_path TEXT, edit_recipe_json TEXT NOT NULL, width INTEGER, height INTEGER)',
          );
          await d.execute(
            'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, color INTEGER NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (document_id, tag_id))',
          );
          await d.execute(
            'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_number INTEGER NOT NULL, title TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await d.execute('''
            CREATE VIRTUAL TABLE documents_fts USING fts5(
              document_id UNINDEXED,
              title,
              full_text,
              tokenize='unicode61 remove_diacritics 1'
            )
          ''');
        },
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_stage12_e2e_');
    await AppStorageService.instance.init(tempDir);
    SharedPreferences.setMockInitialValues({});
    OcrService.instance.nativeTesseractOverrideForTesting = null;
  });

  tearDown(() async {
    OcrService.instance.nativeTesseractOverrideForTesting = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('End-to-end pipeline: Scan Isolate Filter + Redact -> Mixed Bn-En OCR + AI/Invoice -> Searchable UTF-8 PDF -> FTS5 Vault + Duplicate -> Flatten & Scrub -> AES-256 Backup & Restore', () async {
    final db = await openSchemaV6Db('${tempDir.path}/vault_e2e.db');
    AppDatabaseService.instance.setDatabaseForTesting(db);

    // 1. Create a bright scan image and verify isolate filter + irreversible blackout
    final imgCanvas = img.Image(width: 480, height: 640);
    img.fill(imgCanvas, color: img.ColorRgb8(240, 240, 240));
    final rawScanFile = await AppStorageService.instance.saveOriginalPage(
      'e2e_scan_1',
      img.encodeJpg(imgCanvas, quality: 92),
    );

    final enhancedBytes =
        await ImageProcessingService.processImageFileToBytesInIsolate(
          rawScanFile,
          const EditRecipe(filter: PageFilter.magicColor),
        );
    expect(enhancedBytes, isNotEmpty);

    final redactedPreviewFile = File('${tempDir.path}/redacted_scan.jpg');
    await ImageProcessingService.permanentlyRedactImageFile(
      sourceImage: rawScanFile,
      targetImage: redactedPreviewFile,
      normX: 0.1,
      normY: 0.1,
      normW: 0.5,
      normH: 0.2,
    );
    final decodedRedacted = img.decodeImage(
      await redactedPreviewFile.readAsBytes(),
    )!;
    final samplePixel = decodedRedacted.getPixel(120, 96);
    expect(samplePixel.r, lessThan(20));

    // 2. Bilingual Mixed Bengali-English OCR + Intelligence + Invoice parsing
    const bilingualInvoiceText = '''
ঢাকা এন্টারপ্রাইজ লিমিটেড
Invoice # INV-2026-550
TIN: TIN-998877
Date: 2026-11-19
নোটবুক এবং কাগজ ৫০০.০০ টাকা
VAT (15%) 75.00
Grand Total BDT 575.00
''';
    OcrService.instance.nativeTesseractOverrideForTesting =
        (processedFile, script) async => const PageOcrResult(
          fullText: bilingualInvoiceText,
          boxes: [
            OcrBoundingBox(
              text:
                  'ঢাকা এন্টারপ্রাইজ লিমিটেড Invoice # INV-2026-550 BDT 575.00',
              left: 36,
              top: 48,
              width: 400,
              height: 26,
            ),
          ],
          script: OcrScript.mixedBengaliEnglish,
          engine: 'tesseract4android:ben+eng',
        );

    final ocrResult = await OcrService.instance.extractPageOcr(
      rawScanFile,
      script: OcrScript.mixedBengaliEnglish,
    );
    expect(ocrResult.script, OcrScript.mixedBengaliEnglish);
    expect(OcrService.containsBengali(ocrResult.fullText), isTrue);

    final parsedInvoice = ReceiptParserService.instance.parseText(
      ocrResult.fullText,
    );
    expect(parsedInvoice.invoiceNumber, 'INV-2026-550');
    expect(parsedInvoice.vendorTaxId, 'TIN-998877');
    expect(parsedInvoice.total, 575.00);

    final aiEntities = AiDocumentService.instance.extractEntities(
      ocrResult.fullText,
    );
    expect(aiEntities.identifiers, contains('INV-2026-550'));
    expect(aiEntities.amounts, isNotEmpty);

    // 3. Build searchable PDF preserving Bengali Unicode & persist in SQLite v6
    final folder = await AppDatabaseService.instance.createFolder('Invoices');
    final subFolder = await AppDatabaseService.instance.createFolder(
      'Dhaka 2026',
      parentId: folder.id,
    );
    final doc = ScannedDocument(
      id: 'e2e_doc_1',
      title: 'ঢাকা Invoice INV-2026-550',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      pageCount: 1,
      folderId: subFolder.id,
    );
    final page = DocumentPage(
      id: 'e2e_page_1',
      documentId: doc.id,
      pageOrder: 0,
      originalPath: rawScanFile.path,
      editRecipe: const EditRecipe(),
    );

    final searchablePdf = await PdfService.generatePdf(
      document: doc,
      pages: [page],
      ocrBoxesByPage: {0: ocrResult.boxes},
    );
    expect(await searchablePdf.exists(), isTrue);

    final sfDoc = sf.PdfDocument(inputBytes: await searchablePdf.readAsBytes());
    try {
      final extracted = sf.PdfTextExtractor(sfDoc).extractText();
      expect(extracted, contains('INV-2026-550'));
      expect(OcrService.containsBengali(extracted), isTrue);
    } finally {
      sfDoc.dispose();
    }

    await AppDatabaseService.instance.saveDocumentWithPages(
      doc.copyWith(exportPath: searchablePdf.path),
      [page],
    );
    await AppDatabaseService.instance.saveDocumentOcr(
      doc.id,
      ocrResult.fullText,
    );

    final ftsMatches = await AppDatabaseService.instance
        .searchDocumentsWithSnippets('এন্টারপ্রাইজ');
    expect(ftsMatches.length, 1);
    expect(ftsMatches.first.document.id, doc.id);

    final cloned = await AppDatabaseService.instance.duplicateDocument(doc.id);
    expect(cloned, isNotNull);
    expect(cloned!.title, 'ঢাকা Invoice INV-2026-550 (Copy)');

    // 4. Flatten & Scrub PDF removes all vector/OCR extractable text
    final flatPng = img.encodePng(imgCanvas);
    final scrubbedPdf = await AdvancedPdfService.instance.flattenAndRedactPdf(
      sourcePdf: searchablePdf,
      redactions: const [
        PdfRedactionArea(pageIndex: 0, x: 20, y: 30, width: 450, height: 80),
      ],
      outputFileName: 'Scrubbed_E2E',
      pageRasterizerOverride: (_) async => [flatPng],
    );
    final scrubbedSf = sf.PdfDocument(
      inputBytes: await scrubbedPdf.readAsBytes(),
    );
    try {
      expect(sf.PdfTextExtractor(scrubbedSf).extractText().trim(), isEmpty);
    } finally {
      scrubbedSf.dispose();
    }

    // 5. Encrypted Backup & Non-destructive Restore into fresh DB
    final backupFile = await CloudBackupService.instance.createBackupArchive(
      encryptionPassword: 'E2E-Vault-Key-2026',
    );
    final backupPrefix = String.fromCharCodes(
      (await backupFile.readAsBytes()).take(
        CloudBackupService.encryptedHeaderV2.length,
      ),
    );
    expect(backupPrefix, CloudBackupService.encryptedHeaderV2);

    final restoreDb = await openSchemaV6Db('${tempDir.path}/restore_e2e.db');
    AppDatabaseService.instance.setDatabaseForTesting(restoreDb);

    final wrongPassResult = await CloudBackupService.instance
        .restoreBackupArchive(backupFile, decryptionPassword: 'Wrong-Password');
    expect(wrongPassResult.success, isFalse);

    final restoreResult = await CloudBackupService.instance
        .restoreBackupArchive(
          backupFile,
          decryptionPassword: 'E2E-Vault-Key-2026',
        );
    expect(restoreResult.success, isTrue);
    expect(restoreResult.restoredDocuments, 2); // original + duplicate
    expect(restoreResult.restoredFolders, 2); // parent + nested child

    await db.close();
    await restoreDb.close();
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/intelligence/data/ai_document_service.dart';
import 'package:scaneliq/features/scanner/data/translation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('scaneliq_stage7_ai_');
    await AppStorageService.instance.init(tempDir);
    TranslationService.instance.translatorOverrideForTesting = null;
  });

  tearDown(() async {
    TranslationService.instance.translatorOverrideForTesting = null;
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Stage 7 — Offline Translation & Upgraded AI Intelligence', () {
    test('TranslationService infers Bn script, runs offline route cleanly & exports UTF-8 PDF + TXT', () async {
      expect(
        TranslationService.inferSourceLanguage('বাংলাদেশ সরকার কর রশিদ'),
        equals('bn'),
      );
      expect(
        TranslationService.inferSourceLanguage('Commercial Invoice FY26'),
        equals('en'),
      );

      TranslationService.instance.translatorOverrideForTesting =
          (text, src, dst, preferOffline) async => TranslationOutcome(
            translatedText: 'Government Tax Receipt 2026 — বাংলা অনুবাদ',
            resolvedSourceLang: src,
            targetLang: dst,
            usedOfflineModel: true,
          );

      final outcome = await TranslationService.instance.translate(
        text: 'সরকারি কর রশিদ ২০২৬',
        sourceLang: 'auto',
        targetLang: 'en',
        preferOffline: true,
      );

      expect(outcome.usedOfflineModel, isTrue);
      expect(outcome.resolvedSourceLang, equals('bn'));
      expect(outcome.translatedText, contains('Tax Receipt'));

      final txtFile = await TranslationService.instance.exportAsText(
        sourceText: 'সরকারি কর রশিদ ২০২৬',
        translatedText: outcome.translatedText,
        sourceLang: 'bn',
        targetLang: 'en',
      );
      final pdfFile = await TranslationService.instance.exportAsPdf(
        sourceText: 'সরকারি কর রশিদ ২০২৬',
        translatedText: outcome.translatedText,
        sourceLang: 'bn',
        targetLang: 'en',
      );

      expect(txtFile.existsSync(), isTrue);
      expect(pdfFile.existsSync(), isTrue);
      expect(await txtFile.readAsString(), contains('TRANSLATED (en)'));
    });

    test('AiDocumentService extracts dates, amounts, orgs, explains document, and answers Bn+En Q&A', () async {
      const sampleContract = '''
Commercial Service Invoice INV-2026-884 issued by Apex Digital Ltd on 2026-11-18.
Total payment due is BDT 45,500.00 before 15/12/2026 for cloud scanning software licensing.
বাংলাদেশ কর নং ১২৩৪ এবং মোট টাকা ১২,০০০.০০।
Please send signed remittance confirmation to billing@apexdigital.example or call +880 1711-000111.
''';

      final summary = AiDocumentService.instance.summarize(sampleContract);
      expect(summary.bulletPoints, isNotEmpty);
      expect(summary.totalSentences, greaterThanOrEqualTo(3));

      final entities = AiDocumentService.instance.extractEntities(
        sampleContract,
      );
      expect(entities.dates, containsAll(['2026-11-18', '15/12/2026']));
      expect(entities.amounts.any((a) => a.contains('45,500.00')), isTrue);
      expect(
        entities.identifiers.any((id) => id.contains('INV-2026-884')),
        isTrue,
      );
      expect(entities.emails, contains('billing@apexdigital.example'));
      expect(
        entities.namesAndOrganizations.any((o) => o.contains('Apex Digital')),
        isTrue,
      );

      final explanation = AiDocumentService.instance.explainDocument(
        sampleContract,
      );
      expect(explanation.documentCategory, contains('Invoice'));
      expect(explanation.plainExplanation, contains('45,500.00'));

      final qaAmount = AiDocumentService.instance.answerQuestion(
        sampleContract,
        'How much is the total amount?',
      );
      expect(qaAmount.bestAnswer, contains('45,500.00'));
      expect(qaAmount.confidence, greaterThan(0.7));

      final qaBangla = AiDocumentService.instance.answerQuestion(
        sampleContract,
        'বাংলাদেশ কর নম্বর কত?',
      );
      expect(qaBangla.bestAnswer, contains('১২,০০০'));
    });

    test('AiDocumentService semanticSearchVault ranks matching vault documents using concept expansion', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (d, _) async {
            await d.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT, parent_id TEXT, created_at INTEGER, modified_at INTEGER)',
            );
            await d.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER, modified_at INTEGER, page_count INTEGER, is_favorite INTEGER, is_draft INTEGER, export_path TEXT, folder_id TEXT, deleted_at INTEGER)',
            );
            await d.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_order INTEGER, original_path TEXT, processed_path TEXT, edit_recipe_json TEXT, width INTEGER, height INTEGER)',
            );
            await d.execute(
              'CREATE TABLE document_ocr (document_id TEXT PRIMARY KEY, full_text TEXT NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, color INTEGER, created_at INTEGER, modified_at INTEGER)',
            );
            await d.execute(
              'CREATE TABLE document_tags (document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER)',
            );
            await d.execute(
              'CREATE TABLE document_bookmarks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL, page_number INTEGER, title TEXT, created_at INTEGER)',
            );
            await d.execute(
              'CREATE VIRTUAL TABLE documents_fts USING fts5(document_id UNINDEXED, title, full_text)',
            );
          },
        ),
      );
      AppDatabaseService.instance.setDatabaseForTesting(db);

      try {
        final d1 = ScannedDocument(
          id: 'ai_v1',
          title: 'Vendor Bill',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 1,
        );
        final d2 = ScannedDocument(
          id: 'ai_v2',
          title: 'Botany Notes',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          pageCount: 1,
        );
        await AppDatabaseService.instance.saveDocument(d1);
        await AppDatabaseService.instance.saveDocument(d2);
        await AppDatabaseService.instance.saveDocumentOcr(
          'ai_v1',
          'Subtotal 100.00 VAT 15.00 Payment receipt for hardware',
        );
        await AppDatabaseService.instance.saveDocumentOcr(
          'ai_v2',
          'Photosynthesis chlorophyll plant biology lecture summary',
        );

        final hits = await AiDocumentService.instance.semanticSearchVault(
          'invoice',
        );
        expect(hits, isNotEmpty);
        expect(hits.first.document.id, equals('ai_v1'));
      } finally {
        await db.close();
        AppDatabaseService.instance.setDatabaseForTesting(null);
      }
    });
  });
}

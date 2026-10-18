import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppStorageService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('scaneliq_storage_test_');
      await AppStorageService.instance.init(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Initializes required subdirectories', () {
      expect(AppStorageService.instance.originalsDir.existsSync(), isTrue);
      expect(AppStorageService.instance.processedDir.existsSync(), isTrue);
      expect(AppStorageService.instance.exportsDir.existsSync(), isTrue);
      expect(AppStorageService.instance.tempDir.existsSync(), isTrue);
    });

    test('Saves original page image atomically', () async {
      final fakeBytes = [0xDE, 0xAD, 0xBE, 0xEF];
      final savedFile = await AppStorageService.instance.saveOriginalPage('page_test_1', fakeBytes);

      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsBytes(), equals(fakeBytes));
      expect(savedFile.path.contains('originals'), isTrue);
    });

    test('getExportPdfPath sanitizes filename characters', () {
      final sanitizedPath = AppStorageService.instance.getExportPdfPath('Invalid/Name:With*Bad?Chars');
      final fileName = sanitizedPath.split(Platform.pathSeparator).last;
      expect(fileName.contains(':'), isFalse);
      expect(fileName.contains('*'), isFalse);
      expect(fileName.contains('?'), isFalse);
      expect(fileName.contains('/'), isFalse);
      expect(fileName.endsWith('.pdf'), isTrue);
    });

    test('deleteDocumentFiles removes export PDF and original page files', () async {
      // 1. Create fake page original file
      final pageFile = await AppStorageService.instance.saveOriginalPage('page_to_delete', [1, 2, 3]);
      expect(await pageFile.exists(), isTrue);

      // 2. Create fake export file
      final exportPath = AppStorageService.instance.getExportPdfPath('doc_to_delete');
      final exportFile = File(exportPath);
      await exportFile.writeAsBytes([4, 5, 6]);
      expect(await exportFile.exists(), isTrue);

      final doc = ScannedDocument(
        id: 'doc_del_01',
        title: 'doc_to_delete',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
        exportPath: exportPath,
        pages: [
          DocumentPage(
            id: 'page_to_delete',
            documentId: 'doc_del_01',
            pageOrder: 0,
            originalPath: pageFile.path,
          ),
        ],
      );

      // Execute deletion
      await AppStorageService.instance.deleteDocumentFiles(doc);

      expect(await pageFile.exists(), isFalse);
      expect(await exportFile.exists(), isFalse);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

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
      final savedFile = await AppStorageService.instance.saveOriginalPage(
        'page_test_1',
        fakeBytes,
      );

      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsBytes(), equals(fakeBytes));
      expect(savedFile.path.contains('originals'), isTrue);
    });

    test(
      'getExportPdfPath sanitizes filename characters and produces valid paths',
      () {
        final sanitizedPath = AppStorageService.instance.getExportPdfPath(
          'Invalid/Name:With*Bad?Chars',
        );
        final fileName = sanitizedPath.split(Platform.pathSeparator).last;
        expect(fileName.contains(':'), isFalse);
        expect(fileName.contains('*'), isFalse);
        expect(fileName.contains('?'), isFalse);
        expect(fileName.contains('/'), isFalse);
        expect(fileName.endsWith('.pdf'), isTrue);
      },
    );

    test('Original image remains bit-for-bit preserved after EditRecipe and JPEG export', () async {
      // Create a test original image
      final source = img.Image(width: 150, height: 150);
      img.fill(source, color: img.ColorRgb8(128, 64, 32));
      final originalJpgBytes = img.encodeJpg(source);

      final originalFile = await AppStorageService.instance.saveOriginalPage(
        'immutable_page_1',
        originalJpgBytes,
      );
      final preExportBytes = await originalFile.readAsBytes();

      final page = DocumentPage(
        id: 'immutable_page_1',
        documentId: 'doc_imm',
        pageOrder: 0,
        originalPath: originalFile.path,
        editRecipe: const EditRecipe(
          rotationDegrees: 180,
          filter: PageFilter.blackAndWhite,
          contrast: 1.5,
          brightness: 0.2,
        ),
      );

      // Perform JPEG export with heavy transformations
      final exported = await PdfService.exportPageAsJpeg(
        page: page,
        baseName: 'Transformed_Export',
      );
      expect(await exported.exists(), isTrue);

      // Verify original file is bit-for-bit unchanged
      final postExportBytes = await originalFile.readAsBytes();
      expect(postExportBytes, equals(preExportBytes));
    });

    test(
      'deleteDocumentFiles removes export PDF and original page files',
      () async {
        // 1. Create fake page original file
        final pageFile = await AppStorageService.instance.saveOriginalPage(
          'page_to_delete',
          [1, 2, 3],
        );
        expect(await pageFile.exists(), isTrue);

        // 2. Create fake export file
        final exportPath = AppStorageService.instance.getExportPdfPath(
          'doc_to_delete',
        );
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
      },
    );
  });
}

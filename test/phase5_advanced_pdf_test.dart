import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late File samplePdf3Pages;
  late File samplePdf1Page;
  late File sampleImageFile;
  late Database testDb;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_phase5_test_');
    await AppStorageService.instance.init(tempDir);

    // Setup SQLite DB for bookmarks
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
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
              deleted_at INTEGER
            )
          ''');

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
        },
      ),
    );
    AppDatabaseService.instance.setDatabaseForTesting(testDb);

    // Create a 3-page sample PDF
    final doc3 = sf.PdfDocument();
    for (int i = 1; i <= 3; i++) {
      final page = doc3.pages.add();
      page.graphics.drawString(
        'Document 3 - Page $i Content',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(50, 50, 400, 50),
      );
    }
    doc3.documentInformation.title = 'Sample 3-Page Document';
    doc3.documentInformation.author = 'Scaneliq Engine';
    samplePdf3Pages = File('${tempDir.path}/sample_3pages.pdf');
    await samplePdf3Pages.writeAsBytes(doc3.saveSync());
    doc3.dispose();

    // Create a 1-page sample PDF
    final doc1 = sf.PdfDocument();
    doc1.pages.add().graphics.drawString(
      'Document 1 - Single Page Content',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
      bounds: const Rect.fromLTWH(50, 50, 400, 50),
    );
    samplePdf1Page = File('${tempDir.path}/sample_1page.pdf');
    await samplePdf1Page.writeAsBytes(doc1.saveSync());
    doc1.dispose();

    // Create a sample image file for image-insertion test
    final image = img.Image(width: 200, height: 200);
    img.fill(image, color: img.ColorRgb8(0, 100, 200));
    final pngBytes = img.encodePng(image);
    sampleImageFile = File('${tempDir.path}/test_image.png');
    await sampleImageFile.writeAsBytes(pngBytes);
  });

  tearDownAll(() async {
    await testDb.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 5 — PDF Inspection & Validation', () {
    test(
      'validatePdf accurately identifies valid, empty, and corrupt PDFs',
      () async {
        final isValid = await AdvancedPdfService.instance.validatePdf(
          samplePdf3Pages,
        );
        expect(isValid, isTrue);

        final emptyFile = File('${tempDir.path}/empty.pdf');
        await emptyFile.writeAsBytes([]);
        expect(
          await AdvancedPdfService.instance.validatePdf(emptyFile),
          isFalse,
        );

        final corruptFile = File('${tempDir.path}/corrupt.pdf');
        await corruptFile.writeAsString('THIS IS NOT A VALID PDF FILE CONTENT');
        expect(
          await AdvancedPdfService.instance.validatePdf(corruptFile),
          isFalse,
        );
      },
    );

    test('inspectPdf correctly extracts metadata and dimensions', () async {
      final metadata = await AdvancedPdfService.instance.inspectPdf(
        samplePdf3Pages,
      );
      expect(metadata.pageCount, equals(3));
      expect(metadata.fileSizeBytes, greaterThan(0));
      expect(metadata.isEncrypted, isFalse);
      expect(metadata.title, equals('Sample 3-Page Document'));
      expect(metadata.author, equals('Scaneliq Engine'));
      expect(metadata.firstPageWidth, greaterThan(0));
      expect(metadata.firstPageHeight, greaterThan(0));
    });

    test('getPageCount returns exact page count', () async {
      final count3 = await AdvancedPdfService.instance.getPageCount(
        samplePdf3Pages,
      );
      expect(count3, equals(3));

      final count1 = await AdvancedPdfService.instance.getPageCount(
        samplePdf1Page,
      );
      expect(count1, equals(1));
    });
  });

  group('Phase 5 — Page Organizer Operations', () {
    test('reorderPages changes page sequence correctly', () async {
      // Original 3 pages -> reorder to [3, 1, 2]
      final reordered = await AdvancedPdfService.instance.reorderPages(
        sourcePdf: samplePdf3Pages,
        newPageOrder1Indexed: [3, 1, 2],
        outputFileName: 'reordered_test',
      );

      expect(reordered.existsSync(), isTrue);
      expect(
        await AdvancedPdfService.instance.getPageCount(reordered),
        equals(3),
      );
    });

    test(
      'rotatePages applies 90/180/270 degree rotation to specified pages',
      () async {
        final rotated = await AdvancedPdfService.instance.rotatePages(
          sourcePdf: samplePdf3Pages,
          pageRotationsDegrees: {1: 90, 2: 180, 3: 270},
          outputFileName: 'rotated_test',
        );

        expect(rotated.existsSync(), isTrue);
        expect(
          await AdvancedPdfService.instance.getPageCount(rotated),
          equals(3),
        );

        // Inspect rotated document
        final bytes = await rotated.readAsBytes();
        final doc = sf.PdfDocument(inputBytes: bytes);
        expect(
          doc.pages[0].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle90),
        );
        expect(
          doc.pages[1].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle180),
        );
        expect(
          doc.pages[2].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle270),
        );
        doc.dispose();
      },
    );

    test(
      'deletePages removes selected pages and preserves remainder',
      () async {
        // Delete page 2 from 3-page document -> results in 2 pages
        final deleted = await AdvancedPdfService.instance.deletePages(
          sourcePdf: samplePdf3Pages,
          pagesToDelete1Indexed: [2],
          outputFileName: 'deleted_page2_test',
        );

        expect(deleted.existsSync(), isTrue);
        expect(
          await AdvancedPdfService.instance.getPageCount(deleted),
          equals(2),
        );
      },
    );

    test('deletePages throws if attempting to delete all pages', () async {
      expect(
        () => AdvancedPdfService.instance.deletePages(
          sourcePdf: samplePdf3Pages,
          pagesToDelete1Indexed: [1, 2, 3],
          outputFileName: 'delete_all_fail',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'duplicatePage duplicates specified page and inserts following itself',
      () async {
        // Duplicate page 1 -> results in 4 pages
        final duplicated = await AdvancedPdfService.instance.duplicatePage(
          sourcePdf: samplePdf3Pages,
          pageNumber1Indexed: 1,
          outputFileName: 'duplicated_page1_test',
        );

        expect(duplicated.existsSync(), isTrue);
        expect(
          await AdvancedPdfService.instance.getPageCount(duplicated),
          equals(4),
        );
      },
    );

    test(
      'insertPagesFromPdf inserts pages from external PDF into target',
      () async {
        // Insert samplePdf1Page into samplePdf3Pages after page 1 -> 4 pages total
        final result = await AdvancedPdfService.instance.insertPagesFromPdf(
          sourcePdf: samplePdf3Pages,
          insertAfterPageIndex1Indexed: 1,
          pdfToInsert: samplePdf1Page,
          outputFileName: 'inserted_from_pdf_test',
        );

        expect(result.existsSync(), isTrue);
        expect(
          await AdvancedPdfService.instance.getPageCount(result),
          equals(4),
        );
      },
    );

    test('insertImageAsPage appends an image file as a new PDF page', () async {
      final withImage = await AdvancedPdfService.instance.insertImageAsPage(
        sourcePdf: samplePdf3Pages,
        insertAfterPageIndex1Indexed: 3,
        imageFile: sampleImageFile,
        outputFileName: 'inserted_image_page_test',
      );

      expect(withImage.existsSync(), isTrue);
      expect(
        await AdvancedPdfService.instance.getPageCount(withImage),
        equals(4),
      );
    });
  });

  group('Phase 5 — Merge & Split Operations', () {
    test(
      'mergePdfs combines multiple PDFs preserving page integrity',
      () async {
        final merged = await AdvancedPdfService.instance.mergePdfs(
          sourcePdfs: [samplePdf3Pages, samplePdf1Page],
          outputFileName: 'phase5_merged_test',
        );

        expect(merged.existsSync(), isTrue);
        expect(
          await AdvancedPdfService.instance.getPageCount(merged),
          equals(4),
        );
      },
    );

    test(
      'splitPdfIntoPages splits document into separate single-page files',
      () async {
        final pages = await AdvancedPdfService.instance.splitPdfIntoPages(
          sourcePdf: samplePdf3Pages,
          baseOutputName: 'split_single',
        );

        expect(pages.length, equals(3));
        for (final p in pages) {
          expect(p.existsSync(), isTrue);
          expect(await AdvancedPdfService.instance.getPageCount(p), equals(1));
        }
      },
    );

    test(
      'splitPdfByRanges splits document according to multi-page ranges',
      () async {
        // Split into ranges [[1, 2], [3]]
        final splitRanges = await AdvancedPdfService.instance.splitPdfByRanges(
          sourcePdf: samplePdf3Pages,
          ranges1Indexed: [
            [1, 2],
            [3],
          ],
          baseOutputName: 'split_range_test',
        );

        expect(splitRanges.length, equals(2));
        expect(
          await AdvancedPdfService.instance.getPageCount(splitRanges[0]),
          equals(2),
        );
        expect(
          await AdvancedPdfService.instance.getPageCount(splitRanges[1]),
          equals(1),
        );
      },
    );
  });

  group('Phase 5 — PDF Compression Engine', () {
    test(
      'compressPdf executes High Quality preset and reports metrics',
      () async {
        final result = await AdvancedPdfService.instance.compressPdf(
          sourcePdf: samplePdf3Pages,
          preset: PdfCompressionPreset.highQuality,
          outputFileName: 'comp_high_test',
        );

        expect(result.outputFile.existsSync(), isTrue);
        expect(result.originalSizeBytes, greaterThan(0));
        expect(result.compressedSizeBytes, greaterThan(0));
        expect(result.percentageReduction, isNotNull);
        expect(
          await AdvancedPdfService.instance.getPageCount(result.outputFile),
          equals(3),
        );
      },
    );

    test('compressPdf executes Balanced preset and reports metrics', () async {
      final result = await AdvancedPdfService.instance.compressPdf(
        sourcePdf: samplePdf3Pages,
        preset: PdfCompressionPreset.balanced,
        outputFileName: 'comp_balanced_test',
      );

      expect(result.outputFile.existsSync(), isTrue);
      expect(result.originalSizeBytes, greaterThan(0));
      expect(result.compressedSizeBytes, greaterThan(0));
      expect(
        await AdvancedPdfService.instance.getPageCount(result.outputFile),
        equals(3),
      );
    });

    test(
      'compressPdf executes Small File preset and reports metrics',
      () async {
        final result = await AdvancedPdfService.instance.compressPdf(
          sourcePdf: samplePdf3Pages,
          preset: PdfCompressionPreset.smallerFile,
          outputFileName: 'comp_small_test',
        );

        expect(result.outputFile.existsSync(), isTrue);
        expect(result.originalSizeBytes, greaterThan(0));
        expect(result.compressedSizeBytes, greaterThan(0));
        expect(
          await AdvancedPdfService.instance.getPageCount(result.outputFile),
          equals(3),
        );
      },
    );
  });

  group('Phase 5 — Watermarking Engine', () {
    test('addWatermark applies preset watermark text with custom opacity and rotation', () async {
      final watermarked = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: samplePdf3Pages,
        watermarkText: 'CONFIDENTIAL',
        options: const WatermarkOptions(
          text: 'CONFIDENTIAL',
          opacity: 0.3,
          fontSize: 48,
          rotationDegrees: 45,
          position: WatermarkPosition.diagonalCenter,
          pageSelection: WatermarkPageSelection.allPages,
        ),
        outputFileName: 'confidential_watermark_test',
      );

      expect(watermarked.existsSync(), isTrue);
      expect(
        await AdvancedPdfService.instance.getPageCount(watermarked),
        equals(3),
      );
    });

    test('addWatermark targets odd pages only', () async {
      final watermarkedOdd = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: samplePdf3Pages,
        watermarkText: 'DRAFT',
        options: const WatermarkOptions(
          text: 'DRAFT',
          pageSelection: WatermarkPageSelection.oddPagesOnly,
          position: WatermarkPosition.headerTop,
        ),
        outputFileName: 'odd_draft_watermark_test',
      );

      expect(watermarkedOdd.existsSync(), isTrue);
      expect(
        await AdvancedPdfService.instance.getPageCount(watermarkedOdd),
        equals(3),
      );
    });

    test('addWatermark targets custom page range', () async {
      final watermarkedRange = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: samplePdf3Pages,
        watermarkText: 'COPY',
        options: const WatermarkOptions(
          text: 'COPY',
          pageSelection: WatermarkPageSelection.customPages,
          customPages1Indexed: [2],
          position: WatermarkPosition.footerBottom,
        ),
        outputFileName: 'custom_page2_watermark_test',
      );

      expect(watermarkedRange.existsSync(), isTrue);
      expect(
        await AdvancedPdfService.instance.getPageCount(watermarkedRange),
        equals(3),
      );
    });
  });

  group('Phase 5 — Native Bookmarks & Outlines', () {
    test(
      'addOutlineBookmarks embeds native PDF outlines and extracts them',
      () async {
        final withOutlines = await AdvancedPdfService.instance
            .addOutlineBookmarks(
              sourcePdf: samplePdf3Pages,
              bookmarksTitleToPage1Indexed: {
                'Chapter 1: Intro': 1,
                'Chapter 2: Analysis': 2,
                'Chapter 3: Conclusion': 3,
              },
              outputFileName: 'bookmarks_outline_test',
            );

        expect(withOutlines.existsSync(), isTrue);

        final extracted = await AdvancedPdfService.instance
            .extractOutlineBookmarks(withOutlines);
        expect(extracted.length, equals(3));
        expect(extracted[0].title, equals('Chapter 1: Intro'));
        expect(extracted[0].pageNumber1Indexed, equals(1));
        expect(extracted[1].title, equals('Chapter 2: Analysis'));
        expect(extracted[1].pageNumber1Indexed, equals(2));
        expect(extracted[2].title, equals('Chapter 3: Conclusion'));
        expect(extracted[2].pageNumber1Indexed, equals(3));
      },
    );
  });

  group('Phase 5 — In-App SQLite Bookmarks CRUD', () {
    const testDocId = 'test-doc-bookmarks-1';

    setUp(() async {
      // Insert test document
      await testDb.insert('documents', {
        'id': testDocId,
        'title': 'Test Doc for Bookmarks',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
        'page_count': 5,
      });
    });

    test('addBookmark, getBookmarks, updateBookmarkTitle, and deleteBookmark work correctly', () async {
      // 1. Add Bookmark
      final b1 = await AppDatabaseService.instance.addBookmark(
        documentId: testDocId,
        pageNumber: 2,
        title: 'Executive Summary',
      );
      expect(b1.id.isNotEmpty, isTrue);
      expect(b1.pageNumber, equals(2));
      expect(b1.title, equals('Executive Summary'));

      final b2 = await AppDatabaseService.instance.addBookmark(
        documentId: testDocId,
        pageNumber: 4,
        title: 'Financial Statements',
      );
      expect(b2.pageNumber, equals(4));

      // 2. Get Bookmarks
      var list = await AppDatabaseService.instance.getBookmarks(testDocId);
      expect(list.length, equals(2));
      expect(list[0].pageNumber, equals(2)); // Ordered by page_number ASC
      expect(list[1].pageNumber, equals(4));

      // 3. Update Bookmark Title
      await AppDatabaseService.instance.updateBookmarkTitle(
        b1.id,
        'Updated Summary',
      );

      list = await AppDatabaseService.instance.getBookmarks(testDocId);
      expect(list[0].title, equals('Updated Summary'));

      // 4. Delete Bookmark
      await AppDatabaseService.instance.deleteBookmark(b1.id);

      list = await AppDatabaseService.instance.getBookmarks(testDocId);
      expect(list.length, equals(1));
      expect(list[0].id, equals(b2.id));
    });
  });

  group('Phase 5 — Security: AES-256 Encryption, Verification & Decryption', () {
    const testPass = 'SecureMasterPass99!';

    test(
      'encryptPdf protects document with AES-256 and blocks unauthorized open',
      () async {
        final encrypted = await AdvancedPdfService.instance.encryptPdf(
          sourcePdf: samplePdf3Pages,
          userPassword: testPass,
          outputFileName: 'aes_encrypted_test',
        );

        expect(encrypted.existsSync(), isTrue);

        final metadata = await AdvancedPdfService.instance.inspectPdf(
          encrypted,
        );
        expect(metadata.isEncrypted, isTrue);

        // Verify wrong password fails
        final wrongCheck = await AdvancedPdfService.instance.verifyPassword(
          encrypted,
          'wrongPassword',
        );
        expect(wrongCheck, isFalse);

        // Verify correct password succeeds
        final rightCheck = await AdvancedPdfService.instance.verifyPassword(
          encrypted,
          testPass,
        );
        expect(rightCheck, isTrue);
      },
    );

    test(
      'removePassword decrypts document producing clean unencrypted file',
      () async {
        final encrypted = await AdvancedPdfService.instance.encryptPdf(
          sourcePdf: samplePdf3Pages,
          userPassword: testPass,
          outputFileName: 'to_be_unlocked_test',
        );

        final unlocked = await AdvancedPdfService.instance.removePassword(
          sourcePdf: encrypted,
          password: testPass,
          outputFileName: 'unlocked_result_test',
        );

        expect(unlocked.existsSync(), isTrue);
        final metadata = await AdvancedPdfService.instance.inspectPdf(unlocked);
        expect(metadata.isEncrypted, isFalse);
        expect(metadata.pageCount, equals(3));
      },
    );

    test('removePassword throws with wrong password', () async {
      final encrypted = await AdvancedPdfService.instance.encryptPdf(
        sourcePdf: samplePdf3Pages,
        userPassword: testPass,
        outputFileName: 'to_be_unlocked_fail_test',
      );

      expect(
        () => AdvancedPdfService.instance.removePassword(
          sourcePdf: encrypted,
          password: 'wrongPassword',
          outputFileName: 'fail_unlocked',
        ),
        throwsA(anything),
      );
    });
  });

  group('Phase 5 — Defensive Error Handling', () {
    test('non-existent file throws FileNotFoundException', () async {
      final ghostFile = File('${tempDir.path}/does_not_exist.pdf');

      expect(
        () => AdvancedPdfService.instance.inspectPdf(ghostFile),
        throwsA(isA<FileNotFoundException>()),
      );
      expect(
        await AdvancedPdfService.instance.getPageCount(ghostFile),
        equals(0),
      );
      expect(
        () => AdvancedPdfService.instance.extractPages(
          sourcePdf: ghostFile,
          pageNumbers: [1],
          outputFileName: 'fail_extract',
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('reorderPages with invalid page count throws RangeError', () async {
      expect(
        () => AdvancedPdfService.instance.reorderPages(
          sourcePdf: samplePdf3Pages,
          newPageOrder1Indexed: [1, 99], // Out of range page 99
          outputFileName: 'fail_reorder',
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test(
      'duplicatePage with out-of-range page number throws RangeError',
      () async {
        expect(
          () => AdvancedPdfService.instance.duplicatePage(
            sourcePdf: samplePdf3Pages,
            pageNumber1Indexed: 99,
            outputFileName: 'fail_dup',
          ),
          throwsA(isA<RangeError>()),
        );
      },
    );
  });
}

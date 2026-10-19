import 'dart:io';
import 'dart:ui';

import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Advanced PDF processing engine for merging, splitting, encrypting, and watermarking PDFs.
class AdvancedPdfService {
  static AdvancedPdfService? _instance;
  static AdvancedPdfService get instance =>
      _instance ??= AdvancedPdfService._();
  AdvancedPdfService._();

  /// Merges multiple existing PDF files into a single consolidated PDF file.
  Future<File> mergePdfs({
    required List<File> sourcePdfs,
    required String outputFileName,
  }) async {
    if (sourcePdfs.length < 2) {
      throw ArgumentError('At least 2 PDF files are required for merging.');
    }

    final sf.PdfDocument finalDoc = sf.PdfDocument();

    try {
      for (final file in sourcePdfs) {
        if (!await file.exists()) {
          throw FileNotFoundException(
            'Source PDF file does not exist: ${file.path}',
          );
        }
        final bytes = await file.readAsBytes();
        final sf.PdfDocument sourceDoc = sf.PdfDocument(inputBytes: bytes);
        try {
          final int pageCount = sourceDoc.pages.count;
          for (int i = 0; i < pageCount; i++) {
            final sf.PdfTemplate template = sourceDoc.pages[i].createTemplate();
            final sf.PdfPage newPage = finalDoc.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              const Offset(0, 0),
              newPage.size,
            );
          }
        } finally {
          sourceDoc.dispose();
        }
      }

      final List<int> outputBytes = finalDoc.saveSync();
      if (outputBytes.isEmpty) {
        throw StateError('Merging resulted in empty PDF output.');
      }

      final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final exportPath = AppStorageService.instance.getExportPdfPath(sanitized);
      final tempPath = '$exportPath.tmp';

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(outputBytes, flush: true);
      return await tempFile.rename(exportPath);
    } finally {
      finalDoc.dispose();
    }
  }

  /// Splits an existing PDF into individual single-page PDF files.
  Future<List<File>> splitPdfIntoPages({
    required File sourcePdf,
    required String baseOutputName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final sf.PdfDocument sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final List<File> generatedFiles = [];

    try {
      final int count = sourceDoc.pages.count;
      final sanitizedBase = baseOutputName.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );

      for (int i = 0; i < count; i++) {
        final sf.PdfDocument singleDoc = sf.PdfDocument();
        try {
          final sf.PdfTemplate template = sourceDoc.pages[i].createTemplate();
          final sf.PdfPage newPage = singleDoc.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.size,
          );

          final List<int> singleBytes = singleDoc.saveSync();
          final outName = '${sanitizedBase}_page_${i + 1}';
          final exportPath = AppStorageService.instance.getExportPdfPath(
            outName,
          );
          final tempPath = '$exportPath.tmp';

          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(singleBytes, flush: true);
          final committedFile = await tempFile.rename(exportPath);
          generatedFiles.add(committedFile);
        } finally {
          singleDoc.dispose();
        }
      }
      return generatedFiles;
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Extracts specific 1-indexed pages (e.g. [1, 3, 5]) into a new PDF document.
  Future<File> extractPages({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (pageNumbers.isEmpty) {
      throw ArgumentError('At least one page number must be specified.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final sf.PdfDocument sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfDocument extractedDoc = sf.PdfDocument();

    try {
      final int totalPages = sourceDoc.pages.count;
      for (final pNum in pageNumbers) {
        if (pNum < 1 || pNum > totalPages) {
          throw RangeError(
            'Page number $pNum is out of bounds (1 to $totalPages).',
          );
        }
        final sf.PdfTemplate template = sourceDoc.pages[pNum - 1]
            .createTemplate();
        final sf.PdfPage newPage = extractedDoc.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          newPage.size,
        );
      }

      final List<int> outputBytes = extractedDoc.saveSync();
      final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final exportPath = AppStorageService.instance.getExportPdfPath(sanitized);
      final tempPath = '$exportPath.tmp';

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(outputBytes, flush: true);
      return await tempFile.rename(exportPath);
    } finally {
      extractedDoc.dispose();
      sourceDoc.dispose();
    }
  }

  /// Protects a PDF with standard password encryption.
  Future<File> encryptPdf({
    required File sourcePdf,
    required String userPassword,
    String? ownerPassword,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (userPassword.trim().isEmpty) {
      throw ArgumentError('User password cannot be empty.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final sf.PdfDocument sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      final sf.PdfSecurity security = sourceDoc.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword ?? '${userPassword}_owner';
      security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;
      security.permissions.addAll([
        sf.PdfPermissionsFlags.print,
        sf.PdfPermissionsFlags.copyContent,
      ]);

      final List<int> encryptedBytes = sourceDoc.saveSync();
      final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final exportPath = AppStorageService.instance.getExportPdfPath(sanitized);
      final tempPath = '$exportPath.tmp';

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(encryptedBytes, flush: true);
      return await tempFile.rename(exportPath);
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Adds a diagonal text watermark (e.g. "CONFIDENTIAL") across every page of a PDF.
  Future<File> addWatermark({
    required File sourcePdf,
    required String watermarkText,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (watermarkText.trim().isEmpty) {
      throw ArgumentError('Watermark text cannot be empty.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final sf.PdfDocument sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      final sf.PdfFont font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        36,
        style: sf.PdfFontStyle.bold,
      );
      final sf.PdfBrush brush = sf.PdfSolidBrush(
        sf.PdfColor(180, 180, 180, 100),
      );

      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final page = sourceDoc.pages[i];
        final graphics = page.graphics;
        graphics.save();
        // Translate to center and rotate 45 degrees
        graphics.translateTransform(page.size.width / 2, page.size.height / 2);
        graphics.rotateTransform(-45);
        final textSize = font.measureString(watermarkText);
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );
        graphics.restore();
      }

      final List<int> watermarkedBytes = sourceDoc.saveSync();
      final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final exportPath = AppStorageService.instance.getExportPdfPath(sanitized);
      final tempPath = '$exportPath.tmp';

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(watermarkedBytes, flush: true);
      return await tempFile.rename(exportPath);
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Returns total page count of an existing PDF.
  Future<int> getPageCount(File sourcePdf) async {
    if (!await sourcePdf.exists()) return 0;
    final bytes = await sourcePdf.readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}

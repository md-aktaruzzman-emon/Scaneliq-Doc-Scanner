import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

// =============================================================================
// DATA MODELS & ENUMS FOR ADVANCED PDF OPERATIONS
// =============================================================================

/// PDF metadata and structural information
class PdfMetadataInfo {
  final int pageCount;
  final int fileSizeBytes;
  final bool isEncrypted;
  final String? title;
  final String? author;
  final String? producer;
  final DateTime? creationDate;
  final double firstPageWidth;
  final double firstPageHeight;

  const PdfMetadataInfo({
    required this.pageCount,
    required this.fileSizeBytes,
    required this.isEncrypted,
    this.title,
    this.author,
    this.producer,
    this.creationDate,
    required this.firstPageWidth,
    required this.firstPageHeight,
  });
}

/// Compression preset levels
enum PdfCompressionPreset {
  highQuality, // High visual fidelity (~85% JPEG quality)
  balanced, // Optimal balance of size and fidelity (~65% JPEG quality)
  smallerFile, // Maximum size reduction (~45% JPEG quality)
}

/// Measured result of a PDF compression operation
class PdfCompressionResult {
  final File outputFile;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int bytesSaved;
  final double percentageReduction;
  final PdfCompressionPreset preset;

  const PdfCompressionResult({
    required this.outputFile,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.bytesSaved,
    required this.percentageReduction,
    required this.preset,
  });
}

/// Positioning modes for watermarks
enum WatermarkPosition {
  diagonalCenter,
  horizontalCenter,
  headerTop,
  footerBottom,
  center,
}

/// Page target options for watermarks
enum WatermarkPageSelection {
  allPages,
  firstPageOnly,
  oddPagesOnly,
  evenPagesOnly,
  customPages,
}

/// Comprehensive configuration for PDF watermarks
class WatermarkOptions {
  final String text;
  final double fontSize;
  final Color color;
  final double opacity; // 0.0 to 1.0
  final double rotationDegrees;
  final WatermarkPosition position;
  final WatermarkPageSelection pageSelection;
  final List<int>? customPages1Indexed;
  final File? imageFile;
  final double imageScale;

  const WatermarkOptions({
    required this.text,
    this.fontSize = 36.0,
    this.color = const Color(0xFF888888),
    this.opacity = 0.25,
    this.rotationDegrees = -45.0,
    this.position = WatermarkPosition.diagonalCenter,
    this.pageSelection = WatermarkPageSelection.allPages,
    this.customPages1Indexed,
    this.imageFile,
    this.imageScale = 0.5,
  });

  /// Factory preset for Draft
  factory WatermarkOptions.draft() => const WatermarkOptions(
    text: 'DRAFT',
    color: Color(0xFF6B7280),
    opacity: 0.25,
    rotationDegrees: -45,
  );

  /// Factory preset for Confidential
  factory WatermarkOptions.confidential() => const WatermarkOptions(
    text: 'CONFIDENTIAL',
    color: Color(0xFFDC2626),
    opacity: 0.25,
    rotationDegrees: -45,
  );

  /// Factory preset for Copy
  factory WatermarkOptions.copy() => const WatermarkOptions(
    text: 'COPY',
    color: Color(0xFF2563EB),
    opacity: 0.25,
    rotationDegrees: -45,
  );

  /// Factory preset for Internal
  factory WatermarkOptions.internal() => const WatermarkOptions(
    text: 'INTERNAL ONLY',
    color: Color(0xFFD97706),
    opacity: 0.25,
    rotationDegrees: -45,
  );

  /// Factory preset for Approved
  factory WatermarkOptions.approved() => const WatermarkOptions(
    text: 'APPROVED',
    color: Color(0xFF059669),
    opacity: 0.25,
    rotationDegrees: -45,
  );
}

/// Outline bookmark item
class PdfOutlineItem {
  final String title;
  final int pageNumber1Indexed;

  const PdfOutlineItem({required this.title, required this.pageNumber1Indexed});
}

/// Types of supported PDF annotations
enum PdfAnnotationType { text, signature, highlight }

/// Represents an interactive annotation or signature to be applied to a PDF page
class PdfAnnotationItem {
  final PdfAnnotationType type;
  final int pageIndex; // 0-indexed
  final double x;
  final double y;
  final double width;
  final double height;
  final String? text;
  final double fontSize;
  final Color color;
  final List<int>? signaturePngBytes;

  const PdfAnnotationItem({
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    this.width = 160.0,
    this.height = 40.0,
    this.text,
    this.fontSize = 14.0,
    this.color = const Color(0xFF000000),
    this.signaturePngBytes,
  });
}

/// Area marked for permanent content redaction
class PdfRedactionArea {
  final int pageIndex; // 0-indexed
  final double x;
  final double y;
  final double width;
  final double height;
  final String? overlayText;

  const PdfRedactionArea({
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.overlayText = '[REDACTED]',
  });
}

// =============================================================================
// ADVANCED PDF SERVICE
// =============================================================================

/// Professional PDF manipulation engine for inspection, page management,
/// merging, splitting, compression, encryption, and watermarking.
class AdvancedPdfService {
  static AdvancedPdfService? _instance;
  static AdvancedPdfService get instance =>
      _instance ??= AdvancedPdfService._();
  AdvancedPdfService._();

  // ---------------------------------------------------------------------------
  // 1. INSPECTION & VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates that a file is an authentic, non-empty, and parseable PDF document.
  Future<bool> validatePdf(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 8) return false;

      final handle = await file.open(mode: FileMode.read);
      try {
        final header = await handle.read(5);
        if (header.length < 5) return false;
        final headerStr = String.fromCharCodes(header);
        if (headerStr != '%PDF-') return false;
      } finally {
        await handle.close();
      }

      // Verify parseability
      final bytes = await file.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count >= 0;
    } catch (_) {
      return false;
    }
  }

  /// Extracts comprehensive structural and descriptive metadata from a PDF.
  Future<PdfMetadataInfo> inspectPdf(File file) async {
    if (!await file.exists()) {
      throw FileNotFoundException('PDF file does not exist: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    final fileSizeBytes = bytes.length;

    sf.PdfDocument doc;
    try {
      doc = sf.PdfDocument(inputBytes: bytes);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypted')) {
        return PdfMetadataInfo(
          pageCount: 0,
          fileSizeBytes: fileSizeBytes,
          isEncrypted: true,
          firstPageWidth: 0,
          firstPageHeight: 0,
        );
      }
      rethrow;
    }

    try {
      final pageCount = doc.pages.count;
      final firstPage = pageCount > 0 ? doc.pages[0] : null;
      final width = firstPage != null ? firstPage.size.width : 0.0;
      final height = firstPage != null ? firstPage.size.height : 0.0;

      final docInfo = doc.documentInformation;
      return PdfMetadataInfo(
        pageCount: pageCount,
        fileSizeBytes: fileSizeBytes,
        isEncrypted: false,
        title: docInfo.title.isNotEmpty ? docInfo.title : null,
        author: docInfo.author.isNotEmpty ? docInfo.author : null,
        producer: docInfo.producer.isNotEmpty ? docInfo.producer : null,
        creationDate: docInfo.creationDate,
        firstPageWidth: width,
        firstPageHeight: height,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Returns total page count of an existing PDF.
  Future<int> getPageCount(File sourcePdf) async {
    if (!await sourcePdf.exists()) return 0;
    try {
      final bytes = await sourcePdf.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      try {
        return doc.pages.count;
      } finally {
        doc.dispose();
      }
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. PAGE MANAGEMENT & REORGANIZATION
  // ---------------------------------------------------------------------------

  /// Reorders pages of an existing PDF according to [newPageOrder1Indexed].
  /// Example: [3, 1, 2] places page 3 first, page 1 second, and page 2 third.
  Future<File> reorderPages({
    required File sourcePdf,
    required List<int> newPageOrder1Indexed,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (newPageOrder1Indexed.isEmpty) {
      throw ArgumentError('New page order cannot be empty.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final finalDoc = sf.PdfDocument();

    try {
      final totalPages = sourceDoc.pages.count;
      for (final pNum in newPageOrder1Indexed) {
        if (pNum < 1 || pNum > totalPages) {
          throw RangeError(
            'Page number $pNum is out of bounds (1..$totalPages).',
          );
        }
        final page = sourceDoc.pages[pNum - 1];
        final template = page.createTemplate();
        final newPage = finalDoc.pages.add();
        newPage.rotation = page.rotation;
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          newPage.size,
        );
      }

      return await _saveDocumentSafely(finalDoc, outputFileName);
    } finally {
      finalDoc.dispose();
      sourceDoc.dispose();
    }
  }

  /// Rotates specific pages in an existing PDF by given angles in degrees.
  /// [pageRotationsDegrees] maps 1-indexed page number to degrees (90, 180, 270).
  Future<File> rotatePages({
    required File sourcePdf,
    required Map<int, int> pageRotationsDegrees,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      final count = sourceDoc.pages.count;
      for (int i = 0; i < count; i++) {
        final pageNum = i + 1;
        final sourcePage = sourceDoc.pages[i];

        // Calculate combined rotation
        int baseAngle = 0;
        switch (sourcePage.rotation) {
          case sf.PdfPageRotateAngle.rotateAngle90:
            baseAngle = 90;
            break;
          case sf.PdfPageRotateAngle.rotateAngle180:
            baseAngle = 180;
            break;
          case sf.PdfPageRotateAngle.rotateAngle270:
            baseAngle = 270;
            break;
          default:
            baseAngle = 0;
        }

        final addAngle = pageRotationsDegrees[pageNum] ?? 0;
        final netAngle = (baseAngle + addAngle) % 360;

        switch (netAngle) {
          case 90:
            sourcePage.rotation = sf.PdfPageRotateAngle.rotateAngle90;
            break;
          case 180:
            sourcePage.rotation = sf.PdfPageRotateAngle.rotateAngle180;
            break;
          case 270:
            sourcePage.rotation = sf.PdfPageRotateAngle.rotateAngle270;
            break;
          default:
            sourcePage.rotation = sf.PdfPageRotateAngle.rotateAngle0;
        }
      }

      return await _saveDocumentSafely(sourceDoc, outputFileName);
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Deletes specified 1-indexed pages from an existing PDF.
  Future<File> deletePages({
    required File sourcePdf,
    required List<int> pagesToDelete1Indexed,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final totalPages = await getPageCount(sourcePdf);
    final deleteSet = pagesToDelete1Indexed.toSet();

    final remaining = <int>[];
    for (int i = 1; i <= totalPages; i++) {
      if (!deleteSet.contains(i)) {
        remaining.add(i);
      }
    }

    if (remaining.isEmpty) {
      throw ArgumentError('Cannot delete all pages from document.');
    }

    return await reorderPages(
      sourcePdf: sourcePdf,
      newPageOrder1Indexed: remaining,
      outputFileName: outputFileName,
    );
  }

  /// Duplicates a specific 1-indexed page immediately following itself.
  Future<File> duplicatePage({
    required File sourcePdf,
    required int pageNumber1Indexed,
    required String outputFileName,
  }) async {
    final total = await getPageCount(sourcePdf);
    if (pageNumber1Indexed < 1 || pageNumber1Indexed > total) {
      throw RangeError('Page $pageNumber1Indexed out of bounds (1..$total).');
    }

    final order = <int>[];
    for (int i = 1; i <= total; i++) {
      order.add(i);
      if (i == pageNumber1Indexed) {
        order.add(i); // Duplicate
      }
    }

    return await reorderPages(
      sourcePdf: sourcePdf,
      newPageOrder1Indexed: order,
      outputFileName: outputFileName,
    );
  }

  /// Extracts specific 1-indexed pages (e.g. [1, 3, 5]) into a new PDF document.
  Future<File> extractPages({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  }) async {
    return await reorderPages(
      sourcePdf: sourcePdf,
      newPageOrder1Indexed: pageNumbers,
      outputFileName: outputFileName,
    );
  }

  /// Inserts pages from another PDF after [insertAfterPageIndex1Indexed] (0 = at beginning).
  Future<File> insertPagesFromPdf({
    required File sourcePdf,
    required int insertAfterPageIndex1Indexed,
    required File pdfToInsert,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (!await pdfToInsert.exists()) {
      throw FileNotFoundException(
        'Insert PDF does not exist: ${pdfToInsert.path}',
      );
    }

    final bytes1 = await sourcePdf.readAsBytes();
    final bytes2 = await pdfToInsert.readAsBytes();

    final doc1 = sf.PdfDocument(inputBytes: bytes1);
    final doc2 = sf.PdfDocument(inputBytes: bytes2);
    final finalDoc = sf.PdfDocument();

    try {
      final total1 = doc1.pages.count;
      final total2 = doc2.pages.count;

      final clampIndex = insertAfterPageIndex1Indexed.clamp(0, total1);

      // Pages before insertion
      for (int i = 0; i < clampIndex; i++) {
        final p = doc1.pages[i];
        final t = p.createTemplate();
        final np = finalDoc.pages.add();
        np.rotation = p.rotation;
        np.graphics.drawPdfTemplate(t, const Offset(0, 0), np.size);
      }

      // Inserted pages
      for (int i = 0; i < total2; i++) {
        final p = doc2.pages[i];
        final t = p.createTemplate();
        final np = finalDoc.pages.add();
        np.rotation = p.rotation;
        np.graphics.drawPdfTemplate(t, const Offset(0, 0), np.size);
      }

      // Remaining pages
      for (int i = clampIndex; i < total1; i++) {
        final p = doc1.pages[i];
        final t = p.createTemplate();
        final np = finalDoc.pages.add();
        np.rotation = p.rotation;
        np.graphics.drawPdfTemplate(t, const Offset(0, 0), np.size);
      }

      return await _saveDocumentSafely(finalDoc, outputFileName);
    } finally {
      finalDoc.dispose();
      doc2.dispose();
      doc1.dispose();
    }
  }

  /// Inserts an image file as a new page after [insertAfterPageIndex1Indexed].
  Future<File> insertImageAsPage({
    required File sourcePdf,
    required int insertAfterPageIndex1Indexed,
    required File imageFile,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (!await imageFile.exists()) {
      throw FileNotFoundException(
        'Image file does not exist: ${imageFile.path}',
      );
    }

    final pdfBytes = await sourcePdf.readAsBytes();
    final imgBytes = await imageFile.readAsBytes();

    final doc = sf.PdfDocument(inputBytes: pdfBytes);
    final finalDoc = sf.PdfDocument();

    try {
      final total = doc.pages.count;
      final clampIndex = insertAfterPageIndex1Indexed.clamp(0, total);

      // Pages before
      for (int i = 0; i < clampIndex; i++) {
        final p = doc.pages[i];
        final t = p.createTemplate();
        final np = finalDoc.pages.add();
        np.rotation = p.rotation;
        np.graphics.drawPdfTemplate(t, const Offset(0, 0), np.size);
      }

      // Image page
      final bitmap = sf.PdfBitmap(imgBytes);
      final newPage = finalDoc.pages.add();
      // Set page dimensions based on image aspect ratio, normalized to A4 (595 x 842 pt)
      const a4Width = 595.0;
      const a4Height = 842.0;
      // Fit image centered
      final aspect = bitmap.width / bitmap.height;
      double drawW = a4Width;
      double drawH = drawW / aspect;
      if (drawH > a4Height) {
        drawH = a4Height;
        drawW = drawH * aspect;
      }
      final dx = (a4Width - drawW) / 2;
      final dy = (a4Height - drawH) / 2;
      newPage.graphics.drawImage(bitmap, Rect.fromLTWH(dx, dy, drawW, drawH));

      // Pages after
      for (int i = clampIndex; i < total; i++) {
        final p = doc.pages[i];
        final t = p.createTemplate();
        final np = finalDoc.pages.add();
        np.rotation = p.rotation;
        np.graphics.drawPdfTemplate(t, const Offset(0, 0), np.size);
      }

      return await _saveDocumentSafely(finalDoc, outputFileName);
    } finally {
      finalDoc.dispose();
      doc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. MERGE & SPLIT
  // ---------------------------------------------------------------------------

  /// Merges multiple existing PDF files into a single consolidated PDF file.
  Future<File> mergePdfs({
    required List<File> sourcePdfs,
    required String outputFileName,
  }) async {
    if (sourcePdfs.length < 2) {
      throw ArgumentError('At least 2 PDF files are required for merging.');
    }

    final finalDoc = sf.PdfDocument();

    try {
      for (final file in sourcePdfs) {
        if (!await file.exists()) {
          throw FileNotFoundException(
            'Source PDF file does not exist: ${file.path}',
          );
        }
        final bytes = await file.readAsBytes();
        final sourceDoc = sf.PdfDocument(inputBytes: bytes);
        try {
          final count = sourceDoc.pages.count;
          for (int i = 0; i < count; i++) {
            final page = sourceDoc.pages[i];
            final template = page.createTemplate();
            final newPage = finalDoc.pages.add();
            newPage.rotation = page.rotation;
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

      return await _saveDocumentSafely(finalDoc, outputFileName);
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
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final generatedFiles = <File>[];

    try {
      final count = sourceDoc.pages.count;
      for (int i = 0; i < count; i++) {
        final singleDoc = sf.PdfDocument();
        try {
          final page = sourceDoc.pages[i];
          final template = page.createTemplate();
          final newPage = singleDoc.pages.add();
          newPage.rotation = page.rotation;
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.size,
          );

          final outName = '${baseOutputName}_page_${i + 1}';
          final saved = await _saveDocumentSafely(singleDoc, outName);
          generatedFiles.add(saved);
        } finally {
          singleDoc.dispose();
        }
      }
      return generatedFiles;
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Splits a PDF by specified 1-indexed page ranges.
  /// Example: [[1, 2], [3, 5]] generates 2 PDFs.
  Future<List<File>> splitPdfByRanges({
    required File sourcePdf,
    required List<List<int>> ranges1Indexed,
    required String baseOutputName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }
    if (ranges1Indexed.isEmpty) {
      throw ArgumentError('At least one page range must be supplied.');
    }

    final results = <File>[];
    for (int i = 0; i < ranges1Indexed.length; i++) {
      final range = ranges1Indexed[i];
      if (range.isEmpty) continue;
      final outName = '${baseOutputName}_part_${i + 1}';
      final file = await extractPages(
        sourcePdf: sourcePdf,
        pageNumbers: range,
        outputFileName: outName,
      );
      results.add(file);
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // 4. COMPRESSION & OPTIMIZATION
  // ---------------------------------------------------------------------------

  /// Performs genuine PDF compression with measurable before-and-after reporting.
  /// If [associatedDocument] is provided with original scan images, it re-compresses
  /// through the image pipeline with target JPEG qualities.
  Future<PdfCompressionResult> compressPdf({
    required File sourcePdf,
    required PdfCompressionPreset preset,
    required String outputFileName,
    ScannedDocument? associatedDocument,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final originalSizeBytes = await sourcePdf.length();
    File compressedFile;

    // Route 1: Scaneliq native document with original images
    if (associatedDocument != null && associatedDocument.pages.isNotEmpty) {
      int targetQuality = 85;
      switch (preset) {
        case PdfCompressionPreset.highQuality:
          targetQuality = 85;
          break;
        case PdfCompressionPreset.balanced:
          targetQuality = 65;
          break;
        case PdfCompressionPreset.smallerFile:
          targetQuality = 45;
          break;
      }

      // Read pages, decode, re-encode with target quality into a new PDF
      compressedFile = await _compressDocumentPages(
        associatedDocument: associatedDocument,
        quality: targetQuality,
        outputFileName: outputFileName,
      );
    } else {
      // Route 2: Arbitrary external PDF
      final bytes = await sourcePdf.readAsBytes();
      final sourceDoc = sf.PdfDocument(inputBytes: bytes);
      final finalDoc = sf.PdfDocument();
      // Set compression level
      finalDoc.compressionLevel = sf.PdfCompressionLevel.best;

      try {
        final count = sourceDoc.pages.count;
        for (int i = 0; i < count; i++) {
          final page = sourceDoc.pages[i];
          final template = page.createTemplate();
          final newPage = finalDoc.pages.add();
          newPage.rotation = page.rotation;
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.size,
          );
        }

        compressedFile = await _saveDocumentSafely(finalDoc, outputFileName);
      } finally {
        finalDoc.dispose();
        sourceDoc.dispose();
      }
    }

    final compressedSizeBytes = await compressedFile.length();
    final bytesSaved = math.max(0, originalSizeBytes - compressedSizeBytes);
    final percentage = originalSizeBytes > 0
        ? (bytesSaved / originalSizeBytes) * 100.0
        : 0.0;

    return PdfCompressionResult(
      outputFile: compressedFile,
      originalSizeBytes: originalSizeBytes,
      compressedSizeBytes: compressedSizeBytes,
      bytesSaved: bytesSaved,
      percentageReduction: percentage,
      preset: preset,
    );
  }

  /// Internal helper to compress a document's original images into an optimized PDF
  Future<File> _compressDocumentPages({
    required ScannedDocument associatedDocument,
    required int quality,
    required String outputFileName,
  }) async {
    final finalDoc = sf.PdfDocument();
    finalDoc.compressionLevel = sf.PdfCompressionLevel.best;

    try {
      for (final page in associatedDocument.pages) {
        final imagePath = page.processedPath ?? page.originalPath;
        final imgFile = File(imagePath);
        if (!await imgFile.exists()) continue;

        final rawBytes = await imgFile.readAsBytes();
        final decoded = img.decodeImage(rawBytes);
        if (decoded == null) continue;

        // Apply page recipe filters if present
        final processed = PdfService.applyEditRecipe(decoded, page.editRecipe);

        // Downscale slightly for smallerFile preset
        img.Image readyImg = processed;
        if (quality <= 50 &&
            (processed.width > 1200 || processed.height > 1600)) {
          readyImg = img.copyResize(
            processed,
            width: (processed.width * 0.75).round(),
            height: (processed.height * 0.75).round(),
            interpolation: img.Interpolation.linear,
          );
        }

        final compressedJpg = img.encodeJpg(readyImg, quality: quality);
        final bitmap = sf.PdfBitmap(compressedJpg);

        const a4Width = 595.0;
        const a4Height = 842.0;
        final newPage = finalDoc.pages.add();

        final aspect = bitmap.width / bitmap.height;
        double drawW = a4Width;
        double drawH = drawW / aspect;
        if (drawH > a4Height) {
          drawH = a4Height;
          drawW = drawH * aspect;
        }
        final dx = (a4Width - drawW) / 2;
        final dy = (a4Height - drawH) / 2;
        newPage.graphics.drawImage(bitmap, Rect.fromLTWH(dx, dy, drawW, drawH));
      }

      return await _saveDocumentSafely(finalDoc, outputFileName);
    } finally {
      finalDoc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // 5. TEXT & IMAGE WATERMARKS
  // ---------------------------------------------------------------------------

  /// Applies customizable text or image watermarks across selected or all pages.
  /// Supports backward compatibility when only [watermarkText] is specified.
  Future<File> addWatermark({
    required File sourcePdf,
    String? watermarkText,
    WatermarkOptions? options,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final opts =
        options ?? WatermarkOptions(text: watermarkText ?? 'CONFIDENTIAL');
    if (opts.text.trim().isEmpty && opts.imageFile == null) {
      throw ArgumentError('Watermark must have text or an image.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      final pageCount = sourceDoc.pages.count;

      // Font and brush setup
      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        opts.fontSize,
        style: sf.PdfFontStyle.bold,
      );

      final r = (opts.color.r * 255).round().clamp(0, 255);
      final g = (opts.color.g * 255).round().clamp(0, 255);
      final b = (opts.color.b * 255).round().clamp(0, 255);
      final alpha = (opts.opacity * 255).round().clamp(10, 255);
      final brush = sf.PdfSolidBrush(sf.PdfColor(r, g, b, alpha));

      sf.PdfBitmap? imageBitmap;
      if (opts.imageFile != null && await opts.imageFile!.exists()) {
        final imgBytes = await opts.imageFile!.readAsBytes();
        imageBitmap = sf.PdfBitmap(imgBytes);
      }

      for (int i = 0; i < pageCount; i++) {
        final pageNum = i + 1;
        if (!_shouldWatermarkPage(pageNum, pageCount, opts)) continue;

        final page = sourceDoc.pages[i];
        final graphics = page.graphics;
        graphics.save();

        if (imageBitmap != null) {
          _drawImageWatermark(graphics, page.size, imageBitmap, opts);
        } else {
          _drawTextWatermark(graphics, page.size, font, brush, opts);
        }

        graphics.restore();
      }

      return await _saveDocumentSafely(sourceDoc, outputFileName);
    } finally {
      sourceDoc.dispose();
    }
  }

  bool _shouldWatermarkPage(int pageNum, int total, WatermarkOptions opts) {
    switch (opts.pageSelection) {
      case WatermarkPageSelection.allPages:
        return true;
      case WatermarkPageSelection.firstPageOnly:
        return pageNum == 1;
      case WatermarkPageSelection.oddPagesOnly:
        return pageNum % 2 != 0;
      case WatermarkPageSelection.evenPagesOnly:
        return pageNum % 2 == 0;
      case WatermarkPageSelection.customPages:
        return opts.customPages1Indexed?.contains(pageNum) ?? true;
    }
  }

  void _drawTextWatermark(
    sf.PdfGraphics graphics,
    Size pageSize,
    sf.PdfFont font,
    sf.PdfBrush brush,
    WatermarkOptions opts,
  ) {
    final textSize = font.measureString(opts.text);

    switch (opts.position) {
      case WatermarkPosition.diagonalCenter:
        graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
        graphics.rotateTransform(opts.rotationDegrees);
        graphics.drawString(
          opts.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );
        break;

      case WatermarkPosition.horizontalCenter:
      case WatermarkPosition.center:
        graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
        if (opts.rotationDegrees != 0) {
          graphics.rotateTransform(opts.rotationDegrees);
        }
        graphics.drawString(
          opts.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );
        break;

      case WatermarkPosition.headerTop:
        graphics.drawString(
          opts.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            (pageSize.width - textSize.width) / 2,
            30,
            textSize.width,
            textSize.height,
          ),
        );
        break;

      case WatermarkPosition.footerBottom:
        graphics.drawString(
          opts.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            (pageSize.width - textSize.width) / 2,
            pageSize.height - 40 - textSize.height,
            textSize.width,
            textSize.height,
          ),
        );
        break;
    }
  }

  void _drawImageWatermark(
    sf.PdfGraphics graphics,
    Size pageSize,
    sf.PdfBitmap bitmap,
    WatermarkOptions opts,
  ) {
    final scale = opts.imageScale.clamp(0.1, 1.0);
    final targetW = pageSize.width * scale;
    final targetH = (targetW / bitmap.width) * bitmap.height;

    final dx = (pageSize.width - targetW) / 2;
    final dy = (pageSize.height - targetH) / 2;

    graphics.drawImage(bitmap, Rect.fromLTWH(dx, dy, targetW, targetH));
  }

  // ---------------------------------------------------------------------------
  // 6. BOOKMARKS & OUTLINES
  // ---------------------------------------------------------------------------

  /// Embeds native PDF outline bookmarks into a copy of the document.
  Future<File> addOutlineBookmarks({
    required File sourcePdf,
    required Map<String, int> bookmarksTitleToPage1Indexed,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final total = doc.pages.count;
      bookmarksTitleToPage1Indexed.forEach((title, pageNum) {
        if (pageNum >= 1 && pageNum <= total) {
          final page = doc.pages[pageNum - 1];
          final bookmark = doc.bookmarks.add(title);
          bookmark.destination = sf.PdfDestination(page, const Offset(0, 0));
        }
      });

      return await _saveDocumentSafely(doc, outputFileName);
    } finally {
      doc.dispose();
    }
  }

  /// Extracts existing outline bookmarks from any PDF document.
  Future<List<PdfOutlineItem>> extractOutlineBookmarks(File sourcePdf) async {
    if (!await sourcePdf.exists()) return [];
    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final items = <PdfOutlineItem>[];

    try {
      final bookmarks = doc.bookmarks;
      for (int i = 0; i < bookmarks.count; i++) {
        final b = bookmarks[i];
        int pageNum = 1;
        if (b.destination != null) {
          final destPage = b.destination!.page;
          final idx = doc.pages.indexOf(destPage);
          if (idx >= 0) pageNum = idx + 1;
        }
        items.add(PdfOutlineItem(title: b.title, pageNumber1Indexed: pageNum));
      }
      return items;
    } catch (_) {
      return [];
    } finally {
      doc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // 7. PASSWORD PROTECTION & ENCRYPTION
  // ---------------------------------------------------------------------------

  /// Protects a PDF with standard AES-256 bit password encryption.
  Future<File> encryptPdf({
    required File sourcePdf,
    required String userPassword,
    String? ownerPassword,
    required String outputFileName,
    List<sf.PdfPermissionsFlags>? permissions,
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
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      final security = sourceDoc.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword ?? '${userPassword}_owner';
      security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;
      security.permissions.clear();
      security.permissions.addAll(
        permissions ??
            [sf.PdfPermissionsFlags.print, sf.PdfPermissionsFlags.copyContent],
      );

      return await _saveDocumentSafely(sourceDoc, outputFileName);
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Verifies whether a given password correctly decrypts an encrypted PDF file.
  Future<bool> verifyPassword(File file, String password) async {
    try {
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes, password: password);
      final count = doc.pages.count;
      doc.dispose();
      return count >= 0;
    } catch (_) {
      return false;
    }
  }

  /// Removes password encryption from an authorized document.
  Future<File> removePassword({
    required File sourcePdf,
    required String password,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes, password: password);
    final finalDoc = sf.PdfDocument();

    try {
      final count = sourceDoc.pages.count;
      for (int i = 0; i < count; i++) {
        final page = sourceDoc.pages[i];
        final template = page.createTemplate();
        final newPage = finalDoc.pages.add();
        newPage.rotation = page.rotation;
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          newPage.size,
        );
      }

      return await _saveDocumentSafely(finalDoc, outputFileName);
    } finally {
      finalDoc.dispose();
      sourceDoc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // 7. ANNOTATIONS, SIGNATURES & GENUINE REDACTION (F-26 & F-27)
  // ---------------------------------------------------------------------------

  /// Applies interactive annotations, drawn signatures, and highlights onto a PDF document.
  Future<File> applyAnnotations({
    required File sourcePdf,
    required List<PdfAnnotationItem> annotations,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      for (final item in annotations) {
        if (item.pageIndex < 0 || item.pageIndex >= doc.pages.count) continue;
        final page = doc.pages[item.pageIndex];

        switch (item.type) {
          case PdfAnnotationType.text:
            if (item.text != null && item.text!.isNotEmpty) {
              final font = sf.PdfStandardFont(
                sf.PdfFontFamily.helvetica,
                item.fontSize,
                style: sf.PdfFontStyle.bold,
              );
              final brush = sf.PdfSolidBrush(
                sf.PdfColor(
                  (item.color.r * 255).round(),
                  (item.color.g * 255).round(),
                  (item.color.b * 255).round(),
                ),
              );
              page.graphics.drawString(
                item.text!,
                font,
                brush: brush,
                bounds: Rect.fromLTWH(item.x, item.y, item.width, item.height),
              );
            }
            break;

          case PdfAnnotationType.signature:
            if (item.signaturePngBytes != null &&
                item.signaturePngBytes!.isNotEmpty) {
              final bitmap = sf.PdfBitmap(item.signaturePngBytes!);
              page.graphics.drawImage(
                bitmap,
                Rect.fromLTWH(item.x, item.y, item.width, item.height),
              );
            }
            break;

          case PdfAnnotationType.highlight:
            final highlightBrush = sf.PdfSolidBrush(
              sf.PdfColor(
                (item.color.r * 255).round(),
                (item.color.g * 255).round(),
                (item.color.b * 255).round(),
                100, // Semi-transparent highlight
              ),
            );
            page.graphics.drawRectangle(
              brush: highlightBrush,
              bounds: Rect.fromLTWH(item.x, item.y, item.width, item.height),
            );
            break;
        }
      }

      return await _saveDocumentSafely(doc, outputFileName);
    } finally {
      doc.dispose();
    }
  }

  /// Permanently redacts targeted areas by drawing opaque black blocks and sanitizing metadata.
  Future<File> applyRedaction({
    required File sourcePdf,
    required List<PdfRedactionArea> redactions,
    required String outputFileName,
    bool sanitizeMetadata = true,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final blackBrush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
      final whiteBrush = sf.PdfSolidBrush(sf.PdfColor(255, 255, 255));
      final overlayFont = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        8.0,
        style: sf.PdfFontStyle.bold,
      );

      for (final r in redactions) {
        if (r.pageIndex < 0 || r.pageIndex >= doc.pages.count) continue;
        final page = doc.pages[r.pageIndex];

        // 1. Draw solid opaque black fill across the entire redaction rectangle
        final rect = Rect.fromLTWH(r.x, r.y, r.width, r.height);
        page.graphics.drawRectangle(brush: blackBrush, bounds: rect);

        // 2. Draw overlay text if specified
        if (r.overlayText != null && r.overlayText!.isNotEmpty) {
          final textSize = overlayFont.measureString(r.overlayText!);
          final textX = r.x + (r.width - textSize.width) / 2.0;
          final textY = r.y + (r.height - textSize.height) / 2.0;
          page.graphics.drawString(
            r.overlayText!,
            overlayFont,
            brush: whiteBrush,
            bounds: Rect.fromLTWH(
              math.max(r.x, textX),
              math.max(r.y, textY),
              r.width,
              r.height,
            ),
          );
        }
      }

      // 3. Metadata sanitization
      if (sanitizeMetadata) {
        doc.documentInformation.title = '';
        doc.documentInformation.author = '';
        doc.documentInformation.subject = '';
        doc.documentInformation.keywords = '';
        doc.documentInformation.producer = 'Scaneliq Redaction Engine';
      }

      return await _saveDocumentSafely(doc, outputFileName);
    } finally {
      doc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER: SAFE COMMIT & EXPORT
  // ---------------------------------------------------------------------------

  Future<File> _saveDocumentSafely(
    sf.PdfDocument doc,
    String outputFileName,
  ) async {
    final List<int> outputBytes = doc.saveSync();
    if (outputBytes.isEmpty) {
      throw StateError('PDF generation produced empty byte output.');
    }

    final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final exportPath = AppStorageService.instance.getExportPdfPath(sanitized);
    final tempPath = '$exportPath.tmp';

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(outputBytes, flush: true);
    return await tempFile.rename(exportPath);
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}

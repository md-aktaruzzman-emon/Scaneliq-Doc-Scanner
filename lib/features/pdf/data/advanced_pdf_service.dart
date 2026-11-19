import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
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
enum PdfAnnotationType { text, signature, highlight, underline, freehand, shape }

/// Vector shape variants supported in annotation mode
enum PdfShapeKind { rectangle, circle, arrow, line }

/// Represents an interactive annotation or visual signature to be applied to a PDF page.
///
/// When [normalized] is true, [x], [y], [width], [height], and [points] are expressed in
/// normalized `[0.0..1.0]` page-fraction coordinates and scaled to exact PDF page points on export.
class PdfAnnotationItem {
  final String? id;
  final PdfAnnotationType type;
  final int pageIndex; // 0-indexed
  final double x;
  final double y;
  final double width;
  final double height;
  final String? text;
  final double fontSize;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final List<Offset> points;
  final PdfShapeKind shapeKind;
  final double rotationDegrees;
  final bool normalized;
  final List<int>? signaturePngBytes;

  const PdfAnnotationItem({
    this.id,
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    this.width = 160.0,
    this.height = 40.0,
    this.text,
    this.fontSize = 14.0,
    this.color = const Color(0xFF000000),
    this.strokeWidth = 2.5,
    this.opacity = 1.0,
    this.points = const [],
    this.shapeKind = PdfShapeKind.rectangle,
    this.rotationDegrees = 0.0,
    this.normalized = false,
    this.signaturePngBytes,
  });

  PdfAnnotationItem copyWith({
    String? id,
    PdfAnnotationType? type,
    int? pageIndex,
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    double? fontSize,
    Color? color,
    double? strokeWidth,
    double? opacity,
    List<Offset>? points,
    PdfShapeKind? shapeKind,
    double? rotationDegrees,
    bool? normalized,
    List<int>? signaturePngBytes,
  }) {
    return PdfAnnotationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
      shapeKind: shapeKind ?? this.shapeKind,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      normalized: normalized ?? this.normalized,
      signaturePngBytes: signaturePngBytes ?? this.signaturePngBytes,
    );
  }
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

    final targetPath = _resolveExportPath(outputFileName);
    final srcPath = sourcePdf.path;
    final orderCopy = List<int>.from(newPageOrder1Indexed);

    await Isolate.run(() {
      final bytes = File(srcPath).readAsBytesSync();
      final sourceDoc = sf.PdfDocument(inputBytes: bytes);
      final finalDoc = sf.PdfDocument();
      try {
        final totalPages = sourceDoc.pages.count;
        for (final pNum in orderCopy) {
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
        _writePdfSyncAtomically(finalDoc.saveSync(), targetPath);
      } finally {
        finalDoc.dispose();
        sourceDoc.dispose();
      }
    });
    return File(targetPath);
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

    final targetPath = _resolveExportPath(outputFileName);
    final srcPath = sourcePdf.path;
    final rotCopy = Map<int, int>.from(pageRotationsDegrees);

    await Isolate.run(() {
      final bytes = File(srcPath).readAsBytesSync();
      final sourceDoc = sf.PdfDocument(inputBytes: bytes);
      try {
        final count = sourceDoc.pages.count;
        for (int i = 0; i < count; i++) {
          final pageNum = i + 1;
          final sourcePage = sourceDoc.pages[i];
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
          final addAngle = rotCopy[pageNum] ?? 0;
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
        _writePdfSyncAtomically(sourceDoc.saveSync(), targetPath);
      } finally {
        sourceDoc.dispose();
      }
    });
    return File(targetPath);
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

  /// Merges multiple existing PDF files into a single consolidated PDF file in a background isolate.
  Future<File> mergePdfs({
    required List<File> sourcePdfs,
    required String outputFileName,
  }) async {
    if (sourcePdfs.length < 2) {
      throw ArgumentError('At least 2 PDF files are required for merging.');
    }
    final paths = <String>[];
    for (final file in sourcePdfs) {
      if (!await file.exists()) {
        throw FileNotFoundException(
          'Source PDF file does not exist: ${file.path}',
        );
      }
      paths.add(file.path);
    }

    final targetPath = _resolveExportPath(outputFileName);
    await Isolate.run(() {
      final finalDoc = sf.PdfDocument();
      try {
        for (final path in paths) {
          final bytes = File(path).readAsBytesSync();
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
        _writePdfSyncAtomically(finalDoc.saveSync(), targetPath);
      } finally {
        finalDoc.dispose();
      }
    });
    return File(targetPath);
  }

  /// Splits an existing PDF into individual single-page PDF files in a background isolate.
  Future<List<File>> splitPdfIntoPages({
    required File sourcePdf,
    required String baseOutputName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final totalCount = await getPageCount(sourcePdf);
    final srcPath = sourcePdf.path;
    final targetPaths = [
      for (int i = 0; i < totalCount; i++)
        _resolveExportPath('${baseOutputName}_page_${i + 1}'),
    ];

    await Isolate.run(() {
      final bytes = File(srcPath).readAsBytesSync();
      final sourceDoc = sf.PdfDocument(inputBytes: bytes);
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
            _writePdfSyncAtomically(singleDoc.saveSync(), targetPaths[i]);
          } finally {
            singleDoc.dispose();
          }
        }
      } finally {
        sourceDoc.dispose();
      }
    });
    return targetPaths.map((p) => File(p)).toList();
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

      compressedFile = await _compressDocumentPages(
        associatedDocument: associatedDocument,
        quality: targetQuality,
        outputFileName: outputFileName,
      );
    } else {
      final targetPath = _resolveExportPath(outputFileName);
      final srcPath = sourcePdf.path;
      await Isolate.run(() {
        final bytes = File(srcPath).readAsBytesSync();
        final sourceDoc = sf.PdfDocument(inputBytes: bytes);
        final finalDoc = sf.PdfDocument();
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
          _writePdfSyncAtomically(finalDoc.saveSync(), targetPath);
        } finally {
          finalDoc.dispose();
          sourceDoc.dispose();
        }
      });
      compressedFile = File(targetPath);
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

  /// Internal helper to compress a document's original images into an optimized PDF inside a background isolate
  Future<File> _compressDocumentPages({
    required ScannedDocument associatedDocument,
    required int quality,
    required String outputFileName,
  }) async {
    final targetPath = _resolveExportPath(outputFileName);
    final pageJobs = <Map<String, Object?>>[
      for (final p in associatedDocument.pages)
        {
          'path': p.processedPath ?? p.originalPath,
          'recipe': p.editRecipe.toMap(),
        },
    ];

    await Isolate.run(() {
      final finalDoc = sf.PdfDocument();
      finalDoc.compressionLevel = sf.PdfCompressionLevel.best;

      try {
        for (final job in pageJobs) {
          final imagePath = job['path'] as String;
          final imgFile = File(imagePath);
          if (!imgFile.existsSync()) continue;

          final rawBytes = imgFile.readAsBytesSync();
          final decoded = img.decodeImage(rawBytes);
          if (decoded == null) continue;

          final recipe = EditRecipe.fromMap(
            Map<String, dynamic>.from(job['recipe'] as Map),
          );
          final processed = PdfService.applyEditRecipe(decoded, recipe);

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
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(dx, dy, drawW, drawH),
          );
        }

        _writePdfSyncAtomically(finalDoc.saveSync(), targetPath);
      } finally {
        finalDoc.dispose();
      }
    });
    return File(targetPath);
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

  /// Protects a PDF with standard AES-256 bit password encryption inside a background isolate.
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

    final targetPath = _resolveExportPath(outputFileName);
    final srcPath = sourcePdf.path;
    final permIndices =
        permissions?.map((p) => p.index).toList() ??
        [
          sf.PdfPermissionsFlags.print.index,
          sf.PdfPermissionsFlags.copyContent.index,
        ];

    await Isolate.run(() {
      final bytes = File(srcPath).readAsBytesSync();
      final sourceDoc = sf.PdfDocument(inputBytes: bytes);
      try {
        final security = sourceDoc.security;
        security.userPassword = userPassword;
        security.ownerPassword = ownerPassword ?? '${userPassword}_owner';
        security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;
        security.permissions.clear();
        for (final idx in permIndices) {
          security.permissions.add(sf.PdfPermissionsFlags.values[idx]);
        }
        _writePdfSyncAtomically(sourceDoc.saveSync(), targetPath);
      } finally {
        sourceDoc.dispose();
      }
    });
    return File(targetPath);
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

  /// Removes password encryption from an authorized document inside a background isolate.
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

    final targetPath = _resolveExportPath(outputFileName);
    final srcPath = sourcePdf.path;

    await Isolate.run(() {
      final bytes = File(srcPath).readAsBytesSync();
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
        _writePdfSyncAtomically(finalDoc.saveSync(), targetPath);
      } finally {
        finalDoc.dispose();
        sourceDoc.dispose();
      }
    });
    return File(targetPath);
  }

  // ---------------------------------------------------------------------------
  // 7. ANNOTATIONS, SIGNATURES & GENUINE REDACTION (F-26 & F-27)
  // ---------------------------------------------------------------------------

  /// Extracts selectable text per 1-indexed page number.
  /// Returns a map `{pageNumber1Indexed: text}` (empty strings on image-only scanned pages).
  Future<Map<int, String>> extractTextByPage(File sourcePdf) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException('PDF file does not exist: ${sourcePdf.path}');
    }
    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = sf.PdfTextExtractor(doc);
      final out = <int, String>{};
      for (int i = 0; i < doc.pages.count; i++) {
        out[i + 1] = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  /// Updates descriptive PDF metadata (Title, Author, Subject, Keywords) into a new PDF file.
  Future<File> updateMetadata({
    required File sourcePdf,
    String? title,
    String? author,
    String? subject,
    String? keywords,
    required String outputFileName,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException('PDF file does not exist: ${sourcePdf.path}');
    }
    final bytes = await sourcePdf.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      if (title != null) doc.documentInformation.title = title;
      if (author != null) doc.documentInformation.author = author;
      if (subject != null) doc.documentInformation.subject = subject;
      if (keywords != null) doc.documentInformation.keywords = keywords;
      return await _saveDocumentSafely(doc, outputFileName);
    } finally {
      doc.dispose();
    }
  }

  /// Applies interactive annotations, visual signatures, underlines, freehand ink,
  /// shapes, and highlights onto a new PDF document non-destructively.
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
        final pageW = page.size.width;
        final pageH = page.size.height;

        final double px = item.normalized ? (item.x * pageW) : item.x;
        final double py = item.normalized ? (item.y * pageH) : item.y;
        final double pw = item.normalized ? (item.width * pageW) : item.width;
        final double ph = item.normalized ? (item.height * pageH) : item.height;

        final int r = (item.color.r * 255).round().clamp(0, 255);
        final int g = (item.color.g * 255).round().clamp(0, 255);
        final int b = (item.color.b * 255).round().clamp(0, 255);
        final int alpha = (item.opacity * 255).round().clamp(15, 255);

        switch (item.type) {
          case PdfAnnotationType.text:
            if (item.text != null && item.text!.isNotEmpty) {
              final font = sf.PdfStandardFont(
                sf.PdfFontFamily.helvetica,
                item.fontSize,
                style: sf.PdfFontStyle.bold,
              );
              final brush = sf.PdfSolidBrush(sf.PdfColor(r, g, b, alpha));
              page.graphics.drawString(
                item.text!,
                font,
                brush: brush,
                bounds: Rect.fromLTWH(px, py, math.max(40.0, pw), math.max(18.0, ph)),
              );
            }
            break;

          case PdfAnnotationType.signature:
            if (item.signaturePngBytes != null &&
                item.signaturePngBytes!.isNotEmpty) {
              final bitmap = sf.PdfBitmap(item.signaturePngBytes!);
              if (item.rotationDegrees.abs() > 0.1) {
                page.graphics.save();
                final cx = px + pw / 2.0;
                final cy = py + ph / 2.0;
                page.graphics.translateTransform(cx, cy);
                page.graphics.rotateTransform(item.rotationDegrees);
                page.graphics.drawImage(
                  bitmap,
                  Rect.fromLTWH(-pw / 2.0, -ph / 2.0, pw, ph),
                );
                page.graphics.restore();
              } else {
                page.graphics.drawImage(
                  bitmap,
                  Rect.fromLTWH(px, py, pw, ph),
                );
              }
            }
            break;

          case PdfAnnotationType.highlight:
            final int hAlpha = item.opacity < 0.99
                ? alpha
                : 100; // Semi-transparent default
            final highlightBrush = sf.PdfSolidBrush(sf.PdfColor(r, g, b, hAlpha));
            page.graphics.drawRectangle(
              brush: highlightBrush,
              bounds: Rect.fromLTWH(px, py, pw, math.max(8.0, ph)),
            );
            break;

          case PdfAnnotationType.underline:
            final pen = sf.PdfPen(
              sf.PdfColor(r, g, b, alpha),
              width: math.max(1.5, item.strokeWidth),
            );
            final lineY = py + ph;
            page.graphics.drawLine(
              pen,
              Offset(px, lineY),
              Offset(px + math.max(12.0, pw), lineY),
            );
            break;

          case PdfAnnotationType.freehand:
            if (item.points.length >= 2) {
              final pen = sf.PdfPen(
                sf.PdfColor(r, g, b, alpha),
                width: math.max(1.0, item.strokeWidth),
              )..lineCap = sf.PdfLineCap.round
               ..lineJoin = sf.PdfLineJoin.round;
              for (int i = 0; i < item.points.length - 1; i++) {
                final p1 = item.points[i];
                final p2 = item.points[i + 1];
                final a = item.normalized
                    ? Offset(p1.dx * pageW, p1.dy * pageH)
                    : p1;
                final c = item.normalized
                    ? Offset(p2.dx * pageW, p2.dy * pageH)
                    : p2;
                page.graphics.drawLine(pen, a, c);
              }
            }
            break;

          case PdfAnnotationType.shape:
            final pen = sf.PdfPen(
              sf.PdfColor(r, g, b, alpha),
              width: math.max(1.5, item.strokeWidth),
            );
            final rect = Rect.fromLTWH(
              px,
              py,
              math.max(8.0, pw),
              math.max(8.0, ph),
            );
            switch (item.shapeKind) {
              case PdfShapeKind.rectangle:
                page.graphics.drawRectangle(pen: pen, bounds: rect);
                break;
              case PdfShapeKind.circle:
                page.graphics.drawEllipse(rect, pen: pen);
                break;
              case PdfShapeKind.line:
                page.graphics.drawLine(
                  pen,
                  Offset(px, py),
                  Offset(px + pw, py + ph),
                );
                break;
              case PdfShapeKind.arrow:
                final end = Offset(px + pw, py + ph);
                final start = Offset(px, py);
                page.graphics.drawLine(pen, start, end);
                final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
                const headLen = 10.0;
                const headAngle = 0.52;
                page.graphics.drawLine(
                  pen,
                  end,
                  Offset(
                    end.dx - headLen * math.cos(angle - headAngle),
                    end.dy - headLen * math.sin(angle - headAngle),
                  ),
                );
                page.graphics.drawLine(
                  pen,
                  end,
                  Offset(
                    end.dx - headLen * math.cos(angle + headAngle),
                    end.dy - headLen * math.sin(angle + headAngle),
                  ),
                );
                break;
            }
            break;
        }
      }

      return await _saveDocumentSafely(doc, outputFileName);
    } finally {
      doc.dispose();
    }
  }

  /// Applies visual blackout mask rectangles over specified regions and sanitizes document metadata.
  ///
  /// IMPORTANT SECURITY NOTE:
  /// On digital vector PDFs with searchable text streams, drawing rectangles on page graphics masks
  /// content visually, but underlying text operators may remain in the PDF stream.
  /// For absolute data destruction on sensitive scanned pages, use [ImageProcessingService.permanentlyRedactImage]
  /// which irreversibly zeroes out raw bitmap pixels before PDF compilation.
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
  // 8. EXTERNAL PDF-TO-IMAGES & IRREVERSIBLE FLATTEN + REDACT
  // ---------------------------------------------------------------------------

  /// Rasterizes arbitrary PDF pages into JPEG files via PDFium (`pdfrx`).
  Future<List<File>> exportPdfToImages({
    required File sourcePdf,
    required String baseOutputName,
    List<int>? pageNumbers1Indexed,
    double scale = 2.0,
    Future<List<Uint8List>> Function(File pdf)? pageRasterizerOverride,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    final exportsDir = AppStorageService.instance.exportsDir;
    await exportsDir.create(recursive: true);
    final sanitized = baseOutputName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final generated = <File>[];

    if (pageRasterizerOverride != null) {
      final rasterPages = await pageRasterizerOverride(sourcePdf);
      for (int i = 0; i < rasterPages.length; i++) {
        final pageNum = i + 1;
        if (pageNumbers1Indexed != null &&
            !pageNumbers1Indexed.contains(pageNum)) {
          continue;
        }
        final outFile = File('${exportsDir.path}/${sanitized}_page_$pageNum.jpg');
        await outFile.writeAsBytes(rasterPages[i], flush: true);
        generated.add(outFile);
      }
      return generated;
    }

    final doc = await pdfrx.PdfDocument.openFile(sourcePdf.path);
    try {
      for (int i = 0; i < doc.pages.length; i++) {
        final pageNum = i + 1;
        if (pageNumbers1Indexed != null &&
            !pageNumbers1Indexed.contains(pageNum)) {
          continue;
        }
        final page = doc.pages[i];
        final targetW = (page.width * scale).round().clamp(100, 4096);
        final targetH = (page.height * scale).round().clamp(100, 4096);
        final rendered = await page.render(
          width: targetW,
          height: targetH,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) continue;
        try {
          final bgraBytes = Uint8List.fromList(rendered.pixels);
          final w = rendered.width;
          final h = rendered.height;
          final jpgBytes = await Isolate.run(() {
            final im = img.Image.fromBytes(
              width: w,
              height: h,
              bytes: bgraBytes.buffer,
              numChannels: 4,
              order: img.ChannelOrder.bgra,
            );
            return Uint8List.fromList(img.encodeJpg(im, quality: 90));
          });
          final outFile = File('${exportsDir.path}/${sanitized}_page_$pageNum.jpg');
          await outFile.writeAsBytes(jpgBytes, flush: true);
          generated.add(outFile);
        } finally {
          rendered.dispose();
        }
      }
      return generated;
    } finally {
      await doc.dispose();
    }
  }

  /// Irreversibly scrubs vector/text PDF content by rasterizing pages, permanently zeroing pixels
  /// inside every matching [PdfRedactionArea], and rebuilding a flattened image-only PDF.
  Future<File> flattenAndRedactPdf({
    required File sourcePdf,
    required List<PdfRedactionArea> redactions,
    required String outputFileName,
    ScannedDocument? associatedDocument,
    Future<List<Uint8List>> Function(File pdf)? pageRasterizerOverride,
  }) async {
    if (!await sourcePdf.exists()) {
      throw FileNotFoundException(
        'Source PDF does not exist: ${sourcePdf.path}',
      );
    }

    // Gather original PDF page sizes (in PDF points) so normalized boxes map accurately.
    final pdfBytes = await sourcePdf.readAsBytes();
    final srcDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final pageSizesPt = <List<double>>[];
    try {
      for (int i = 0; i < srcDoc.pages.count; i++) {
        final sz = srcDoc.pages[i].size;
        pageSizesPt.add([sz.width, sz.height]);
      }
    } finally {
      srcDoc.dispose();
    }

    // Obtain per-page raster bytes via override, PDFium rasterizer, or original page scans.
    List<Uint8List> pageBitmaps = [];
    if (pageRasterizerOverride != null) {
      pageBitmaps = await pageRasterizerOverride(sourcePdf);
    } else {
      try {
        final exportedImgs = await exportPdfToImages(
          sourcePdf: sourcePdf,
          baseOutputName: '_flatten_tmp_${DateTime.now().millisecondsSinceEpoch}',
        );
        for (final f in exportedImgs) {
          pageBitmaps.add(await f.readAsBytes());
          try {
            await f.delete();
          } catch (_) {}
        }
      } catch (_) {
        if (associatedDocument != null && associatedDocument.pages.isNotEmpty) {
          for (final p in associatedDocument.pages) {
            final f = File(p.processedPath ?? p.originalPath);
            if (await f.exists()) {
              pageBitmaps.add(await f.readAsBytes());
            }
          }
        }
      }
    }

    if (pageBitmaps.isEmpty) {
      throw StateError(
        'Unable to rasterize PDF pages for irreversible flattening in this environment.',
      );
    }

    final targetPath = _resolveExportPath(outputFileName);
    final redactionMaps = [
      for (final r in redactions)
        {
          'pageIndex': r.pageIndex,
          'x': r.x,
          'y': r.y,
          'w': r.width,
          'h': r.height,
        },
    ];

    await Isolate.run(() {
      final flatDoc = sf.PdfDocument();
      try {
        for (int i = 0; i < pageBitmaps.length; i++) {
          final decoded = img.decodeImage(pageBitmaps[i]);
          if (decoded == null) continue;
          img.Image working = decoded;
          final pageW = i < pageSizesPt.length ? pageSizesPt[i][0] : 595.0;
          final pageH = i < pageSizesPt.length ? pageSizesPt[i][1] : 842.0;

          for (final r in redactionMaps) {
            if (r['pageIndex'] != i) continue;
            final rx = ((r['x'] as num).toDouble() / pageW).clamp(0.0, 0.99);
            final ry = ((r['y'] as num).toDouble() / pageH).clamp(0.0, 0.99);
            final rw = ((r['w'] as num).toDouble() / pageW).clamp(0.01, 1.0 - rx);
            final rh = ((r['h'] as num).toDouble() / pageH).clamp(0.01, 1.0 - ry);
            working = ImageProcessingService.permanentlyRedactImage(
              src: working,
              normX: rx,
              normY: ry,
              normW: rw,
              normH: rh,
            );
          }

          final jpg = Uint8List.fromList(img.encodeJpg(working, quality: 92));
          final bitmap = sf.PdfBitmap(jpg);
          final newPage = flatDoc.pages.add();
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, newPage.size.width, newPage.size.height),
          );
        }
        flatDoc.documentInformation.title = '';
        flatDoc.documentInformation.author = '';
        flatDoc.documentInformation.subject = '';
        flatDoc.documentInformation.keywords = '';
        flatDoc.documentInformation.producer = 'Scaneliq Flattened Redaction';
        _writePdfSyncAtomically(flatDoc.saveSync(), targetPath);
      } finally {
        flatDoc.dispose();
      }
    });
    return File(targetPath);
  }

  // ---------------------------------------------------------------------------
  // HELPER: SAFE COMMIT & EXPORT
  // ---------------------------------------------------------------------------

  String _resolveExportPath(String outputFileName) {
    final sanitized = outputFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return AppStorageService.instance.getExportPdfPath(sanitized);
  }

  static void _writePdfSyncAtomically(
    List<int> outputBytes,
    String exportPath,
  ) {
    if (outputBytes.isEmpty) {
      throw StateError('PDF generation produced empty byte output.');
    }
    final tempPath = '$exportPath.tmp';
    final tempFile = File(tempPath);
    tempFile.writeAsBytesSync(outputBytes, flush: true);
    tempFile.renameSync(exportPath);
  }

  Future<File> _saveDocumentSafely(
    sf.PdfDocument doc,
    String outputFileName,
  ) async {
    final List<int> outputBytes = doc.saveSync();
    if (outputBytes.isEmpty) {
      throw StateError('PDF generation produced empty byte output.');
    }

    final exportPath = _resolveExportPath(outputFileName);
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

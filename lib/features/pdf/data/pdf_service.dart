import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/services/scan_preferences_service.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Container for background isolate image processing input
class _PageProcessingInput {
  final Uint8List rawBytes;
  final EditRecipe recipe;
  final int jpegQuality;
  final int maxEdgePx;

  _PageProcessingInput({
    required this.rawBytes,
    required this.recipe,
    this.jpegQuality = 85,
    this.maxEdgePx = 2338,
  });
}

/// Container for processed page output from isolate
class _PageProcessingOutput {
  final Uint8List jpegBytes;
  final int width;
  final int height;

  _PageProcessingOutput({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });
}

/// Isolate worker function for CPU-intensive decoding, filter application, and JPEG compression
List<_PageProcessingOutput> _processPagesInIsolate(
  List<_PageProcessingInput> inputs,
) {
  final List<_PageProcessingOutput> outputs = [];
  for (final input in inputs) {
    final decoded = img.decodeImage(input.rawBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }
    var processed = PdfService.applyEditRecipe(decoded, input.recipe);
    if (input.maxEdgePx > 0 &&
        (processed.width > input.maxEdgePx ||
            processed.height > input.maxEdgePx)) {
      processed = processed.width >= processed.height
          ? img.copyResize(processed, width: input.maxEdgePx)
          : img.copyResize(processed, height: input.maxEdgePx);
    }
    final encoded = Uint8List.fromList(
      img.encodeJpg(processed, quality: input.jpegQuality),
    );
    outputs.add(
      _PageProcessingOutput(
        jpegBytes: encoded,
        width: processed.width,
        height: processed.height,
      ),
    );
  }
  return outputs;
}

/// Isolate worker for 2-in-1 ID card stitching
Uint8List _stitchIdCardWorker(List<Uint8List> cardBytes) {
  final front = img.decodeImage(cardBytes[0]);
  final back = img.decodeImage(cardBytes[1]);
  if (front == null || back == null) {
    throw Exception('Failed to decode card images for 2-in-1 stitching');
  }

  // Create standard A4 portrait canvas at 200 DPI (1654 x 2338)
  const int canvasW = 1654;
  const int canvasH = 2338;
  final canvas = img.Image(width: canvasW, height: canvasH);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  // Standard ID-1 card target size: ~1050 x 660 pixels
  const int targetCardW = 1050;
  const int targetCardH = 660;

  final scaledFront = img.copyResize(
    front,
    width: targetCardW,
    height: targetCardH,
    interpolation: img.Interpolation.linear,
  );
  final scaledBack = img.copyResize(
    back,
    width: targetCardW,
    height: targetCardH,
    interpolation: img.Interpolation.linear,
  );

  final int posX = (canvasW - targetCardW) ~/ 2;
  const int posYFront = 320;
  const int posYBack = 1250;

  // Composite cards onto canvas
  img.compositeImage(canvas, scaledFront, dstX: posX, dstY: posYFront);
  img.compositeImage(canvas, scaledBack, dstX: posX, dstY: posYBack);

  // Draw delicate card outlines
  final borderColor = img.ColorRgb8(200, 205, 215);
  img.drawRect(
    canvas,
    x1: posX - 2,
    y1: posYFront - 2,
    x2: posX + targetCardW + 2,
    y2: posYFront + targetCardH + 2,
    color: borderColor,
    thickness: 2,
  );
  img.drawRect(
    canvas,
    x1: posX - 2,
    y1: posYBack - 2,
    x2: posX + targetCardW + 2,
    y2: posYBack + targetCardH + 2,
    color: borderColor,
    thickness: 2,
  );

  return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
}

/// PDF generator using pure Dart 'pdf' engine according to blueprint section 4.4
class PdfService {
  static pw.Font? _cachedUnicodeFont;

  static Future<pw.Font?> _loadUnicodeFont() async {
    if (_cachedUnicodeFont != null) return _cachedUnicodeFont;
    try {
      final data = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      );
      _cachedUnicodeFont = pw.Font.ttf(data);
      return _cachedUnicodeFont;
    } catch (_) {
      try {
        final localFile = File('assets/fonts/NotoSansBengali-Regular.ttf');
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          _cachedUnicodeFont = pw.Font.ttf(ByteData.sublistView(bytes));
          return _cachedUnicodeFont;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Resolves the canonical single-pass source file and recipe for [page].
  ///
  /// Always reads [DocumentPage.originalPath] with [DocumentPage.editRecipe] so
  /// pre-rendered [DocumentPage.processedPath] thumbnails never suffer double
  /// rotation, double cropping, or stacked adjustments during export.
  static Future<(File file, EditRecipe recipe)> resolveSinglePassSource(
    DocumentPage page,
  ) async {
    final origFile = File(page.originalPath);
    if (await origFile.exists()) {
      return (origFile, page.editRecipe);
    }
    if (page.processedPath != null) {
      final procFile = File(page.processedPath!);
      if (await procFile.exists()) {
        return (procFile, const EditRecipe());
      }
    }
    throw Exception(
      'Page source image file is missing and does not exist at: ${page.originalPath}',
    );
  }

  /// Generates a validated multi-page PDF with optional Searchable PDF OCR text layer
  static Future<File> generatePdf({
    required ScannedDocument document,
    required List<DocumentPage> pages,
    String? customTitle,
    Map<int, List<OcrBoundingBox>>? ocrBoxesByPage,
    PdfQualityPreset? qualityPreset,
    PdfPageFormatOption? pageFormatOption,
  }) async {
    if (pages.isEmpty) {
      throw Exception('Cannot generate PDF: document contains 0 pages');
    }

    final resolvedQuality =
        qualityPreset ?? ScanPreferencesService.instance.qualityPreset;
    final resolvedFormatOption =
        pageFormatOption ?? ScanPreferencesService.instance.pageFormat;

    final pdf = pw.Document(
      title: customTitle ?? document.title,
      author: 'Scaneliq',
      creator: 'Scaneliq Doc Scanner',
    );

    final bool hasUnicodeOcr =
        ocrBoxesByPage != null &&
        ocrBoxesByPage.values.any(
          (list) => list.any((b) => b.text.runes.any((r) => r > 255)),
        );
    final pw.Font? unicodeFont = hasUnicodeOcr
        ? await _loadUnicodeFont()
        : null;

    // Read canonical original pages asynchronously so EditRecipe applies cleanly once.
    final List<_PageProcessingInput> inputs = [];
    for (int i = 0; i < pages.length; i++) {
      final (sourceFile, sourceRecipe) = await resolveSinglePassSource(
        pages[i],
      );
      final bytes = await sourceFile.readAsBytes();
      inputs.add(
        _PageProcessingInput(
          rawBytes: bytes,
          recipe: sourceRecipe,
          jpegQuality: resolvedQuality.jpegQuality,
          maxEdgePx: resolvedQuality.maxEdgePx,
        ),
      );
    }

    // Process images in background isolate to prevent UI thread freezing
    final List<_PageProcessingOutput> processedOutputs = await compute(
      _processPagesInIsolate,
      inputs,
    );

    // Build PDF pages with image and searchable OCR text overlay
    final pageFormat = resolvedFormatOption == PdfPageFormatOption.letter
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;
    final double pageWidth = pageFormat.width;
    final double pageHeight = pageFormat.height;

    for (int i = 0; i < processedOutputs.length; i++) {
      final out = processedOutputs[i];
      final pdfImage = pw.MemoryImage(out.jpegBytes);

      // Calculate image scale and offset inside A4 contain box
      final double imgAspect = out.width / out.height;
      final double pageAspect = pageWidth / pageHeight;

      double renderedW, renderedH, dx, dy;
      if (imgAspect < pageAspect) {
        renderedH = pageHeight;
        renderedW = pageHeight * imgAspect;
        dx = (pageWidth - renderedW) / 2.0;
        dy = 0.0;
      } else {
        renderedW = pageWidth;
        renderedH = pageWidth / imgAspect;
        dx = 0.0;
        dy = (pageHeight - renderedH) / 2.0;
      }

      final boxes = ocrBoxesByPage?[i] ?? [];
      final textOverlays = <pw.Widget>[];

      for (final box in boxes) {
        if (box.text.trim().isEmpty) continue;
        final scaledX = dx + (box.left / out.width) * renderedW;
        final scaledY = dy + (box.top / out.height) * renderedH;
        final scaledW = (box.width / out.width) * renderedW;
        final scaledH = (box.height / out.height) * renderedH;

        // Preserve genuine Unicode (e.g. Bengali U+0980..U+09FF) when Unicode TTF is available;
        // otherwise safely degrade to Latin-1 Helvetica fallback so PDF synthesis never throws.
        final bool boxHasUnicode = box.text.runes.any((r) => r > 255);
        final pw.Font? boxFont = boxHasUnicode ? unicodeFont : null;
        final String searchableText = (boxHasUnicode && boxFont == null)
            ? box.text.runes.map((r) {
                if (r <= 255) return String.fromCharCode(r);
                if (r >= 0x09E6 && r <= 0x09EF) {
                  return String.fromCharCode(48 + (r - 0x09E6));
                }
                return ' ';
              }).join()
            : box.text;

        if (searchableText.trim().isEmpty) continue;

        textOverlays.add(
          pw.Positioned(
            left: scaledX.clamp(0.0, pageWidth),
            top: scaledY.clamp(0.0, pageHeight),
            child: pw.SizedBox(
              width: scaledW.clamp(4.0, pageWidth),
              height: scaledH.clamp(4.0, pageHeight),
              child: pw.Opacity(
                opacity: 0.0,
                child: pw.Text(
                  searchableText,
                  softWrap: false,
                  style: pw.TextStyle(
                    font: boxFont,
                    fontSize: (scaledH * 0.75).clamp(4.0, 48.0),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add full A4 page with background image and searchable text layer
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
                ...textOverlays,
              ],
            );
          },
        ),
      );
    }

    // Write to temporary file first (atomic safety principle)
    final exportTitle = (customTitle ?? document.title).trim();
    final exportFileName = exportTitle.isEmpty
        ? 'Scaneliq_Doc_${document.id}'
        : exportTitle;
    final finalPath = AppStorageService.instance.getExportPdfPath(
      exportFileName,
    );
    final tempPath = '$finalPath.tmp';

    final tempFile = File(tempPath);
    final pdfBytes = await pdf.save();

    // Verify non-empty before committing
    if (pdfBytes.isEmpty || pdfBytes.length < 50) {
      throw Exception('PDF generation resulted in empty output.');
    }

    // Independent validation using Syncfusion parser to guarantee PDF integrity
    try {
      final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
      sfDoc.dispose();
    } catch (e) {
      throw Exception('Generated PDF validation failed: $e');
    }

    await tempFile.writeAsBytes(pdfBytes, flush: true);

    // Atomically commit to final export path
    final finalFile = await tempFile.rename(finalPath);
    return finalFile;
  }

  /// Composites front and back ID card images onto a single vertical A4 layout
  static Future<File> stitchIdCard2In1({
    required File frontImage,
    required File backImage,
    required String baseTitle,
  }) async {
    if (!await frontImage.exists()) {
      throw Exception('Front card image is missing: ${frontImage.path}');
    }
    if (!await backImage.exists()) {
      throw Exception('Back card image is missing: ${backImage.path}');
    }

    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();

    final stitchedBytes = await compute(_stitchIdCardWorker, [
      frontBytes,
      backBytes,
    ]);

    final sanitized = baseTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath =
        '${AppStorageService.instance.originalsDir.path}/${sanitized}_id2in1.jpg';
    final tempPath = '$targetPath.tmp';

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(stitchedBytes, flush: true);
    return await tempFile.rename(targetPath);
  }

  /// Exports an individual page as a processed JPEG file inside a background isolate
  static Future<File> exportPageAsJpeg({
    required DocumentPage page,
    required String baseName,
    int quality = 90,
  }) async {
    final (sourceFile, sourceRecipe) = await resolveSinglePassSource(page);

    final encodedJpeg =
        await ImageProcessingService.processImageFileToBytesInIsolate(
          sourceFile,
          sourceRecipe,
          quality: quality,
        );

    final sanitized = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath =
        '${AppStorageService.instance.exportsDir.path}/${sanitized}_p${page.pageOrder + 1}.jpg';
    final tempPath = '$targetPath.tmp';

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(encodedJpeg, flush: true);

    return await tempFile.rename(targetPath);
  }

  /// Helper to apply EditRecipe modifications using the unified ImageProcessingService
  static img.Image applyEditRecipe(img.Image image, EditRecipe recipe) {
    return ImageProcessingService.applyEditRecipe(image, recipe);
  }
}

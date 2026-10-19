import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

/// Container for background isolate image processing input
class _PageProcessingInput {
  final Uint8List rawBytes;
  final EditRecipe recipe;

  _PageProcessingInput({required this.rawBytes, required this.recipe});
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
    final processed = PdfService.applyEditRecipe(decoded, input.recipe);
    final encoded = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
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
  /// Generates a validated multi-page PDF with optional Searchable PDF OCR text layer
  static Future<File> generatePdf({
    required ScannedDocument document,
    required List<DocumentPage> pages,
    String? customTitle,
    Map<int, List<OcrBoundingBox>>? ocrBoxesByPage,
  }) async {
    if (pages.isEmpty) {
      throw Exception('Cannot generate PDF: document contains 0 pages');
    }

    final pdf = pw.Document(
      title: customTitle ?? document.title,
      author: 'Scaneliq',
      creator: 'Scaneliq Doc Scanner',
    );

    // Read all page bytes asynchronously from disk
    final List<_PageProcessingInput> inputs = [];
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final imagePath = page.processedPath ?? page.originalPath;
      final file = File(imagePath);

      if (!await file.exists()) {
        throw Exception('Page ${i + 1} image file is missing at: $imagePath');
      }

      final bytes = await file.readAsBytes();
      inputs.add(
        _PageProcessingInput(rawBytes: bytes, recipe: page.editRecipe),
      );
    }

    // Process images in background isolate to prevent UI thread freezing
    final List<_PageProcessingOutput> processedOutputs = await compute(
      _processPagesInIsolate,
      inputs,
    );

    // Build PDF pages with image and searchable OCR text overlay
    final pageFormat = PdfPageFormat.a4;
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
                  box.text,
                  softWrap: false,
                  style: pw.TextStyle(
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
    if (pdfBytes.isEmpty) {
      throw Exception('PDF generation resulted in empty output.');
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

  /// Exports an individual page as a processed JPEG file
  static Future<File> exportPageAsJpeg({
    required DocumentPage page,
    required String baseName,
  }) async {
    final imagePath = page.processedPath ?? page.originalPath;
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Page source file does not exist at: $imagePath');
    }

    final bytes = await file.readAsBytes();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image for JPEG export');
    }

    img.Image workingImage = applyEditRecipe(decodedImage, page.editRecipe);

    final sanitized = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath =
        '${AppStorageService.instance.exportsDir.path}/${sanitized}_p${page.pageOrder + 1}.jpg';
    final tempPath = '$targetPath.tmp';

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(
      img.encodeJpg(workingImage, quality: 90),
      flush: true,
    );

    return await tempFile.rename(targetPath);
  }

  /// Helper to apply EditRecipe modifications using the unified ImageProcessingService
  static img.Image applyEditRecipe(img.Image image, EditRecipe recipe) {
    return ImageProcessingService.applyEditRecipe(image, recipe);
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';

/// PDF generator using pure Dart 'pdf' engine according to blueprint section 4.4
class PdfService {
  /// Generates a validated multi-page PDF from a document's ordered pages
  static Future<File> generatePdf({
    required ScannedDocument document,
    required List<DocumentPage> pages,
    String? customTitle,
  }) async {
    if (pages.isEmpty) {
      throw Exception('Cannot generate PDF: document contains 0 pages');
    }

    final pdf = pw.Document(
      title: customTitle ?? document.title,
      author: 'Scaneliq',
      creator: 'Scaneliq Doc Scanner',
    );

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final imagePath = page.processedPath ?? page.originalPath;
      final file = File(imagePath);

      if (!await file.exists()) {
        throw Exception('Page ${i + 1} image file is missing at: $imagePath');
      }

      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        throw Exception('Failed to decode image for page ${i + 1}');
      }

      // Apply non-destructive rotation, filter, brightness, contrast
      img.Image workingImage = applyEditRecipe(decodedImage, page.editRecipe);

      final encodedJpg = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: 85),
      );
      final pdfImage = pw.MemoryImage(encodedJpg);

      // Add full A4 or source aspect page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain));
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

  /// Helper to apply EditRecipe modifications (rotation, filter, brightness, contrast)
  static img.Image applyEditRecipe(img.Image image, EditRecipe recipe) {
    img.Image workingImage = image;
    if (recipe.rotationDegrees != 0) {
      workingImage = img.copyRotate(
        workingImage,
        angle: recipe.rotationDegrees,
      );
    }
    if (recipe.filter == PageFilter.grayscale) {
      workingImage = img.grayscale(workingImage);
    } else if (recipe.filter == PageFilter.blackAndWhite) {
      workingImage = img.grayscale(workingImage);
      workingImage = img.contrast(workingImage, contrast: 150);
    }
    if (recipe.contrast != 1.0 || recipe.brightness != 0.0) {
      workingImage = img.adjustColor(
        workingImage,
        brightness: 1.0 + recipe.brightness,
        contrast: recipe.contrast,
      );
    }
    return workingImage;
  }
}

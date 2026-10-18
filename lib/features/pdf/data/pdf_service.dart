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

      // Apply non-destructive rotation or filter if specified
      img.Image workingImage = decodedImage;
      if (page.editRecipe.rotationDegrees != 0) {
        workingImage = img.copyRotate(workingImage, angle: page.editRecipe.rotationDegrees);
      }
      if (page.editRecipe.filter == PageFilter.grayscale) {
        workingImage = img.grayscale(workingImage);
      } else if (page.editRecipe.filter == PageFilter.blackAndWhite) {
        workingImage = img.grayscale(workingImage);
        // Contrast enhancement for clean B&W document scans
        workingImage = img.contrast(workingImage, contrast: 150);
      }

      final encodedJpg = Uint8List.fromList(img.encodeJpg(workingImage, quality: 85));
      final pdfImage = pw.MemoryImage(encodedJpg);

      // Add full A4 or source aspect page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    // Write to temporary file first (atomic safety principle)
    final exportTitle = (customTitle ?? document.title).trim();
    final exportFileName = exportTitle.isEmpty ? 'Scaneliq_Doc_${document.id}' : exportTitle;
    final finalPath = AppStorageService.instance.getExportPdfPath(exportFileName);
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
}

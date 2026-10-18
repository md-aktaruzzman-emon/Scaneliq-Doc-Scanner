import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scaneliq/core/models/document_models.dart';

/// Manages app-private local storage directories according to blueprint section 6.1
class AppStorageService {
  static AppStorageService? _instance;
  static AppStorageService get instance => _instance ??= AppStorageService._();
  AppStorageService._();

  Directory? _baseDir;

  Future<void> init([Directory? customBaseDir]) async {
    _baseDir = customBaseDir ?? await getApplicationDocumentsDirectory();
    await originalsDir.create(recursive: true);
    await processedDir.create(recursive: true);
    await exportsDir.create(recursive: true);
    await tempDir.create(recursive: true);
  }

  Directory get originalsDir => Directory(
    p.join(_baseDir?.path ?? Directory.systemTemp.path, 'originals'),
  );
  Directory get processedDir => Directory(
    p.join(_baseDir?.path ?? Directory.systemTemp.path, 'processed'),
  );
  Directory get exportsDir =>
      Directory(p.join(_baseDir?.path ?? Directory.systemTemp.path, 'exports'));
  Directory get tempDir =>
      Directory(p.join(_baseDir?.path ?? Directory.systemTemp.path, 'temp'));

  /// Safely writes an original page image into the app-private originals directory
  Future<File> saveOriginalPage(
    String pageId,
    List<int> bytes, {
    String extension = 'jpg',
  }) async {
    final targetPath = p.join(originalsDir.path, '$pageId.$extension');
    final tempPath = p.join(tempDir.path, '${pageId}_tmp.$extension');

    // Write to temporary location first (atomic safety)
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    // Commit to persistent path
    return await tempFile.rename(targetPath);
  }

  /// Copies an external file safely to originals
  Future<File> copyToOriginals(
    String pageId,
    File sourceFile, {
    String extension = 'jpg',
  }) async {
    final targetPath = p.join(originalsDir.path, '$pageId.$extension');
    return await sourceFile.copy(targetPath);
  }

  /// Creates a safe unique path for a PDF export
  String getExportPdfPath(String baseName) {
    final sanitized = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return p.join(exportsDir.path, '$sanitized.pdf');
  }

  /// Safely deletes the export file and associated page images for a document
  Future<void> deleteDocumentFiles(ScannedDocument doc) async {
    if (doc.exportPath != null) {
      final exportFile = File(doc.exportPath!);
      if (await exportFile.exists()) {
        try {
          await exportFile.delete();
        } catch (_) {}
      }
    }
    for (final page in doc.pages) {
      final orig = File(page.originalPath);
      if (await orig.exists() && orig.path.startsWith(originalsDir.path)) {
        try {
          await orig.delete();
        } catch (_) {}
      }
      if (page.processedPath != null) {
        final proc = File(page.processedPath!);
        if (await proc.exists() && proc.path.startsWith(processedDir.path)) {
          try {
            await proc.delete();
          } catch (_) {}
        }
      }
    }
  }
}

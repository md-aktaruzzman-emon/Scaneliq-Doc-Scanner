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

    // Stale temp file cleanup (>24 hours) for storage hygiene
    try {
      if (tempDir.existsSync()) {
        final now = DateTime.now();
        for (final entity in tempDir.listSync()) {
          if (entity is File) {
            final stat = entity.statSync();
            if (now.difference(stat.modified).inHours >= 24) {
              entity.deleteSync();
            }
          }
        }
      }
    } catch (_) {
      // Non-critical startup cleanup
    }
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

  /// Validates magic bytes for JPEG, PNG, or WebP image formats
  static bool isValidImageBytes(List<int> bytes) {
    if (bytes.length < 8) return false;
    // JPEG magic bytes: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // WebP magic bytes: 'RIFF' at 0..3 and 'WEBP' at 8..11
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Safely writes an original page image into the app-private originals directory
  Future<File> saveOriginalPage(
    String pageId,
    List<int> bytes, {
    String extension = 'jpg',
    bool validateHeader = false,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Cannot save empty image bytes for page: $pageId');
    }
    if (validateHeader && !isValidImageBytes(bytes)) {
      throw Exception(
        'Corrupted or invalid image byte header for page: $pageId',
      );
    }

    final targetPath = p.join(originalsDir.path, '$pageId.$extension');
    final tempPath = p.join(tempDir.path, '${pageId}_tmp.$extension');

    // Write to temporary location first (atomic safety)
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    // Commit to persistent path
    return await tempFile.rename(targetPath);
  }

  /// Copies an external file safely to originals with atomic write and existence check
  Future<File> copyToOriginals(
    String pageId,
    File sourceFile, {
    String extension = 'jpg',
  }) async {
    if (!await sourceFile.exists()) {
      throw Exception('Source image file does not exist: ${sourceFile.path}');
    }
    final fileSize = await sourceFile.length();
    if (fileSize == 0) {
      throw Exception(
        'Source image file is empty (0 bytes): ${sourceFile.path}',
      );
    }

    final targetPath = p.join(originalsDir.path, '$pageId.$extension');
    final tempPath = p.join(tempDir.path, '${pageId}_copy_tmp.$extension');

    final tempFile = await sourceFile.copy(tempPath);
    return await tempFile.rename(targetPath);
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

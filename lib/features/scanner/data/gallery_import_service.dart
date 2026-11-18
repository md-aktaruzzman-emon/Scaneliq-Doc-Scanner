import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/storage/app_storage_service.dart';

/// Rejection details for an invalid or unreadable picked gallery file.
class GalleryImportRejection {
  final String fileName;
  final String reason;

  const GalleryImportRejection({
    required this.fileName,
    required this.reason,
  });
}

/// Validated image entry ready to enter a scan session.
class ValidatedGalleryImage {
  final File file;
  final String extension;
  final int byteLength;
  final int? width;
  final int? height;

  const ValidatedGalleryImage({
    required this.file,
    required this.extension,
    required this.byteLength,
    this.width,
    this.height,
  });
}

/// Outcome of a gallery multi-image selection and validation pass.
class GalleryImportResult {
  final bool cancelled;
  final List<ValidatedGalleryImage> accepted;
  final List<GalleryImportRejection> rejections;

  const GalleryImportResult({
    this.cancelled = false,
    this.accepted = const [],
    this.rejections = const [],
  });

  bool get hasAccepted => accepted.isNotEmpty;
  bool get hasRejections => rejections.isNotEmpty;
}

typedef GalleryFilePickerCallback = Future<List<File>?> Function();

/// Handles device gallery selection, magic-byte validation, and format checks.
class GalleryImportService {
  static const List<String> supportedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// Guardrail against corrupted / pathological giant files (> 80 MB).
  static const int maxFileSizeBytes = 80 * 1024 * 1024;

  final GalleryFilePickerCallback? _customPicker;

  const GalleryImportService({GalleryFilePickerCallback? picker})
    : _customPicker = picker;

  /// Picks images from device storage and validates each file before import.
  Future<GalleryImportResult> pickAndValidateImages() async {
    final List<File>? picked;
    if (_customPicker != null) {
      picked = await _customPicker();
    } else {
      final platformFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
      );
      if (platformFiles.isEmpty) {
        return const GalleryImportResult(cancelled: true);
      }
      picked = platformFiles
          .where((p) => p.path != null && p.path!.isNotEmpty)
          .map((p) => File(p.path!))
          .toList();
    }

    if (picked == null || picked.isEmpty) {
      return const GalleryImportResult(cancelled: true);
    }

    return validateFiles(picked);
  }

  /// Validates an arbitrary list of image files without duplicating pipeline logic.
  Future<GalleryImportResult> validateFiles(List<File> files) async {
    final accepted = <ValidatedGalleryImage>[];
    final rejections = <GalleryImportRejection>[];

    for (final file in files) {
      final name = file.path.split(Platform.pathSeparator).last;
      if (!await file.exists()) {
        rejections.add(
          GalleryImportRejection(fileName: name, reason: 'File no longer exists'),
        );
        continue;
      }

      final ext = file.path.contains('.')
          ? file.path.split('.').last.toLowerCase()
          : '';
      if (!supportedExtensions.contains(ext)) {
        rejections.add(
          GalleryImportRejection(
            fileName: name,
            reason: 'Unsupported format (expected JPG, PNG, or WebP)',
          ),
        );
        continue;
      }

      final length = await file.length();
      if (length <= 0) {
        rejections.add(
          GalleryImportRejection(fileName: name, reason: 'Image file is empty'),
        );
        continue;
      }
      if (length > maxFileSizeBytes) {
        rejections.add(
          GalleryImportRejection(
            fileName: name,
            reason: 'Image exceeds 80 MB single-page limit',
          ),
        );
        continue;
      }

      try {
        final headerBytes = await _readHeaderBytes(file, 32);
        if (!AppStorageService.isValidImageBytes(headerBytes)) {
          rejections.add(
            GalleryImportRejection(
              fileName: name,
              reason: 'Corrupted or disguised image header',
            ),
          );
          continue;
        }

        final dims = await _readImageDimensions(file);
        accepted.add(
          ValidatedGalleryImage(
            file: file,
            extension: ext == 'jpeg' ? 'jpg' : ext,
            byteLength: length,
            width: dims?.$1,
            height: dims?.$2,
          ),
        );
      } catch (_) {
        rejections.add(
          GalleryImportRejection(
            fileName: name,
            reason: 'Unable to read image file',
          ),
        );
      }
    }

    return GalleryImportResult(
      cancelled: false,
      accepted: accepted,
      rejections: rejections,
    );
  }

  static Future<List<int>> _readHeaderBytes(File file, int count) async {
    final raf = await file.open();
    try {
      return await raf.read(count);
    } finally {
      await raf.close();
    }
  }

  static Future<(int, int)?> _readImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info != null && info.width > 0 && info.height > 0) {
        return (info.width, info.height);
      }
    } catch (_) {}
    return null;
  }
}

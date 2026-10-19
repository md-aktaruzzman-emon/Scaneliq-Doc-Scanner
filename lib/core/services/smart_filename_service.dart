import 'dart:io';

import 'package:intl/intl.dart';

/// Service for generating, sanitizing, and resolving collision-safe smart filenames
class SmartFilenameService {
  static const String defaultTemplate = '[Date]_[Category]_[Counter]';
  static const String templateDateTitle = '[Date]_[Title]';
  static const String templateCategoryDate = '[Category]_[Date]';
  static const String templateScanTimestamp = 'Scan_[Date]_[Time]';

  /// Generates a standardized, sanitized filename based on template and runtime metadata
  static String generateFilename({
    String template = defaultTemplate,
    String? title,
    String? category,
    int counter = 1,
    DateTime? timestamp,
    String extension = 'pdf',
  }) {
    final now = timestamp ?? DateTime.now();

    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final yearStr = DateFormat('yyyy').format(now);
    final monthStr = DateFormat('MM').format(now);
    final dayStr = DateFormat('dd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);

    final cleanCategory = sanitizeToken(category ?? 'Doc');
    final cleanTitle = sanitizeToken(title ?? 'Document');
    final counterStr = counter.toString().padLeft(3, '0');

    String result = template
        .replaceAll('[Date]', dateStr)
        .replaceAll('[Year]', yearStr)
        .replaceAll('[Month]', monthStr)
        .replaceAll('[Day]', dayStr)
        .replaceAll('[Time]', timeStr)
        .replaceAll('[Category]', cleanCategory)
        .replaceAll('[Title]', cleanTitle)
        .replaceAll('[Counter]', counterStr);

    result = sanitizeFilename(result);

    final cleanExt = extension.replaceAll('.', '').trim();
    if (cleanExt.isEmpty) return result;
    return '$result.$cleanExt';
  }

  /// Sanitizes raw tokens (title, category) by removing invalid filesystem characters
  static String sanitizeToken(String raw) {
    if (raw.trim().isEmpty) return 'Doc';
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (sanitized.isEmpty) return 'Doc';
    return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
  }

  /// Sanitizes complete filenames for cross-platform filesystem safety
  static String sanitizeFilename(String filename) {
    String clean = filename
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '')
        .trim();

    if (clean.isEmpty) {
      clean = 'Scaneliq_Doc';
    }

    if (clean.length > 80) {
      clean = clean.substring(0, 80);
    }

    return clean;
  }

  /// Generates a preview string for UI template selection
  static String previewTemplate(
    String template, {
    String? sampleCategory,
    String? sampleTitle,
  }) {
    return generateFilename(
      template: template,
      title: sampleTitle ?? 'Contract',
      category: sampleCategory ?? 'Business',
      counter: 1,
      extension: 'pdf',
    );
  }

  /// Resolves filename collisions by adding sequential `_001`, `_002` suffixes if file exists
  static Future<String> resolveUniqueFilename(
    Directory directory,
    String baseFilenameWithExt,
  ) async {
    final dotIndex = baseFilenameWithExt.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1
        ? baseFilenameWithExt.substring(0, dotIndex)
        : baseFilenameWithExt;
    final ext = dotIndex != -1 ? baseFilenameWithExt.substring(dotIndex) : '';

    String candidate = '$nameWithoutExt$ext';
    File file = File('${directory.path}/$candidate');
    int counter = 1;

    while (await file.exists()) {
      candidate = '${nameWithoutExt}_${counter.toString().padLeft(3, '0')}$ext';
      file = File('${directory.path}/$candidate');
      counter++;
    }

    return candidate;
  }
}

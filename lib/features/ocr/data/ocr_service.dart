import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';

/// Supported recognition scripts for OCR.
enum OcrScript { latin, devanagari, bengali, mixedBengaliEnglish }

/// Represents an OCR-recognized text element with pixel coordinates on the source image.
class OcrBoundingBox {
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get centerY => top + (height / 2.0);
  double get right => left + width;
}

/// Consolidated OCR result with full text and bounding boxes for searchable PDF generation.
class PageOcrResult {
  final String fullText;
  final List<OcrBoundingBox> boxes;
  final OcrScript script;
  final String engine;

  const PageOcrResult({
    required this.fullText,
    required this.boxes,
    this.script = OcrScript.latin,
    this.engine = 'mlkit',
  });

  String get text => fullText;
}

/// Extracted structured table parsed from spatial OCR bounding boxes.
class ExtractedTable {
  final List<List<String>> rows;

  const ExtractedTable(this.rows);

  bool get isEmpty => rows.isEmpty;

  String toCsv() {
    String escape(String cell) {
      final clean = cell.replaceAll('\n', ' ').trim();
      if (clean.contains(',') || clean.contains('"') || clean.contains('\n')) {
        return '"${clean.replaceAll('"', '""')}"';
      }
      return clean;
    }

    return rows.map((r) => r.map(escape).join(',')).join('\n');
  }

  String toMarkdown() {
    if (rows.isEmpty) return '';
    final maxCols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (maxCols == 0) return '';

    String formatRow(List<String> cells) {
      final padded = List<String>.generate(
        maxCols,
        (i) => (i < cells.length ? cells[i] : '').replaceAll('|', '\\|'),
      );
      return '| ${padded.join(' | ')} |';
    }

    final buffer = StringBuffer();
    buffer.writeln(formatRow(rows.first));
    buffer.writeln('| ${List.filled(maxCols, '---').join(' | ')} |');
    for (int i = 1; i < rows.length; i++) {
      buffer.writeln(formatRow(rows[i]));
    }
    return buffer.toString().trim();
  }
}

/// Extracts row/column tables from OCR bounding boxes by spatial Y-line grouping
/// and X-column clustering.
class OcrTableExtractor {
  static ExtractedTable extract(PageOcrResult result) {
    if (result.boxes.isEmpty) {
      return _extractFromPlainText(result.fullText);
    }

    final sorted = List<OcrBoundingBox>.from(result.boxes)
      ..sort((a, b) {
        final dy = a.centerY.compareTo(b.centerY);
        if (dy != 0) return dy;
        return a.left.compareTo(b.left);
      });

    final rows = <List<OcrBoundingBox>>[];
    for (final box in sorted) {
      if (rows.isEmpty) {
        rows.add([box]);
        continue;
      }
      final lastRow = rows.last;
      final avgY =
          lastRow.fold<double>(0, (s, b) => s + b.centerY) / lastRow.length;
      final avgH =
          lastRow.fold<double>(0, (s, b) => s + b.height) / lastRow.length;
      final tolerance = (avgH * 0.65).clamp(8.0, 40.0);
      if ((box.centerY - avgY).abs() <= tolerance) {
        lastRow.add(box);
      } else {
        rows.add([box]);
      }
    }

    final tableRows = <List<String>>[];
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      // Split text within single lines if multi-space tabular gaps appear
      if (row.length == 1 && RegExp(r'\s{2,}|\t|\|').hasMatch(row.first.text)) {
        final split = row.first.text
            .split(RegExp(r'\s{2,}|\t|\|'))
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (split.isNotEmpty) tableRows.add(split);
      } else {
        final cols = row
            .map((b) => b.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (cols.isNotEmpty) tableRows.add(cols);
      }
    }

    // Filter out rows if none have > 1 column and plain-text delimiters exist
    final multiColCount = tableRows.where((r) => r.length > 1).length;
    if (multiColCount == 0) {
      final fallback = _extractFromPlainText(result.fullText);
      if (!fallback.isEmpty) return fallback;
    }

    return ExtractedTable(tableRows);
  }

  static ExtractedTable _extractFromPlainText(String fullText) {
    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final parsed = <List<String>>[];
    for (final line in lines) {
      final parts = line
          .split(RegExp(r'\t+|\s{2,}|\|'))
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        parsed.add(parts);
      }
    }
    return ExtractedTable(parsed);
  }
}

/// Service for on-device multi-script OCR text extraction:
/// - Latin & Devanagari via Google ML Kit Text Recognition
/// - Bengali (`বাংলা`) and Mixed Bengali-English (`ben+eng`) via native Tesseract4Android
///   using Apache-2.0 quantized `tessdata_fast` models + Isolate preprocessing.
class OcrService {
  static OcrService? _instance;
  static OcrService get instance => _instance ??= OcrService._();
  OcrService._();

  static const MethodChannel _tesseractChannel = MethodChannel(
    'com.scaneliq.scaneliq/tesseract',
  );

  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  /// Optional test hook allowing automated unit tests to verify Bengali/mixed OCR
  /// preprocessing, post-processing, and PDF integration without Android JNI.
  @visibleForTesting
  Future<PageOcrResult> Function(File processedImage, OcrScript script)?
  nativeTesseractOverrideForTesting;

  TextRecognizer _getRecognizer(TextRecognitionScript script) {
    return _recognizers.putIfAbsent(
      script,
      () => TextRecognizer(script: script),
    );
  }

  /// Checks whether bundled native Bengali/English tessdata models are ready on Android.
  Future<Map<String, bool>> checkOfflineModelsReady() async {
    try {
      final res = await _tesseractChannel.invokeMapMethod<String, bool>(
        'checkModelsReady',
      );
      return res ?? const {'ben': false, 'eng': false};
    } catch (_) {
      return const {'ben': false, 'eng': false};
    }
  }

  /// Performs OCR on an image file and returns full recognized text.
  Future<String> extractText(
    File imageFile, {
    OcrScript script = OcrScript.latin,
    bool enhanceForOcr = true,
  }) async {
    final result = await extractPageOcr(
      imageFile,
      script: script,
      enhanceForOcr: enhanceForOcr,
    );
    return result.fullText;
  }

  /// Performs full OCR and returns line bounding boxes along with text.
  Future<PageOcrResult> extractPageOcr(
    File imageFile, {
    OcrScript script = OcrScript.latin,
    bool enhanceForOcr = true,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    if (script == OcrScript.bengali ||
        script == OcrScript.mixedBengaliEnglish) {
      return _extractWithTesseract(
        imageFile,
        script: script,
        enhanceForOcr: enhanceForOcr,
      );
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final targetScript = script == OcrScript.devanagari
          ? TextRecognitionScript.devanagiri
          : TextRecognitionScript.latin;

      final recognizer = _getRecognizer(targetScript);
      final RecognizedText recognizedText = await recognizer.processImage(
        inputImage,
      );

      final List<OcrBoundingBox> boxes = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            boxes.add(
              OcrBoundingBox(
                text: line.text.replaceAll('\r\n', '\n').trim(),
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                width: line.boundingBox.width,
                height: line.boundingBox.height,
              ),
            );
          }
        }
      }

      return PageOcrResult(
        fullText: recognizedText.text.replaceAll('\r\n', '\n').trim(),
        boxes: boxes,
        script: script,
        engine: 'mlkit:${targetScript.name}',
      );
    } catch (_) {
      return PageOcrResult(fullText: '', boxes: [], script: script);
    }
  }

  Future<PageOcrResult> _extractWithTesseract(
    File imageFile, {
    required OcrScript script,
    required bool enhanceForOcr,
  }) async {
    File? tempProcessedFile;
    try {
      File workingFile = imageFile;
      if (enhanceForOcr) {
        tempProcessedFile = await preparePreprocessedOcrImage(imageFile);
        workingFile = tempProcessedFile;
      }

      if (nativeTesseractOverrideForTesting != null) {
        final raw = await nativeTesseractOverrideForTesting!(workingFile, script);
        final normalizedFull = normalizeBanglaNumerals(raw.fullText);
        final normalizedBoxes = raw.boxes
            .map(
              (b) => OcrBoundingBox(
                text: normalizeBanglaNumerals(b.text),
                left: b.left,
                top: b.top,
                width: b.width,
                height: b.height,
              ),
            )
            .toList();
        return PageOcrResult(
          fullText: normalizedFull,
          boxes: normalizedBoxes,
          script: script,
          engine: raw.engine,
        );
      }

      final lang = script == OcrScript.mixedBengaliEnglish ? 'ben+eng' : 'ben';
      final response = await _tesseractChannel.invokeMapMethod<String, dynamic>(
        'extractText',
        {'imagePath': workingFile.path, 'lang': lang},
      );

      if (response == null) {
        return PageOcrResult(
          fullText: '',
          boxes: [],
          script: script,
          engine: 'tesseract4android:$lang',
        );
      }

      final rawFull = response['fullText'] as String? ?? '';
      final normalizedFull = normalizeBanglaNumerals(rawFull);

      final rawBoxes = (response['boxes'] as List?) ?? const [];
      final boxes = <OcrBoundingBox>[];
      for (final entry in rawBoxes) {
        if (entry is! Map) continue;
        final text = normalizeBanglaNumerals(
          entry['text']?.toString() ?? '',
        );
        if (text.trim().isEmpty) continue;
        boxes.add(
          OcrBoundingBox(
            text: text,
            left: (entry['left'] as num?)?.toDouble() ?? 0.0,
            top: (entry['top'] as num?)?.toDouble() ?? 0.0,
            width: (entry['width'] as num?)?.toDouble() ?? 0.0,
            height: (entry['height'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }

      return PageOcrResult(
        fullText: normalizedFull,
        boxes: boxes,
        script: script,
        engine: response['engine']?.toString() ?? 'tesseract4android:$lang',
      );
    } on PlatformException catch (e) {
      debugPrint('Tesseract OCR error: ${e.message}');
      return PageOcrResult(
        fullText: '',
        boxes: [],
        script: script,
        engine: 'tesseract_error',
      );
    } on MissingPluginException {
      return PageOcrResult(
        fullText: '',
        boxes: [],
        script: script,
        engine: 'tesseract_unavailable_host',
      );
    } finally {
      if (tempProcessedFile != null && await tempProcessedFile.exists()) {
        try {
          await tempProcessedFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Prepares a high-contrast grayscale/Sauvola document bitmap in a background isolate
  /// for significantly cleaner Bengali matra/juktakkhor segmentation in Tesseract.
  static Future<File> preparePreprocessedOcrImage(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final processedBytes = await Isolate.run(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      // Apply clean document contrast stretch + adaptive enhancement
      final enhanced = ImageProcessingService.applyEditRecipe(
        decoded,
        const EditRecipe(filter: PageFilter.enhancedText, contrast: 1.15),
      );
      return Uint8List.fromList(img.encodePng(enhanced));
    });

    final tempDir = AppStorageService.instance.tempDir;
    await tempDir.create(recursive: true);
    final outFile = File(
      '${tempDir.path}/ocr_pre_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await outFile.writeAsBytes(processedBytes, flush: true);
    return outFile;
  }

  /// Exports extracted OCR text cleanly to a `.txt` or `.csv` file in the exports sandbox.
  Future<File> exportTextFile({
    required String content,
    required String baseName,
    String extension = 'txt',
  }) async {
    final exportsDir = AppStorageService.instance.exportsDir;
    await exportsDir.create(recursive: true);
    final cleanBase = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeBase = cleanBase.isEmpty ? 'Scaneliq_OCR' : cleanBase;
    final outFile = File('${exportsDir.path}/${safeBase}_ocr.$extension');
    final tmpFile = File('${outFile.path}.tmp');
    await tmpFile.writeAsString(content, flush: true);
    return tmpFile.rename(outFile.path);
  }

  /// Converts English/ASCII digits (0-9) to Bangla digits (০-৯).
  static String convertAsciiToBanglaDigits(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], banglaDigits[i]);
    }
    return result;
  }

  /// Converts Bangla digits (০-৯) to standard ASCII digits (0-9).
  static String convertBanglaToAsciiDigits(String input) {
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < banglaDigits.length; i++) {
      result = result.replaceAll(banglaDigits[i], englishDigits[i]);
    }
    return result;
  }

  /// Normalizes Bengali & mixed OCR text: cleans line breaks, removes stray spaces
  /// before Bengali dari (`।`) / commas, trims per-line noise, and optionally normalizes
  /// Bengali digits (`০-৯`) to ASCII (`0-9`).
  static String normalizeBanglaNumerals(
    String text, {
    bool convertBanglaDigitsToAscii = false,
  }) {
    String normalized = text.replaceAll('\r\n', '\n');
    // Fix common OCR artifacts around Bengali punctuation
    normalized = normalized.replaceAll(RegExp(r'[ \t]+।'), '।');
    normalized = normalized.replaceAll(RegExp(r'\|(?=\s|$)'), '।');
    normalized = normalized.replaceAll(RegExp(r'[ \t]+([,;:])'), r'$1');
    // Collapse multiple spaces inside lines without losing newlines
    normalized = normalized
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim())
        .join('\n')
        .trim();

    if (convertBanglaDigitsToAscii) {
      normalized = convertBanglaToAsciiDigits(normalized);
    }
    return normalized;
  }

  /// Detects whether text contains Bengali or Devanagari Unicode codepoints.
  static bool containsBanglaOrIndic(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0980 && rune <= 0x09FF) ||
          (rune >= 0x0900 && rune <= 0x097F)) {
        return true;
      }
    }
    return false;
  }

  /// Detects whether text specifically contains Bengali (`U+0980..U+09FF`) codepoints.
  static bool containsBengali(String text) {
    for (final rune in text.runes) {
      if (rune >= 0x0980 && rune <= 0x09FF) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.close();
    }
    _recognizers.clear();
  }
}

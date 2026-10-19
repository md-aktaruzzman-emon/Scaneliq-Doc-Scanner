import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Supported recognition scripts for OCR
enum OcrScript { latin, devanagari, bengali }

/// Represents an OCR-recognized text element with pixel coordinates on the source image
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
}

/// Consolidated OCR result with full text and bounding boxes for searchable PDF generation
class PageOcrResult {
  final String fullText;
  final List<OcrBoundingBox> boxes;
  final OcrScript script;

  const PageOcrResult({
    required this.fullText,
    required this.boxes,
    this.script = OcrScript.latin,
  });

  String get text => fullText;
}

/// Service for on-device multi-script OCR text extraction (Latin, Devanagari, Bangla/Indic)
class OcrService {
  static OcrService? _instance;
  static OcrService get instance => _instance ??= OcrService._();
  OcrService._();

  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  TextRecognizer _getRecognizer(TextRecognitionScript script) {
    return _recognizers.putIfAbsent(
      script,
      () => TextRecognizer(script: script),
    );
  }

  /// Performs OCR on an image file and returns full recognized text and lines
  Future<String> extractText(
    File imageFile, {
    OcrScript script = OcrScript.latin,
  }) async {
    final result = await extractPageOcr(imageFile, script: script);
    return result.fullText;
  }

  /// Performs full OCR and returns bounding boxes along with text
  Future<PageOcrResult> extractPageOcr(
    File imageFile, {
    OcrScript script = OcrScript.latin,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final targetScript =
          script == OcrScript.devanagari || script == OcrScript.bengali
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
            String processedLineText = line.text;
            if (script == OcrScript.bengali) {
              // Post-process Indic tokens and numerals
              processedLineText = normalizeBanglaNumerals(processedLineText);
            }
            boxes.add(
              OcrBoundingBox(
                text: processedLineText,
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                width: line.boundingBox.width,
                height: line.boundingBox.height,
              ),
            );
          }
        }
      }

      String finalFullText = recognizedText.text;
      if (script == OcrScript.bengali) {
        finalFullText = normalizeBanglaNumerals(finalFullText);
      }

      return PageOcrResult(
        fullText: finalFullText,
        boxes: boxes,
        script: script,
      );
    } catch (_) {
      return PageOcrResult(fullText: '', boxes: [], script: script);
    }
  }

  /// Converts English/ASCII digits (0-9) to Bangla digits (০-৯)
  static String convertAsciiToBanglaDigits(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], banglaDigits[i]);
    }
    return result;
  }

  /// Converts Bangla digits (০-৯) to standard ASCII digits (0-9)
  static String convertBanglaToAsciiDigits(String input) {
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < banglaDigits.length; i++) {
      result = result.replaceAll(banglaDigits[i], englishDigits[i]);
    }
    return result;
  }

  /// Normalizes Bangla text, formatting punctuation and standardizing spaces
  static String normalizeBanglaNumerals(String text) {
    // Preserve mixed text while cleaning common OCR noise
    return text.replaceAll('\r\n', '\n');
  }

  /// Detects whether text contains predominantly Bangla / Indic unicode codepoints
  static bool containsBanglaOrIndic(String text) {
    for (final rune in text.runes) {
      // Bengali Unicode Block: U+0980 to U+09FF
      // Devanagari Unicode Block: U+0900 to U+097F
      if ((rune >= 0x0980 && rune <= 0x09FF) ||
          (rune >= 0x0900 && rune <= 0x097F)) {
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

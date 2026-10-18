import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  const PageOcrResult({
    required this.fullText,
    required this.boxes,
  });

  String get text => fullText;
}

/// Service for on-device OCR text extraction using ML Kit
class OcrService {
  static OcrService? _instance;
  static OcrService get instance => _instance ??= OcrService._();
  OcrService._();

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Performs OCR on an image file and returns full recognized text and lines
  Future<String> extractText(File imageFile) async {
    final result = await extractPageOcr(imageFile);
    return result.fullText;
  }

  /// Performs full OCR and returns bounding boxes along with text
  Future<PageOcrResult> extractPageOcr(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _recognizer.processImage(
        inputImage,
      );

      final List<OcrBoundingBox> boxes = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            boxes.add(
              OcrBoundingBox(
                text: line.text,
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
        fullText: recognizedText.text,
        boxes: boxes,
      );
    } catch (_) {
      return const PageOcrResult(fullText: '', boxes: []);
    }
  }

  void dispose() {
    _recognizer.close();
  }
}


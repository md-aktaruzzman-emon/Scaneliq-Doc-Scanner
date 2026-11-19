import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:translator/translator.dart';

class TranslationOutcome {
  final String translatedText;
  final String resolvedSourceLang;
  final String targetLang;
  final bool usedOfflineModel;

  const TranslationOutcome({
    required this.translatedText,
    required this.resolvedSourceLang,
    required this.targetLang,
    required this.usedOfflineModel,
  });
}

/// Manages genuine on-device offline translation via `google_mlkit_translation`
/// with explicit opt-in online fallback and `.txt` / Unicode `.pdf` export.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const Map<String, TranslateLanguage> _mlKitMap = {
    'en': TranslateLanguage.english,
    'bn': TranslateLanguage.bengali,
    'es': TranslateLanguage.spanish,
    'fr': TranslateLanguage.french,
    'de': TranslateLanguage.german,
    'ar': TranslateLanguage.arabic,
    'hi': TranslateLanguage.hindi,
    'zh-cn': TranslateLanguage.chinese,
  };

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  final GoogleTranslator _onlineTranslator = GoogleTranslator();

  /// Optional test override for verifying offline/online routing cleanly in VM tests.
  @visibleForTesting
  Future<TranslationOutcome> Function(
    String text,
    String sourceLang,
    String targetLang,
    bool preferOffline,
  )?
  translatorOverrideForTesting;

  static TranslateLanguage? resolveMlKitLanguage(String code) =>
      _mlKitMap[code.toLowerCase()];

  /// Detects likely source script when set to `'auto'`.
  static String inferSourceLanguage(String text, {String requested = 'auto'}) {
    if (requested != 'auto') return requested;
    if (OcrService.containsBengali(text)) return 'bn';
    for (final r in text.runes) {
      if (r >= 0x0900 && r <= 0x097F) return 'hi';
      if (r >= 0x0600 && r <= 0x06FF) return 'ar';
      if (r >= 0x4E00 && r <= 0x9FFF) return 'zh-cn';
    }
    return 'en';
  }

  Future<bool> isOfflineModelDownloaded(String langCode) async {
    final mlLang = resolveMlKitLanguage(langCode);
    if (mlLang == null) return false;
    try {
      return await _modelManager.isModelDownloaded(mlLang.bcpCode);
    } catch (_) {
      return false;
    }
  }

  Future<bool> downloadOfflineModel(String langCode) async {
    final mlLang = resolveMlKitLanguage(langCode);
    if (mlLang == null) return false;
    try {
      return await _modelManager.downloadModel(mlLang.bcpCode);
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteOfflineModel(String langCode) async {
    final mlLang = resolveMlKitLanguage(langCode);
    if (mlLang == null) return false;
    try {
      return await _modelManager.deleteModel(mlLang.bcpCode);
    } catch (_) {
      return false;
    }
  }

  Future<bool> arePairModelsReady(String sourceCode, String targetCode) async {
    if (sourceCode == 'auto') return false;
    final srcReady = await isOfflineModelDownloaded(sourceCode);
    final dstReady = await isOfflineModelDownloaded(targetCode);
    return srcReady && dstReady;
  }

  /// Translates [text] offline via ML Kit when downloadable models exist;
  /// optionally falls back to online `GoogleTranslator` ONLY if [allowOnlineFallback] is true.
  Future<TranslationOutcome> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    bool preferOffline = true,
    bool allowOnlineFallback = false,
  }) async {
    final resolvedSource = inferSourceLanguage(text, requested: sourceLang);

    if (translatorOverrideForTesting != null) {
      return translatorOverrideForTesting!(
        text,
        resolvedSource,
        targetLang,
        preferOffline,
      );
    }

    if (resolvedSource == targetLang) {
      return TranslationOutcome(
        translatedText: text,
        resolvedSourceLang: resolvedSource,
        targetLang: targetLang,
        usedOfflineModel: true,
      );
    }

    final srcMl = resolveMlKitLanguage(resolvedSource);
    final dstMl = resolveMlKitLanguage(targetLang);

    if (preferOffline && srcMl != null && dstMl != null) {
      final pairReady = await arePairModelsReady(resolvedSource, targetLang);
      if (pairReady) {
        final translator = OnDeviceTranslator(
          sourceLanguage: srcMl,
          targetLanguage: dstMl,
        );
        try {
          final result = await translator.translateText(text);
          return TranslationOutcome(
            translatedText: result,
            resolvedSourceLang: resolvedSource,
            targetLang: targetLang,
            usedOfflineModel: true,
          );
        } finally {
          await translator.close();
        }
      }
    }

    if (!allowOnlineFallback) {
      throw StateError(
        'Offline model not downloaded for $resolvedSource -> $targetLang. '
        'Download the offline pack or approve online translation.',
      );
    }

    final onlineRes = await _onlineTranslator.translate(
      text,
      from: sourceLang,
      to: targetLang,
    );
    return TranslationOutcome(
      translatedText: onlineRes.text,
      resolvedSourceLang: onlineRes.sourceLanguage.code,
      targetLang: targetLang,
      usedOfflineModel: false,
    );
  }

  /// Exports translated text to `.txt` inside app exports directory.
  Future<File> exportAsText({
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) async {
    final dir = AppStorageService.instance.exportsDir;
    await dir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outFile = File(
      '${dir.path}/Translation_${sourceLang}_${targetLang}_$ts.txt',
    );
    final tmpFile = File('${outFile.path}.tmp');
    final body =
        'SOURCE ($sourceLang):\n$sourceText\n\n---\nTRANSLATED ($targetLang):\n$translatedText\n';
    await tmpFile.writeAsString(body, flush: true);
    return tmpFile.rename(outFile.path);
  }

  /// Exports translated document cleanly as a UTF-8 A4 PDF supporting Bengali and Latin text.
  Future<File> exportAsPdf({
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) async {
    pw.Font? unicodeFont;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
      unicodeFont = pw.Font.ttf(data);
    } catch (_) {
      final f = File('assets/fonts/NotoSansBengali-Regular.ttf');
      if (await f.exists()) {
        unicodeFont = pw.Font.ttf(ByteData.sublistView(await f.readAsBytes()));
      }
    }

    final pdf = pw.Document(
      title: 'Scaneliq Translation ($sourceLang -> $targetLang)',
      author: 'Scaneliq',
    );
    final baseStyle = pw.TextStyle(font: unicodeFont, fontSize: 12, height: 1.5);
    final headingStyle = pw.TextStyle(
      font: unicodeFont,
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text('Translated Document ($targetLang)', style: headingStyle),
          pw.SizedBox(height: 12),
          pw.Paragraph(text: translatedText, style: baseStyle),
          if (sourceText.trim().isNotEmpty) ...[
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('Original Source ($sourceLang)', style: headingStyle),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: sourceText, style: baseStyle),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = AppStorageService.instance.exportsDir;
    await dir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outFile = File(
      '${dir.path}/Translation_${sourceLang}_${targetLang}_$ts.pdf',
    );
    final tmp = File('${outFile.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp.rename(outFile.path);
  }
}

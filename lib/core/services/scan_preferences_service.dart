import 'package:flutter/foundation.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/services/smart_filename_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PdfQualityPreset { compact150, balanced200, high300 }

enum PdfPageFormatOption { a4, letter }

extension PdfQualityPresetMeta on PdfQualityPreset {
  String get label => switch (this) {
    PdfQualityPreset.compact150 => 'Compact (150 DPI)',
    PdfQualityPreset.balanced200 => 'Balanced (200 DPI)',
    PdfQualityPreset.high300 => 'High HD (300 DPI)',
  };

  String get shortName => switch (this) {
    PdfQualityPreset.compact150 => '150 DPI',
    PdfQualityPreset.balanced200 => '200 DPI',
    PdfQualityPreset.high300 => '300 DPI',
  };

  int get jpegQuality => switch (this) {
    PdfQualityPreset.compact150 => 65,
    PdfQualityPreset.balanced200 => 85,
    PdfQualityPreset.high300 => 94,
  };

  int get maxEdgePx => switch (this) {
    PdfQualityPreset.compact150 => 1754, // ~150 DPI A4 long edge
    PdfQualityPreset.balanced200 => 2338, // ~200 DPI A4 long edge
    PdfQualityPreset.high300 => 3508, // ~300 DPI A4 long edge
  };
}

extension PdfPageFormatMeta on PdfPageFormatOption {
  String get label => switch (this) {
    PdfPageFormatOption.a4 => 'ISO A4 (210 × 297 mm)',
    PdfPageFormatOption.letter => 'US Letter (8.5 × 11 in)',
  };

  String get shortBadge => switch (this) {
    PdfPageFormatOption.a4 => 'ISO A4',
    PdfPageFormatOption.letter => 'LETTER',
  };
}

/// Persistent user preferences for scan defaults, smart naming, OCR script,
/// and PDF export presets (shared across Camera, Review, Viewer & Settings).
class ScanPreferencesService {
  ScanPreferencesService._();
  static final ScanPreferencesService instance = ScanPreferencesService._();

  static const String _prefQuality = 'scan_pref_pdf_quality';
  static const String _prefPageFormat = 'scan_pref_page_format';
  static const String _prefOcrScript = 'scan_pref_ocr_script';
  static const String _prefAutoOcr = 'scan_pref_auto_embed_ocr';
  static const String _prefFilenameTemplate = 'scan_pref_filename_template';
  static const String _prefDefaultFilter = 'scan_pref_default_filter';

  SharedPreferences? _prefsOverride;
  bool _initialized = false;

  PdfQualityPreset _qualityPreset = PdfQualityPreset.balanced200;
  PdfPageFormatOption _pageFormat = PdfPageFormatOption.a4;
  OcrScript _defaultOcrScript = OcrScript.latin;
  bool _autoEmbedSearchableOcr = true;
  String _smartFilenameTemplate = SmartFilenameService.defaultTemplate;
  PageFilter _defaultFilter = PageFilter.original;

  PdfQualityPreset get qualityPreset => _qualityPreset;
  PdfPageFormatOption get pageFormat => _pageFormat;
  OcrScript get defaultOcrScript => _defaultOcrScript;
  bool get autoEmbedSearchableOcr => _autoEmbedSearchableOcr;
  String get smartFilenameTemplate => _smartFilenameTemplate;
  PageFilter get defaultFilter => _defaultFilter;

  @visibleForTesting
  void setPreferencesForTesting(SharedPreferences prefs) {
    _prefsOverride = prefs;
    _initialized = false;
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<void> init() async {
    final prefs = await _getPrefs();
    _qualityPreset = PdfQualityPreset.values.firstWhere(
      (v) => v.name == prefs.getString(_prefQuality),
      orElse: () => PdfQualityPreset.balanced200,
    );
    _pageFormat = PdfPageFormatOption.values.firstWhere(
      (v) => v.name == prefs.getString(_prefPageFormat),
      orElse: () => PdfPageFormatOption.a4,
    );
    _defaultOcrScript = OcrScript.values.firstWhere(
      (v) => v.name == prefs.getString(_prefOcrScript),
      orElse: () => OcrScript.latin,
    );
    _autoEmbedSearchableOcr = prefs.getBool(_prefAutoOcr) ?? true;
    final savedTpl = prefs.getString(_prefFilenameTemplate);
    _smartFilenameTemplate = (savedTpl != null && savedTpl.trim().isNotEmpty)
        ? savedTpl
        : SmartFilenameService.defaultTemplate;
    _defaultFilter = PageFilter.values.firstWhere(
      (v) => v.name == prefs.getString(_prefDefaultFilter),
      orElse: () => PageFilter.original,
    );
    _initialized = true;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> setQualityPreset(PdfQualityPreset preset) async {
    _qualityPreset = preset;
    final prefs = await _getPrefs();
    await prefs.setString(_prefQuality, preset.name);
  }

  Future<void> setPageFormat(PdfPageFormatOption format) async {
    _pageFormat = format;
    final prefs = await _getPrefs();
    await prefs.setString(_prefPageFormat, format.name);
  }

  Future<void> setDefaultOcrScript(OcrScript script) async {
    _defaultOcrScript = script;
    final prefs = await _getPrefs();
    await prefs.setString(_prefOcrScript, script.name);
  }

  Future<void> setAutoEmbedSearchableOcr(bool enabled) async {
    _autoEmbedSearchableOcr = enabled;
    final prefs = await _getPrefs();
    await prefs.setBool(_prefAutoOcr, enabled);
  }

  Future<void> setSmartFilenameTemplate(String template) async {
    final clean = template.trim().isEmpty
        ? SmartFilenameService.defaultTemplate
        : template.trim();
    _smartFilenameTemplate = clean;
    final prefs = await _getPrefs();
    await prefs.setString(_prefFilenameTemplate, clean);
  }

  Future<void> setDefaultFilter(PageFilter filter) async {
    _defaultFilter = filter;
    final prefs = await _getPrefs();
    await prefs.setString(_prefDefaultFilter, filter.name);
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/scanner/data/translation_service.dart';
import 'package:share_plus/share_plus.dart';

class TranslateScreen extends StatefulWidget {
  final String? initialText;

  const TranslateScreen({super.key, this.initialText});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _sourceTextController = TextEditingController();
  final TextEditingController _translatedTextController =
      TextEditingController();

  String _sourceLang = 'auto';
  String _targetLang = 'bn';
  bool _isOcrExtracting = false;
  bool _isTranslating = false;
  bool _isDownloadingModel = false;
  bool _onlineConsentGranted = false;
  bool? _lastUsedOffline;
  bool _enModelReady = false;
  bool _bnModelReady = false;

  final Map<String, String> _languages = {
    'auto': 'Auto Detect',
    'en': 'English',
    'bn': 'Bengali (বাংলা)',
    'es': 'Spanish (Español)',
    'fr': 'French (Français)',
    'de': 'German (Deutsch)',
    'ar': 'Arabic (العربية)',
    'hi': 'Hindi (हिन्दी)',
    'zh-cn': 'Chinese (Simplified)',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _sourceTextController.text = widget.initialText!;
    }
    _refreshModelStatus();
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    _translatedTextController.dispose();
    super.dispose();
  }

  Future<void> _refreshModelStatus() async {
    final en = await TranslationService.instance.isOfflineModelDownloaded('en');
    final bn = await TranslationService.instance.isOfflineModelDownloaded('bn');
    if (mounted) {
      setState(() {
        _enModelReady = en;
        _bnModelReady = bn;
      });
    }
  }

  Future<void> _downloadEnBnPacks() async {
    setState(() => _isDownloadingModel = true);
    try {
      final enOk = await TranslationService.instance.downloadOfflineModel('en');
      final bnOk = await TranslationService.instance.downloadOfflineModel('bn');
      await _refreshModelStatus();
      if (mounted) {
        showScaneliqToast(
          context,
          (enOk && bnOk)
              ? 'Offline English & Bengali packs ready.'
              : 'Model download requires internet connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingModel = false);
    }
  }

  Future<void> _pickImagesAndExtractOcr() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      final paths = result.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty) return;

      setState(() => _isOcrExtracting = true);
      final OcrScript script = (_sourceLang == 'bn' || _sourceLang == 'auto')
          ? OcrScript.mixedBengaliEnglish
          : OcrScript.latin;

      final buffer = StringBuffer();
      for (final path in paths) {
        final txt = await OcrService.instance.extractText(
          File(path),
          script: script,
        );
        if (txt.trim().isNotEmpty) {
          buffer.writeln(txt.trim());
        }
      }

      if (!mounted) return;
      setState(() {
        _isOcrExtracting = false;
        _sourceTextController.text = buffer.toString().trim();
      });

      if (_sourceTextController.text.isNotEmpty) {
        await _translate();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOcrExtracting = false);
        showScaneliqToast(context, 'OCR extraction failed: $e');
      }
    }
  }

  Future<void> _translate() async {
    final text = _sourceTextController.text.trim();
    if (text.isEmpty) {
      showScaneliqToast(context, 'Enter text or import scanned pages first.');
      return;
    }

    final inferredSource = TranslationService.inferSourceLanguage(
      text,
      requested: _sourceLang,
    );
    final offlineReady = await TranslationService.instance.arePairModelsReady(
      inferredSource,
      _targetLang,
    );

    if (!offlineReady && !_onlineConsentGranted) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Offline Model Not Downloaded'),
          content: Text(
            'Offline translation pack ($inferredSource ↔ $_targetLang) is not downloaded yet.\n\n'
            'You can download offline ML Kit packs (~30 MB, stays 100% on-device) or allow online Google Translate for this session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'download'),
              child: const Text('Download Offline Packs'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'online'),
              child: const Text('Allow Online'),
            ),
          ],
        ),
      );
      if (choice == 'download') {
        await _downloadEnBnPacks();
        return;
      }
      if (choice != 'online') return;
      _onlineConsentGranted = true;
    }

    setState(() => _isTranslating = true);
    try {
      final outcome = await TranslationService.instance.translate(
        text: text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        preferOffline: true,
        allowOnlineFallback: _onlineConsentGranted,
      );
      if (mounted) {
        setState(() {
          _translatedTextController.text = outcome.translatedText;
          _lastUsedOffline = outcome.usedOfflineModel;
        });
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'Translation error: $e');
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _swapLanguages() {
    if (_sourceLang == 'auto') return;
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      final textTemp = _sourceTextController.text;
      _sourceTextController.text = _translatedTextController.text;
      _translatedTextController.text = textTemp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: const Text('Document & OCR Translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Import scanned pages',
            onPressed: _isOcrExtracting ? null : _pickImagesAndExtractOcr,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Offline Model Status Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_pin_outlined, color: tokens.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline Language Packs', style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'English: ${_enModelReady ? 'Ready' : 'Not downloaded'} · Bengali: ${_bnModelReady ? 'Ready' : 'Not downloaded'}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isDownloadingModel ? null : _downloadEnBnPacks,
                  child: Text(
                    _isDownloadingModel
                        ? 'Downloading…'
                        : (_enModelReady && _bnModelReady)
                        ? 'Verified'
                        : 'Download',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Language selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _sourceLang,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _languages.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sourceLang = val);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: _sourceLang == 'auto' ? null : _swapLanguages,
                ),
                Expanded(
                  child: DropdownButton<String>(
                    value: _targetLang,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _languages.entries
                        .where((e) => e.key != 'auto')
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _targetLang = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Source Text Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Original Document Text', style: textTheme.titleMedium),
                    if (_isOcrExtracting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Scan / Import Pages'),
                        onPressed: _pickImagesAndExtractOcr,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sourceTextController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Type, paste, or import document images (En / বাংলা)...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isTranslating ? null : _translate,
                    icon: _isTranslating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.translate_rounded),
                    label: const Text('Translate'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Translated Output & Exports
          if (_translatedTextController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Translation (${_languages[_targetLang]})',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (_lastUsedOffline != null)
                        ScaneliqStatusLabel(
                          text: _lastUsedOffline! ? 'OFFLINE ML KIT' : 'ONLINE',
                          tone: _lastUsedOffline!
                              ? ScaneliqStatusTone.success
                              : ScaneliqStatusTone.warning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _translatedTextController.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _translatedTextController.text),
                          );
                          showScaneliqToast(context, 'Copied translation.');
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Save .TXT'),
                        onPressed: () async {
                          final f = await TranslationService.instance
                              .exportAsText(
                                sourceText: _sourceTextController.text,
                                translatedText: _translatedTextController.text,
                                sourceLang: _sourceLang,
                                targetLang: _targetLang,
                              );
                          if (context.mounted) {
                            showScaneliqToast(
                              context,
                              'Saved ${f.path.split(Platform.pathSeparator).last}',
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('Export PDF'),
                        onPressed: () async {
                          final f = await TranslationService.instance
                              .exportAsPdf(
                                sourceText: _sourceTextController.text,
                                translatedText: _translatedTextController.text,
                                sourceLang: _sourceLang,
                                targetLang: _targetLang,
                              );
                          if (context.mounted) {
                            SharePlus.instance.share(
                              ShareParams(
                                text: 'Translated Document',
                                files: [XFile(f.path)],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

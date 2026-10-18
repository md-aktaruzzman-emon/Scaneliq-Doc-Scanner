import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final GoogleTranslator _translator = GoogleTranslator();
  final TextEditingController _sourceTextController = TextEditingController();
  final TextEditingController _translatedTextController = TextEditingController();

  String _sourceLang = 'auto';
  String _targetLang = 'bn'; // Default to Bengali
  bool _isOcrExtracting = false;
  bool _isTranslating = false;
  bool _privacyDisclosed = false;

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
  void dispose() {
    _sourceTextController.dispose();
    _translatedTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndExtractOcr() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        setState(() {
          _isOcrExtracting = true;
        });

        final extracted = await OcrService.instance.extractText(file);
        setState(() {
          _isOcrExtracting = false;
          _sourceTextController.text = extracted.trim();
        });

        if (extracted.trim().isNotEmpty) {
          // Trigger instant translation
          await _translate();
        }
      }
    } catch (e) {
      setState(() {
        _isOcrExtracting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR extraction failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _translate() async {
    final text = _sourceTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or scan some text first.')),
      );
      return;
    }

    if (!_privacyDisclosed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: AppColors.brandPrimary),
              SizedBox(width: 8),
              Text('Translation Privacy Notice'),
            ],
          ),
          content: const Text(
            'Online translation transmits the selected document text securely to Google Translate servers. '
            'Scaneliq does not track, store, or sell your documents.\n\n'
            'Do you wish to proceed with online translation?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
      _privacyDisclosed = true;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final translation = await _translator.translate(
        text,
        from: _sourceLang,
        to: _targetLang,
      );

      setState(() {
        _translatedTextController.text = translation.text;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _swapLanguages() {
    if (_sourceLang == 'auto') return; // Cannot translate into 'auto'
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document & OCR Translator', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Extract from Image',
            onPressed: _isOcrExtracting ? null : _pickImageAndExtractOcr,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language selector bar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<String>(
                    value: _sourceLang,
                    underline: const SizedBox(),
                    items: _languages.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sourceLang = val);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: _sourceLang == 'auto' ? null : _swapLanguages,
                  ),
                  DropdownButton<String>(
                    value: _targetLang,
                    underline: const SizedBox(),
                    items: _languages.entries
                        .where((e) => e.key != 'auto')
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _targetLang = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Source text box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Original Text', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_isOcrExtracting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton.icon(
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Import Image', style: TextStyle(fontSize: 12)),
                          onPressed: _pickImageAndExtractOcr,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sourceTextController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Type or import an image to extract text via OCR...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isTranslating ? null : _translate,
                      icon: _isTranslating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.translate),
                      label: const Text('Translate'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Translated text box
          if (_translatedTextController.text.isNotEmpty || _isTranslating)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Translated Text (${_languages[_targetLang]})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _translatedTextController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied translation!')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, size: 18),
                              tooltip: 'Share',
                              onPressed: () {
                                SharePlus.instance.share(ShareParams(text: _translatedTextController.text));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _translatedTextController.text,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/intelligence/data/ai_document_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

class AiDocumentSheet extends StatefulWidget {
  final String? initialText;
  final File? initialImage;

  const AiDocumentSheet({super.key, this.initialText, this.initialImage});

  static Future<void> show(
    BuildContext context, {
    String? text,
    File? imageFile,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AiDocumentSheet(initialText: text, initialImage: imageFile),
    );
  }

  @override
  State<AiDocumentSheet> createState() => _AiDocumentSheetState();
}

class _AiDocumentSheetState extends State<AiDocumentSheet> {
  bool _isAnalyzing = false;
  String? _documentText;
  DocumentSummaryResult? _summaryResult;
  final _questionCtrl = TextEditingController();
  DocumentQaResult? _qaResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _analyzeText(widget.initialText!);
    } else if (widget.initialImage != null) {
      _processImage(widget.initialImage!);
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked.isNotEmpty && picked.first.path != null) {
      _processImage(File(picked.first.path!));
    }
  }

  Future<void> _processImage(File file) async {
    setState(() => _isAnalyzing = true);
    try {
      final ocrText = await OcrService.instance.extractText(file);
      _analyzeText(ocrText);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _analyzeText(String text) {
    setState(() {
      _isAnalyzing = true;
      _documentText = text;
    });

    final summary = AiDocumentService.instance.summarize(text);
    setState(() {
      _summaryResult = summary;
      _isAnalyzing = false;
    });
  }

  void _askQuestion() {
    final query = _questionCtrl.text.trim();
    if (query.isEmpty || _documentText == null) return;

    final answer = AiDocumentService.instance.answerQuestion(
      _documentText!,
      query,
    );
    setState(() {
      _qaResult = answer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surface1Dark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Document Assistant & Q&A',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing semantics, scoring sentences & summarizing...',
                  ),
                ],
              ),
            )
          else if (_summaryResult == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Column(
                children: [
                  Icon(
                    Icons.text_snippet_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a document image to generate an AI summary',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Document Image'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  // Topic Chips & Stats
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.analytics_outlined, size: 16),
                        label: Text(
                          '${_summaryResult!.totalWords} words · ${_summaryResult!.totalSentences} sentences',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      ..._summaryResult!.topKeywords.map(
                        (kw) => Chip(
                          backgroundColor: const Color(0xFF6366F1)
                              .withValues(alpha: 0.1),
                          label: Text(
                            kw,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Executive Summary Card
                  const Text(
                    'Executive Key Points',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._summaryResult!.bulletPoints.map(
                    (point) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              point,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Semantic Q&A Section
                  const Text(
                    'Ask Document a Question (Offline Semantic Search)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. What is the deadline or amount?',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _askQuestion(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _askQuestion,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),

                  if (_qaResult != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6366F1)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Matched Passage',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(_qaResult!.confidence * 100).toInt()}% Match',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _qaResult!.bestAnswer,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Analyze Another Document'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

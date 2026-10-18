import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  final ScannedDocument document;

  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isExtractingText = false;
  String? _extractedText;

  void _shareDocument() {
    if (widget.document.exportPath != null && File(widget.document.exportPath!).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          text: widget.document.title,
          files: [XFile(widget.document.exportPath!)],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF file is not found on device.')),
      );
    }
  }

  void _runOcr() async {
    if (widget.document.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages available for OCR.')),
      );
      return;
    }

    setState(() {
      _isExtractingText = true;
    });

    try {
      final buffer = StringBuffer();
      for (int i = 0; i < widget.document.pages.length; i++) {
        final page = widget.document.pages[i];
        final imagePath = page.processedPath ?? page.originalPath;
        final file = File(imagePath);
        if (await file.exists()) {
          final text = await OcrService.instance.extractText(file);
          if (text.trim().isNotEmpty) {
            buffer.writeln('--- Page ${i + 1} ---');
            buffer.writeln(text.trim());
            buffer.writeln();
          }
        }
      }

      final fullText = buffer.toString().trim();
      setState(() {
        _isExtractingText = false;
        _extractedText = fullText.isEmpty ? 'No readable text was detected on these pages.' : fullText;
      });

      if (mounted) {
        _showOcrResultModal(_extractedText!);
      }
    } catch (e) {
      setState(() {
        _isExtractingText = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR extraction error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showOcrResultModal(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extracted Text (OCR)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy all text',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfPath = widget.document.exportPath;
    final file = pdfPath != null ? File(pdfPath) : null;
    final fileExists = file != null && file.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: _isExtractingText
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.text_snippet_outlined),
            tooltip: 'Extract Text (OCR)',
            onPressed: _isExtractingText ? null : _runOcr,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: fileExists
          ? PdfViewer.file(
              file.path,
              params: const PdfViewerParams(
                panAxis: PanAxis.free,
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 64, color: AppColors.textSecondaryLight),
                  const SizedBox(height: 16),
                  const Text('PDF file is missing or has not been exported yet.'),
                  const SizedBox(height: 8),
                  Text(
                    'Original ${widget.document.pageCount} pages are still safely preserved.',
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
    );
  }
}

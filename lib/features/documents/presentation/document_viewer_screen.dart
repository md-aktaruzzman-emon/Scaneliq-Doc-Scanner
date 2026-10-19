import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_page_organizer_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  final ScannedDocument document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final PdfViewerController _pdfController;
  late final PdfTextSearcher _textSearcher;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isSearchOpen = false;
  final TextEditingController _searchQueryController = TextEditingController();

  bool _isExtractingText = false;
  String? _extractedText;

  List<DocumentBookmark> _bookmarks = [];
  bool _isLoadingBookmarks = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _textSearcher = PdfTextSearcher(_pdfController)
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchQueryController.dispose();
    _textSearcher.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoadingBookmarks = true);
    try {
      final list = await AppDatabaseService.instance.getBookmarks(
        widget.document.id,
      );
      if (mounted) {
        setState(() {
          _bookmarks = list;
          _isLoadingBookmarks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBookmarks = false);
    }
  }

  Future<String?> _promptPassword(BuildContext ctx) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        title: const Text('Password Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This PDF document is encrypted with password protection:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, controller.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _shareDocument() {
    if (widget.document.exportPath != null &&
        File(widget.document.exportPath!).existsSync()) {
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
        _extractedText = fullText.isEmpty
            ? 'No readable text was detected on these pages.'
            : fullText;
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
                        const SnackBar(
                          content: Text('Text copied to clipboard!'),
                        ),
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

  // ---------------------------------------------------------------------------
  // JUMP TO PAGE
  // ---------------------------------------------------------------------------

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter page number (1 to $_totalPages):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Page Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              if (target != null && target >= 1 && target <= _totalPages) {
                Navigator.pop(ctx);
                _pdfController.goToPage(pageNumber: target);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKMARKS
  // ---------------------------------------------------------------------------

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Page Bookmarks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bookmark_add, size: 18),
                    label: const Text('Bookmark Page'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final titleController = TextEditingController(
                        text: 'Page $_currentPage',
                      );
                      final title = await showDialog<String>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: Text('Bookmark Page $_currentPage'),
                          content: TextField(
                            controller: titleController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Bookmark Label',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, null),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                dCtx,
                                titleController.text.trim(),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );

                      if (title != null && title.isNotEmpty) {
                        await AppDatabaseService.instance.addBookmark(
                          documentId: widget.document.id,
                          pageNumber: _currentPage,
                          title: title,
                        );
                        await _loadBookmarks();
                        setSheetState(() {});
                      }
                    },
                  ),
                ],
              ),
              const Divider(),
              if (_isLoadingBookmarks)
                const Center(child: CircularProgressIndicator())
              else if (_bookmarks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No bookmarks yet.\nTap "Bookmark Page" to save important pages.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final b = _bookmarks[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brandPrimary.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            '${b.pageNumber}',
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Page ${b.pageNumber} · ${b.createdAt.year}-${b.createdAt.month.toString().padLeft(2, '0')}-${b.createdAt.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () async {
                            await AppDatabaseService.instance.deleteBookmark(
                              b.id,
                            );
                            await _loadBookmarks();
                            setSheetState(() {});
                          },
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pdfController.goToPage(pageNumber: b.pageNumber);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // METADATA INSPECTION
  // ---------------------------------------------------------------------------

  Future<void> _showMetadataDialog(File file) async {
    try {
      final info = await AdvancedPdfService.instance.inspectPdf(file);
      if (!mounted) return;

      final sizeMb = (info.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      final sizeKb = (info.fileSizeBytes / 1024).toStringAsFixed(1);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF Document Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Title', info.title ?? widget.document.title),
              _detailRow('Page Count', '${info.pageCount} pages'),
              _detailRow('File Size', '$sizeMb MB ($sizeKb KB)'),
              _detailRow(
                'Page Dimensions',
                '${info.firstPageWidth.toStringAsFixed(0)} × ${info.firstPageHeight.toStringAsFixed(0)} pt',
              ),
              _detailRow('Encrypted', info.isEncrypted ? 'Yes' : 'No'),
              if (info.producer != null) _detailRow('Producer', info.producer!),
              if (info.creationDate != null)
                _detailRow(
                  'Created',
                  '${info.creationDate!.year}-${info.creationDate!.month.toString().padLeft(2, '0')}-${info.creationDate!.day.toString().padLeft(2, '0')}',
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPRESS PDF QUICK ACTION
  // ---------------------------------------------------------------------------

  Future<void> _showCompressDialog(File file) async {
    PdfCompressionPreset selected = PdfCompressionPreset.balanced;

    final confirmed = await showDialog<PdfCompressionPreset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: const Text('Compress PDF Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select target compression level:'),
              RadioGroup<PdfCompressionPreset>(
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selected = val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.highQuality,
                      title: Text('High Quality'),
                      subtitle: Text('Minimal compression (~85% quality)'),
                    ),
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.balanced,
                      title: Text('Balanced (Recommended)'),
                      subtitle: Text('Optimal balance (~65% quality)'),
                    ),
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.smallerFile,
                      title: Text('Smaller File'),
                      subtitle: Text('Maximum size reduction (~45% quality)'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, selected),
              child: const Text('Compress'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compressing PDF document...')),
    );

    try {
      final outName =
          '${widget.document.title}_compressed_${DateTime.now().millisecondsSinceEpoch}';
      final result = await AdvancedPdfService.instance.compressPdf(
        sourcePdf: file,
        preset: confirmed,
        outputFileName: outName,
        associatedDocument: widget.document,
      );

      final origKb = (result.originalSizeBytes / 1024).toStringAsFixed(1);
      final compKb = (result.compressedSizeBytes / 1024).toStringAsFixed(1);
      final pct = result.percentageReduction.toStringAsFixed(1);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Compression Complete'),
            content: Text(
              'Original: $origKb KB\nCompressed: $compKb KB\nSpace Saved: $pct%\n\nSaved to: ${result.outputFile.path}',
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                onPressed: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Compressed PDF',
                      files: [XFile(result.outputFile.path)],
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compression failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // WATERMARK QUICK ACTION
  // ---------------------------------------------------------------------------

  Future<void> _showWatermarkDialog(File file) async {
    final textController = TextEditingController(text: 'CONFIDENTIAL');
    WatermarkPosition pos = WatermarkPosition.diagonalCenter;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: const Text('Apply Watermark'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Watermark Text',
                  hintText: 'e.g. CONFIDENTIAL / DRAFT',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WatermarkPosition>(
                initialValue: pos,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: WatermarkPosition.diagonalCenter,
                    child: Text('Diagonal Center (-45°)'),
                  ),
                  DropdownMenuItem(
                    value: WatermarkPosition.horizontalCenter,
                    child: Text('Horizontal Center'),
                  ),
                  DropdownMenuItem(
                    value: WatermarkPosition.headerTop,
                    child: Text('Header (Top)'),
                  ),
                  DropdownMenuItem(
                    value: WatermarkPosition.footerBottom,
                    child: Text('Footer (Bottom)'),
                  ),
                ],
                onChanged: (val) => setDialogState(() => pos = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final outName =
          '${widget.document.title}_watermarked_${DateTime.now().millisecondsSinceEpoch}';
      final watermarked = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: file,
        options: WatermarkOptions(
          text: textController.text.trim(),
          position: pos,
          color: const Color(0xFFDC2626),
          opacity: 0.25,
        ),
        outputFileName: outName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watermark applied: ${watermarked.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watermark failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PASSWORD PROTECT QUICK ACTION
  // ---------------------------------------------------------------------------

  Future<void> _showEncryptDialog(File file) async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Password Protect PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter password to encrypt with AES-256:'),
            const SizedBox(height: 12),
            TextField(
              controller: pass1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pass1.text != pass2.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match!')),
                );
                return;
              }
              if (pass1.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Password cannot be empty!')),
                );
                return;
              }
              Navigator.pop(ctx, pass1.text.trim());
            },
            child: const Text('Encrypt'),
          ),
        ],
      ),
    );

    if (confirmed == null) return;

    try {
      final outName =
          '${widget.document.title}_protected_${DateTime.now().millisecondsSinceEpoch}';
      final encrypted = await AdvancedPdfService.instance.encryptPdf(
        sourcePdf: file,
        userPassword: confirmed,
        outputFileName: outName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document protected: ${encrypted.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Encryption failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfPath = widget.document.exportPath;
    final file = pdfPath != null ? File(pdfPath) : null;
    final fileExists = file != null && file.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchQueryController,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search text in document...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchQueryController.clear();
                      _textSearcher.resetTextSearch();
                    },
                  ),
                ),
                onSubmitted: (query) {
                  if (query.trim().isNotEmpty) {
                    _textSearcher.startTextSearch(query.trim());
                  }
                },
              )
            : Text(
                widget.document.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_isSearchOpen) ...[
            if (_textSearcher.hasMatches) ...[
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Previous Match',
                onPressed: () => _textSearcher.goToPrevMatch(),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Next Match',
                onPressed: () => _textSearcher.goToNextMatch(),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close Search',
              onPressed: () {
                setState(() => _isSearchOpen = false);
                _searchQueryController.clear();
                _textSearcher.resetTextSearch();
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search in Document',
              onPressed: () => setState(() => _isSearchOpen = true),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Bookmarks',
              onPressed: _showBookmarksSheet,
            ),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Document Tools',
              onSelected: (val) {
                if (file == null) return;
                switch (val) {
                  case 'organize':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfPageOrganizerScreen(
                          pdfFile: file,
                          document: widget.document,
                        ),
                      ),
                    );
                    break;
                  case 'compress':
                    _showCompressDialog(file);
                    break;
                  case 'watermark':
                    _showWatermarkDialog(file);
                    break;
                  case 'encrypt':
                    _showEncryptDialog(file);
                    break;
                  case 'details':
                    _showMetadataDialog(file);
                    break;
                  case 'share':
                    _shareDocument();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'organize',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Organize Pages'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'compress',
                  child: Row(
                    children: [
                      Icon(Icons.compress, size: 20),
                      SizedBox(width: 8),
                      Text('Compress PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'watermark',
                  child: Row(
                    children: [
                      Icon(Icons.branding_watermark_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Add Watermark'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'encrypt',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Password Protect'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Document Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Share PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: fileExists
          ? Stack(
              children: [
                PdfViewer.file(
                  file.path,
                  controller: _pdfController,
                  passwordProvider: () async => await _promptPassword(context),
                  params: PdfViewerParams(
                    panAxis: PanAxis.free,
                    onPageChanged: (page) {
                      if (mounted) {
                        setState(() {
                          _currentPage = page ?? 1;
                        });
                      }
                    },
                    onViewerReady: (document, layout) {
                      if (mounted) {
                        setState(() {
                          _totalPages = document.pages.length;
                        });
                      }
                    },
                  ),
                ),

                // Floating Page Indicator & Jump Bar
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showJumpToPageDialog,
                            child: Text(
                              'Page $_currentPage of $_totalPages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.white30,
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _pdfController.zoomDown(),
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _pdfController.zoomUp(),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Search Match Indicator Bar if searching
                if (_isSearchOpen && _textSearcher.hasMatches)
                  Positioned(
                    top: 10,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Match ${(_textSearcher.currentIndex ?? 0) + 1} of ${_textSearcher.matches.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 64,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PDF file is missing or has not been exported yet.',
                  ),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/editor/presentation/edit_page_screen.dart';
import 'package:scaneliq/features/intelligence/presentation/ai_document_sheet.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_page_organizer_screen.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/pdf_annotation_studio.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/pdf_metadata_and_bookmarks_sheets.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/signature_studio_sheet.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/watermark_studio_sheet.dart';

/// Concept A Professional PDF Viewer & Productivity Studio.
///
/// Supports PDFium rendering via `pdfrx` (pinch/double-tap zoom, text search,
/// page jump), collapsible page thumbnail strip, interactive annotations &
/// markup, visual signature overlays, watermarks, compression, encryption,
/// metadata editing, bookmarks, OCR, and page organization.
class DocumentViewerScreen extends StatefulWidget {
  final ScannedDocument document;
  final WidgetBuilder? pdfCanvasBuilder;
  final bool startInAnnotateMode;
  final bool startInSearchMode;

  const DocumentViewerScreen({
    super.key,
    required this.document,
    this.pdfCanvasBuilder,
    this.startInAnnotateMode = false,
    this.startInSearchMode = false,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  PdfTextSearcher? _textSearcher;
  final PdfAnnotationController _annotationController = PdfAnnotationController();
  final TextEditingController _searchQueryController = TextEditingController();

  late ScannedDocument _activeDoc;
  int _currentPage = 1;
  int _totalPages = 1;
  double _zoomFactor = 1.0;

  bool _isGeneratingPdf = false;
  bool _isSavingAnnotated = false;
  bool _isExtractingText = false;
  bool _showFallbackImageViewer = false;
  bool _isSearchOpen = false;
  bool _isAnnotateMode = false;
  bool _showThumbnailRail = false;
  bool _searchHasTextLayer = true;
  int _fallbackTextMatchCount = 0;

  String? _pdfError;
  String? _extractedText;
  List<DocumentBookmark> _bookmarks = [];
  Map<int, String> _cachedPageTexts = {};

  @override
  void initState() {
    super.initState();
    _activeDoc = widget.document;
    _totalPages = _activeDoc.pageCount > 0 ? _activeDoc.pageCount : 1;
    _isAnnotateMode = widget.startInAnnotateMode;
    _isSearchOpen = widget.startInSearchMode;

    _loadInitialMetadata();
  }

  void _ensureTextSearcher() {
    if (_textSearcher != null || !_pdfController.isReady) return;
    try {
      final searcher = PdfTextSearcher(_pdfController);
      searcher.addListener(() {
        if (mounted) setState(() {});
      });
      _textSearcher = searcher;
    } catch (_) {}
  }

  @override
  void dispose() {
    _textSearcher?.dispose();
    _annotationController.dispose();
    _searchQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMetadata() async {
    await Future.wait([
      _refreshPageCountAndTextLayer(),
      _loadBookmarks(),
    ]);
    await _autoEnsurePdfExists();
  }

  Future<List<DocumentBookmark>> _loadBookmarks() async {
    try {
      final list = await AppDatabaseService.instance.getBookmarks(
        _activeDoc.id,
      );
      if (mounted) {
        setState(() => _bookmarks = list);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _refreshPageCountAndTextLayer() async {
    final path = _activeDoc.exportPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final count = await AdvancedPdfService.instance.getPageCount(file);
      final texts = await AdvancedPdfService.instance.extractTextByPage(file);
      final hasText = texts.values.any((t) => t.trim().isNotEmpty);
      if (mounted && count > 0) {
        setState(() {
          _totalPages = count;
          _cachedPageTexts = texts;
          _searchHasTextLayer = hasText;
        });
      }
    } catch (_) {}
  }

  Future<void> _autoEnsurePdfExists() async {
    final pdfPath = _activeDoc.exportPath;
    final hasFile = pdfPath != null && File(pdfPath).existsSync();
    if (!hasFile && _activeDoc.pages.isNotEmpty) {
      await _regeneratePdf();
    }
  }

  Future<void> _regeneratePdf() async {
    if (_isGeneratingPdf) return;
    setState(() {
      _isGeneratingPdf = true;
      _pdfError = null;
    });

    try {
      List<DocumentPage> pages = _activeDoc.pages;
      if (pages.isEmpty) {
        final loaded = await AppDatabaseService.instance.getDocument(
          _activeDoc.id,
        );
        if (loaded != null && loaded.pages.isNotEmpty) {
          _activeDoc = loaded;
          pages = loaded.pages;
        }
      }

      if (pages.isEmpty) {
        throw Exception('No scanned pages found for this document.');
      }

      final generatedPdf = await PdfService.generatePdf(
        document: _activeDoc,
        pages: pages,
        customTitle: _activeDoc.title,
      );

      _activeDoc = _activeDoc.copyWith(
        exportPath: generatedPdf.path,
        pageCount: pages.length,
        isDraft: false,
      );
      await AppDatabaseService.instance.saveDocument(_activeDoc);
      await _refreshPageCountAndTextLayer();

      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _showFallbackImageViewer = false;
        });
        showScaneliqToast(context, 'PDF compiled cleanly.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _pdfError = '$e';
        });
        showScaneliqToast(context, 'PDF regeneration failed: $e');
      }
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Protected PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter document password to unlock viewing:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _updateActivePdfFile(File newFile, {String? toastMessage}) async {
    final count = await AdvancedPdfService.instance.getPageCount(newFile);
    final texts = await AdvancedPdfService.instance.extractTextByPage(newFile);
    final updatedDoc = _activeDoc.copyWith(
      exportPath: newFile.path,
      pageCount: count > 0 ? count : _activeDoc.pageCount,
      modifiedAt: DateTime.now(),
    );
    try {
      await AppDatabaseService.instance.saveDocument(updatedDoc);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _activeDoc = updatedDoc;
        if (count > 0) _totalPages = count;
        _currentPage = _currentPage.clamp(1, _totalPages);
        _cachedPageTexts = texts;
        _searchHasTextLayer = texts.values.any((t) => t.trim().isNotEmpty);
      });
      if (toastMessage != null) {
        showScaneliqToast(context, toastMessage);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _textSearcher?.resetTextSearch();
      setState(() => _fallbackTextMatchCount = 0);
      return;
    }

    if (!_searchHasTextLayer && _cachedPageTexts.isEmpty) {
      final path = _activeDoc.exportPath;
      if (path != null && File(path).existsSync()) {
        _cachedPageTexts = await AdvancedPdfService.instance.extractTextByPage(
          File(path),
        );
        _searchHasTextLayer = _cachedPageTexts.values.any(
          (t) => t.trim().isNotEmpty,
        );
      }
    }

    final lower = trimmed.toLowerCase();
    int count = 0;
    int? firstMatchPage;
    for (final entry in _cachedPageTexts.entries) {
      final matches = lower.allMatches(entry.value.toLowerCase()).length;
      if (matches > 0) {
        firstMatchPage ??= entry.key;
        count += matches;
      }
    }

    if (mounted) {
      setState(() => _fallbackTextMatchCount = count);
      if (firstMatchPage != null && firstMatchPage != _currentPage) {
        _jumpToPage(firstMatchPage);
      }
    }

    try {
      _ensureTextSearcher();
      _textSearcher?.startTextSearch(trimmed);
    } catch (_) {}
  }

  void _jumpToPage(int pageNumber) {
    final target = pageNumber.clamp(1, _totalPages);
    setState(() => _currentPage = target);
    try {
      if (_pdfController.isReady) {
        _pdfController.goToPage(pageNumber: target);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // ANNOTATIONS & SIGNATURES
  // ---------------------------------------------------------------------------

  Future<String?> _promptAnnotationNote(String? initialText) async {
    final ctrl = TextEditingController(text: initialText ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initialText == null ? 'Add PDF Note' : 'Edit PDF Note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter annotation text...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _saveAnnotationsToPdf() async {
    final path = _activeDoc.exportPath;
    if (path == null || !File(path).existsSync()) {
      showScaneliqToast(context, 'Generate a PDF first before saving markup.');
      return;
    }
    if (_annotationController.items.isEmpty) {
      showScaneliqToast(context, 'Add annotations before saving.');
      return;
    }

    setState(() => _isSavingAnnotated = true);
    try {
      final outFile = await AdvancedPdfService.instance.applyAnnotations(
        sourcePdf: File(path),
        annotations: _annotationController.items,
        outputFileName:
            '${_activeDoc.title}_annotated_${DateTime.now().millisecondsSinceEpoch}',
      );
      _annotationController.clearAll();
      if (mounted) {
        setState(() {
          _isSavingAnnotated = false;
          _isAnnotateMode = false;
        });
      }
      await _updateActivePdfFile(
        outFile,
        toastMessage: 'Saved annotated PDF copy non-destructively.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingAnnotated = false);
        showScaneliqToast(context, 'Annotation save failed: $e');
      }
    }
  }

  Future<void> _openSignatureStudio() async {
    final draft = await showSignatureStudioSheet(context);
    if (draft == null || !mounted) return;

    _annotationController.addItem(
      PdfAnnotationItem(
        type: PdfAnnotationType.signature,
        pageIndex: (_currentPage - 1).clamp(0, _totalPages - 1),
        x: 0.30,
        y: 0.68,
        width: 0.36 * draft.scale,
        height: 0.12 * draft.scale,
        rotationDegrees: draft.rotationDegrees,
        signaturePngBytes: draft.pngBytes,
        normalized: true,
      ),
      select: true,
    );
    _annotationController.setTool(PdfAnnotationTool.select);
    setState(() => _isAnnotateMode = true);
    showScaneliqToast(
      context,
      'Drag signature to position it, then tap Save PDF.',
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE EDITOR, ORGANIZER, OCR, WATERMARK, COMPRESS, ENCRYPT, SHARE
  // ---------------------------------------------------------------------------

  Future<void> _openPageEditorSheet() async {
    List<DocumentPage> pages = _activeDoc.pages;
    if (pages.isEmpty) {
      final loaded = await AppDatabaseService.instance.getDocument(
        _activeDoc.id,
      );
      if (loaded != null && loaded.pages.isNotEmpty) {
        setState(() => _activeDoc = loaded);
        pages = loaded.pages;
      }
    }
    if (pages.isEmpty || !mounted) {
      if (mounted) showScaneliqToast(context, 'No original pages to edit.');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPageScreen(
          page: pages[(_currentPage - 1).clamp(0, pages.length - 1)],
          pages: pages,
          initialPageIndex: (_currentPage - 1).clamp(0, pages.length - 1),
          onApply: (newRecipe) async {
            final idx = (_currentPage - 1).clamp(0, pages.length - 1);
            final target = pages[idx];
            final updatedPages = List<DocumentPage>.from(pages);
            updatedPages[idx] = target.copyWith(editRecipe: newRecipe);
            _activeDoc = _activeDoc.copyWith(pages: updatedPages);
            await AppDatabaseService.instance.saveDocumentWithPages(
              _activeDoc,
              updatedPages,
            );
          },
        ),
      ),
    );
    await _regeneratePdf();
  }

  Future<void> _openOrganizer() async {
    final path = _activeDoc.exportPath;
    if (path == null || !File(path).existsSync()) {
      showScaneliqToast(context, 'PDF file not available yet.');
      return;
    }

    final updatedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPageOrganizerScreen(
          pdfFile: File(path),
          document: _activeDoc,
        ),
      ),
    );
    if (updatedFile != null && await updatedFile.exists()) {
      await _updateActivePdfFile(
        updatedFile,
        toastMessage: 'PDF page layout updated.',
      );
    }
  }

  Future<void> _runOcr() async {
    if (_activeDoc.pages.isEmpty) {
      showScaneliqToast(context, 'No image pages available for OCR.');
      return;
    }
    setState(() => _isExtractingText = true);
    try {
      final buffer = StringBuffer();
      for (int i = 0; i < _activeDoc.pages.length; i++) {
        final page = _activeDoc.pages[i];
        final f = File(page.processedPath ?? page.originalPath);
        if (await f.exists()) {
          final txt = await OcrService.instance.extractText(f);
          if (txt.trim().isNotEmpty) {
            buffer.writeln('--- Page ${i + 1} ---');
            buffer.writeln(txt.trim());
            buffer.writeln();
          }
        }
      }
      final full = buffer.toString().trim();
      if (full.isNotEmpty) {
        await AppDatabaseService.instance.saveDocumentOcr(_activeDoc.id, full);
      }
      if (!mounted) return;
      setState(() {
        _isExtractingText = false;
        _extractedText = full;
      });
      if (full.isEmpty) {
        showScaneliqToast(context, 'No readable text detected on scanned pages.');
      } else {
        AiDocumentSheet.show(context, text: full);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtractingText = false);
        showScaneliqToast(context, 'OCR extraction failed: $e');
      }
    }
  }

  Future<void> _openWatermarkStudio(File file) async {
    final opts = await showWatermarkStudioSheet(
      context,
      currentPage: _currentPage,
      totalPages: _totalPages,
    );
    if (opts == null) return;
    try {
      final out = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: file,
        options: opts,
        outputFileName:
            '${_activeDoc.title}_watermarked_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _updateActivePdfFile(
        out,
        toastMessage: 'Watermark applied to new PDF copy.',
      );
    } catch (e) {
      if (mounted) showScaneliqToast(context, 'Watermark failed: $e');
    }
  }

  Future<void> _showCompressSheet(File file) async {
    PdfCompressionPreset selected = PdfCompressionPreset.balanced;
    final chosen = await showScaneliqBottomSheet<PdfCompressionPreset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final tokens = ctx.tokens;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compress PDF',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              RadioGroup<PdfCompressionPreset>(
                groupValue: selected,
                onChanged: (v) {
                  if (v != null) setSheetState(() => selected = v);
                },
                child: Column(
                  children: const [
                    RadioListTile(
                      value: PdfCompressionPreset.highQuality,
                      title: Text('High Quality'),
                      subtitle: Text('Minimal size optimization (~85% quality)'),
                    ),
                    RadioListTile(
                      value: PdfCompressionPreset.balanced,
                      title: Text('Balanced (Recommended)'),
                      subtitle: Text('Sharp text & compact storage (~65%)'),
                    ),
                    RadioListTile(
                      value: PdfCompressionPreset.smallerFile,
                      title: Text('Small File'),
                      subtitle: Text('Maximum reduction for email/upload (~45%)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: const Text('Compress Copy'),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;

    try {
      final res = await AdvancedPdfService.instance.compressPdf(
        sourcePdf: file,
        preset: chosen,
        outputFileName:
            '${_activeDoc.title}_compressed_${DateTime.now().millisecondsSinceEpoch}',
        associatedDocument: _activeDoc,
      );
      if (!mounted) return;
      final origKb = (res.originalSizeBytes / 1024).toStringAsFixed(1);
      final compKb = (res.compressedSizeBytes / 1024).toStringAsFixed(1);
      final pct = res.percentageReduction.toStringAsFixed(1);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Compression Result'),
          content: Text(
            'Original: $origKb KB\nCompressed: $compKb KB\nReduced by: $pct%',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateActivePdfFile(res.outputFile);
              },
              child: const Text('Use Compressed Copy'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.share_outlined, size: 17),
              label: const Text('Share'),
              onPressed: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(
                  ShareParams(
                    text: _activeDoc.title,
                    files: [XFile(res.outputFile.path)],
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showScaneliqToast(context, 'Compression failed: $e');
    }
  }

  Future<void> _showEncryptDialog(File file) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Password Protect PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: p1,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: p2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (p1.text.trim().isEmpty || p1.text != p2.text) return;
              Navigator.pop(ctx, p1.text.trim());
            },
            child: const Text('Protect Copy'),
          ),
        ],
      ),
    );
    p1.dispose();
    p2.dispose();
    if (password == null) return;
    try {
      final out = await AdvancedPdfService.instance.encryptPdf(
        sourcePdf: file,
        userPassword: password,
        outputFileName:
            '${_activeDoc.title}_protected_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        showScaneliqToast(context, 'Protected PDF saved: ${out.uri.pathSegments.last}');
      }
    } catch (e) {
      if (mounted) showScaneliqToast(context, 'Protection failed: $e');
    }
  }

  Future<void> _showJumpToPageDialog() async {
    final ctrl = TextEditingController(text: '$_currentPage');
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page (1 - $_totalPages)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (target != null && target >= 1 && target <= _totalPages) {
      _jumpToPage(target);
    }
  }

  Future<void> _exportPagesAsImages() async {
    if (_activeDoc.pages.isEmpty) {
      showScaneliqToast(context, 'No source pages to export as JPEG.');
      return;
    }
    int count = 0;
    for (int i = 0; i < _activeDoc.pages.length; i++) {
      final page = _activeDoc.pages[i];
      final f = File(page.processedPath ?? page.originalPath);
      if (await f.exists()) {
        final raw = await f.readAsBytes();
        final outBytes = await ImageProcessingService.processEncodedSourceBytesInIsolate(
          raw,
          page.editRecipe,
          quality: 92,
        );
        final outPath =
            '${AppStorageService.instance.exportsDir.path}/${_activeDoc.title}_p${i + 1}.jpg';
        await File(outPath).writeAsBytes(outBytes, flush: true);
        count++;
      }
    }
    if (mounted) {
      showScaneliqToast(context, 'Exported $count JPEG page(s) to Exports folder.');
    }
  }

  Future<void> _shareDocument() async {
    final path = _activeDoc.exportPath;
    if (path == null || !File(path).existsSync()) {
      showScaneliqToast(context, 'Generate the PDF before sharing.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: _activeDoc.title, files: [XFile(path)]),
    );
  }

  void _showMoreToolsSheet(File? file) {
    final tokens = context.tokens;
    final hasFile = file != null && file.existsSync();
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PDF Tools & Export',
            style: Theme.of(sheetCtx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          if (hasFile) ...[
            ScaneliqContextMenuRow(
              icon: Icons.branding_watermark_outlined,
              title: 'Watermark Studio',
              onTap: () {
                Navigator.pop(sheetCtx);
                _openWatermarkStudio(file);
              },
            ),
            ScaneliqContextMenuRow(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              onTap: () {
                Navigator.pop(sheetCtx);
                _showCompressSheet(file);
              },
            ),
            ScaneliqContextMenuRow(
              icon: Icons.lock_outline_rounded,
              title: 'Password Protect PDF',
              onTap: () {
                Navigator.pop(sheetCtx);
                _showEncryptDialog(file);
              },
            ),
            ScaneliqContextMenuRow(
              icon: Icons.info_outline_rounded,
              title: 'PDF Properties & Metadata',
              onTap: () {
                Navigator.pop(sheetCtx);
                showPdfMetadataSheet(
                  context: context,
                  pdfFile: file,
                  fallbackTitle: _activeDoc.title,
                  onMetadataUpdatedPdf: (updated) => _updateActivePdfFile(
                    updated,
                    toastMessage: 'PDF metadata updated in new copy.',
                  ),
                );
              },
            ),
            ScaneliqContextMenuRow(
              icon: Icons.ios_share_rounded,
              title: 'Share PDF',
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareDocument();
              },
            ),
          ],
          ScaneliqContextMenuRow(
            icon: Icons.image_outlined,
            title: 'Export Pages as JPEG',
            onTap: () {
              Navigator.pop(sheetCtx);
              _exportPagesAsImages();
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.tune_rounded,
            title: 'Edit Scan Filters & Crop',
            onTap: () {
              Navigator.pop(sheetCtx);
              _openPageEditorSheet();
            },
          ),
          if (_extractedText != null && _extractedText!.isNotEmpty)
            ScaneliqContextMenuRow(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Summary & Q&A',
              titleColor: tokens.accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                AiDocumentSheet.show(context, text: _extractedText);
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pdfPath = _activeDoc.exportPath;
    final file = pdfPath != null ? File(pdfPath) : null;
    final fileExists = file != null && file.existsSync();

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tokens.hairline),
        ),
        title: _isSearchOpen
            ? TextField(
                controller: _searchQueryController,
                autofocus: true,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Find text in PDF...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 19),
                    tooltip: 'Clear Search',
                    onPressed: () {
                      _searchQueryController.clear();
                      _executeSearch('');
                    },
                  ),
                ),
                onSubmitted: _executeSearch,
                onChanged: (val) {
                  if (val.isEmpty) _executeSearch('');
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activeDoc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: ScaneliqTypography.monoStyle(
                      color: tokens.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearchOpen) ...[
            if (_textSearcher?.hasMatches == true) ...[
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                tooltip: 'Previous Match',
                onPressed: _textSearcher?.goToPrevMatch,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                tooltip: 'Next Match',
                onPressed: _textSearcher?.goToNextMatch,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close Search',
              onPressed: () {
                setState(() {
                  _isSearchOpen = false;
                  _fallbackTextMatchCount = 0;
                });
                _searchQueryController.clear();
                _textSearcher?.resetTextSearch();
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search Text',
              onPressed: () => setState(() => _isSearchOpen = true),
            ),
            IconButton(
              icon: Icon(
                _showThumbnailRail
                    ? Icons.view_carousel_rounded
                    : Icons.view_carousel_outlined,
                color: _showThumbnailRail ? tokens.accent : tokens.textPrimary,
              ),
              tooltip: 'Page Thumbnails',
              onPressed: () => setState(() => _showThumbnailRail = !_showThumbnailRail),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded),
              tooltip: 'Bookmarks',
              onPressed: () => showPdfBookmarksSheet(
                context: context,
                documentId: _activeDoc.id,
                currentPage: _currentPage,
                initialBookmarks: _bookmarks,
                onReload: _loadBookmarks,
                onJumpToPage: _jumpToPage,
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search info strip (scanned-PDF notice or match counter)
          if (_isSearchOpen) _buildSearchBanner(tokens),

          // Main interactive canvas
          Expanded(child: _buildBody(fileExists, file, tokens)),

          // Collapsible Page Thumbnail Strip
          if (_showThumbnailRail && fileExists) _buildThumbnailStrip(tokens),

          // Bottom Action Bar: Annotate Toolbar OR 5-action Dock
          if (_isAnnotateMode)
            PdfAnnotationToolbar(
              controller: _annotationController,
              isSaving: _isSavingAnnotated,
              onSavePdf: _saveAnnotationsToPdf,
              onClearCurrentPage: () =>
                  _annotationController.clearPage(_currentPage - 1),
              onClose: () => setState(() => _isAnnotateMode = false),
            )
          else
            _buildBottomActionDock(tokens, fileExists, file),
        ],
      ),
    );
  }

  Widget _buildSearchBanner(ScaneliqTokens tokens) {
    final query = _searchQueryController.text.trim();
    final searcher = _textSearcher;
    final int pdfrxMatches = searcher?.matches.length ?? 0;
    final int count = pdfrxMatches > 0 ? pdfrxMatches : _fallbackTextMatchCount;

    String statusText;
    if (!_searchHasTextLayer) {
      statusText = 'Scanned PDF has no text layer — run OCR to search text.';
    } else if (query.isEmpty) {
      statusText = 'Enter keywords and press search to highlight matches.';
    } else if (count == 0) {
      statusText = 'No matches for "$query".';
    } else if (searcher?.hasMatches == true) {
      statusText =
          'Match ${(searcher?.currentIndex ?? 0) + 1} of $pdfrxMatches matches';
    } else {
      statusText = '$count match(es) located across searchable text.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: [
          Icon(
            _searchHasTextLayer
                ? Icons.find_in_page_outlined
                : Icons.document_scanner_outlined,
            size: 16,
            color: _searchHasTextLayer ? tokens.accent : tokens.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          if (!_searchHasTextLayer)
            TextButton(
              onPressed: _isExtractingText ? null : _runOcr,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: tokens.accent,
              ),
              child: const Text('Run OCR'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool fileExists, File? file, ScaneliqTokens tokens) {
    if (_isGeneratingPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tokens.accent),
            const SizedBox(height: 14),
            Text(
              'Compiling PDF document...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${_activeDoc.pageCount} page(s) · A4 print layout',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_showFallbackImageViewer) {
      return _buildFallbackImageViewer(tokens);
    }

    if (fileExists && file != null) {
      return Stack(
        children: [
          // Main PDF canvas or test override
          Positioned.fill(
            child: widget.pdfCanvasBuilder != null
                ? widget.pdfCanvasBuilder!(context)
                : PdfViewer.file(
                    file.path,
                    controller: _pdfController,
                    passwordProvider: () async => await _promptPassword(context),
                    params: PdfViewerParams(
                      panAxis: PanAxis.free,
                      onPageChanged: (page) {
                        if (mounted) {
                          setState(() => _currentPage = page ?? 1);
                        }
                      },
                      onViewerReady: (document, _) {
                        if (mounted) {
                          _ensureTextSearcher();
                          setState(() => _totalPages = document.pages.length);
                        }
                      },
                      errorBannerBuilder: (ctx, err, _, _) => Container(
                        padding: const EdgeInsets.all(12),
                        color: tokens.surfaceSubtle,
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: tokens.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PDF preview unavailable: $err',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tokens.danger, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showFallbackImageViewer = true),
                              child: const Text('Raw Scans'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Interactive Vector / Ink / Note / Signature overlay during Annotate mode
          if (_isAnnotateMode)
            Positioned.fill(
              child: PdfAnnotationOverlay(
                controller: _annotationController,
                pageIndex: (_currentPage - 1).clamp(0, _totalPages - 1),
                onRequestNoteText: _promptAnnotationNote,
              ),
            ),

          // Floating Page Jump & Zoom pill (bottom center)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.hairline),
                  boxShadow: tokens.paperShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _showJumpToPageDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'P$_currentPage/$_totalPages',
                          style: ScaneliqTypography.monoStyle(
                            color: tokens.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: tokens.hairline,
                    ),
                    InkWell(
                      onTap: () {
                        setState(
                          () => _zoomFactor = (_zoomFactor - 0.25).clamp(0.75, 4.0),
                        );
                        try {
                          if (_pdfController.isReady) _pdfController.zoomDown();
                        } catch (_) {}
                      },
                      child: Icon(Icons.remove_rounded, size: 17, color: tokens.textPrimary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${(_zoomFactor * 100).round()}%',
                        style: ScaneliqTypography.monoStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(
                          () => _zoomFactor = (_zoomFactor + 0.25).clamp(0.75, 4.0),
                        );
                        try {
                          if (_pdfController.isReady) _pdfController.zoomUp();
                        } catch (_) {}
                      },
                      child: Icon(Icons.add_rounded, size: 17, color: tokens.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Missing PDF state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 54, color: tokens.textTertiary),
            const SizedBox(height: 12),
            Text(
              'PDF file not yet exported',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_pdfError != null) ...[
              const SizedBox(height: 8),
              Text(
                _pdfError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: tokens.accent),
                  onPressed: _regeneratePdf,
                  icon: const Icon(Icons.build_circle_outlined, size: 18),
                  label: const Text('Generate PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showFallbackImageViewer = true),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Raw Scans'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(ScaneliqTokens tokens) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _totalPages,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final pageNum = index + 1;
          final isActive = pageNum == _currentPage;
          final pageModel = index < _activeDoc.pages.length
              ? _activeDoc.pages[index]
              : null;
          final imgPath = pageModel?.processedPath ?? pageModel?.originalPath;
          final imgFile = imgPath != null ? File(imgPath) : null;

          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _jumpToPage(pageNum),
            child: Container(
              width: 46,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? tokens.accent : tokens.paperBorder,
                  width: isActive ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgFile != null && imgFile.existsSync())
                    Image.file(imgFile, fit: BoxFit.cover, cacheWidth: 140)
                  else
                    Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: tokens.textTertiary,
                      ),
                    ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive ? tokens.accent : Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pageNum',
                        style: ScaneliqTypography.monoStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomActionDock(
    ScaneliqTokens tokens,
    bool fileExists,
    File? file,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DockAction(
              icon: Icons.edit_note_rounded,
              label: 'Annotate',
              enabled: fileExists,
              onTap: () => setState(() => _isAnnotateMode = true),
            ),
            _DockAction(
              icon: Icons.draw_outlined,
              label: 'Sign',
              enabled: fileExists,
              onTap: _openSignatureStudio,
            ),
            _DockAction(
              icon: Icons.dashboard_customize_outlined,
              label: 'Organize',
              enabled: fileExists,
              onTap: _openOrganizer,
            ),
            _DockAction(
              icon: Icons.text_snippet_outlined,
              label: _isExtractingText ? 'OCR...' : 'OCR',
              enabled: !_isExtractingText,
              onTap: _runOcr,
            ),
            _DockAction(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              enabled: true,
              onTap: () => _showMoreToolsSheet(file),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImageViewer(ScaneliqTokens tokens) {
    final pages = _activeDoc.pages;
    if (pages.isEmpty) {
      return const Center(child: Text('No original scan pages available.'));
    }
    return Stack(
      children: [
        PageView.builder(
          itemCount: pages.length,
          onPageChanged: (idx) => setState(() => _currentPage = idx + 1),
          itemBuilder: (_, idx) {
            final f = File(pages[idx].processedPath ?? pages[idx].originalPath);
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: f.existsSync()
                    ? Image.file(f, fit: BoxFit.contain)
                    : Icon(Icons.broken_image_outlined, color: tokens.textTertiary, size: 42),
              ),
            );
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FilledButton.tonalIcon(
            onPressed: () => setState(() => _showFallbackImageViewer = false),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('PDF View'),
          ),
        ),
      ],
    );
  }
}

class _DockAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _DockAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = enabled
        ? tokens.textPrimary
        : tokens.textTertiary.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ScaneliqTypography.bodyFontFamily,
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/editor/presentation/edit_page_screen.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

class ReviewPagesScreen extends ConsumerStatefulWidget {
  const ReviewPagesScreen({super.key});

  @override
  ConsumerState<ReviewPagesScreen> createState() => _ReviewPagesScreenState();
}

class _ReviewPagesScreenState extends ConsumerState<ReviewPagesScreen> {
  late TextEditingController _titleController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(scanSessionProvider);
    _titleController = TextEditingController(text: session.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _exportAndSavePdf() async {
    final session = ref.read(scanSessionProvider);
    if (session.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export empty document.')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final doc = ScannedDocument(
        id: session.documentId,
        title: _titleController.text.trim().isEmpty
            ? session.title
            : _titleController.text.trim(),
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: session.pages.length,
      );

      // Extract OCR for each page for searchable PDF text layer & library indexing
      final ocrBoxesByPage = <int, List<OcrBoundingBox>>{};
      final ocrTexts = <String>[];

      for (int i = 0; i < session.pages.length; i++) {
        final page = session.pages[i];
        final imageFile = File(page.processedPath ?? page.originalPath);
        if (imageFile.existsSync()) {
          try {
            final pageOcr = await OcrService.instance.extractPageOcr(imageFile);
            if (pageOcr.boxes.isNotEmpty) {
              ocrBoxesByPage[i] = pageOcr.boxes;
            }
            if (pageOcr.text.trim().isNotEmpty) {
              ocrTexts.add(pageOcr.text.trim());
            }
          } catch (_) {
            // Non-critical: OCR extraction can fall back gracefully
          }
        }
      }

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: session.pages,
        customTitle: doc.title,
        ocrBoxesByPage: ocrBoxesByPage.isNotEmpty ? ocrBoxesByPage : null,
      );

      // Save verified export path to database and mark as finalized (not draft)
      final finalizedDoc = doc.copyWith(
        exportPath: pdfFile.path,
        isDraft: false,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(
        finalizedDoc,
        session.pages,
      );

      // Persist full-text OCR in SQLite for instant library search
      if (ocrTexts.isNotEmpty) {
        await AppDatabaseService.instance.saveDocumentOcr(
          finalizedDoc.id,
          ocrTexts.join('\n\n'),
        );
      }

      // Invalidate library and draft providers
      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
      ref.invalidate(latestDraftProvider);

      if (mounted) {
        setState(() {
          _isExporting = false;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Saved to Scaneliq'),
              ],
            ),
            content: Text(
              'PDF document successfully created and saved locally with ${session.pages.length} pages.${ocrTexts.isNotEmpty ? ' Text made searchable.' : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DocumentViewerScreen(document: finalizedDoc),
                    ),
                  );
                },
                child: const Text('View PDF'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Export Images (JPG)'),
                onPressed: () async {
                  await _exportAllPagesAsJpegs(session);
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(text: doc.title, files: [XFile(pdfFile.path)]),
                  );
                },
                child: const Text('Share PDF'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Return to Home
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stitch2In1IdCard() async {
    final session = ref.read(scanSessionProvider);
    if (session.pages.length != 2) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final frontFile = File(
        session.pages[0].processedPath ?? session.pages[0].originalPath,
      );
      final backFile = File(
        session.pages[1].processedPath ?? session.pages[1].originalPath,
      );
      final baseTitle = _titleController.text.trim().isEmpty
          ? session.title
          : _titleController.text.trim();

      final stitchedJpg = await PdfService.stitchIdCard2In1(
        frontImage: frontFile,
        backImage: backFile,
        baseTitle: '${baseTitle}_2in1',
      );

      await ref
          .read(scanSessionProvider.notifier)
          .replaceWithSinglePage(stitchedJpg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Combined Front & Back into 2-in-1 ID Card Sheet!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID Card stitching failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportAllPagesAsJpegs(ScanSessionState session) async {
    try {
      final exportedFiles = <XFile>[];
      for (final page in session.pages) {
        final jpegFile = await PdfService.exportPageAsJpeg(
          page: page,
          baseName: _titleController.text.trim().isEmpty
              ? session.title
              : _titleController.text.trim(),
        );
        exportedFiles.add(XFile(jpegFile.path));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${exportedFiles.length} JPEGs to exports folder.',
            ),
            action: SnackBarAction(
              label: 'Share All',
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Scaneliq Exported Pages',
                    files: exportedFiles,
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exporting images failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddPagesSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.brandPrimary,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Add Pages to Document',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.document_scanner_rounded,
                  color: AppColors.brandPrimary,
                ),
                title: const Text('Google ML Kit Document Scanner'),
                subtitle: const Text(
                  'Automatic corner boundary detection & deskewing',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(scanSessionProvider.notifier).startScannerCapture();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Continuous Camera Mode'),
                subtitle: const Text(
                  'Rapid multi-page viewfinder with custom guides',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ContinuousCameraScreen(mode: ScanMode.batch),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF059669),
                ),
                title: const Text('Import from Photo Gallery'),
                subtitle: const Text('Pick existing JPG, PNG, or WebP images'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  );
                  if (picked.isNotEmpty) {
                    final files = picked
                        .where((p) => p.path != null)
                        .map((p) => File(p.path!))
                        .toList();
                    if (files.isNotEmpty) {
                      await ref
                          .read(scanSessionProvider.notifier)
                          .importFiles(files);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRetakeOptions(DocumentPage page) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cameraswitch_outlined,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Retake Page ${page.pageOrder + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.document_scanner,
                  color: AppColors.brandPrimary,
                ),
                title: const Text('Scan with Document Scanner'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(scanSessionProvider.notifier)
                      .retakePage(page.id);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF059669),
                ),
                title: const Text('Select Replacement from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  );
                  if (picked.isNotEmpty && picked.first.path != null) {
                    await ref
                        .read(scanSessionProvider.notifier)
                        .retakePageWithFile(page.id, File(picked.first.path!));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePage(DocumentPage page, int pageIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Are you sure you want to delete Page ${pageIndex + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(scanSessionProvider.notifier).removePage(page.id);
    }
  }

  void _showImagePreviewDialog(File file, int pageIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add More Pages',
            onPressed: _showAddPagesSheet,
          ),
        ],
      ),
      body: session.pages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.document_scanner,
                    size: 64,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text('No pages captured yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Pages'),
                    onPressed: _showAddPagesSheet,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Document Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_note),
                    ),
                    onChanged: (val) {
                      ref.read(scanSessionProvider.notifier).updateTitle(val);
                    },
                  ),
                ),
                if (session.pages.length == 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            color: AppColors.brandPrimary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '2-in-1 ID Card Sheet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Combine front & back onto single A4 page',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _isExporting ? null : _stitch2In1IdCard,
                            child: const Text('Combine'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${session.pages.length} Pages (Drag to reorder)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add page'),
                        onPressed: _showAddPagesSheet,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: session.pages.length,
                    onReorderItem: (oldIndex, newIndex) {
                      ref
                          .read(scanSessionProvider.notifier)
                          .reorderPages(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final page = session.pages[index];
                      final file = File(
                        page.processedPath ?? page.originalPath,
                      );

                      return Card(
                        key: ValueKey(page.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: file.existsSync()
                                    ? () => _showImagePreviewDialog(file, index)
                                    : null,
                                child: Container(
                                  width: 64,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.surface2Dark
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: file.existsSync()
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            file,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.image_not_supported),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Page ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Filter: ${page.editRecipe.filter.name.toUpperCase()}'
                                      '${page.editRecipe.rotationDegrees != 0 ? ' · ${page.editRecipe.rotationDegrees}°' : ''}'
                                      '${page.editRecipe.hasCrop ? ' · Cropped' : ''}'
                                      '${page.editRecipe.hasPerspective ? ' · Warped' : ''}'
                                      '${page.editRecipe.binarization != BinarizationMode.none ? ' · ${page.editRecipe.binarization.name.toUpperCase()}' : ''}'
                                      '${page.editRecipe.shadowCorrection ? ' · Shadows' : ''}'
                                      '${page.editRecipe.hasCleanup ? ' · Cleaned' : ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune),
                                tooltip: 'Edit Page',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditPageScreen(
                                        page: page,
                                        onApply: (recipe) {
                                          ref
                                              .read(
                                                scanSessionProvider.notifier,
                                              )
                                              .updatePageRecipe(
                                                page.id,
                                                recipe,
                                              );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cameraswitch_outlined),
                                tooltip: 'Retake Page',
                                onPressed: () => _showRetakeOptions(page),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                tooltip: 'Delete Page',
                                onPressed: () =>
                                    _confirmDeletePage(page, index),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                tooltip: 'Page Options',
                                onSelected: (val) async {
                                  if (val == 'export_jpeg') {
                                    try {
                                      final jpegFile =
                                          await PdfService.exportPageAsJpeg(
                                            page: page,
                                            baseName:
                                                _titleController.text
                                                    .trim()
                                                    .isEmpty
                                                ? 'Page_${index + 1}'
                                                : _titleController.text.trim(),
                                          );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'JPEG saved: ${jpegFile.path.split(Platform.pathSeparator).last}',
                                            ),
                                            action: SnackBarAction(
                                              label: 'Share',
                                              onPressed: () {
                                                SharePlus.instance.share(
                                                  ShareParams(
                                                    text:
                                                        'Scaneliq Page ${index + 1}',
                                                    files: [
                                                      XFile(jpegFile.path),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'JPEG export failed: $e',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(
                                    value: 'export_jpeg',
                                    child: Row(
                                      children: [
                                        Icon(Icons.image_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text('Export as JPEG'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.surface3Dark
                            : AppColors.surface3Light,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportAndSavePdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _isExporting
                            ? 'Generating PDF...'
                            : 'Save PDF to Scaneliq',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

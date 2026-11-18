import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_buttons.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/editor/presentation/edit_page_screen.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart';

/// Concept A (Editorial Gallery Minimal) Captured Pages Review Screen.
///
/// Displays a large centered page stage, page index indicator, horizontal
/// thumbnail strip, Retake, Delete, Add Page, Continue Editing ([EditPageScreen]),
/// and Finish Capture / Save PDF workflow.
class ReviewPagesScreen extends ConsumerStatefulWidget {
  const ReviewPagesScreen({super.key});

  @override
  ConsumerState<ReviewPagesScreen> createState() => _ReviewPagesScreenState();
}

class _ReviewPagesScreenState extends ConsumerState<ReviewPagesScreen> {
  late TextEditingController _titleController;
  int _selectedPageIndex = 0;
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
      showScaneliqToast(context, 'Cannot finish empty scan session.');
      return;
    }

    setState(() => _isExporting = true);

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
            // Non-critical: OCR failure never blocks document PDF export.
          }
        }
      }

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: session.pages,
        customTitle: doc.title,
        ocrBoxesByPage: ocrBoxesByPage.isNotEmpty ? ocrBoxesByPage : null,
      );

      final finalizedDoc = doc.copyWith(
        exportPath: pdfFile.path,
        isDraft: false,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(
        finalizedDoc,
        session.pages,
      );

      if (ocrTexts.isNotEmpty) {
        await AppDatabaseService.instance.saveDocumentOcr(
          finalizedDoc.id,
          ocrTexts.join('\n\n'),
        );
      }

      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
      ref.invalidate(latestDraftProvider);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await showScaneliqBottomSheet<void>(
        context: context,
        builder: (ctx) {
          final tokens = ctx.tokens;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.success,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved to Scaneliq',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                  ),
                  ScaneliqStatusLabel(
                    text: '${session.pages.length} PAGES',
                    tone: ScaneliqStatusTone.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'PDF saved locally${ocrTexts.isNotEmpty ? ' with searchable OCR text layer.' : '.'}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ScaneliqPrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ScaneliqSecondaryButton(
                      label: 'View PDF',
                      icon: Icons.picture_as_pdf_outlined,
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ScaneliqSecondaryButton(
                      label: 'Share',
                      icon: Icons.share_outlined,
                      onPressed: () {
                        Navigator.pop(ctx);
                        SharePlus.instance.share(
                          ShareParams(
                            text: doc.title,
                            files: [
                              XFile(pdfFile.path, mimeType: 'application/pdf'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: ScaneliqTextButton(
                  label: 'Export All Pages as JPEG',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _exportAllPagesAsJpegs(session);
                  },
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        showScaneliqToast(context, 'Save failed: $e');
      }
    }
  }

  Future<void> _stitch2In1IdCard() async {
    final session = ref.read(scanSessionProvider);
    if (session.pages.length != 2) return;

    setState(() => _isExporting = true);

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
        setState(() => _selectedPageIndex = 0);
        showScaneliqToast(
          context,
          'Combined Front & Back into 2-in-1 ID Card sheet.',
        );
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'ID Card stitching failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
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
        showScaneliqToast(
          context,
          'Exported ${exportedFiles.length} JPEGs to exports folder.',
        );
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'Exporting images failed: $e');
      }
    }
  }

  void _showAddPagesSheet() {
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Pages', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Append additional scans or gallery photos to this document',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.camera_alt_outlined,
            title: 'Scan in Camera Studio',
            subtitle: 'Continuous multi-page optical capture',
            onTap: () async {
              Navigator.pop(ctx);
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const ContinuousCameraScreen(mode: ScanMode.batch),
                ),
              );
            },
          ),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.photo_library_outlined,
            title: 'Import from Gallery',
            subtitle: 'Select JPG, PNG, or WebP images',
            onTap: () async {
              Navigator.pop(ctx);
              final result = await ref
                  .read(galleryImportServiceProvider)
                  .pickAndValidateImages();
              if (result.cancelled) return;
              if (!result.hasAccepted) {
                if (mounted) {
                  showScaneliqToast(
                    context,
                    result.rejections.isNotEmpty
                        ? result.rejections.first.reason
                        : 'No valid images selected.',
                  );
                }
                return;
              }
              final count = await ref
                  .read(scanSessionProvider.notifier)
                  .importFiles(result.accepted.map((a) => a.file).toList());
              if (count > 0 && mounted) {
                final total = ref.read(scanSessionProvider).pages.length;
                setState(() => _selectedPageIndex = total - 1);
                showScaneliqToast(context, 'Added $count page(s).');
              }
            },
          ),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.document_scanner_outlined,
            title: 'Google ML Kit Scanner',
            subtitle: 'Native boundary crop & deskew scanner',
            onTap: () {
              Navigator.pop(ctx);
              ref.read(scanSessionProvider.notifier).startScannerCapture();
            },
          ),
        ],
      ),
    );
  }

  void _showRetakeSheet(DocumentPage page, int pageIndex) {
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Retake Page ${pageIndex + 1}',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Replace only this page while preserving page order',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.camera_alt_outlined,
            title: 'Retake in Camera Studio',
            subtitle: 'Capture a fresh photo replacement',
            onTap: () async {
              Navigator.pop(ctx);
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContinuousCameraScreen(
                    mode: ScanMode.document,
                    retakePageId: page.id,
                  ),
                ),
              );
            },
          ),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.photo_library_outlined,
            title: 'Pick Replacement from Gallery',
            subtitle: 'Select an existing image from device',
            onTap: () async {
              Navigator.pop(ctx);
              final result = await ref
                  .read(galleryImportServiceProvider)
                  .pickAndValidateImages();
              if (result.cancelled) return;
              if (!result.hasAccepted) {
                if (mounted) {
                  showScaneliqToast(
                    context,
                    result.rejections.isNotEmpty
                        ? result.rejections.first.reason
                        : 'Selected file is invalid.',
                  );
                }
                return;
              }
              final ok = await ref
                  .read(scanSessionProvider.notifier)
                  .retakePageWithFile(page.id, result.accepted.first.file);
              if (ok && mounted) {
                showScaneliqToast(context, 'Page ${pageIndex + 1} updated.');
              }
            },
          ),
          const ScaneliqHairlineDivider(),
          ScaneliqContextMenuRow(
            icon: Icons.document_scanner_outlined,
            title: 'Retake with ML Kit Scanner',
            onTap: () async {
              Navigator.pop(ctx);
              await ref
                  .read(scanSessionProvider.notifier)
                  .retakePage(page.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePage(DocumentPage page, int pageIndex) async {
    final confirm = await showScaneliqConfirmDialog(
      context: context,
      title: 'Delete Page ${pageIndex + 1}?',
      message: 'Remove this page from the active scan session.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;

    await ref.read(scanSessionProvider.notifier).removePage(page.id);
    if (!mounted) return;
    final remaining = ref.read(scanSessionProvider).pages.length;
    setState(() {
      if (remaining == 0) {
        _selectedPageIndex = 0;
      } else if (_selectedPageIndex >= remaining) {
        _selectedPageIndex = remaining - 1;
      }
    });
  }

  Future<void> _renameDocumentSheet() async {
    final controller = TextEditingController(text: _titleController.text);
    final updated = await showScaneliqBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Document Title',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Scan_Document',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          const SizedBox(height: 16),
          ScaneliqPrimaryButton(
            label: 'Update Title',
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null && updated.isNotEmpty) {
      _titleController.text = updated;
      ref.read(scanSessionProvider.notifier).updateTitle(updated);
      if (mounted) setState(() {});
    }
  }

  void _openPageEditor(DocumentPage page) {
    final pages = ref.read(scanSessionProvider).pages;
    final idx = pages.indexWhere((p) => p.id == page.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditPageScreen(
          page: page,
          pages: pages,
          initialPageIndex: idx >= 0 ? idx : 0,
          onApply: (recipe) {
            ref
                .read(scanSessionProvider.notifier)
                .updatePageRecipe(page.id, recipe);
          },
        ),
      ),
    );
  }

  Future<void> _movePageOrder(int currentIndex, int targetIndex) async {
    final notifier = ref.read(scanSessionProvider.notifier);
    final adjustedNew =
        targetIndex > currentIndex ? targetIndex + 1 : targetIndex;
    await notifier.reorderPages(currentIndex, adjustedNew);
    if (mounted) {
      setState(() => _selectedPageIndex = targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    if (session.pages.isEmpty) {
      return Scaffold(
        backgroundColor: tokens.bg,
        appBar: AppBar(
          title: const Text('Capture Review'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(horizontalPad),
          child: ScaneliqEmptyState(
            icon: Icons.document_scanner_outlined,
            title: 'No captured pages yet',
            description:
                'Open the Optical Camera Studio or import document images from your device.',
            primaryActionLabel: 'Open Camera Studio',
            onPrimaryAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const ContinuousCameraScreen(mode: ScanMode.batch),
              ),
            ),
            secondaryActionLabel: 'Add Pages',
            onSecondaryAction: _showAddPagesSheet,
          ),
        ),
      );
    }

    final safeIndex = _selectedPageIndex.clamp(0, session.pages.length - 1);
    final activePage = session.pages[safeIndex];
    final activeFile = File(
      activePage.processedPath ?? activePage.originalPath,
    );
    final pageCount = session.pages.length;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Minimal Concept A Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad - 8,
                8,
                horizontalPad,
                8,
              ),
              child: Row(
                children: [
                  ScaneliqIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _renameDocumentSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _titleController.text.trim().isEmpty
                                    ? session.title
                                    : _titleController.text.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: tokens.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _isExporting ? null : _exportAndSavePdf,
                    child: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Finish Capture',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const ScaneliqHairlineDivider(),

            // 2. Large Page Preview Stage
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    // Status / Page count bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: tokens.hairline),
                          ),
                          child: Text(
                            'PAGE ${_twoDigits(safeIndex + 1)} OF ${_twoDigits(pageCount)}',
                            style: ScaneliqTypography.monoStyle(
                              color: tokens.textPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activePage.width != null &&
                                activePage.height != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ScaneliqStatusLabel(
                                  text:
                                      '${activePage.width}×${activePage.height}',
                                  tone: ScaneliqStatusTone.neutral,
                                ),
                              ),
                            ScaneliqStatusLabel(
                              text: activePage.editRecipe.filter.name
                                  .toUpperCase(),
                              tone: activePage.editRecipe.hasPerspective
                                  ? ScaneliqStatusTone.accent
                                  : ScaneliqStatusTone.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Large Paper Preview Card
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 340,
                          maxHeight: 370,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ScaneliqRadius.paper,
                          ),
                          border: Border.all(
                            color: tokens.paperBorder,
                            width: 1,
                          ),
                          boxShadow: tokens.paperShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 0.72,
                          child: activeFile.existsSync()
                              ? InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 3.5,
                                  child: Image.file(
                                    activeFile,
                                    key: ValueKey(
                                      '${activePage.id}_${activePage.processedPath}_${activePage.originalPath}',
                                    ),
                                    fit: BoxFit.contain,
                                    cacheWidth: 1080,
                                    errorBuilder: (_, _, _) =>
                                        _missingPagePlaceholder(tokens),
                                  ),
                                )
                              : _missingPagePlaceholder(tokens),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Compact Page Stage Controls (Retake, Delete, Continue Editing, Add)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ReviewStageActionChip(
                          icon: Icons.cameraswitch_outlined,
                          label: 'Retake',
                          onPressed: () =>
                              _showRetakeSheet(activePage, safeIndex),
                        ),
                        _ReviewStageActionChip(
                          icon: Icons.tune_rounded,
                          label: 'Continue Editing',
                          accent: true,
                          onPressed: () => _openPageEditor(activePage),
                        ),
                        _ReviewStageActionChip(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Add Page',
                          onPressed: _showAddPagesSheet,
                        ),
                        _ReviewStageActionChip(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          destructive: true,
                          onPressed: () =>
                              _confirmDeletePage(activePage, safeIndex),
                        ),
                      ],
                    ),

                    // Page Reorder Quick Controls (when multiple pages exist)
                    if (pageCount > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: safeIndex > 0
                                ? () => _movePageOrder(safeIndex, safeIndex - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('Move Left'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: safeIndex < pageCount - 1
                                ? () => _movePageOrder(safeIndex, safeIndex + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('Move Right'),
                          ),
                        ],
                      ),
                    ],

                    // Contextual 2-in-1 ID Card Combine Banner
                    if (pageCount == 2) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: tokens.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              color: tokens.accent,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '2-in-1 ID Card Sheet',
                                    style: textTheme.titleSmall,
                                  ),
                                  Text(
                                    'Merge front & back pages on one A4 sheet',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ScaneliqTextButton(
                              label: 'Combine',
                              onPressed:
                                  _isExporting ? null : _stitch2In1IdCard,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Bottom Thumbnail Strip & Primary Save Dock
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(
                  top: BorderSide(color: tokens.hairline, width: 1),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                      itemCount: pageCount + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index == pageCount) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _showAddPagesSheet,
                            child: Container(
                              width: 58,
                              height: 76,
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: tokens.hairline),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    color: tokens.accent,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ADD',
                                    style: ScaneliqTypography.monoStyle(
                                      color: tokens.accent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final page = session.pages[index];
                        final file = File(
                          page.processedPath ?? page.originalPath,
                        );
                        final isSelected = index == safeIndex;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPageIndex = index),
                          child: Container(
                            width: 58,
                            height: 76,
                            decoration: BoxDecoration(
                              color: tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.accent
                                    : tokens.hairline,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (file.existsSync())
                                  Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    cacheWidth: 220,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.description_outlined,
                                      color: tokens.textTertiary,
                                      size: 20,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.description_outlined,
                                    color: tokens.textTertiary,
                                    size: 20,
                                  ),
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? tokens.accent
                                          : ScaneliqColorPalette.cameraStudioBg
                                              .withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _twoDigits(index + 1),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingPagePlaceholder(ScaneliqTokens tokens) {
    return Container(
      color: tokens.surfaceSubtle,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 36,
          color: tokens.textTertiary,
        ),
      ),
    );
  }

  static String _twoDigits(int n) => n < 10 ? '0$n' : '$n';
}

class _ReviewStageActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;
  final bool destructive;

  const _ReviewStageActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color fg = destructive
        ? tokens.danger
        : accent
        ? tokens.accent
        : tokens.textPrimary;
    final Color bg = destructive
        ? tokens.dangerSoft
        : accent
        ? tokens.accentSoft
        : tokens.surface;
    final Color border = destructive
        ? tokens.danger.withValues(alpha: 0.35)
        : accent
        ? tokens.accent.withValues(alpha: 0.4)
        : tokens.hairline;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

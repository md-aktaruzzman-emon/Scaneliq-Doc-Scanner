import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/editor/presentation/edit_page_screen.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';

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

      final pdfFile = await PdfService.generatePdf(
        document: doc,
        pages: session.pages,
        customTitle: doc.title,
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

      // Invalidate library and draft providers
      ref.invalidate(documentsListProvider);
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
              'PDF document successfully created and saved locally with ${session.pages.length} pages.',
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Add More Pages',
            onPressed: () async {
              await ref
                  .read(scanSessionProvider.notifier)
                  .startScannerCapture();
            },
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
                    onPressed: () => ref
                        .read(scanSessionProvider.notifier)
                        .startScannerCapture(),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add page'),
                        onPressed: () => ref
                            .read(scanSessionProvider.notifier)
                            .startScannerCapture(),
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
                              Container(
                                width: 64,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: file.existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          file,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.image_not_supported),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Page ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Filter: ${page.editRecipe.filter.name.toUpperCase()} · ${page.editRecipe.rotationDegrees}°',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondaryLight,
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
                                onPressed: () async {
                                  final success = await ref
                                      .read(scanSessionProvider.notifier)
                                      .retakePage(page.id);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Retake cancelled or failed.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                tooltip: 'Delete Page',
                                onPressed: () {
                                  ref
                                      .read(scanSessionProvider.notifier)
                                      .removePage(page.id);
                                },
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
                      top: BorderSide(color: Theme.of(context).dividerColor),
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

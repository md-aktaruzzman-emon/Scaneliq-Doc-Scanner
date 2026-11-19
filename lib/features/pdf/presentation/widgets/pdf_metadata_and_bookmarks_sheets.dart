import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';

/// Opens the Concept A Page Bookmarks bottom sheet for quick bookmarking and navigation.
Future<void> showPdfBookmarksSheet({
  required BuildContext context,
  required String documentId,
  required int currentPage,
  required List<DocumentBookmark> initialBookmarks,
  required Future<List<DocumentBookmark>> Function() onReload,
  required ValueChanged<int> onJumpToPage,
}) async {
  List<DocumentBookmark> bookmarks = List.from(initialBookmarks);

  await showScaneliqBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final tokens = sheetCtx.tokens;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.62,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page Bookmarks',
                style: Theme.of(sheetCtx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Current Page: P$currentPage',
                    style: ScaneliqTypography.monoStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                    label: const Text('Bookmark Page'),
                    onPressed: () async {
                      final ctrl = TextEditingController(
                        text: 'Page $currentPage',
                      );
                      final title = await showDialog<String>(
                        context: sheetCtx,
                        builder: (dCtx) => AlertDialog(
                          title: Text('Bookmark Page $currentPage'),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Bookmark Label',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dCtx, ctrl.text.trim()),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      ctrl.dispose();
                      if (title != null && title.isNotEmpty) {
                        await AppDatabaseService.instance.addBookmark(
                          documentId: documentId,
                          pageNumber: currentPage,
                          title: title,
                        );
                        bookmarks = await onReload();
                        if (sheetCtx.mounted) setSheetState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: tokens.hairline, height: 1),
              const SizedBox(height: 8),
              if (bookmarks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bookmarks_outlined,
                        size: 36,
                        color: tokens.textTertiary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No bookmarks saved yet.\nTap "Bookmark Page" to pin key sections.',
                        textAlign: TextAlign.center,
                        style: Theme.of(sheetCtx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: tokens.hairline, height: 1),
                    itemBuilder: (_, idx) {
                      final b = bookmarks[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'P${b.pageNumber}',
                            style: ScaneliqTypography.monoStyle(
                              color: tokens.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          b.title,
                          style: Theme.of(sheetCtx).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          'Page ${b.pageNumber}',
                          style: Theme.of(sheetCtx).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: tokens.danger,
                            size: 20,
                          ),
                          onPressed: () async {
                            await AppDatabaseService.instance.deleteBookmark(
                              b.id,
                            );
                            bookmarks = await onReload();
                            if (sheetCtx.mounted) setSheetState(() {});
                          },
                        ),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          onJumpToPage(b.pageNumber);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Opens the Concept A PDF Properties & Metadata sheet, allowing inspection and
/// saving an updated PDF copy with new Title / Author metadata.
Future<void> showPdfMetadataSheet({
  required BuildContext context,
  required File pdfFile,
  required String fallbackTitle,
  ValueChanged<File>? onMetadataUpdatedPdf,
}) async {
  final info = await AdvancedPdfService.instance.inspectPdf(pdfFile);
  if (!context.mounted) return;

  final titleCtrl = TextEditingController(text: info.title ?? fallbackTitle);
  final authorCtrl = TextEditingController(text: info.author ?? '');
  final sizeKb = (info.fileSizeBytes / 1024).toStringAsFixed(1);
  final sizeMb = (info.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
  bool isSaving = false;

  await showScaneliqBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final tokens = sheetCtx.tokens;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF Properties & Metadata',
              style: Theme.of(sheetCtx).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.hairline),
              ),
              child: Column(
                children: [
                  _MetaRow(label: 'Pages', value: '${info.pageCount} pages'),
                  _MetaRow(
                    label: 'File Size',
                    value: '$sizeKb KB ($sizeMb MB)',
                  ),
                  _MetaRow(
                    label: 'Page Size',
                    value:
                        '${info.firstPageWidth.toStringAsFixed(0)} × ${info.firstPageHeight.toStringAsFixed(0)} pt',
                  ),
                  _MetaRow(
                    label: 'Security',
                    value: info.isEncrypted ? 'Password Encrypted' : 'Unlocked',
                  ),
                  if (info.producer != null)
                    _MetaRow(label: 'Producer', value: info.producer!),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!info.isEncrypted) ...[
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'PDF Title Metadata',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(labelText: 'Author Metadata'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setSheetState(() => isSaving = true);
                          try {
                            final outFile = await AdvancedPdfService.instance
                                .updateMetadata(
                                  sourcePdf: pdfFile,
                                  title: titleCtrl.text.trim(),
                                  author: authorCtrl.text.trim(),
                                  outputFileName:
                                      '${fallbackTitle}_meta_${DateTime.now().millisecondsSinceEpoch}',
                                );
                            onMetadataUpdatedPdf?.call(outFile);
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                          } finally {
                            if (sheetCtx.mounted) {
                              setSheetState(() => isSaving = false);
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Metadata to PDF Copy'),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
  titleCtrl.dispose();
  authorCtrl.dispose();
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: ScaneliqTypography.monoStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

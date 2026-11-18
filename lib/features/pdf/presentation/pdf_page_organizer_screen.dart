import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';

/// Concept A Interactive PDF Page Organizer supporting grid/list view switching,
/// multi-page selection, drag-and-drop reordering, 90-degree rotation,
/// duplication, confirmed deletion, page extraction, and PDF/image insertion.
class PdfPageOrganizerScreen extends StatefulWidget {
  final File pdfFile;
  final ScannedDocument? document;

  const PdfPageOrganizerScreen({
    super.key,
    required this.pdfFile,
    this.document,
  });

  @override
  State<PdfPageOrganizerScreen> createState() => _PdfPageOrganizerScreenState();
}

class _PdfPageOrganizerScreenState extends State<PdfPageOrganizerScreen> {
  late File _activePdfFile;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isGridView = true;
  String? _statusMessage;

  // Ordered list of 1-indexed source PDF page numbers
  List<int> _currentPages = [];
  final Map<int, int> _pageRotations = {};
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _activePdfFile = widget.pdfFile;
    _loadPdfPages();
  }

  Future<void> _loadPdfPages() async {
    setState(() => _isLoading = true);
    try {
      final count = await AdvancedPdfService.instance.getPageCount(_activePdfFile);
      if (mounted) {
        setState(() {
          _currentPages = List<int>.generate(count, (i) => i + 1);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showScaneliqToast(context, 'Failed to read PDF pages: $e');
      }
    }
  }

  void _toggleSelectPage(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAllOrNone() {
    setState(() {
      if (_selectedIndices.length == _currentPages.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices
          ..clear()
          ..addAll(List.generate(_currentPages.length, (i) => i));
      }
    });
  }

  void _rotateSelected() {
    setState(() {
      for (final idx in _selectedIndices) {
        final origPageNum = _currentPages[idx];
        final curr = _pageRotations[origPageNum] ?? 0;
        _pageRotations[origPageNum] = (curr + 90) % 360;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    if (_selectedIndices.length >= _currentPages.length) {
      showScaneliqToast(context, 'A PDF document must retain at least 1 page.');
      return;
    }

    final confirmed = await showScaneliqConfirmDialog(
      context: context,
      title: 'Delete ${_selectedIndices.length} Page(s)?',
      message: 'Selected pages will be removed from the arranged PDF copy.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      final toRemove = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in toRemove) {
        _currentPages.removeAt(idx);
      }
      _selectedIndices.clear();
    });
  }

  void _duplicateSelected() {
    if (_selectedIndices.isEmpty) return;
    setState(() {
      final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sorted) {
        _currentPages.insert(idx + 1, _currentPages[idx]);
      }
      _selectedIndices.clear();
    });
    showScaneliqToast(context, 'Duplicated selected page(s).');
  }

  Future<void> _extractSelected() async {
    if (_selectedIndices.isEmpty) return;
    final selectedPages =
        (_selectedIndices.toList()..sort()).map((i) => _currentPages[i]).toList();

    final ctrl = TextEditingController(
      text:
          'Extracted_${widget.document?.title ?? 'Document'}_${DateTime.now().millisecondsSinceEpoch}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Extract ${selectedPages.length} Page(s)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Output File Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Extract PDF'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Extracting ${selectedPages.length} page(s)...';
    });

    try {
      final outFile = await AdvancedPdfService.instance.extractPages(
        sourcePdf: _activePdfFile,
        pageNumbers: selectedPages,
        outputFileName: name,
      );
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        showScaneliqToast(
          context,
          'Extracted to ${outFile.uri.pathSegments.last}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        showScaneliqToast(context, 'Extraction failed: $e');
      }
    }
  }

  Future<void> _insertExternalFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (picked.isEmpty || picked.first.path == null) return;

    final file = File(picked.first.path!);
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    final insertPos = _selectedIndices.isNotEmpty
        ? _selectedIndices.first + 1
        : _currentPages.length;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Inserting ${isPdf ? 'PDF pages' : 'image'}...';
    });

    try {
      final outName = 'Inserted_${DateTime.now().millisecondsSinceEpoch}';
      final updatedFile = isPdf
          ? await AdvancedPdfService.instance.insertPagesFromPdf(
              sourcePdf: _activePdfFile,
              insertAfterPageIndex1Indexed: insertPos,
              pdfToInsert: file,
              outputFileName: outName,
            )
          : await AdvancedPdfService.instance.insertImageAsPage(
              sourcePdf: _activePdfFile,
              insertAfterPageIndex1Indexed: insertPos,
              imageFile: file,
              outputFileName: outName,
            );

      final newCount = await AdvancedPdfService.instance.getPageCount(updatedFile);
      if (mounted) {
        setState(() {
          _activePdfFile = updatedFile;
          _currentPages = List<int>.generate(newCount, (i) => i + 1);
          _selectedIndices.clear();
          _pageRotations.clear();
          _isProcessing = false;
          _statusMessage = null;
        });
        showScaneliqToast(context, 'Inserted pages ($newCount total).');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        showScaneliqToast(context, 'Insert failed: $e');
      }
    }
  }

  void _movePage(int fromIdx, int toIdx) {
    if (fromIdx == toIdx ||
        fromIdx < 0 ||
        toIdx < 0 ||
        fromIdx >= _currentPages.length ||
        toIdx >= _currentPages.length) {
      return;
    }
    setState(() {
      final moved = _currentPages.removeAt(fromIdx);
      _currentPages.insert(toIdx, moved);
      _selectedIndices.clear();
    });
  }

  Future<void> _saveChanges() async {
    if (_currentPages.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Saving organized PDF...';
    });

    try {
      final baseName = widget.document?.title ?? 'Organized_Document';
      File outputFile = await AdvancedPdfService.instance.reorderPages(
        sourcePdf: _activePdfFile,
        newPageOrder1Indexed: _currentPages,
        outputFileName: '${baseName}_organized_${DateTime.now().millisecondsSinceEpoch}',
      );

      final newRotations = <int, int>{};
      for (int i = 0; i < _currentPages.length; i++) {
        final deg = _pageRotations[_currentPages[i]] ?? 0;
        if (deg != 0) newRotations[i + 1] = deg;
      }
      if (newRotations.isNotEmpty) {
        outputFile = await AdvancedPdfService.instance.rotatePages(
          sourcePdf: outputFile,
          pageRotationsDegrees: newRotations,
          outputFileName: '${baseName}_final_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      if (widget.document != null) {
        try {
          await AppDatabaseService.instance.saveDocument(
            widget.document!.copyWith(
              exportPath: outputFile.path,
              pageCount: _currentPages.length,
              modifiedAt: DateTime.now(),
            ),
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        Navigator.of(context).pop(outputFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        showScaneliqToast(context, 'Failed to save changes: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasSelection = _selectedIndices.isNotEmpty;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document?.title ?? 'Organize Pages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${_currentPages.length} pages · ${hasSelection ? '${_selectedIndices.length} selected' : 'Tap to select'}',
              style: ScaneliqTypography.monoStyle(
                color: hasSelection ? tokens.accent : tokens.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'List View' : 'Grid View',
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            tooltip: 'Select All',
            icon: Icon(
              _selectedIndices.length == _currentPages.length &&
                      _currentPages.isNotEmpty
                  ? Icons.deselect_outlined
                  : Icons.select_all_rounded,
            ),
            onPressed: _currentPages.isNotEmpty ? _selectAllOrNone : null,
          ),
          IconButton(
            tooltip: 'Insert PDF or Image',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _isProcessing ? null : _insertExternalFile,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: _isProcessing || _currentPages.isEmpty
                  ? null
                  : _saveChanges,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: tokens.accent))
          else if (_currentPages.isEmpty)
            const Center(child: Text('No pages remaining in document.'))
          else if (_isGridView)
            GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _currentPages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (ctx, i) => _buildGridCard(tokens, i),
            )
          else
            ReorderableListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _currentPages.length,
              onReorderItem: (oldIdx, newIdx) {
                _movePage(oldIdx, newIdx);
              },
              itemBuilder: (ctx, i) => _buildListCard(tokens, i),
            ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: tokens.accent),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage ?? 'Updating PDF...',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
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
              _OrganizerAction(
                icon: Icons.rotate_right_rounded,
                label: 'Rotate 90°',
                enabled: hasSelection,
                onTap: _rotateSelected,
              ),
              _OrganizerAction(
                icon: Icons.content_copy_outlined,
                label: 'Duplicate',
                enabled: hasSelection,
                onTap: _duplicateSelected,
              ),
              _OrganizerAction(
                icon: Icons.file_upload_outlined,
                label: 'Extract',
                enabled: hasSelection,
                onTap: _extractSelected,
              ),
              _OrganizerAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                enabled: hasSelection,
                color: tokens.danger,
                onTap: _deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(ScaneliqTokens tokens, int index) {
    final origPage = _currentPages[index];
    final isSelected = _selectedIndices.contains(index);
    final rotation = _pageRotations[origPage] ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggleSelectPage(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.hairline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: tokens.paperShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: isSelected ? tokens.accent : tokens.textTertiary,
                ),
                const Spacer(),
                if (rotation != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$rotation°',
                      style: ScaneliqTypography.monoStyle(
                        color: tokens.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Transform.rotate(
                angle: rotation * 3.14159265 / 180.0,
                child: _buildPagePreviewTile(tokens, index + 1, origPage),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: index > 0 ? () => _movePage(index, index - 1) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: index > 0
                              ? tokens.textPrimary
                              : tokens.textTertiary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: index < _currentPages.length - 1
                          ? () => _movePage(index, index + 1)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: index < _currentPages.length - 1
                              ? tokens.textPrimary
                              : tokens.textTertiary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(ScaneliqTokens tokens, int index) {
    final origPage = _currentPages[index];
    final isSelected = _selectedIndices.contains(index);
    final rotation = _pageRotations[origPage] ?? 0;

    return Card(
      key: ValueKey('org_list_${origPage}_$index'),
      color: tokens.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? tokens.accent : tokens.hairline,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _toggleSelectPage(index),
        leading: Icon(
          isSelected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: isSelected ? tokens.accent : tokens.textTertiary,
        ),
        title: Text('Page ${index + 1}'),
        subtitle: Text(
          'Source page #$origPage${rotation != 0 ? ' · Rotated $rotation°' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Icon(Icons.drag_handle_rounded, color: tokens.textTertiary),
      ),
    );
  }

  Widget _buildPagePreviewTile(
    ScaneliqTokens tokens,
    int displayIndex,
    int origPageNum,
  ) {
    final pages = widget.document?.pages ?? const [];
    final modelIdx = origPageNum - 1;
    final imgPath = (modelIdx >= 0 && modelIdx < pages.length)
        ? (pages[modelIdx].processedPath ?? pages[modelIdx].originalPath)
        : null;
    final file = imgPath != null ? File(imgPath) : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.paperBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null && file.existsSync()
          ? Image.file(file, fit: BoxFit.cover, cacheWidth: 260)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 28,
                    color: tokens.accent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P$displayIndex',
                    style: ScaneliqTypography.monoStyle(
                      color: tokens.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _OrganizerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color? color;

  const _OrganizerAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectiveColor = enabled
        ? (color ?? tokens.textPrimary)
        : tokens.textTertiary.withValues(alpha: 0.4);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: effectiveColor),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ScaneliqTypography.bodyFontFamily,
                  color: effectiveColor,
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

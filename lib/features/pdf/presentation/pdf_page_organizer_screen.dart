import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';

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
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _statusMessage;

  // Pages currently in order: list of 1-indexed original page numbers
  late List<int> _currentPages;
  // Rotation degrees for each 1-indexed page (0, 90, 180, 270)
  final Map<int, int> _pageRotations = {};
  // Selected page indices in the _currentPages list
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadPdfPages();
  }

  Future<void> _loadPdfPages() async {
    setState(() => _isLoading = true);
    try {
      final count = await AdvancedPdfService.instance.getPageCount(
        widget.pdfFile,
      );
      setState(() {
        _currentPages = List<int>.generate(count, (i) => i + 1);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PDF pages: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _currentPages.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(_currentPages.length, (i) => i));
      }
    });
  }

  void _rotateSelected() {
    if (_selectedIndices.isEmpty) return;
    setState(() {
      for (final idx in _selectedIndices) {
        final pNum = _currentPages[idx];
        final currentAngle = _pageRotations[pNum] ?? 0;
        _pageRotations[pNum] = (currentAngle + 90) % 360;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rotated ${_selectedIndices.length} page(s) by 90°.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;

    if (_selectedIndices.length == _currentPages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete all pages from the PDF.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Pages'),
        content: Text(
          'Are you sure you want to remove ${_selectedIndices.length} page(s)? This will not affect the original file until saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        final toRemove = _selectedIndices.map((i) => _currentPages[i]).toSet();
        _currentPages.removeWhere((p) => toRemove.contains(p));
        _selectedIndices.clear();
      });
    }
  }

  void _duplicateSelected() {
    if (_selectedIndices.isEmpty) return;
    setState(() {
      // Duplicate each selected page in place
      final sortedIndices = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final idx in sortedIndices) {
        final item = _currentPages[idx];
        _currentPages.insert(idx + 1, item);
      }
      _selectedIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Duplicated selected page(s).'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _extractSelected() async {
    if (_selectedIndices.isEmpty) return;

    final selectedPages = _selectedIndices
        .map((i) => _currentPages[i])
        .toList();
    final nameController = TextEditingController(
      text: 'Extracted_${DateTime.now().millisecondsSinceEpoch}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extract Pages to New PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extracting ${selectedPages.length} page(s): ${selectedPages.join(", ")}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'New PDF Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Extract'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Extracting pages...';
      });

      try {
        final outName = nameController.text.trim();
        final extractedFile = await AdvancedPdfService.instance.extractPages(
          sourcePdf: widget.pdfFile,
          pageNumbers: selectedPages,
          outputFileName: outName,
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });

        if (mounted) {
          _showOutputDialog('Pages Extracted Successfully', extractedFile);
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Extraction failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
      _statusMessage = 'Inserting external ${isPdf ? 'PDF' : 'image'}...';
    });

    try {
      final outName = 'Modified_${DateTime.now().millisecondsSinceEpoch}';
      File updatedFile;
      if (isPdf) {
        updatedFile = await AdvancedPdfService.instance.insertPagesFromPdf(
          sourcePdf: widget.pdfFile,
          insertAfterPageIndex1Indexed: insertPos,
          pdfToInsert: file,
          outputFileName: outName,
        );
      } else {
        updatedFile = await AdvancedPdfService.instance.insertImageAsPage(
          sourcePdf: widget.pdfFile,
          insertAfterPageIndex1Indexed: insertPos,
          imageFile: file,
          outputFileName: outName,
        );
      }

      final newCount = await AdvancedPdfService.instance.getPageCount(
        updatedFile,
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
        _currentPages = List.generate(newCount, (i) => i + 1);
        _selectedIndices.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inserted into document ($newCount pages total).'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insert failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final nameController = TextEditingController(
      text: widget.document != null
          ? '${widget.document!.title}_organized'
          : 'Organized_${DateTime.now().millisecondsSinceEpoch}',
    );

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Page Organization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saving ${_currentPages.length} pages in current visual order.',
            ),
            if (_pageRotations.isNotEmpty)
              Text(
                'Applying ${_pageRotations.length} custom page rotation(s).',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'PDF Document Name',
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
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save as New PDF'),
          ),
        ],
      ),
    );

    if (choice == null || choice.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Generating organized PDF...';
    });

    try {
      // 1. First reorder pages according to current sequence
      File finalFile = await AdvancedPdfService.instance.reorderPages(
        sourcePdf: widget.pdfFile,
        newPageOrder1Indexed: _currentPages,
        outputFileName: '${choice}_temp',
      );

      // 2. If any rotations were specified, apply them
      if (_pageRotations.isNotEmpty) {
        final mapRotations = <int, int>{};
        for (int i = 0; i < _currentPages.length; i++) {
          final origPage = _currentPages[i];
          if (_pageRotations.containsKey(origPage)) {
            mapRotations[i + 1] = _pageRotations[origPage]!;
          }
        }
        if (mapRotations.isNotEmpty) {
          final rotated = await AdvancedPdfService.instance.rotatePages(
            sourcePdf: finalFile,
            pageRotationsDegrees: mapRotations,
            outputFileName: choice,
          );
          if (finalFile.existsSync()) finalFile.deleteSync();
          finalFile = rotated;
        }
      } else {
        // Rename temp to final
        final finalPath = finalFile.path.replaceAll('_temp.pdf', '.pdf');
        if (finalFile.path != finalPath) {
          finalFile = await finalFile.rename(finalPath);
        }
      }

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showOutputDialog('PDF Successfully Organized', finalFile);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showOutputDialog(String title, File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('Saved output:\n${file.path}'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Open Viewer'),
            onPressed: () {
              Navigator.pop(ctx);
              final doc = ScannedDocument(
                id: 'org_${DateTime.now().millisecondsSinceEpoch}',
                title: file.path
                    .split(Platform.pathSeparator)
                    .last
                    .replaceAll('.pdf', ''),
                createdAt: DateTime.now(),
                modifiedAt: DateTime.now(),
                pageCount: _currentPages.length,
                exportPath: file.path,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: doc),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document != null
              ? widget.document!.title
              : 'Organize PDF Pages',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedIndices.length == _currentPages.length &&
                      _currentPages.isNotEmpty
                  ? Icons.select_all
                  : Icons.checklist,
            ),
            tooltip: 'Select All / None',
            onPressed: _currentPages.isNotEmpty ? _selectAll : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_to_photos_outlined),
            tooltip: 'Insert Pages / Image',
            onPressed: _isProcessing ? null : _insertExternalFile,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: _isProcessing || _currentPages.isEmpty
                ? null
                : _saveChanges,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentPages.isEmpty)
            const Center(child: Text('No pages remaining in document.'))
          else
            Column(
              children: [
                // Info & Selection bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isDark
                      ? AppColors.surface2Dark
                      : AppColors.surface2Light,
                  child: Row(
                    children: [
                      Text(
                        '${_currentPages.length} Pages · Drag to reorder',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIndices.isNotEmpty)
                        Text(
                          '${_selectedIndices.length} selected',
                          style: const TextStyle(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),

                // Reorderable Pages Grid
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.all(12),
                    onReorderItem: (oldIdx, newIdx) {
                      setState(() {
                        final item = _currentPages.removeAt(oldIdx);
                        _currentPages.insert(newIdx, item);
                        _selectedIndices.clear();
                      });
                    },
                    children: [
                      for (int i = 0; i < _currentPages.length; i++)
                        _buildPageCard(
                          key: ValueKey('page_${_currentPages[i]}_$i'),
                          displayIndex: i + 1,
                          originalPageNum: _currentPages[i],
                          isSelected: _selectedIndices.contains(i),
                          onTap: () => _toggleSelectPage(i),
                          rotation: _pageRotations[_currentPages[i]] ?? 0,
                          isDark: isDark,
                        ),
                    ],
                  ),
                ),
              ],
            ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage ?? 'Processing PDF...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // Bottom Action Toolbar for Selected Pages
      bottomNavigationBar: _selectedIndices.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.rotate_right_rounded),
                      tooltip: 'Rotate 90°',
                      onPressed: _rotateSelected,
                    ),
                    IconButton(
                      icon: const Icon(Icons.control_point_duplicate_rounded),
                      tooltip: 'Duplicate',
                      onPressed: _duplicateSelected,
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined),
                      tooltip: 'Extract Pages',
                      onPressed: _extractSelected,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete Pages',
                      onPressed: _deleteSelected,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPageCard({
    required Key key,
    required int displayIndex,
    required int originalPageNum,
    required bool isSelected,
    required VoidCallback onTap,
    required int rotation,
    required bool isDark,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppColors.brandPrimary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.brandPrimary : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 14),

              // Page thumbnail placeholder / icon
              Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: AppColors.brandPrimary,
                      ),
                      Text(
                        '$displayIndex',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page $displayIndex',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Original Page: #$originalPageNum',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Rotation indicator if rotated
              if (rotation != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.rotate_90_degrees_ccw,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$rotation°',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

              // Drag handle
              const Icon(Icons.drag_handle, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

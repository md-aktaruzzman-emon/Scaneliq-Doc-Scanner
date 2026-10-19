import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _restoreSingle(ScannedDocument doc) async {
    await AppDatabaseService.instance.restoreFromTrash(doc.id);
    ref.invalidate(trashedDocumentsProvider);
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored "${doc.title}" to library.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restoreBatch() async {
    final count = _selectedIds.length;
    await AppDatabaseService.instance.restoreDocumentsFromTrash(
      _selectedIds.toList(),
    );
    _exitSelectionMode();
    ref.invalidate(trashedDocumentsProvider);
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $count documents to library.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _permanentDeleteSingle(ScannedDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'Are you sure you want to permanently delete "${doc.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabaseService.instance.permanentlyDelete(doc.id);
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
    }
  }

  Future<void> _permanentDeleteBatch() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Documents Permanently?'),
        content: const Text(
          'This will permanently delete all selected documents and their source files. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabaseService.instance.permanentlyDeleteDocuments(
        _selectedIds.toList(),
      );
      _exitSelectionMode();
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
    }
  }

  Future<void> _emptyTrash(List<ScannedDocument> docs) async {
    if (docs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
          'Permanently delete all ${docs.length} documents in Trash? All associated scan images will be purged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Empty Trash',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ids = docs.map((d) => d.id).toList();
      await AppDatabaseService.instance.permanentlyDeleteDocuments(ids);
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trashedAsync = ref.watch(trashedDocumentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Trash',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (!_isSelectionMode)
            trashedAsync.maybeWhen(
              data: (docs) => docs.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'Empty Trash',
                      onPressed: () => _emptyTrash(docs),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.restore_from_trash),
              tooltip: 'Restore Selected',
              onPressed: _selectedIds.isNotEmpty ? _restoreBatch : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.error),
              tooltip: 'Permanently Delete Selected',
              onPressed: _selectedIds.isNotEmpty ? _permanentDeleteBatch : null,
            ),
          ],
        ],
      ),
      body: trashedAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 72,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Trash is Empty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleted documents are stored here for 30 days\nbefore being permanently purged.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final isSelected = _selectedIds.contains(doc.id);

              // Calculate days until 30-day expiration
              int daysRemaining = 30;
              if (doc.deletedAt != null) {
                final elapsed = DateTime.now()
                    .difference(doc.deletedAt!)
                    .inDays;
                daysRemaining = (30 - elapsed).clamp(0, 30);
              }

              final deletedDateStr = doc.deletedAt != null
                  ? DateFormat('MMM d, yyyy').format(doc.deletedAt!)
                  : 'Recently';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? const BorderSide(
                          color: AppColors.brandPrimary,
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(doc.id);
                    });
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(doc.id);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (_isSelectionMode) ...[
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(doc.id),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Thumbnail
                        Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surface2Dark
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              (doc.pages.isNotEmpty &&
                                  File(doc.pages.first.originalPath)
                                      .existsSync())
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(doc.pages.first.originalPath),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.description_outlined,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deleted $deletedDateStr · $daysRemaining days left',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: daysRemaining <= 3
                                      ? AppColors.error
                                      : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        if (!_isSelectionMode) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.restore_from_trash,
                              color: AppColors.brandPrimary,
                            ),
                            tooltip: 'Restore',
                            onPressed: () => _restoreSingle(doc),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: AppColors.error,
                            ),
                            tooltip: 'Permanently Delete',
                            onPressed: () => _permanentDeleteSingle(doc),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading Trash: $err')),
      ),
    );
  }
}

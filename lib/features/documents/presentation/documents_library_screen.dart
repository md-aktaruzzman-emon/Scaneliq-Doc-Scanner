import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/navigation/app_router.dart';
import 'package:scaneliq/core/services/smart_filename_service.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_buttons.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_document_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/core/widgets/scaneliq_search_field.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/data/batch_merge_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/documents/presentation/trash_screen.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

enum DocumentSortOption { newest, oldest, nameAsc, nameDesc }

enum FileCategoryFilter { all, favorites, pdfs, images }

/// Concept A (Editorial Gallery Minimal) Folders & Document Vault Experience (Tab 2).
class DocumentsLibraryScreen extends ConsumerStatefulWidget {
  const DocumentsLibraryScreen({super.key});

  @override
  ConsumerState<DocumentsLibraryScreen> createState() =>
      _DocumentsLibraryScreenState();
}

class _DocumentsLibraryScreenState
    extends ConsumerState<DocumentsLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentSortOption _sortOption = DocumentSortOption.newest;
  FileCategoryFilter _selectedCategory = FileCategoryFilter.all;

  // Hierarchical Folder Navigation
  String? _currentFolderId;
  DocumentFolder? _currentFolder;
  List<DocumentFolder> _folderAncestors = [];

  // Tag Filtering
  final Set<String> _selectedTagIds = {};

  // Multi-Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);
    ref.invalidate(foldersListProvider(_currentFolderId));
    ref.invalidate(foldersListProvider(null));
    ref.invalidate(tagsListProvider);
  }

  Future<void> _navigateToFolder(DocumentFolder? folder) async {
    setState(() {
      _currentFolderId = folder?.id;
      _currentFolder = folder;
    });

    if (folder != null) {
      final ancestors = await AppDatabaseService.instance.getFolderAncestors(
        folder.id,
      );
      if (mounted) setState(() => _folderAncestors = ancestors);
    } else {
      if (mounted) setState(() => _folderAncestors = []);
    }
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedDocIds.contains(docId)) {
        _selectedDocIds.remove(docId);
        if (_selectedDocIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedDocIds.add(docId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedDocIds.clear();
      _isSelectionMode = false;
    });
  }

  void _selectAll(List<ScannedDocument> docs) {
    setState(() {
      _selectedDocIds
        ..clear()
        ..addAll(docs.map((d) => d.id));
    });
  }

  Future<void> _startNewScan() async {
    ref.read(scanSessionProvider.notifier).resetSession();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ContinuousCameraScreen(mode: ScanMode.batch),
      ),
    );
  }

  Future<void> _importFiles() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles
            .where((p) => p.path != null)
            .map((p) => File(p.path!))
            .toList();

        if (files.isNotEmpty) {
          ref.read(scanSessionProvider.notifier).resetSession();
          final count = await ref
              .read(scanSessionProvider.notifier)
              .importFiles(files);
          if (count > 0 && mounted) {
            navigateToReviewPages(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'Could not import files: $e');
      }
    }
  }

  // ===========================================================================
  // FOLDER SHEETS & OPERATIONS
  // ===========================================================================

  Future<void> _showCreateFolderSheet() async {
    final controller = TextEditingController();
    final created = await showScaneliqBottomSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentFolder == null ? 'New Vault Folder' : 'New Subfolder',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Cycle-safe SQLite hierarchical folder',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g., Tax & Finance FY26',
            ),
            onSubmitted: (_) {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ScaneliqSecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaneliqPrimaryButton(
                  label: 'Create Folder',
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (created == true && controller.text.trim().isNotEmpty) {
      await AppDatabaseService.instance.createFolder(
        controller.text.trim(),
        parentId: _currentFolderId,
      );
      _invalidateAll();
      if (mounted) {
        showScaneliqToast(
          context,
          'Created folder "${controller.text.trim()}"',
        );
      }
    }
  }

  Future<void> _showRenameFolderSheet(DocumentFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final confirmed = await showScaneliqBottomSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Rename Folder', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder Name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ScaneliqSecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaneliqPrimaryButton(
                  label: 'Save Name',
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final trimmed = controller.text.trim();
      await AppDatabaseService.instance.renameFolder(folder.id, trimmed);
      _invalidateAll();
      if (mounted && _currentFolderId == folder.id) {
        setState(() {
          _currentFolder = folder.copyWith(name: trimmed);
          _folderAncestors = _folderAncestors
              .map((a) => a.id == folder.id ? a.copyWith(name: trimmed) : a)
              .toList();
        });
      }
    }
  }

  Future<void> _showDeleteFolderSheet(DocumentFolder folder) async {
    final choice = await showScaneliqBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete "${folder.name}"?',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose what happens to documents inside this folder:',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ScaneliqContextMenuRow(
            icon: Icons.drive_file_move_outline,
            title: 'Move Documents to Vault Root',
            subtitle: 'Keep all documents, delete folder only',
            onTap: () => Navigator.pop(ctx, 'root'),
          ),
          ScaneliqContextMenuRow(
            icon: Icons.delete_outline_rounded,
            title: 'Move Folder Contents to Trash',
            subtitle: 'Recoverable for 30 days inside Trash',
            titleColor: ctx.tokens.danger,
            onTap: () => Navigator.pop(ctx, 'trash'),
          ),
          const SizedBox(height: 12),
          ScaneliqSecondaryButton(
            label: 'Cancel',
            expand: true,
            onPressed: () => Navigator.pop(ctx, 'cancel'),
          ),
        ],
      ),
    );

    if (choice == 'root') {
      await AppDatabaseService.instance.deleteFolder(
        folder.id,
        moveDocsToRoot: true,
      );
      if (_currentFolderId == folder.id) {
        await _navigateToFolder(null);
      }
      _invalidateAll();
    } else if (choice == 'trash') {
      await AppDatabaseService.instance.deleteFolder(
        folder.id,
        moveDocsToRoot: false,
      );
      if (_currentFolderId == folder.id) {
        await _navigateToFolder(null);
      }
      _invalidateAll();
    }
  }

  void _showFolderActionsSheet(DocumentFolder folder) {
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  folder.name,
                  style: Theme.of(ctx).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ScaneliqStatusLabel(text: '${folder.documentCount} FILES'),
            ],
          ),
          const SizedBox(height: 10),
          ScaneliqContextMenuRow(
            icon: Icons.folder_open_rounded,
            title: 'Open Folder',
            onTap: () {
              Navigator.pop(ctx);
              _navigateToFolder(folder);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Rename Folder',
            onTap: () {
              Navigator.pop(ctx);
              _showRenameFolderSheet(folder);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Folder',
            titleColor: ctx.tokens.danger,
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteFolderSheet(folder);
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BATCH ACTIONS (MOVE, TAG, TRASH, MERGE)
  // ===========================================================================

  Future<void> _showMoveFolderSheet(List<String> docIds) async {
    final folderTree = await AppDatabaseService.instance.getFolderHierarchy();

    if (!mounted) return;
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Move ${docIds.length} Document${docIds.length > 1 ? 's' : ''}',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          ScaneliqContextMenuRow(
            icon: Icons.home_outlined,
            title: 'Vault Root (No Folder)',
            onTap: () async {
              Navigator.pop(ctx);
              await AppDatabaseService.instance.moveDocumentsToFolder(
                docIds,
                null,
              );
              _exitSelectionMode();
              _invalidateAll();
            },
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final entry in folderTree)
                    ScaneliqContextMenuRow(
                      icon: entry.depth > 0
                          ? Icons.subdirectory_arrow_right_rounded
                          : Icons.folder_outlined,
                      title: entry.breadcrumbPath,
                      trailing: ScaneliqStatusLabel(
                        text: '${entry.folder.documentCount} FILES',
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AppDatabaseService.instance.moveDocumentsToFolder(
                          docIds,
                          entry.folder.id,
                        );
                        _exitSelectionMode();
                        _invalidateAll();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignTagsSheet(List<String> docIds) async {
    final allTags = await AppDatabaseService.instance.getTags();
    final selectedTagIds = <String>{};

    if (docIds.length == 1) {
      final docTags = await AppDatabaseService.instance.getDocumentTags(
        docIds.first,
      );
      selectedTagIds.addAll(docTags.map((t) => t.id));
    }

    if (!mounted) return;
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assign Tags (${docIds.length})',
                  style: Theme.of(ctx).textTheme.headlineMedium,
                ),
                ScaneliqTextButton(
                  label: '+ New Tag',
                  onPressed: () async {
                    final nameController = TextEditingController();
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Create New Tag'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tag Name',
                            hintText: 'e.g., Medical',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    );
                    if (created == true &&
                        nameController.text.trim().isNotEmpty) {
                      final newTag = await AppDatabaseService.instance
                          .createTag(nameController.text.trim(), 0xFF0052FF);
                      setSheetState(() {
                        allTags.add(newTag);
                        selectedTagIds.add(newTag.id);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (allTags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No tags created yet. Tap + New Tag above.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in allTags)
                    FilterChip(
                      selected: selectedTagIds.contains(tag.id),
                      label: Text(tag.name),
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            selectedTagIds.add(tag.id);
                          } else {
                            selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ScaneliqSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ScaneliqPrimaryButton(
                    label: 'Apply Tags',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (docIds.length == 1) {
                        await AppDatabaseService.instance.setDocumentTags(
                          docIds.first,
                          selectedTagIds.toList(),
                        );
                      } else {
                        for (final tId in selectedTagIds) {
                          await AppDatabaseService.instance.addTagToDocuments(
                            docIds,
                            tId,
                          );
                        }
                      }
                      _exitSelectionMode();
                      _invalidateAll();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatchMergeDialog(List<ScannedDocument> docsToMerge) async {
    final titleController = TextEditingController(
      text: SmartFilenameService.generateFilename(
        template: SmartFilenameService.defaultTemplate,
        title: 'Consolidated',
        category: 'Merge',
        extension: '',
      ),
    );

    final orderedDocs = List<ScannedDocument>.from(docsToMerge);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Merge Documents into PDF'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Merged PDF Title',
                    prefixIcon: Icon(Icons.picture_as_pdf, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Drag to reorder documents:',
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    onReorderItem: (oldIdx, newIdx) {
                      setDialogState(() {
                        final item = orderedDocs.removeAt(oldIdx);
                        orderedDocs.insert(newIdx, item);
                      });
                    },
                    children: [
                      for (int i = 0; i < orderedDocs.length; i++)
                        ListTile(
                          key: ValueKey(orderedDocs[i].id),
                          dense: true,
                          leading: ScaneliqStatusLabel(text: '0${i + 1}'),
                          title: Text(orderedDocs[i].title, maxLines: 1),
                          subtitle: Text('${orderedDocs[i].pageCount} pages'),
                          trailing: const Icon(Icons.drag_handle, size: 20),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge to PDF'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && orderedDocs.isNotEmpty) {
      try {
        final merged = await BatchMergeService.instance.mergeDocuments(
          sourceDocuments: orderedDocs,
          outputTitle: titleController.text.trim(),
          folderId: _currentFolderId,
        );
        _exitSelectionMode();
        _invalidateAll();

        if (mounted) {
          showScaneliqToast(
            context,
            'Merged PDF "${merged.title}" saved.',
            actionLabel: 'View',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: merged),
                ),
              );
            },
          );
        }
      } catch (e) {
        if (mounted) {
          showScaneliqToast(context, 'Merge failed: $e');
        }
      }
    }
  }

  // ===========================================================================
  // SINGLE DOCUMENT ACTIONS
  // ===========================================================================

  Future<void> _moveToTrash(ScannedDocument doc) async {
    await AppDatabaseService.instance.moveToTrash(doc.id);
    _invalidateAll();
    if (mounted) {
      showScaneliqToast(
        context,
        'Moved "${doc.title}" to 30-day Trash.',
        actionLabel: 'Undo',
        onAction: () async {
          await AppDatabaseService.instance.restoreFromTrash(doc.id);
          _invalidateAll();
        },
      );
    }
  }

  Future<void> _renameDocumentWithSmartNaming(ScannedDocument doc) async {
    final controller = TextEditingController(text: doc.title);
    final confirmed = await showScaneliqBottomSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rename Document',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Document Title'),
          ),
          const SizedBox(height: 10),
          ScaneliqSecondaryButton(
            label: 'Apply Smart Filename Template',
            icon: Icons.auto_fix_high_outlined,
            onPressed: () {
              final categoryName = doc.tags.isNotEmpty
                  ? doc.tags.first.name
                  : 'Doc';
              controller.text = SmartFilenameService.generateFilename(
                template: SmartFilenameService.defaultTemplate,
                title: doc.title,
                category: categoryName,
                extension: '',
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ScaneliqSecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaneliqPrimaryButton(
                  label: 'Save Title',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await AppDatabaseService.instance.renameDocument(
        doc.id,
        controller.text.trim(),
      );
      _invalidateAll();
    }
  }

  Future<void> _shareDocument(ScannedDocument doc) async {
    String? path = doc.exportPath;
    if (path == null || !File(path).existsSync()) {
      final fullDoc = await AppDatabaseService.instance.getDocument(doc.id);
      if (fullDoc != null && fullDoc.pages.isNotEmpty) {
        if (mounted) {
          showScaneliqToast(context, 'Preparing PDF for sharing…');
        }
        try {
          final generated = await PdfService.generatePdf(
            document: fullDoc,
            pages: fullDoc.pages,
            customTitle: fullDoc.title,
          );
          path = generated.path;
          final updated = fullDoc.copyWith(exportPath: path, isDraft: false);
          await AppDatabaseService.instance.saveDocument(updated);
        } catch (e) {
          if (mounted) {
            showScaneliqToast(context, 'Failed to generate PDF: $e');
          }
          return;
        }
      }
    }

    if (path != null && File(path).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          text: doc.title,
          files: [XFile(path, mimeType: 'application/pdf')],
        ),
      );
    } else if (mounted) {
      showScaneliqToast(context, 'No PDF export file found for this scan.');
    }
  }

  void _showDocumentSheet(ScannedDocument doc) {
    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doc.title,
            style: Theme.of(ctx).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          ScaneliqDocumentMetadata(document: doc),
          const SizedBox(height: 12),
          ScaneliqContextMenuRow(
            icon: Icons.open_in_new_rounded,
            title: 'View Document',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: doc),
                ),
              );
            },
          ),
          ScaneliqContextMenuRow(
            icon: doc.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            title: doc.isFavorite ? 'Remove Starred' : 'Add to Starred',
            onTap: () async {
              Navigator.pop(ctx);
              await AppDatabaseService.instance.toggleFavorite(
                doc.id,
                !doc.isFavorite,
              );
              _invalidateAll();
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.ios_share_rounded,
            title: 'Share PDF',
            onTap: () {
              Navigator.pop(ctx);
              _shareDocument(doc);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Rename (Smart Name)',
            onTap: () {
              Navigator.pop(ctx);
              _renameDocumentWithSmartNaming(doc);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.copy_all_outlined,
            title: 'Duplicate Document',
            subtitle: 'Create an independent copy in this folder',
            onTap: () async {
              Navigator.pop(ctx);
              final copy = await AppDatabaseService.instance.duplicateDocument(
                doc.id,
              );
              _invalidateAll();
              if (mounted && copy != null) {
                showScaneliqToast(context, 'Duplicated "${copy.title}"');
              }
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.drive_file_move_outline,
            title: 'Move to Folder',
            onTap: () {
              Navigator.pop(ctx);
              _showMoveFolderSheet([doc.id]);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.label_outline_rounded,
            title: 'Assign Tags',
            onTap: () {
              Navigator.pop(ctx);
              _showAssignTagsSheet([doc.id]);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.delete_outline_rounded,
            title: 'Move to Trash',
            titleColor: ctx.tokens.danger,
            onTap: () {
              Navigator.pop(ctx);
              _moveToTrash(doc);
            },
          ),
        ],
      ),
    );
  }

  List<ScannedDocument> _filterAndSortDocs(List<ScannedDocument> docs) {
    final filtered = docs.where((doc) {
      if (_currentFolderId != null) {
        if (doc.folderId != _currentFolderId) return false;
      } else if (_searchQuery.isEmpty &&
          _selectedCategory == FileCategoryFilter.all &&
          _selectedTagIds.isEmpty) {
        // At vault root without active filter, keep unfiled docs or show all cleanly
      }
      if (_selectedCategory == FileCategoryFilter.favorites &&
          !doc.isFavorite) {
        return false;
      }
      if (_selectedCategory == FileCategoryFilter.pdfs &&
          (doc.exportPath == null ||
              !doc.exportPath!.toLowerCase().endsWith('.pdf'))) {
        return false;
      }
      if (_selectedCategory == FileCategoryFilter.images) {
        final hasPdf =
            doc.exportPath != null &&
            doc.exportPath!.toLowerCase().endsWith('.pdf');
        if (hasPdf && doc.pages.isEmpty) return false;
        if (hasPdf) return false;
      }
      if (_selectedTagIds.isNotEmpty) {
        final docTagIds = doc.tags.map((t) => t.id).toSet();
        if (!_selectedTagIds.any((id) => docTagIds.contains(id))) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case DocumentSortOption.newest:
        filtered.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case DocumentSortOption.oldest:
        filtered.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case DocumentSortOption.nameAsc:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case DocumentSortOption.nameDesc:
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(width);

    final docsAsync = ref.watch(searchedDocumentsProvider(_searchQuery));
    final foldersAsync = ref.watch(foldersListProvider(_currentFolderId));
    final tagsAsync = ref.watch(tagsListProvider);

    final visibleDocs = docsAsync.maybeWhen(
      data: _filterAndSortDocs,
      orElse: () => const <ScannedDocument>[],
    );

    final scopeIndex = switch (_selectedCategory) {
      FileCategoryFilter.all => 0,
      FileCategoryFilter.favorites => 1,
      FileCategoryFilter.pdfs => 2,
      FileCategoryFilter.images => 3,
    };

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: tokens.accent,
              onRefresh: () async => _invalidateAll(),
              child: CustomScrollView(
                slivers: [
                  // 1. Folders Editorial Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        ScaneliqSpacing.headerVerticalTop,
                        horizontalPad,
                        10,
                      ),
                      child: _isSelectionMode
                          ? _buildSelectionHeader(textTheme, docsAsync)
                          : _buildHeader(textTheme, tokens, foldersAsync),
                    ),
                  ),

                  // 2. Breadcrumb Trail
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        12,
                      ),
                      child: _buildBreadcrumbBar(tokens),
                    ),
                  ),

                  // 3. Search & Category Scopes
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        12,
                      ),
                      child: Column(
                        children: [
                          ScaneliqSearchField(
                            controller: _searchController,
                            hintText: 'Search documents...',
                            query: _searchQuery,
                            onChanged: (val) => setState(
                              () => _searchQuery = val.trim().toLowerCase(),
                            ),
                            onClear: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          ScaneliqScopeTabs(
                            items: const [
                              ScaneliqScopeItem(label: 'All'),
                              ScaneliqScopeItem(label: 'Starred'),
                              ScaneliqScopeItem(label: 'PDFs'),
                              ScaneliqScopeItem(label: 'Images'),
                            ],
                            selectedIndex: scopeIndex,
                            onSelected: (index) {
                              setState(() {
                                _selectedCategory = switch (index) {
                                  1 => FileCategoryFilter.favorites,
                                  2 => FileCategoryFilter.pdfs,
                                  3 => FileCategoryFilter.images,
                                  _ => FileCategoryFilter.all,
                                };
                              });
                            },
                            trailing: PopupMenuButton<DocumentSortOption>(
                              icon: Icon(
                                Icons.sort_rounded,
                                size: 19,
                                color: tokens.textSecondary,
                              ),
                              tooltip: 'Sort documents',
                              onSelected: (val) =>
                                  setState(() => _sortOption = val),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: DocumentSortOption.newest,
                                  child: Text('Newest first'),
                                ),
                                PopupMenuItem(
                                  value: DocumentSortOption.oldest,
                                  child: Text('Oldest first'),
                                ),
                                PopupMenuItem(
                                  value: DocumentSortOption.nameAsc,
                                  child: Text('Name (A–Z)'),
                                ),
                                PopupMenuItem(
                                  value: DocumentSortOption.nameDesc,
                                  child: Text('Name (Z–A)'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Optional Tag Filter Strip
                  tagsAsync.maybeWhen(
                    data: (tags) {
                      if (tags.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }
                      return SliverToBoxAdapter(
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            itemCount: tags.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isAll = _selectedTagIds.isEmpty;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    selected: isAll,
                                    label: const Text('All Tags'),
                                    onSelected: (_) =>
                                        setState(() => _selectedTagIds.clear()),
                                  ),
                                );
                              }
                              final t = tags[index - 1];
                              final selected = _selectedTagIds.contains(t.id);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  selected: selected,
                                  label: Text(t.name),
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedTagIds.add(t.id);
                                      } else {
                                        _selectedTagIds.remove(t.id);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    orElse: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  // 5. Hierarchical Folders Table
                  foldersAsync.when(
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, _) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    data: (folders) {
                      if (folders.isEmpty && _currentFolderId != null) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScaneliqSectionHeader(
                                title: _currentFolder == null
                                    ? 'Hierarchical Folders'
                                    : 'Subfolders',
                                trailing: const ScaneliqStatusLabel(
                                  text: 'CYCLE-SAFE',
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (folders.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: tokens.hairline,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'No folders yet — organize scans into vaults',
                                        style: textTheme.bodySmall,
                                      ),
                                      ScaneliqTextButton(
                                        label: '+ New Folder',
                                        onPressed: _showCreateFolderSheet,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    for (final f in folders)
                                      _FolderHairlineRow(
                                        folder: f,
                                        onTap: () => _navigateToFolder(f),
                                        onMoreTap: () =>
                                            _showFolderActionsSheet(f),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // 6. Documents Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        18,
                        horizontalPad,
                        4,
                      ),
                      child: ScaneliqSectionHeader(
                        title: _currentFolder?.name ?? 'All Vault Documents',
                        actionLabel: visibleDocs.isNotEmpty && !_isSelectionMode
                            ? 'Batch Select'
                            : null,
                        onAction: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedDocIds.clear();
                          });
                        },
                      ),
                    ),
                  ),

                  // 7. Documents Stream
                  docsAsync.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: ScaneliqLoadingIndicator(),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: ScaneliqEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Error loading documents',
                        description: '$err',
                      ),
                    ),
                    data: (_) {
                      if (visibleDocs.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 84),
                            child: ScaneliqEmptyState(
                              icon:
                                  _searchQuery.isNotEmpty ||
                                      _selectedTagIds.isNotEmpty ||
                                      _selectedCategory !=
                                          FileCategoryFilter.all
                                  ? Icons.search_off_rounded
                                  : Icons.folder_open_rounded,
                              title: _searchQuery.isNotEmpty
                                  ? 'No matching documents'
                                  : (_currentFolder != null
                                        ? 'Folder is empty'
                                        : 'No documents yet'),
                              description: _searchQuery.isNotEmpty
                                  ? 'Try clearing your search query or removing active filters.'
                                  : 'Scan receipts, contracts, or import files directly into this vault.',
                              primaryActionLabel: _searchQuery.isEmpty
                                  ? 'Scan document'
                                  : null,
                              onPrimaryAction: _startNewScan,
                              secondaryActionLabel: _searchQuery.isEmpty
                                  ? 'Import files'
                                  : null,
                              onSecondaryAction: _importFiles,
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          0,
                          horizontalPad,
                          92,
                        ),
                        sliver: SliverList.builder(
                          itemCount: visibleDocs.length,
                          itemBuilder: (context, index) {
                            final doc = visibleDocs[index];
                            final selected = _selectedDocIds.contains(doc.id);
                            return ScaneliqDocumentRow(
                              document: doc,
                              selectionMode: _isSelectionMode,
                              isSelected: selected,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(doc.id);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DocumentViewerScreen(document: doc),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedDocIds.add(doc.id);
                                });
                              },
                              onMoreTap: _isSelectionMode
                                  ? null
                                  : () => _showDocumentSheet(doc),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 8. Floating Scan CTA or Batch Dock
            if (_isSelectionMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBatchDock(tokens, docsAsync),
              )
            else
              Positioned(
                right: horizontalPad,
                bottom: ScaneliqSpacing.fabClusterBottomGap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: ScaneliqRadius.pillBorderRadius,
                    boxShadow: tokens.floatingShadow,
                  ),
                  child: ScaneliqPrimaryButton(
                    label: _currentFolder != null
                        ? 'Scan to Folder'
                        : 'Scan Document',
                    icon: Icons.camera_alt_outlined,
                    height: 48,
                    onPressed: _startNewScan,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    TextTheme textTheme,
    ScaneliqTokens tokens,
    AsyncValue<List<DocumentFolder>> foldersAsync,
  ) {
    final folderCount = foldersAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (_currentFolderId != null) ...[
                ScaneliqIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Up one folder',
                  onPressed: () {
                    if (_folderAncestors.length > 1) {
                      _navigateToFolder(
                        _folderAncestors[_folderAncestors.length - 2],
                      );
                    } else {
                      _navigateToFolder(null);
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  _currentFolder?.name ?? 'Folders',
                  style: textTheme.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_currentFolderId == null) ...[
                const SizedBox(width: 8),
                ScaneliqStatusLabel(text: '$folderCount VAULTS'),
              ],
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaneliqIconButton(
              icon: Icons.create_new_folder_outlined,
              tooltip: 'New Folder',
              onPressed: _showCreateFolderSheet,
            ),
            ScaneliqIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: '30-Day Trash',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(
    TextTheme textTheme,
    AsyncValue<List<ScannedDocument>> docsAsync,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ScaneliqIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cancel selection',
              onPressed: _exitSelectionMode,
            ),
            const SizedBox(width: 6),
            Text(
              '${_selectedDocIds.length} Selected',
              style: textTheme.headlineMedium,
            ),
          ],
        ),
        ScaneliqTextButton(
          label: 'Select all',
          onPressed: () {
            docsAsync.whenData((docs) => _selectAll(_filterAndSortDocs(docs)));
          },
        ),
      ],
    );
  }

  Widget _buildBreadcrumbBar(ScaneliqTokens tokens) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToFolder(null),
                    child: Text(
                      'VAULT ROOT',
                      style: ScaneliqTypography.monoStyle(
                        color: _currentFolderId == null
                            ? tokens.textSecondary
                            : tokens.accent,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  if (_currentFolderId == null)
                    Text(
                      ' / ALL FOLDERS',
                      style: ScaneliqTypography.monoStyle(
                        color: tokens.textSecondary,
                        fontSize: 10.5,
                      ),
                    )
                  else
                    for (final anc in _folderAncestors) ...[
                      Text(
                        ' / ',
                        style: ScaneliqTypography.monoStyle(
                          color: tokens.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateToFolder(anc),
                        child: Text(
                          anc.name.toUpperCase(),
                          style: ScaneliqTypography.monoStyle(
                            color: anc.id == _currentFolderId
                                ? tokens.textPrimary
                                : tokens.accent,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
          if (_currentFolder != null)
            ScaneliqTextButton(
              label: 'Folder Options',
              onPressed: () => _showFolderActionsSheet(_currentFolder!),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchDock(
    ScaneliqTokens tokens,
    AsyncValue<List<ScannedDocument>> docsAsync,
  ) {
    final hasAny = _selectedDocIds.isNotEmpty;
    final canMerge = _selectedDocIds.length >= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.hairline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ScaneliqIconButton(
            icon: Icons.drive_file_move_outlined,
            tooltip: 'Move to Folder',
            onPressed: hasAny
                ? () => _showMoveFolderSheet(_selectedDocIds.toList())
                : null,
          ),
          ScaneliqIconButton(
            icon: Icons.label_outline_rounded,
            tooltip: 'Assign Tags',
            onPressed: hasAny
                ? () => _showAssignTagsSheet(_selectedDocIds.toList())
                : null,
          ),
          ScaneliqIconButton(
            icon: Icons.merge_type_rounded,
            tooltip: 'Merge to PDF',
            color: canMerge ? tokens.accent : tokens.textTertiary,
            onPressed: canMerge
                ? () {
                    docsAsync.whenData((allDocs) {
                      final selected = allDocs
                          .where((d) => _selectedDocIds.contains(d.id))
                          .toList();
                      _showBatchMergeDialog(selected);
                    });
                  }
                : null,
          ),
          ScaneliqIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Move to Trash',
            color: tokens.danger,
            onPressed: hasAny
                ? () async {
                    final count = _selectedDocIds.length;
                    await AppDatabaseService.instance.moveDocumentsToTrash(
                      _selectedDocIds.toList(),
                    );
                    _exitSelectionMode();
                    _invalidateAll();
                    if (mounted) {
                      showScaneliqToast(
                        context,
                        'Moved $count document(s) to Trash.',
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _FolderHairlineRow extends StatelessWidget {
  final DocumentFolder folder;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _FolderHairlineRow({
    required this.folder,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onMoreTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 22, color: tokens.textPrimary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('Local Vault Folder', style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ScaneliqStatusLabel(text: '${folder.documentCount} FILES'),
            ScaneliqIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Folder options',
              size: 34,
              color: tokens.textTertiary,
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

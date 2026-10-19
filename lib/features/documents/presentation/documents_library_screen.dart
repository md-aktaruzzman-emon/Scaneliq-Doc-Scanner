import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/services/smart_filename_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/data/batch_merge_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/documents/presentation/trash_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

enum DocumentSortOption { newest, oldest, nameAsc, nameDesc }

enum FileCategoryFilter { all, favorites, pdfs, images }

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
      _selectedDocIds.clear();
      _selectedDocIds.addAll(docs.map((d) => d.id));
    });
  }

  // ===========================================================================
  // FOLDER DIALOGS & ACTIONS
  // ===========================================================================

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_currentFolder == null ? 'New Folder' : 'New Subfolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g., Tax Documents',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create'),
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
    }
  }

  Future<void> _showRenameFolderDialog(DocumentFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await AppDatabaseService.instance.renameFolder(
        folder.id,
        controller.text.trim(),
      );
      _invalidateAll();
      if (_currentFolderId == folder.id) {
        final updated = await AppDatabaseService.instance.getFolder(folder.id);
        if (mounted) setState(() => _currentFolder = updated);
      }
    }
  }

  Future<void> _showDeleteFolderDialog(DocumentFolder folder) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text(
          'Choose what should happen to documents inside this folder:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'trash'),
            child: const Text('Move to Trash'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'root'),
            child: const Text('Move to Library Root'),
          ),
        ],
      ),
    );

    if (choice == 'root') {
      await AppDatabaseService.instance.deleteFolder(
        folder.id,
        moveDocsToRoot: true,
      );
      if (_currentFolderId == folder.id) _navigateToFolder(null);
      _invalidateAll();
    } else if (choice == 'trash') {
      await AppDatabaseService.instance.deleteFolder(
        folder.id,
        moveDocsToRoot: false,
      );
      if (_currentFolderId == folder.id) _navigateToFolder(null);
      _invalidateAll();
    }
  }

  // ===========================================================================
  // BATCH ACTIONS (MOVE, TAG, TRASH, MERGE)
  // ===========================================================================

  Future<void> _showMoveFolderSheet(List<String> docIds) async {
    final allFolders = await AppDatabaseService.instance.getFolders();

    if (!mounted) return;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Move ${docIds.length} Document(s) to:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.home_outlined,
                  color: AppColors.brandPrimary,
                ),
                title: const Text('Library Root (No Folder)'),
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
              for (final f in allFolders)
                ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.brandPrimary,
                  ),
                  title: Text(f.name),
                  subtitle: Text('${f.documentCount} items'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await AppDatabaseService.instance.moveDocumentsToFolder(
                      docIds,
                      f.id,
                    );
                    _exitSelectionMode();
                    _invalidateAll();
                  },
                ),
            ],
          ),
        ),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assign Tags (${docIds.length} doc${docIds.length > 1 ? 's' : ''})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Tag'),
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
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                          );
                          if (created == true &&
                              nameController.text.trim().isNotEmpty) {
                            final newTag = await AppDatabaseService.instance
                                .createTag(
                                  nameController.text.trim(),
                                  0xFF2563EB,
                                );
                            setSheetState(() {
                              allTags.add(newTag);
                              selectedTagIds.add(newTag.id);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in allTags)
                        FilterChip(
                          selected: selectedTagIds.contains(tag.id),
                          avatar: CircleAvatar(
                            backgroundColor: Color(tag.colorValue),
                            radius: 6,
                          ),
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (docIds.length == 1) {
                            await AppDatabaseService.instance.setDocumentTags(
                              docIds.first,
                              selectedTagIds.toList(),
                            );
                          } else {
                            for (final tId in selectedTagIds) {
                              await AppDatabaseService.instance
                                  .addTagToDocuments(docIds, tId);
                            }
                          }
                          _exitSelectionMode();
                          _invalidateAll();
                        },
                        child: const Text('Apply Tags'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
        builder: (ctx, setDialogState) {
          return AlertDialog(
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
                  const Text(
                    'Order of pages in merged document:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                            leading: CircleAvatar(
                              radius: 12,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.merge_type),
                label: const Text('Merge to PDF'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          );
        },
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merged PDF "${merged.title}" saved successfully!'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(document: merged),
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
              content: Text('Merge failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ===========================================================================
  // DOCUMENT SINGLE ACTIONS
  // ===========================================================================

  Future<void> _moveToTrash(ScannedDocument doc) async {
    await AppDatabaseService.instance.moveToTrash(doc.id);
    _invalidateAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${doc.title}" to Trash.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await AppDatabaseService.instance.restoreFromTrash(doc.id);
              _invalidateAll();
            },
          ),
        ),
      );
    }
  }

  Future<void> _renameDocumentWithSmartNaming(ScannedDocument doc) async {
    final controller = TextEditingController(text: doc.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Document Title'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Apply Smart Template'),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
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
    final hasExport =
        doc.exportPath != null && File(doc.exportPath!).existsSync();
    if (hasExport) {
      SharePlus.instance.share(
        ShareParams(text: doc.title, files: [XFile(doc.exportPath!)]),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No PDF export file found for this scan.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(searchedDocumentsProvider(_searchQuery));
    final foldersAsync = ref.watch(foldersListProvider(_currentFolderId));
    final tagsAsync = ref.watch(tagsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedDocIds.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : const Text(
                'Files',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : (_currentFolderId != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_folderAncestors.isNotEmpty) {
                          _navigateToFolder(
                            _folderAncestors.length > 1
                                ? _folderAncestors[_folderAncestors.length - 2]
                                : null,
                          );
                        } else {
                          _navigateToFolder(null);
                        }
                      },
                    )
                  : null),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: 'New Folder',
              onPressed: _showCreateFolderDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Trash',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _selectedCategory == FileCategoryFilter.favorites
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _selectedCategory == FileCategoryFilter.favorites
                    ? Colors.amber
                    : null,
              ),
              tooltip: 'Filter Favorites',
              onPressed: () {
                setState(() {
                  _selectedCategory =
                      _selectedCategory == FileCategoryFilter.favorites
                      ? FileCategoryFilter.all
                      : FileCategoryFilter.favorites;
                });
              },
            ),
            PopupMenuButton<DocumentSortOption>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort by',
              onSelected: (val) => setState(() => _sortOption = val),
              itemBuilder: (ctx) => const [
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: () {
                docsAsync.whenData((docs) => _selectAll(docs));
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. Breadcrumbs bar (if inside folder)
          if (_currentFolderId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToFolder(null),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.home,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Files',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final anc in _folderAncestors) ...[
                    const Icon(Icons.chevron_right, size: 16),
                    GestureDetector(
                      onTap: () => _navigateToFolder(anc),
                      child: Text(
                        anc.name,
                        style: TextStyle(
                          fontWeight: anc.id == _currentFolderId
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: anc.id == _currentFolderId
                              ? null
                              : AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_currentFolder != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'rename') {
                          _showRenameFolderDialog(_currentFolder!);
                        }
                        if (val == 'delete') {
                          _showDeleteFolderDialog(_currentFolder!);
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename Folder'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Folder'),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // 3. Subfolders row (if subfolders exist)
          foldersAsync.maybeWhen(
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final f = folders[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.folder,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        label: Text('${f.name} (${f.documentCount})'),
                        onPressed: () => _navigateToFolder(f),
                      ),
                    );
                  },
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // 4. Tags Filter Row
          tagsAsync.maybeWhen(
            data: (tags) {
              if (tags.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final t = tags[index];
                    final isSelected = _selectedTagIds.contains(t.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: CircleAvatar(
                          backgroundColor: Color(t.colorValue),
                          radius: 5,
                        ),
                        label: Text(
                          t.name,
                          style: const TextStyle(fontSize: 12),
                        ),
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
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // 5. Documents List
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                // Apply In-Memory Filtering (folder, categories, tags, sorting)
                List<ScannedDocument> filtered = docs.where((doc) {
                  // Folder filter
                  if (_currentFolderId != null) {
                    if (doc.folderId != _currentFolderId) return false;
                  }

                  // Favorite filter
                  if (_selectedCategory == FileCategoryFilter.favorites &&
                      !doc.isFavorite) {
                    return false;
                  }

                  // Format filters
                  if (_selectedCategory == FileCategoryFilter.pdfs &&
                      (doc.exportPath == null ||
                          !doc.exportPath!.toLowerCase().endsWith('.pdf'))) {
                    return false;
                  }

                  // Tag filters
                  if (_selectedTagIds.isNotEmpty) {
                    final docTagIds = doc.tags.map((t) => t.id).toSet();
                    if (!_selectedTagIds.any((id) => docTagIds.contains(id))) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Sort
                switch (_sortOption) {
                  case DocumentSortOption.newest:
                    filtered.sort(
                      (a, b) => b.modifiedAt.compareTo(a.modifiedAt),
                    );
                    break;
                  case DocumentSortOption.oldest:
                    filtered.sort(
                      (a, b) => a.modifiedAt.compareTo(b.modifiedAt),
                    );
                    break;
                  case DocumentSortOption.nameAsc:
                    filtered.sort(
                      (a, b) => a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      ),
                    );
                    break;
                  case DocumentSortOption.nameDesc:
                    filtered.sort(
                      (a, b) => b.title.toLowerCase().compareTo(
                        a.title.toLowerCase(),
                      ),
                    );
                    break;
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No documents in this view',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try clearing your search query'
                              : 'Scan or import pages to add files',
                          style: TextStyle(
                            fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final isSelected = _selectedDocIds.contains(doc.id);

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
                            _selectedDocIds.add(doc.id);
                          });
                        },
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
                                width: 56,
                                height: 70,
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
                                        Icons.picture_as_pdf,
                                        color: Colors.grey,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Content
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
                                      '${doc.pageCount} page${doc.pageCount > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    // Tags Pills
                                    if (doc.tags.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          for (final tag in doc.tags)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Color(tag.colorValue)
                                                    .withAlpha(30),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Color(tag.colorValue),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                tag.name,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(tag.colorValue),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Trailing options
                              if (!_isSelectionMode) ...[
                                IconButton(
                                  icon: Icon(
                                    doc.isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: doc.isFavorite ? Colors.amber : null,
                                  ),
                                  onPressed: () async {
                                    await AppDatabaseService.instance
                                        .toggleFavorite(
                                          doc.id,
                                          !doc.isFavorite,
                                        );
                                    _invalidateAll();
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) {
                                    if (val == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DocumentViewerScreen(
                                            document: doc,
                                          ),
                                        ),
                                      );
                                    } else if (val == 'share') {
                                      _shareDocument(doc);
                                    } else if (val == 'rename') {
                                      _renameDocumentWithSmartNaming(doc);
                                    } else if (val == 'move') {
                                      _showMoveFolderSheet([doc.id]);
                                    } else if (val == 'tag') {
                                      _showAssignTagsSheet([doc.id]);
                                    } else if (val == 'trash') {
                                      _moveToTrash(doc);
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('View Document'),
                                    ),
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share PDF'),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Rename (Smart Name)'),
                                    ),
                                    PopupMenuItem(
                                      value: 'move',
                                      child: Text('Move to Folder'),
                                    ),
                                    PopupMenuItem(
                                      value: 'tag',
                                      child: Text('Assign Tags'),
                                    ),
                                    PopupMenuItem(
                                      value: 'trash',
                                      child: Text(
                                        'Move to Trash',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
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
              error: (err, _) =>
                  Center(child: Text('Error loading documents: $err')),
            ),
          ),
        ],
      ),
      // 6. Bottom Batch Actions Bar
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      icon: const Icon(Icons.drive_file_move_outlined),
                      tooltip: 'Move to Folder',
                      onPressed: _selectedDocIds.isNotEmpty
                          ? () => _showMoveFolderSheet(_selectedDocIds.toList())
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.label_outline),
                      tooltip: 'Assign Tags',
                      onPressed: _selectedDocIds.isNotEmpty
                          ? () => _showAssignTagsSheet(_selectedDocIds.toList())
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.merge_type),
                      tooltip: 'Merge to PDF',
                      onPressed: _selectedDocIds.length >= 2
                          ? () {
                              docsAsync.whenData((allDocs) {
                                final selected = allDocs
                                    .where(
                                      (d) => _selectedDocIds.contains(d.id),
                                    )
                                    .toList();
                                _showBatchMergeDialog(selected);
                              });
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Move to Trash',
                      onPressed: _selectedDocIds.isNotEmpty
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final count = _selectedDocIds.length;
                              await AppDatabaseService.instance
                                  .moveDocumentsToTrash(
                                    _selectedDocIds.toList(),
                                  );
                              _exitSelectionMode();
                              _invalidateAll();
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Moved $count document(s) to Trash.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

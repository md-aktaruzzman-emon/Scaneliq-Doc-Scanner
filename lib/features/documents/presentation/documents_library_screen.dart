import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

enum DocumentSortOption { newest, oldest, nameAsc, nameDesc }

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
  bool _onlyFavorites = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(searchedDocumentsProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Documents Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _onlyFavorites ? Icons.star : Icons.star_border,
              color: _onlyFavorites ? Colors.amber : null,
            ),
            tooltip: 'Filter Favorites',
            onPressed: () {
              setState(() {
                _onlyFavorites = !_onlyFavorites;
              });
            },
          ),
          PopupMenuButton<DocumentSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (val) {
              setState(() {
                _sortOption = val;
              });
            },
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
                child: Text('Name (A-Z)'),
              ),
              PopupMenuItem(
                value: DocumentSortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (documents) {
                var filtered = documents.where((d) {
                  if (_onlyFavorites && !d.isFavorite) return false;
                  return true;
                }).toList();

                // Sort documents
                filtered.sort((a, b) {
                  switch (_sortOption) {
                    case DocumentSortOption.newest:
                      return b.modifiedAt.compareTo(a.modifiedAt);
                    case DocumentSortOption.oldest:
                      return a.modifiedAt.compareTo(b.modifiedAt);
                    case DocumentSortOption.nameAsc:
                      return a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    case DocumentSortOption.nameDesc:
                      return b.title.toLowerCase().compareTo(
                        a.title.toLowerCase(),
                      );
                  }
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.folder_open,
                          size: 64,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _onlyFavorites
                              ? 'No favorite documents found.'
                              : _searchQuery.isEmpty
                              ? 'No documents in library.'
                              : 'No documents match "$_searchQuery".',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondaryLight,
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
                    final hasExport =
                        doc.exportPath != null &&
                        File(doc.exportPath!).existsSync();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DocumentViewerScreen(document: doc),
                            ),
                          );
                        },
                        leading: Container(
                          width: 48,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        title: Text(
                          doc.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'} · ${doc.createdAt.year}-${doc.createdAt.month.toString().padLeft(2, '0')}-${doc.createdAt.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                doc.isFavorite ? Icons.star : Icons.star_border,
                                color: doc.isFavorite
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              tooltip: doc.isFavorite
                                  ? 'Unfavorite'
                                  : 'Favorite',
                              onPressed: () async {
                                await AppDatabaseService.instance
                                    .toggleFavorite(doc.id, !doc.isFavorite);
                                ref.invalidate(documentsListProvider);
                                ref.invalidate(searchedDocumentsProvider);
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'share') {
                                  if (hasExport) {
                                    SharePlus.instance.share(
                                      ShareParams(
                                        text: doc.title,
                                        files: [XFile(doc.exportPath!)],
                                      ),
                                    );
                                  }
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Document?'),
                                      content: Text(
                                        'Are you sure you want to delete "${doc.title}"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await AppDatabaseService.instance
                                        .deleteDocument(doc.id);
                                    ref.invalidate(documentsListProvider);
                                    ref.invalidate(searchedDocumentsProvider);
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (hasExport)
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, size: 20),
                                        SizedBox(width: 8),
                                        Text('Share PDF'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

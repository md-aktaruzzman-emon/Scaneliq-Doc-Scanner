import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(ScannedDocument doc) async {
    await AppDatabaseService.instance.toggleFavorite(doc.id, !doc.isFavorite);
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);
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
          const SnackBar(content: Text('No PDF export found for this scan.')),
        );
      }
    }
  }

  Future<void> _deleteDocument(ScannedDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
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
      await AppDatabaseService.instance.deleteDocument(doc.id);
      ref.invalidate(documentsListProvider);
      ref.invalidate(searchedDocumentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(searchedDocumentsProvider(_searchQuery));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Files',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
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
                if (_selectedCategory == FileCategoryFilter.favorites) {
                  _selectedCategory = FileCategoryFilter.all;
                } else {
                  _selectedCategory = FileCategoryFilter.favorites;
                }
              });
            },
          ),
          PopupMenuButton<DocumentSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort by',
            onSelected: (val) {
              setState(() {
                _sortOption = val;
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: DocumentSortOption.newest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 18),
                    SizedBox(width: 8),
                    Text('Newest first'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: DocumentSortOption.oldest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 18),
                    SizedBox(width: 8),
                    Text('Oldest first'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: DocumentSortOption.nameAsc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name (A–Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: DocumentSortOption.nameDesc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name (Z–A)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCategoryFilterChip(
                  label: 'All',
                  icon: Icons.all_inbox_rounded,
                  category: FileCategoryFilter.all,
                ),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(
                  label: 'Favorites',
                  icon: Icons.star_rounded,
                  category: FileCategoryFilter.favorites,
                ),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(
                  label: 'PDFs',
                  icon: Icons.picture_as_pdf_rounded,
                  category: FileCategoryFilter.pdfs,
                ),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(
                  label: 'Images',
                  icon: Icons.image_outlined,
                  category: FileCategoryFilter.images,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Documents List
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (documents) {
                var filtered = documents.where((d) {
                  switch (_selectedCategory) {
                    case FileCategoryFilter.all:
                      return true;
                    case FileCategoryFilter.favorites:
                      return d.isFavorite;
                    case FileCategoryFilter.pdfs:
                      return d.exportPath != null &&
                          File(d.exportPath!).existsSync();
                    case FileCategoryFilter.images:
                      return d.exportPath == null ||
                          !File(d.exportPath!).existsSync();
                  }
                }).toList();

                // Apply Sorting
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
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surface2Dark
                                  : AppColors.surface2Light,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedCategory == FileCategoryFilter.favorites
                                ? 'No favorite documents found.'
                                : _searchQuery.isEmpty
                                ? 'No documents in library.'
                                : 'No documents match "$_searchQuery".',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (_searchQuery.isNotEmpty ||
                              _selectedCategory != FileCategoryFilter.all)
                            FilledButton.tonal(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _selectedCategory = FileCategoryFilter.all;
                                });
                              },
                              child: const Text('Reset filters'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return _buildDocumentRow(doc, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required FileCategoryFilter category,
  }) {
    final isSelected = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? (isDark ? AppColors.surface0Dark : Colors.white)
            : (isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
        });
      },
    );
  }

  Widget _buildThumbnailWidget(ScannedDocument doc) {
    if (doc.pages.isNotEmpty) {
      final thumbPath =
          doc.pages.first.processedPath ?? doc.pages.first.originalPath;
      if (File(thumbPath).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(thumbPath),
            width: 48,
            height: 58,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
          ),
        );
      }
    }
    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf_rounded,
          color: AppColors.brandPrimary,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildDocumentRow(ScannedDocument doc, bool isDark) {
    final hasExport =
        doc.exportPath != null && File(doc.exportPath!).existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(document: doc),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnailWidget(doc),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'} · ${doc.createdAt.year}-${doc.createdAt.month.toString().padLeft(2, '0')}-${doc.createdAt.day.toString().padLeft(2, '0')}',
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
              IconButton(
                icon: Icon(
                  doc.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: doc.isFavorite ? Colors.amber : null,
                  size: 22,
                ),
                tooltip: doc.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () => _toggleFavorite(doc),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (val) {
                  if (val == 'share') {
                    _shareDocument(doc);
                  } else if (val == 'delete') {
                    _deleteDocument(doc);
                  }
                },
                itemBuilder: (ctx) => [
                  if (hasExport)
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 18),
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
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

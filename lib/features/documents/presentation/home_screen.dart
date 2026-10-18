import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startNewScan() async {
    ref.read(scanSessionProvider.notifier).resetSession();
    final success = await ref.read(scanSessionProvider.notifier).startScannerCapture();
    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReviewPagesScreen()),
      );
    }
  }

  void _importFiles() async {
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
          final count = await ref.read(scanSessionProvider.notifier).importFiles(files);
          if (count > 0 && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReviewPagesScreen()),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not import files: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/branding/scaneliq_logo_original.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.document_scanner, color: AppColors.brandPrimary),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Scaneliq',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsListProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan documents. Keep everything organized.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Primary Action: Scan Document
                    ElevatedButton.icon(
                      onPressed: _startNewScan,
                      icon: const Icon(Icons.document_scanner_outlined, size: 22),
                      label: const Text('Scan document'),
                    ),
                    const SizedBox(height: 12),
                    // Secondary Action: Import
                    OutlinedButton.icon(
                      onPressed: _importFiles,
                      icon: const Icon(Icons.file_upload_outlined, size: 22),
                      label: const Text('Import'),
                    ),
                    const SizedBox(height: 16),
                    // Draft recovery card if active draft exists
                    ref.watch(latestDraftProvider).maybeWhen(
                          data: (draft) {
                            if (draft == null || draft.pages.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_toggle_off, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Unfinished Scan Draft',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          '${draft.title} · ${draft.pages.length} pages',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(80, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () {
                                      ref.read(scanSessionProvider.notifier).loadDraftSession(draft);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ReviewPagesScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text('Resume', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                    const SizedBox(height: 4),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search documents by name...',
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
                    const SizedBox(height: 20),
                    const Text(
                      'Recent Documents',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            docsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading documents: $err')),
              ),
              data: (documents) {
                final filtered = documents.where((d) {
                  if (_searchQuery.isEmpty) return true;
                  return d.title.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_open, size: 64, color: AppColors.textSecondaryLight),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No documents scanned yet.' : 'No matching documents.',
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 8),
                          if (_searchQuery.isEmpty)
                            const Text(
                              'Tap "Scan document" above to get started.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filtered[index];
                        final hasExport = doc.exportPath != null && File(doc.exportPath!).existsSync();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DocumentViewerScreen(document: doc),
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
                              child: const Icon(Icons.picture_as_pdf, color: AppColors.brandPrimary),
                            ),
                            title: Text(
                              doc.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'} · ${doc.createdAt.year}-${doc.createdAt.month.toString().padLeft(2, '0')}-${doc.createdAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'share') {
                                  if (hasExport) {
                                    SharePlus.instance.share(
                                      ShareParams(
                                        text: doc.title,
                                        files: [XFile(doc.exportPath!)],
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No PDF export found for this scan.')),
                                    );
                                  }
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Document?'),
                                      content: Text('Are you sure you want to delete "${doc.title}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await AppDatabaseService.instance.deleteDocument(doc.id);
                                    ref.invalidate(documentsListProvider);
                                  }
                                }
                              },
                              itemBuilder: (context) => [
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
                                      Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

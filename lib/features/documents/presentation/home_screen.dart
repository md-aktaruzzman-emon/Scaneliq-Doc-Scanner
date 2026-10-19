import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_tools_screen.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/count_cam_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_code_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/scanner/presentation/translate_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startNewScan() async {
    ref.read(scanSessionProvider.notifier).resetSession();
    final success = await ref
        .read(scanSessionProvider.notifier)
        .startScannerCapture();
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
          final count = await ref
              .read(scanSessionProvider.notifier)
              .importFiles(files);
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

  Future<void> _toggleFavorite(ScannedDocument doc) async {
    await AppDatabaseService.instance.toggleFavorite(doc.id, !doc.isFavorite);
    ref.invalidate(documentsListProvider);
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
    await AppDatabaseService.instance.moveToTrash(doc.id);
    ref.invalidate(documentsListProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${doc.title}" to Trash.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await AppDatabaseService.instance.restoreFromTrash(doc.id);
              ref.invalidate(documentsListProvider);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ScaneliqLogo(size: 28, borderRadius: 6),
            SizedBox(width: 10),
            Text(
              'Scaneliq',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF Tools',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfToolsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsListProvider);
          ref.invalidate(latestDraftProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle / tagline
                    Text(
                      'Scan documents. Keep everything organized.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Primary scan & import actions
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _startNewScan,
                            icon: const Icon(
                              Icons.document_scanner_rounded,
                              size: 20,
                            ),
                            label: const Text('Scan document'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _importFiles,
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 20,
                            ),
                            label: const Text('Import'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Draft recovery card if active draft exists
                    ref
                        .watch(latestDraftProvider)
                        .maybeWhen(
                          data: (draft) {
                            if (draft == null || draft.pages.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surface2Dark
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.warning.withValues(alpha: 0.4)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.history_toggle_off,
                                      color: AppColors.warning,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Unfinished Scan Draft',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${draft.title} · ${draft.pages.length} pages',
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
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: const Size(64, 34),
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(scanSessionProvider.notifier)
                                          .loadDraftSession(draft);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ReviewPagesScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Resume',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),

                    const SizedBox(height: 18),

                    // Smart Scanning Modes Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Smart Scanning Modes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Quick capture',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Horizontal scrolling pill carousel of smart modes
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCarouselItem(
                            icon: Icons.burst_mode,
                            label: 'Batch',
                            accentColor: const Color(0xFF2563EB),
                            onTap: () {
                              ref
                                  .read(scanSessionProvider.notifier)
                                  .resetSession('Batch_Scan');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContinuousCameraScreen(
                                    mode: ScanMode.batch,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.badge,
                            label: 'ID Card',
                            accentColor: const Color(0xFF4F46E5),
                            onTap: () {
                              ref
                                  .read(scanSessionProvider.notifier)
                                  .resetSession('ID_Card');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContinuousCameraScreen(
                                    mode: ScanMode.idCard,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.quiz,
                            label: 'Questions',
                            accentColor: const Color(0xFFEA580C),
                            onTap: () {
                              ref
                                  .read(scanSessionProvider.notifier)
                                  .resetSession('Question_Set');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContinuousCameraScreen(
                                    mode: ScanMode.questionSet,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.menu_book,
                            label: 'Book',
                            accentColor: const Color(0xFF0D9488),
                            onTap: () {
                              ref
                                  .read(scanSessionProvider.notifier)
                                  .resetSession('Book_Scan');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContinuousCameraScreen(
                                    mode: ScanMode.book,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.co_present,
                            label: 'Board',
                            accentColor: const Color(0xFF7C3AED),
                            onTap: () {
                              ref
                                  .read(scanSessionProvider.notifier)
                                  .resetSession('Whiteboard');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContinuousCameraScreen(
                                    mode: ScanMode.whiteboard,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.qr_code_scanner,
                            label: 'Scan Code',
                            accentColor: const Color(0xFF059669),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ScanCodeScreen(),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.calculate,
                            label: 'CountCam',
                            accentColor: const Color(0xFFD97706),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CountCamScreen(),
                                ),
                              );
                            },
                          ),
                          _buildCarouselItem(
                            icon: Icons.translate,
                            label: 'Translate',
                            accentColor: const Color(0xFFE11D48),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TranslateScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Search Pill
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search documents by name...',
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

                    const SizedBox(height: 18),

                    // Recent Documents Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isGridView
                                ? Icons.view_agenda_outlined
                                : Icons.grid_view_outlined,
                            size: 20,
                          ),
                          tooltip: _isGridView
                              ? 'Switch to List'
                              : 'Switch to Grid',
                          onPressed: () {
                            setState(() {
                              _isGridView = !_isGridView;
                            });
                          },
                        ),
                      ],
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
                              _searchQuery.isEmpty
                                  ? 'No documents scanned yet.'
                                  : 'No matching documents.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_searchQuery.isEmpty)
                              Text(
                                'Tap "Scan document" above to get started.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (_isGridView) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.76,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final doc = filtered[index];
                        return _buildGridDocumentCard(doc, isDark);
                      }, childCount: filtered.length),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = filtered[index];
                      return _buildListDocumentCard(doc, isDark);
                    }, childCount: filtered.length),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselItem({
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: isDark ? AppColors.surface1Dark : AppColors.surface1Light,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.surface3Dark
                    : AppColors.surface3Light,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailWidget(ScannedDocument doc, double height) {
    if (doc.pages.isNotEmpty) {
      final thumbPath =
          doc.pages.first.processedPath ?? doc.pages.first.originalPath;
      if (File(thumbPath).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(thumbPath),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackThumbnail(height),
          ),
        );
      }
    }
    return _buildFallbackThumbnail(height);
  }

  Widget _buildFallbackThumbnail(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf_rounded,
          color: AppColors.brandPrimary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildGridDocumentCard(ScannedDocument doc, bool isDark) {
    return Material(
      color: isDark ? AppColors.surface1Dark : AppColors.surface1Light,
      borderRadius: BorderRadius.circular(14),
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
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.surface3Dark : AppColors.surface3Light,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildThumbnailWidget(doc, double.infinity),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _toggleFavorite(doc),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            doc.isFavorite ? Icons.star : Icons.star_border,
                            color: doc.isFavorite ? Colors.amber : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                doc.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  _buildCardMenu(doc),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListDocumentCard(ScannedDocument doc, bool isDark) {
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
              SizedBox(
                width: 48,
                height: 58,
                child: _buildThumbnailWidget(doc, 58),
              ),
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
                  doc.isFavorite ? Icons.star : Icons.star_border,
                  color: doc.isFavorite ? Colors.amber : null,
                  size: 20,
                ),
                tooltip: doc.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () => _toggleFavorite(doc),
              ),
              _buildCardMenu(doc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardMenu(ScannedDocument doc) {
    final hasExport =
        doc.exportPath != null && File(doc.exportPath!).existsSync();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (val) {
        if (val == 'share') {
          _shareDocument(doc);
        } else if (val == 'delete') {
          _deleteDocument(doc);
        }
      },
      itemBuilder: (context) => [
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
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

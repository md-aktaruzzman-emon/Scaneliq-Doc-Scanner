import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/navigation/app_router.dart';
import 'package:scaneliq/core/navigation/main_navigation_shell.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_bottom_nav.dart';
import 'package:scaneliq/core/widgets/scaneliq_buttons.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_document_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_mark.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/core/widgets/scaneliq_search_field.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/documents/presentation/documents_library_screen.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart';

enum _HomeDocumentScope { recent, starred }

/// Concept A (Editorial Gallery Minimal) Home Dashboard (`Scans` Tab).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _HomeDocumentScope _scope = _HomeDocumentScope.recent;
  bool _sortNewestFirst = true;
  bool _selectionMode = false;
  final Set<String> _selectedDocIds = {};
  bool _isCaptureBusy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startNewScan() async {
    if (_isCaptureBusy) return;
    setState(() => _isCaptureBusy = true);

    try {
      ref.read(scanSessionProvider.notifier).resetSession();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ContinuousCameraScreen(mode: ScanMode.batch),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCaptureBusy = false);
      }
    }
  }

  Future<void> _importFiles() async {
    if (_isCaptureBusy) return;
    setState(() => _isCaptureBusy = true);

    try {
      final result = await ref
          .read(galleryImportServiceProvider)
          .pickAndValidateImages();
      if (result.cancelled) return;

      if (!result.hasAccepted) {
        if (mounted) {
          showScaneliqToast(
            context,
            result.rejections.isNotEmpty
                ? result.rejections.first.reason
                : 'No valid images selected.',
          );
        }
        return;
      }

      ref.read(scanSessionProvider.notifier).resetSession();
      final count = await ref
          .read(scanSessionProvider.notifier)
          .importFiles(result.accepted.map((a) => a.file).toList());
      if (count > 0 && mounted) {
        navigateToReviewPages(context);
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'Could not import files: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCaptureBusy = false);
      }
    }
  }

  void _openFoldersDestination() {
    final shell = ScaneliqShellScope.of(context);
    if (shell != null) {
      shell.goToTab(1);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DocumentsLibraryScreen()));
  }

  void _openDocument(ScannedDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedDocIds.contains(id)) {
        _selectedDocIds.remove(id);
      } else {
        _selectedDocIds.add(id);
      }
    });
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
      return;
    }
    if (mounted) {
      showScaneliqToast(context, 'Save as PDF first to share "${doc.title}".');
    }
  }

  Future<void> _trashDocument(ScannedDocument doc) async {
    await AppDatabaseService.instance.moveToTrash(doc.id);
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);
    if (!mounted) return;
    showScaneliqToast(
      context,
      'Moved "${doc.title}" to 30-day Trash.',
      actionLabel: 'Undo',
      onAction: () async {
        await AppDatabaseService.instance.restoreFromTrash(doc.id);
        ref.invalidate(documentsListProvider);
        ref.invalidate(searchedDocumentsProvider);
      },
    );
  }

  Future<void> _trashSelected(List<ScannedDocument> docs) async {
    if (_selectedDocIds.isEmpty) return;
    final confirmed = await showScaneliqConfirmDialog(
      context: context,
      title: 'Move to Trash?',
      message:
          'Move ${_selectedDocIds.length} selected documents to 30-day Trash recovery?',
      confirmLabel: 'Move to Trash',
      isDestructive: true,
    );
    if (!confirmed) return;

    for (final id in _selectedDocIds.toList()) {
      await AppDatabaseService.instance.moveToTrash(id);
    }
    setState(() {
      _selectedDocIds.clear();
      _selectionMode = false;
    });
    ref.invalidate(documentsListProvider);
    ref.invalidate(searchedDocumentsProvider);
  }

  void _showDocumentActionsSheet(ScannedDocument doc) {
    final hasExport =
        doc.exportPath != null && File(doc.exportPath!).existsSync();

    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
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
                  ],
                ),
              ),
              ScaneliqStatusLabel(
                text: hasExport ? 'PDF READY' : 'SCAN DRAFT',
                tone: hasExport
                    ? ScaneliqStatusTone.accent
                    : ScaneliqStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ScaneliqContextMenuRow(
            icon: Icons.open_in_new_rounded,
            title: 'Open Document Viewer',
            subtitle: 'View pages, run OCR, sign or annotate',
            onTap: () {
              Navigator.of(ctx).pop();
              _openDocument(doc);
            },
          ),
          ScaneliqContextMenuRow(
            icon: doc.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            title: doc.isFavorite
                ? 'Remove from Starred'
                : 'Add to Starred Priority',
            trailing: ScaneliqStatusLabel(
              text: doc.isFavorite ? 'STARRED' : 'STAR',
              tone: doc.isFavorite
                  ? ScaneliqStatusTone.warning
                  : ScaneliqStatusTone.neutral,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              _toggleFavorite(doc);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.ios_share_rounded,
            title: 'Export & Share',
            subtitle: hasExport
                ? 'Unwatermarked PDF ready to share'
                : 'Open Viewer to compile export PDF',
            trailing: const ScaneliqStatusLabel(
              text: 'SHARE',
              tone: ScaneliqStatusTone.accent,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              _shareDocument(doc);
            },
          ),
          ScaneliqContextMenuRow(
            icon: Icons.delete_outline_rounded,
            title: 'Move to 30-Day Trash',
            titleColor: ctx.tokens.danger,
            trailing: const ScaneliqStatusLabel(
              text: 'TRASH',
              tone: ScaneliqStatusTone.danger,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              _trashDocument(doc);
            },
          ),
        ],
      ),
    );
  }

  List<ScannedDocument> _applyFiltersAndSort(List<ScannedDocument> docs) {
    final activeDocs = docs.where((d) => !d.isDraft && !d.isTrashed).where((d) {
      if (_scope == _HomeDocumentScope.starred && !d.isFavorite) {
        return false;
      }
      return true;
    }).toList();

    activeDocs.sort((a, b) {
      if (_sortNewestFirst) {
        return b.modifiedAt.compareTo(a.modifiedAt);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return activeDocs;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(screenWidth);
    final bottomNavInset = _selectionMode ? 80.0 : 92.0;

    final allDocsAsync = ref.watch(documentsListProvider);
    final docsAsync = _searchQuery.isEmpty
        ? allDocsAsync
        : ref.watch(searchedDocumentsProvider(_searchQuery));
    final foldersAsync = ref.watch(foldersListProvider(null));
    final draftAsync = ref.watch(latestDraftProvider);

    final allActiveDocs = allDocsAsync.maybeWhen(
      data: (list) => list.where((d) => !d.isDraft && !d.isTrashed).toList(),
      orElse: () => const <ScannedDocument>[],
    );
    final recentCount = allActiveDocs.length;
    final starredCount = allActiveDocs.where((d) => d.isFavorite).length;
    final foldersCount = foldersAsync.maybeWhen(
      data: (folders) => folders.length,
      orElse: () => 0,
    );

    final filteredDocs = docsAsync.maybeWhen(
      data: _applyFiltersAndSort,
      orElse: () => const <ScannedDocument>[],
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: tokens.accent,
              onRefresh: () async {
                ref.invalidate(documentsListProvider);
                ref.invalidate(searchedDocumentsProvider);
                ref.invalidate(foldersListProvider(null));
                ref.invalidate(latestDraftProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // 1. Editorial Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        ScaneliqSpacing.headerVerticalTop,
                        horizontalPad,
                        ScaneliqSpacing.headerVerticalBottom,
                      ),
                      child: _selectionMode
                          ? _buildSelectionHeader(
                              textTheme,
                              tokens,
                              filteredDocs,
                            )
                          : _buildEditorialHeader(textTheme, tokens, isDark),
                    ),
                  ),

                  // 2. Search & Scope Strip
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        ScaneliqSpacing.searchZoneBottom,
                      ),
                      child: Column(
                        children: [
                          ScaneliqSearchField(
                            controller: _searchController,
                            query: _searchQuery,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim();
                              });
                            },
                            onClear: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          ScaneliqScopeTabs(
                            items: [
                              ScaneliqScopeItem(
                                label: 'Recent',
                                count: recentCount,
                              ),
                              ScaneliqScopeItem(
                                label: 'Starred',
                                count: starredCount,
                              ),
                              ScaneliqScopeItem(
                                label: 'Folders',
                                count: foldersCount,
                              ),
                            ],
                            selectedIndex: _scope == _HomeDocumentScope.recent
                                ? 0
                                : 1,
                            onSelected: (index) {
                              if (index == 2) {
                                _openFoldersDestination();
                                return;
                              }
                              setState(() {
                                _scope = index == 0
                                    ? _HomeDocumentScope.recent
                                    : _HomeDocumentScope.starred;
                              });
                            },
                            trailing: ScaneliqIconButton(
                              icon: _sortNewestFirst
                                  ? Icons.sort_rounded
                                  : Icons.sort_by_alpha_rounded,
                              tooltip: _sortNewestFirst
                                  ? 'Sorted by newest'
                                  : 'Sorted A–Z',
                              color: tokens.textSecondary,
                              size: 34,
                              onPressed: () {
                                setState(() {
                                  _sortNewestFirst = !_sortNewestFirst;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Featured Continue Working Draft Section
                  if (_searchQuery.isEmpty &&
                      _scope == _HomeDocumentScope.recent)
                    draftAsync.maybeWhen(
                      data: (draft) {
                        if (draft == null || draft.pages.isEmpty) {
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
                              children: [
                                ScaneliqSectionHeader(
                                  title: 'Continue working',
                                  actionLabel: 'Resume draft',
                                  onAction: () {
                                    ref
                                        .read(scanSessionProvider.notifier)
                                        .loadDraftSession(draft);
                                    navigateToReviewPages(context);
                                  },
                                ),
                                const SizedBox(height: 8),
                                ScaneliqFeaturedFolioCard(
                                  draft: draft,
                                  onResume: () {
                                    ref
                                        .read(scanSessionProvider.notifier)
                                        .loadDraftSession(draft);
                                    navigateToReviewPages(context);
                                  },
                                  onAddPages: () {
                                    ref
                                        .read(scanSessionProvider.notifier)
                                        .loadDraftSession(draft);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ContinuousCameraScreen(),
                                      ),
                                    );
                                  },
                                  onSavePdf: () {
                                    ref
                                        .read(scanSessionProvider.notifier)
                                        .loadDraftSession(draft);
                                    navigateToReviewPages(context);
                                  },
                                ),
                                const SizedBox(height: 15),
                                const ScaneliqHairlineDivider(),
                              ],
                            ),
                          ),
                        );
                      },
                      orElse: () =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),

                  // 4. Document Stream Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        16,
                        horizontalPad,
                        4,
                      ),
                      child: ScaneliqSectionHeader(
                        title: _searchQuery.isNotEmpty
                            ? 'Search Results'
                            : (_scope == _HomeDocumentScope.starred
                                  ? 'Starred Documents'
                                  : _currentMonthHeader()),
                        actionLabel: 'All files',
                        onAction: _openFoldersDestination,
                      ),
                    ),
                  ),

                  // 5. Hairline Document Stream / Loading / Empty
                  docsAsync.when(
                    loading: () => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomNavInset),
                        child: const ScaneliqLoadingIndicator(),
                      ),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomNavInset),
                        child: ScaneliqEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not read local vault',
                          description: '$err',
                        ),
                      ),
                    ),
                    data: (rawDocs) {
                      final list = _applyFiltersAndSort(rawDocs);
                      if (list.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottomNavInset),
                            child: ScaneliqEmptyState(
                              icon: _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : (_scope == _HomeDocumentScope.starred
                                        ? Icons.star_outline_rounded
                                        : Icons.document_scanner_outlined),
                              title: _searchQuery.isNotEmpty
                                  ? 'No matching documents'
                                  : (_scope == _HomeDocumentScope.starred
                                        ? 'No starred documents'
                                        : 'No scans yet'),
                              description: _searchQuery.isNotEmpty
                                  ? 'Try another title or keyword indexed by on-device OCR.'
                                  : (_scope == _HomeDocumentScope.starred
                                        ? 'Star important contracts or receipts from any document menu.'
                                        : 'Scan paper documents, IDs, or receipts into your encrypted local vault.'),
                              primaryActionLabel:
                                  _searchQuery.isEmpty &&
                                      _scope == _HomeDocumentScope.recent
                                  ? 'Scan document'
                                  : null,
                              onPrimaryAction: _startNewScan,
                              secondaryActionLabel:
                                  _searchQuery.isEmpty &&
                                      _scope == _HomeDocumentScope.recent
                                  ? 'Import from Gallery'
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
                          bottomNavInset,
                        ),
                        sliver: SliverList.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final doc = list[index];
                            final selected = _selectedDocIds.contains(doc.id);
                            return ScaneliqDocumentRow(
                              document: doc,
                              selectionMode: _selectionMode,
                              isSelected: selected,
                              onTap: _selectionMode
                                  ? () => _toggleSelection(doc.id)
                                  : () => _openDocument(doc),
                              onLongPress: () {
                                if (!_selectionMode) {
                                  setState(() {
                                    _selectionMode = true;
                                    _selectedDocIds.add(doc.id);
                                  });
                                }
                              },
                              onMoreTap: _selectionMode
                                  ? null
                                  : () => _showDocumentActionsSheet(doc),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 6. Floating Capture Cluster (`[Gallery]` + `[📷 Scan]`) OR Selection Dock
            if (_selectionMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSelectionActionDock(tokens, filteredDocs),
              )
            else
              Positioned(
                right: horizontalPad,
                bottom: ScaneliqSpacing.fabClusterBottomGap,
                child: ScaneliqFloatingCaptureCluster(
                  onScanPressed: _startNewScan,
                  onImportPressed: _importFiles,
                  isBusy: _isCaptureBusy,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialHeader(
    TextTheme textTheme,
    ScaneliqTokens tokens,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const ScaneliqMark(size: 26),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Scaneliq',
                  style: textTheme.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaneliqIconButton(
              icon: isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              tooltip: 'Switch theme',
              onPressed: () {
                ref
                    .read(themeModeProvider.notifier)
                    .toggleLightDark(MediaQuery.platformBrightnessOf(context));
              },
            ),
            ScaneliqIconButton(
              icon: Icons.check_box_outlined,
              tooltip: 'Select multiple',
              onPressed: () {
                setState(() {
                  _selectionMode = true;
                  _selectedDocIds.clear();
                });
              },
            ),
            ScaneliqIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings & Vault',
              onPressed: () => navigateToSettings(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(
    TextTheme textTheme,
    ScaneliqTokens tokens,
    List<ScannedDocument> visibleDocs,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              ScaneliqIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Cancel selection',
                onPressed: () {
                  setState(() {
                    _selectionMode = false;
                    _selectedDocIds.clear();
                  });
                },
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${_selectedDocIds.length} Selected',
                  style: textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ScaneliqTextButton(
          label: 'Select all',
          onPressed: () {
            setState(() {
              _selectedDocIds
                ..clear()
                ..addAll(visibleDocs.map((d) => d.id));
            });
          },
        ),
      ],
    );
  }

  Widget _buildSelectionActionDock(
    ScaneliqTokens tokens,
    List<ScannedDocument> visibleDocs,
  ) {
    final count = _selectedDocIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          top: BorderSide(color: tokens.hairline, width: 1),
          bottom: BorderSide(color: tokens.hairline, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count selected',
            style: ScaneliqTypography.monoStyle(
              color: tokens.textSecondary,
              fontSize: 11.5,
            ),
          ),
          Row(
            children: [
              ScaneliqTextButton(
                label: 'Folders',
                onPressed: count == 0 ? null : _openFoldersDestination,
              ),
              const SizedBox(width: 8),
              ScaneliqDestructiveButton(
                label: 'Trash',
                icon: Icons.delete_outline_rounded,
                onPressed: count == 0
                    ? null
                    : () => _trashSelected(visibleDocs),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _currentMonthHeader() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }
}

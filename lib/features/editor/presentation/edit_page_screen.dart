import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/editor/presentation/edit_history_controller.dart';
import 'package:scaneliq/features/editor/presentation/widgets/editor_preview_stage.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

/// Primary editing categories for the Concept A Scan Editor toolbar.
enum EditTab { crop, enhance, filter, adjust, rotate }

/// Concept A (Editorial Gallery Minimal) Non-Destructive Scan Editor.
///
/// Supports Auto Crop, 4-point Perspective Homography Warp, Box Crop,
/// Rotation, 8+ Document Filters, Brightness/Contrast/Sharpness sliders,
/// Otsu/Sauvola Binarization, Shadow Correction, Before/After Split Comparison,
/// per-page Undo/Redo history, and Multi-Page session switching & reordering.
class EditPageScreen extends ConsumerStatefulWidget {
  final DocumentPage page;
  final void Function(EditRecipe recipe) onApply;
  final List<DocumentPage>? pages;
  final int? initialPageIndex;
  final EditTab initialTab;

  const EditPageScreen({
    super.key,
    required this.page,
    required this.onApply,
    this.pages,
    this.initialPageIndex,
    this.initialTab = EditTab.filter,
  });

  @override
  ConsumerState<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends ConsumerState<EditPageScreen> {
  final MultiPageEditHistory _history = MultiPageEditHistory();

  late List<DocumentPage> _editablePages;
  late int _activePageIndex;
  late EditTab _currentTab;

  bool _usePerspectiveWarp = false;
  bool _isComparing = false;
  double _compareSplit = 0.5;
  bool _isCleanupMode = false;
  String _cleanupType = 'holePunch';
  final double _cleanupRadius = 0.035;

  bool _isProcessingPreview = false;
  bool _isSaving = false;
  bool _isAutoDetectingCrop = false;
  Uint8List? _processedPreviewBytes;
  int _renderGeneration = 0;
  Timer? _debounceTimer;
  Timer? _sliderHistoryDebounce;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;

    final initialList = widget.pages;
    if (initialList != null && initialList.isNotEmpty) {
      _editablePages = List<DocumentPage>.from(initialList);
      final idx =
          widget.initialPageIndex ??
          _editablePages.indexWhere((p) => p.id == widget.page.id);
      _activePageIndex = idx.clamp(0, _editablePages.length - 1);
    } else {
      _editablePages = [widget.page];
      _activePageIndex = 0;
    }

    // Seed initial history & perspective toggle from active page.
    _syncUiFromActivePage();
    _loadAndRenderCurrentPage(immediate: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sliderHistoryDebounce?.cancel();
    _history.clear();
    super.dispose();
  }

  DocumentPage get _activePage => _editablePages[_activePageIndex];
  EditHistoryStack get _activeStack => _history.stackFor(_activePage);
  EditRecipe get _recipe => _activeStack.current;

  void _syncUiFromActivePage() {
    final recipe = _recipe;
    final quad = recipe.perspectiveQuad;
    _usePerspectiveWarp =
        quad != null && !quad.isStandard && quad.isValidConvex();
  }

  void _commitRecipe(EditRecipe next, {bool immediatePreview = false}) {
    final changed = _activeStack.record(next);
    if (!changed) return;
    _editablePages[_activePageIndex] = _activePage.copyWith(editRecipe: next);
    setState(() {});
    _schedulePreviewRender(immediate: immediatePreview);
  }

  void _previewContinuousRecipe(EditRecipe next) {
    _activeStack.beginContinuousEdit();
    _activeStack.previewContinuousEdit(next);
    _editablePages[_activePageIndex] = _activePage.copyWith(editRecipe: next);
    setState(() {});
    _schedulePreviewRender(immediate: false);

    _sliderHistoryDebounce?.cancel();
    _sliderHistoryDebounce = Timer(const Duration(milliseconds: 280), () {
      _activeStack.commitContinuousEdit();
      if (mounted) setState(() {});
    });
  }

  void _switchToPage(int newIndex) {
    if (newIndex < 0 ||
        newIndex >= _editablePages.length ||
        newIndex == _activePageIndex) {
      return;
    }
    _activeStack.commitContinuousEdit();
    _debounceTimer?.cancel();
    setState(() {
      _activePageIndex = newIndex;
      _processedPreviewBytes = null;
      _isComparing = false;
      _syncUiFromActivePage();
    });
    _loadAndRenderCurrentPage(immediate: true);
  }

  void _undo() {
    final restored = _activeStack.undo();
    if (restored == null) return;
    _editablePages[_activePageIndex] = _activePage.copyWith(
      editRecipe: restored,
    );
    setState(() {
      _syncUiFromActivePage();
    });
    _schedulePreviewRender(immediate: true);
  }

  void _redo() {
    final redone = _activeStack.redo();
    if (redone == null) return;
    _editablePages[_activePageIndex] = _activePage.copyWith(editRecipe: redone);
    setState(() {
      _syncUiFromActivePage();
    });
    _schedulePreviewRender(immediate: true);
  }

  void _resetCurrentPage() {
    _commitRecipe(const EditRecipe(), immediatePreview: true);
    setState(() {
      _usePerspectiveWarp = false;
      _isComparing = false;
    });
  }

  void _rotateBy(int deltaDegrees) {
    final nextRot =
        ((_recipe.rotationDegrees + deltaDegrees) % 360 + 360) % 360;
    _commitRecipe(
      _recipe.copyWith(rotationDegrees: nextRot),
      immediatePreview: true,
    );
  }

  Future<void> _runAutoCropDetection() async {
    final origFile = File(_activePage.originalPath);
    if (!origFile.existsSync()) {
      showScaneliqToast(context, 'Original capture missing on storage.');
      return;
    }

    setState(() => _isAutoDetectingCrop = true);
    try {
      final detectedQuad =
          await ImageProcessingService.autoDetectDocumentQuadFromFile(origFile);
      if (!mounted) return;
      if (detectedQuad != null && detectedQuad.isValidConvex()) {
        setState(() => _usePerspectiveWarp = true);
        _commitRecipe(
          _recipe.copyWith(
            perspectiveQuad: detectedQuad,
            cropLeft: 0.0,
            cropTop: 0.0,
            cropRight: 1.0,
            cropBottom: 1.0,
          ),
          immediatePreview: true,
        );
        showScaneliqToast(context, 'Document boundary detected.');
      } else {
        showScaneliqToast(
          context,
          'No distinct outer paper boundary detected; adjust handles manually.',
        );
      }
    } catch (e) {
      if (mounted) {
        showScaneliqToast(context, 'Auto-crop analysis failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isAutoDetectingCrop = false);
    }
  }

  void _resetCrop() {
    setState(() => _usePerspectiveWarp = false);
    _commitRecipe(
      _recipe.copyWith(
        cropLeft: 0.0,
        cropTop: 0.0,
        cropRight: 1.0,
        cropBottom: 1.0,
        clearPerspectiveQuad: true,
      ),
      immediatePreview: true,
    );
  }

  Future<void> _movePageOrder(int fromIdx, int toIdx) async {
    if (fromIdx == toIdx || toIdx < 0 || toIdx >= _editablePages.length) {
      return;
    }
    setState(() {
      final moved = _editablePages.removeAt(fromIdx);
      _editablePages.insert(toIdx, moved);
      for (int i = 0; i < _editablePages.length; i++) {
        _editablePages[i] = _editablePages[i].copyWith(pageOrder: i);
      }
      _activePageIndex = toIdx;
    });
  }

  Future<void> _duplicateCurrentPage() async {
    final page = _activePage;
    try {
      final ok = await ref
          .read(scanSessionProvider.notifier)
          .duplicatePage(page.id);
      if (!mounted) return;
      if (ok) {
        final sessionPages = ref.read(scanSessionProvider).pages;
        setState(() {
          _editablePages = List<DocumentPage>.from(sessionPages);
          _activePageIndex = (_activePageIndex + 1).clamp(
            0,
            _editablePages.length - 1,
          );
          _syncUiFromActivePage();
        });
        _loadAndRenderCurrentPage(immediate: true);
        showScaneliqToast(context, 'Page duplicated.');
      } else {
        // Standalone non-session fallback clone in editable list
        final clone = page.copyWith(
          id: '${page.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
          pageOrder: _activePageIndex + 1,
        );
        setState(() {
          _editablePages.insert(_activePageIndex + 1, clone);
          for (int i = 0; i < _editablePages.length; i++) {
            _editablePages[i] = _editablePages[i].copyWith(pageOrder: i);
          }
          _activePageIndex += 1;
        });
        showScaneliqToast(context, 'Page duplicated.');
      }
    } catch (_) {}
  }

  Future<void> _applyCurrentFilterToAllPages() async {
    final activeFilter = _recipe.filter;
    final activeBinarization = _recipe.binarization;
    final activeShadow = _recipe.shadowCorrection;

    for (int i = 0; i < _editablePages.length; i++) {
      final p = _editablePages[i];
      final stack = _history.stackFor(p);
      final updated = stack.current.copyWith(
        filter: activeFilter,
        binarization: activeBinarization,
        shadowCorrection: activeShadow,
      );
      stack.record(updated);
      _editablePages[i] = p.copyWith(editRecipe: updated);
    }
    setState(() {});
    _schedulePreviewRender(immediate: true);
    showScaneliqToast(
      context,
      'Applied filter settings to all ${_editablePages.length} pages.',
    );
  }

  Future<void> _loadAndRenderCurrentPage({bool immediate = false}) async {
    final page = _activePage;
    if (_history.cachedBaseBytesFor(page.id) == null) {
      final file = File(page.originalPath);
      if (file.existsSync()) {
        try {
          final rawBytes = await file.readAsBytes();
          final compactBytes = await Isolate.run(() {
            final decoded = img.decodeImage(rawBytes);
            if (decoded == null) return null;
            const maxPreviewDim = 640;
            final img.Image resized =
                (decoded.width > maxPreviewDim ||
                    decoded.height > maxPreviewDim)
                ? (decoded.width >= decoded.height
                      ? img.copyResize(decoded, width: maxPreviewDim)
                      : img.copyResize(decoded, height: maxPreviewDim))
                : decoded;
            return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
          });
          if (compactBytes != null && mounted) {
            _history.cacheBaseBytes(page.id, compactBytes);
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      _schedulePreviewRender(immediate: immediate);
    }
  }

  void _schedulePreviewRender({bool immediate = false}) {
    _debounceTimer?.cancel();
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 90);
    _debounceTimer = Timer(delay, _executePreviewRender);
  }

  Future<void> _executePreviewRender() async {
    if (!mounted) return;
    final page = _activePage;
    final recipe = _recipe;
    final effectiveRecipe = _currentTab == EditTab.crop
        ? recipe.copyWith(
            cropLeft: 0.0,
            cropTop: 0.0,
            cropRight: 1.0,
            cropBottom: 1.0,
            clearPerspectiveQuad: true,
          )
        : recipe;

    if (effectiveRecipe.isDefault) {
      if (mounted) {
        setState(() {
          _processedPreviewBytes = null;
          _isProcessingPreview = false;
        });
      }
      return;
    }

    final Uint8List? baseBytes = _history.cachedBaseBytesFor(page.id);
    final file = File(page.originalPath);
    if (baseBytes == null && !file.existsSync()) {
      return;
    }

    final int token = ++_renderGeneration;
    if (mounted) setState(() => _isProcessingPreview = true);

    try {
      final Uint8List encoded = baseBytes != null
          ? await ImageProcessingService.processEncodedSourceBytesInIsolate(
              baseBytes,
              effectiveRecipe,
              quality: 86,
            )
          : await ImageProcessingService.processImageFileToBytesInIsolate(
              file,
              effectiveRecipe,
              quality: 86,
              maxDimension: 640,
            );

      if (!mounted || token != _renderGeneration) return;
      setState(() {
        _processedPreviewBytes = encoded;
        _isProcessingPreview = false;
      });
    } catch (_) {
      if (mounted && token == _renderGeneration) {
        setState(() => _isProcessingPreview = false);
      }
    }
  }

  Future<void> _saveAndFinish() async {
    if (_isSaving) return;
    _activeStack.commitContinuousEdit();
    setState(() => _isSaving = true);

    try {
      if (_editablePages.length == 1) {
        widget.onApply(_recipe);
      } else {
        final sessionNotifier = ref.read(scanSessionProvider.notifier);
        final sessionState = ref.read(scanSessionProvider);
        final sessionIds = sessionState.pages.map((p) => p.id).toSet();
        final allInSession = _editablePages.every(
          (p) => sessionIds.contains(p.id),
        );

        if (allInSession && sessionState.pages.isNotEmpty) {
          await sessionNotifier.syncEditedPages(_editablePages);
        } else {
          final initialTarget = _editablePages.firstWhere(
            (p) => p.id == widget.page.id,
            orElse: () => _activePage,
          );
          widget.onApply(initialTarget.editRecipe);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showScaneliqToast(context, 'Could not save edits: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final bool isMultiPage = _editablePages.length > 1;
    final bool compact = MediaQuery.sizeOf(context).width < 360;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar: Back, Page indicator, Undo, Redo, Compare, Done
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 4 : 8,
                6,
                compact ? 8 : 12,
                6,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),

                  // Page indicator & prev/next controls
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tokens.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMultiPage) ...[
                            InkWell(
                              onTap: _activePageIndex > 0
                                  ? () => _switchToPage(_activePageIndex - 1)
                                  : null,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 15,
                                color: _activePageIndex > 0
                                    ? tokens.textPrimary
                                    : tokens.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              isMultiPage
                                  ? 'P${_activePageIndex + 1}/${_editablePages.length}'
                                  : 'PAGE ${_activePage.pageOrder + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ScaneliqTypography.monoStyle(
                                color: tokens.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isMultiPage) ...[
                            const SizedBox(width: 2),
                            InkWell(
                              onTap:
                                  _activePageIndex < _editablePages.length - 1
                                  ? () => _switchToPage(_activePageIndex + 1)
                                  : null,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color:
                                    _activePageIndex < _editablePages.length - 1
                                    ? tokens.textPrimary
                                    : tokens.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  IconButton(
                    tooltip: 'Undo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.undo_rounded,
                      size: 20,
                      color: _activeStack.canUndo
                          ? tokens.textPrimary
                          : tokens.textTertiary.withValues(alpha: 0.45),
                    ),
                    onPressed: _activeStack.canUndo && !_isSaving
                        ? _undo
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.redo_rounded,
                      size: 20,
                      color: _activeStack.canRedo
                          ? tokens.textPrimary
                          : tokens.textTertiary.withValues(alpha: 0.45),
                    ),
                    onPressed: _activeStack.canRedo && !_isSaving
                        ? _redo
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Compare Original',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.compare_rounded,
                      size: 20,
                      color: _isComparing ? tokens.accent : tokens.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isComparing = !_isComparing;
                        if (_isComparing && _currentTab == EditTab.crop) {
                          _currentTab = EditTab.filter;
                        }
                      });
                      _schedulePreviewRender(immediate: true);
                    },
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveAndFinish,
                    child: _isSaving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const ScaneliqHairlineDivider(),

            // 2. Main Document Preview Stage (occupies majority of screen)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad * 0.5,
                  vertical: 8,
                ),
                child: EditorPreviewStage(
                  originalFile: File(_activePage.originalPath),
                  originalPreviewBytes: _history.cachedBaseBytesFor(
                    _activePage.id,
                  ),
                  processedPreviewBytes: _processedPreviewBytes,
                  isProcessing: _isProcessingPreview,
                  isComparing: _isComparing,
                  compareSplit: _compareSplit,
                  onCompareSplitChanged: (v) =>
                      setState(() => _compareSplit = v),
                  isCropMode: _currentTab == EditTab.crop,
                  usePerspectiveWarp: _usePerspectiveWarp,
                  cropLeft: _recipe.cropLeft,
                  cropTop: _recipe.cropTop,
                  cropRight: _recipe.cropRight,
                  cropBottom: _recipe.cropBottom,
                  perspectiveQuad:
                      _recipe.perspectiveQuad ??
                      const PerspectiveQuad(
                        x1: 0.06,
                        y1: 0.06,
                        x2: 0.94,
                        y2: 0.06,
                        x3: 0.94,
                        y3: 0.94,
                        x4: 0.06,
                        y4: 0.94,
                      ),
                  onBoxCropChanged: (l, t, r, b) {
                    _previewContinuousRecipe(
                      _recipe.copyWith(
                        cropLeft: l,
                        cropTop: t,
                        cropRight: r,
                        cropBottom: b,
                        clearPerspectiveQuad: true,
                      ),
                    );
                  },
                  onPerspectiveQuadChanged: (q) {
                    _previewContinuousRecipe(
                      _recipe.copyWith(perspectiveQuad: q),
                    );
                  },
                  isCleanupMode:
                      _currentTab == EditTab.rotate && _isCleanupMode,
                  cleanupPatches: _recipe.cleanupPatches,
                  onAddCleanupPatch: (nx, ny) {
                    final updated =
                        List<CleanupPatch>.from(_recipe.cleanupPatches)..add(
                          CleanupPatch(
                            x: nx,
                            y: ny,
                            radius: _cleanupRadius,
                            type: _cleanupType,
                          ),
                        );
                    _commitRecipe(
                      _recipe.copyWith(cleanupPatches: updated),
                      immediatePreview: true,
                    );
                  },
                ),
              ),
            ),

            // 3. Multi-Page Quick Thumbnail Strip (when editing >=2 pages)
            if (isMultiPage) _buildMultiPageStrip(tokens, horizontalPad),

            // 4. Contextual Tool Controls Drawer + 5-Category Toolbar
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(top: BorderSide(color: tokens.hairline)),
              ),
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                10,
                horizontalPad,
                10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActiveToolPanel(tokens, isMultiPage),
                  const SizedBox(height: 10),
                  const ScaneliqHairlineDivider(),
                  const SizedBox(height: 8),
                  _buildBottomCategoryBar(tokens),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiPageStrip(ScaneliqTokens tokens, double horizontalPad) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: 7,
              ),
              itemCount: _editablePages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final page = _editablePages[index];
                final selected = index == _activePageIndex;
                final f = File(page.processedPath ?? page.originalPath);
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _switchToPage(index),
                  child: Container(
                    width: 36,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? tokens.accent : tokens.hairline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (f.existsSync())
                          Image.file(f, fit: BoxFit.cover, cacheWidth: 140)
                        else
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: tokens.textTertiary,
                          ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? tokens.accent : Colors.black54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: ScaneliqTypography.monoStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Move page earlier',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            onPressed: _activePageIndex > 0
                ? () => _movePageOrder(_activePageIndex, _activePageIndex - 1)
                : null,
          ),
          IconButton(
            tooltip: 'Move page later',
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
            onPressed: _activePageIndex < _editablePages.length - 1
                ? () => _movePageOrder(_activePageIndex, _activePageIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveToolPanel(ScaneliqTokens tokens, bool isMultiPage) {
    return switch (_currentTab) {
      EditTab.crop => _buildCropControls(tokens),
      EditTab.enhance => _buildEnhanceControls(tokens, isMultiPage),
      EditTab.filter => _buildFiltersRibbon(tokens),
      EditTab.adjust => _buildAdjustmentSliders(tokens),
      EditTab.rotate => _buildRotateAndCleanupControls(tokens, isMultiPage),
    };
  }

  Widget _buildCropControls(ScaneliqTokens tokens) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _EditorActionPill(
              icon: _isAutoDetectingCrop
                  ? Icons.hourglass_top_rounded
                  : Icons.auto_fix_high_outlined,
              label: _isAutoDetectingCrop ? 'Detecting...' : 'Auto Crop',
              accent: true,
              onPressed: _isAutoDetectingCrop ? null : _runAutoCropDetection,
            ),
            _EditorActionPill(
              icon: _usePerspectiveWarp
                  ? Icons.transform_rounded
                  : Icons.crop_rounded,
              label: _usePerspectiveWarp ? '4-Pt Perspective' : 'Box Crop',
              onPressed: () {
                setState(() {
                  _usePerspectiveWarp = !_usePerspectiveWarp;
                  if (_usePerspectiveWarp && _recipe.perspectiveQuad == null) {
                    _activeStack.record(
                      _recipe.copyWith(
                        perspectiveQuad: const PerspectiveQuad(
                          x1: 0.06,
                          y1: 0.06,
                          x2: 0.94,
                          y2: 0.06,
                          x3: 0.94,
                          y3: 0.94,
                          x4: 0.06,
                          y4: 0.94,
                        ),
                      ),
                    );
                  }
                });
              },
            ),
            _EditorActionPill(
              icon: Icons.check_rounded,
              label: 'Apply Crop',
              onPressed: () {
                _activeStack.commitContinuousEdit();
                setState(() => _currentTab = EditTab.filter);
                _schedulePreviewRender(immediate: true);
              },
            ),
            _EditorActionPill(
              icon: Icons.restart_alt_rounded,
              label: 'Reset Crop',
              onPressed: _resetCrop,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _usePerspectiveWarp
              ? 'Drag 4 corners to rectify perspective distortion'
              : 'Drag corner handles to frame the page or tap Auto Crop',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEnhanceControls(ScaneliqTokens tokens, bool isMultiPage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _EditorActionPill(
                icon: Icons.auto_awesome_outlined,
                label: 'Auto Enhance',
                selected: _recipe.filter == PageFilter.autoEnhance,
                onPressed: () => _commitRecipe(
                  _recipe.copyWith(
                    filter: PageFilter.autoEnhance,
                    shadowCorrection: true,
                    binarization: BinarizationMode.none,
                  ),
                  immediatePreview: true,
                ),
              ),
              const SizedBox(width: 8),
              _EditorActionPill(
                icon: Icons.contrast_rounded,
                label: 'Otsu B&W',
                selected: _recipe.binarization == BinarizationMode.otsu,
                onPressed: () => _commitRecipe(
                  _recipe.copyWith(
                    binarization: _recipe.binarization == BinarizationMode.otsu
                        ? BinarizationMode.none
                        : BinarizationMode.otsu,
                  ),
                  immediatePreview: true,
                ),
              ),
              const SizedBox(width: 8),
              _EditorActionPill(
                icon: Icons.blur_on_rounded,
                label: 'Sauvola',
                selected: _recipe.binarization == BinarizationMode.sauvola,
                onPressed: () => _commitRecipe(
                  _recipe.copyWith(
                    binarization:
                        _recipe.binarization == BinarizationMode.sauvola
                        ? BinarizationMode.none
                        : BinarizationMode.sauvola,
                  ),
                  immediatePreview: true,
                ),
              ),
              const SizedBox(width: 8),
              _EditorActionPill(
                icon: Icons.wb_sunny_outlined,
                label: 'Shadows',
                selected: _recipe.shadowCorrection,
                onPressed: () => _commitRecipe(
                  _recipe.copyWith(shadowCorrection: !_recipe.shadowCorrection),
                  immediatePreview: true,
                ),
              ),
              if (isMultiPage) ...[
                const SizedBox(width: 8),
                _EditorActionPill(
                  icon: Icons.done_all_rounded,
                  label: 'Apply All Pages',
                  accent: true,
                  onPressed: _applyCurrentFilterToAllPages,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersRibbon(ScaneliqTokens tokens) {
    const options = <(String, PageFilter, IconData)>[
      ('Original', PageFilter.original, Icons.photo_outlined),
      ('Auto', PageFilter.autoEnhance, Icons.auto_awesome_outlined),
      ('Magic Color', PageFilter.magicColor, Icons.auto_fix_normal_outlined),
      ('Enhance', PageFilter.enhancedText, Icons.text_fields_rounded),
      ('Grayscale', PageFilter.grayscale, Icons.filter_b_and_w_outlined),
      ('Black & White', PageFilter.blackAndWhite, Icons.contrast_rounded),
      ('Lighten', PageFilter.lighten, Icons.brightness_high_outlined),
      ('Darken', PageFilter.darken, Icons.brightness_low_outlined),
      ('Color Boost', PageFilter.colorBoost, Icons.palette_outlined),
      ('Whiteboard', PageFilter.whiteboard, Icons.co_present_outlined),
    ];

    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, filter, icon) = options[index];
          final selected = _recipe.filter == filter;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _isComparing = false);
              _commitRecipe(
                _recipe.copyWith(
                  filter: filter,
                  binarization: filter == PageFilter.original
                      ? BinarizationMode.none
                      : _recipe.binarization,
                ),
                immediatePreview: true,
              );
            },
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? tokens.accentSoft : tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? tokens.accent : tokens.hairline,
                  width: selected ? 1.6 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? tokens.accent : tokens.textPrimary,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? tokens.accent : tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdjustmentSliders(ScaneliqTokens tokens) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSingleSlider(
          label: 'Brightness',
          valueText:
              '${_recipe.brightness >= 0 ? '+' : ''}${(_recipe.brightness * 100).round()}',
          value: _recipe.brightness.clamp(-0.5, 0.5),
          min: -0.5,
          max: 0.5,
          divisions: 20,
          onChanged: (v) =>
              _previewContinuousRecipe(_recipe.copyWith(brightness: v)),
        ),
        _buildSingleSlider(
          label: 'Contrast',
          valueText: '${_recipe.contrast.toStringAsFixed(2)}x',
          value: _recipe.contrast.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: (v) =>
              _previewContinuousRecipe(_recipe.copyWith(contrast: v)),
        ),
        _buildSingleSlider(
          label: 'Sharpness',
          valueText: '${(_recipe.sharpness * 100).round()}%',
          value: _recipe.sharpness.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: (v) =>
              _previewContinuousRecipe(_recipe.copyWith(sharpness: v)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              minimumSize: const Size(0, 28),
            ),
            onPressed: () {
              _commitRecipe(
                _recipe.copyWith(
                  brightness: 0.0,
                  contrast: 1.0,
                  sharpness: 0.0,
                ),
                immediatePreview: true,
              );
            },
            child: const Text('Reset Adjustments'),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleSlider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final tokens = context.tokens;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: tokens.accent,
              onChangeStart: (_) => _activeStack.beginContinuousEdit(),
              onChanged: onChanged,
              onChangeEnd: (_) {
                _sliderHistoryDebounce?.cancel();
                _activeStack.commitContinuousEdit();
                setState(() {});
              },
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: ScaneliqTypography.monoStyle(
              color: tokens.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRotateAndCleanupControls(
    ScaneliqTokens tokens,
    bool isMultiPage,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _EditorActionPill(
              icon: Icons.rotate_left_rounded,
              label: 'Left 90°',
              onPressed: () => _rotateBy(-90),
            ),
            _EditorActionPill(
              icon: Icons.rotate_right_rounded,
              label: 'Right 90° (${_recipe.rotationDegrees}°)',
              onPressed: () => _rotateBy(90),
            ),
            _EditorActionPill(
              icon: Icons.cleaning_services_outlined,
              label: _isCleanupMode ? 'Cleanup: ON' : 'Patch Cleanup',
              selected: _isCleanupMode,
              onPressed: () => setState(() => _isCleanupMode = !_isCleanupMode),
            ),
            _EditorActionPill(
              icon: Icons.content_copy_outlined,
              label: 'Duplicate',
              onPressed: _duplicateCurrentPage,
            ),
            _EditorActionPill(
              icon: Icons.restart_alt_rounded,
              label: 'Reset All',
              onPressed: _resetCurrentPage,
            ),
          ],
        ),
        if (_isCleanupMode) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Hole Punch'),
                selected: _cleanupType == 'holePunch',
                onSelected: (_) => setState(() => _cleanupType = 'holePunch'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Finger'),
                selected: _cleanupType == 'finger',
                onSelected: (_) => setState(() => _cleanupType = 'finger'),
              ),
              const SizedBox(width: 8),
              if (_recipe.cleanupPatches.isNotEmpty)
                IconButton(
                  tooltip: 'Clear cleanup patches',
                  icon: Icon(Icons.delete_sweep_outlined, color: tokens.danger),
                  onPressed: () => _commitRecipe(
                    _recipe.copyWith(cleanupPatches: const []),
                    immediatePreview: true,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomCategoryBar(ScaneliqTokens tokens) {
    const categories = <(EditTab, String, IconData)>[
      (EditTab.crop, 'Crop', Icons.crop_rounded),
      (EditTab.enhance, 'Enhance', Icons.auto_fix_high_outlined),
      (EditTab.filter, 'Filters', Icons.auto_awesome_outlined),
      (EditTab.adjust, 'Adjust', Icons.tune_rounded),
      (EditTab.rotate, 'Rotate', Icons.rotate_right_rounded),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: categories.map((item) {
        final (tab, label, icon) = item;
        final selected = _currentTab == tab;
        return Expanded(
          child: Semantics(
            label: '$label tool',
            selected: selected,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final bool cropChanged =
                    (_currentTab == EditTab.crop) != (tab == EditTab.crop);
                setState(() {
                  _currentTab = tab;
                  if (tab == EditTab.crop) _isComparing = false;
                });
                if (cropChanged) _schedulePreviewRender(immediate: true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? tokens.accent : tokens.textSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EditorActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool accent;

  const _EditorActionPill({
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bool active = selected || accent;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? tokens.accent : tokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? tokens.accent : tokens.textPrimary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? tokens.accent : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

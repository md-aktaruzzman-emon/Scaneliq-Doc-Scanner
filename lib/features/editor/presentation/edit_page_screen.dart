import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';

enum EditTab { filter, binarize, crop, adjust, cleanup }

class EditPageScreen extends StatefulWidget {
  final DocumentPage page;
  final Function(EditRecipe) onApply;

  const EditPageScreen({super.key, required this.page, required this.onApply});

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  EditTab _currentTab = EditTab.filter;

  // Edit Recipe state
  late int _rotation;
  late PageFilter _filter;
  late double _contrast;
  late double _brightness;
  late double _cropLeft;
  late double _cropTop;
  late double _cropRight;
  late double _cropBottom;

  // Phase 3 new capabilities
  late BinarizationMode _binarization;
  late bool _shadowCorrection;
  late List<CleanupPatch> _cleanupPatches;
  late PerspectiveQuad _quad;
  bool _usePerspectiveWarp = false;

  // Cleanup tool config
  String _cleanupType = 'holePunch';
  double _cleanupRadius = 0.035; // ~3.5% of width

  // Debounced processed preview
  Uint8List? _previewBytes;
  bool _isProcessingPreview = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final recipe = widget.page.editRecipe;
    _rotation = recipe.rotationDegrees;
    _filter = recipe.filter;
    _contrast = recipe.contrast;
    _brightness = recipe.brightness;
    _cropLeft = recipe.cropLeft;
    _cropTop = recipe.cropTop;
    _cropRight = recipe.cropRight;
    _cropBottom = recipe.cropBottom;
    _binarization = recipe.binarization;
    _shadowCorrection = recipe.shadowCorrection;
    _cleanupPatches = List.from(recipe.cleanupPatches);

    if (recipe.perspectiveQuad != null) {
      _quad = recipe.perspectiveQuad!;
      _usePerspectiveWarp = !_quad.isStandard && _quad.isValidConvex();
    } else {
      _quad = const PerspectiveQuad(
        x1: 0.05,
        y1: 0.05,
        x2: 0.95,
        y2: 0.05,
        x3: 0.95,
        y3: 0.95,
        x4: 0.05,
        y4: 0.95,
      );
      _usePerspectiveWarp = false;
    }

    _schedulePreviewUpdate();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  EditRecipe _buildCurrentRecipe({bool forCropTab = false}) {
    return widget.page.editRecipe.copyWith(
      rotationDegrees: _rotation,
      filter: _filter,
      contrast: _contrast,
      brightness: _brightness,
      cropLeft: forCropTab ? 0.0 : _cropLeft,
      cropTop: forCropTab ? 0.0 : _cropTop,
      cropRight: forCropTab ? 1.0 : _cropRight,
      cropBottom: forCropTab ? 1.0 : _cropBottom,
      perspectiveQuad: forCropTab || !_usePerspectiveWarp ? null : _quad,
      clearPerspectiveQuad: forCropTab || !_usePerspectiveWarp,
      binarization: _binarization,
      shadowCorrection: _shadowCorrection,
      cleanupPatches: _cleanupPatches,
      recipeVersion: 2,
    );
  }

  void _schedulePreviewUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      // Always derive from original uncompressed image to prevent generation loss
      final imagePath = widget.page.originalPath;
      final file = File(imagePath);
      if (!file.existsSync() || !mounted) return;

      final currentRecipe = _buildCurrentRecipe(
        forCropTab: _currentTab == EditTab.crop,
      );

      // If entirely default and not in crop tab, use fast base renderer
      if (currentRecipe.isDefault && _currentTab != EditTab.crop) {
        if (mounted) {
          setState(() {
            _previewBytes = null;
            _isProcessingPreview = false;
          });
        }
        return;
      }

      if (mounted) setState(() => _isProcessingPreview = true);

      try {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null || !mounted) {
          if (mounted) setState(() => _isProcessingPreview = false);
          return;
        }

        // Downsample for responsive preview performance (~600px)
        img.Image previewSource = decoded;
        const maxPreviewDim = 600;
        if (previewSource.width > maxPreviewDim ||
            previewSource.height > maxPreviewDim) {
          final aspect = previewSource.width / previewSource.height;
          final pw = aspect >= 1.0
              ? maxPreviewDim
              : (maxPreviewDim * aspect).round();
          final ph = aspect >= 1.0
              ? (maxPreviewDim / aspect).round()
              : maxPreviewDim;
          previewSource = img.copyResize(previewSource, width: pw, height: ph);
        }

        final processed = ImageProcessingService.applyEditRecipe(
          previewSource,
          currentRecipe,
        );
        final encoded = Uint8List.fromList(
          img.encodeJpg(processed, quality: 85),
        );

        if (mounted) {
          setState(() {
            _previewBytes = encoded;
            _isProcessingPreview = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isProcessingPreview = false);
      }
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
    _schedulePreviewUpdate();
  }

  void _resetCrop() {
    setState(() {
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
      _usePerspectiveWarp = false;
      _quad = const PerspectiveQuad(
        x1: 0.05,
        y1: 0.05,
        x2: 0.95,
        y2: 0.05,
        x3: 0.95,
        y3: 0.95,
        x4: 0.05,
        y4: 0.95,
      );
    });
    _schedulePreviewUpdate();
  }

  void _resetAll() {
    setState(() {
      _rotation = 0;
      _filter = PageFilter.original;
      _contrast = 1.0;
      _brightness = 0.0;
      _binarization = BinarizationMode.none;
      _shadowCorrection = false;
      _cleanupPatches.clear();
      _resetCrop();
    });
    _schedulePreviewUpdate();
  }

  void _applyAndClose() {
    widget.onApply(_buildCurrentRecipe(forCropTab: false));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.page.processedPath ?? widget.page.originalPath;
    final file = File(imagePath);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Page ${widget.page.pageOrder + 1}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset All',
            onPressed: _resetAll,
          ),
          TextButton(
            onPressed: _applyAndClose,
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Preview Canvas with interactive touch handlers
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: file.existsSync()
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Base Preview Image (processed memory bytes or raw file with ColorFilter)
                            if (_previewBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                ),
                              )
                            else
                              Transform.rotate(
                                angle: _rotation * math.pi / 180,
                                child: ColorFiltered(
                                  colorFilter: _getColorFilter(),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                    ),
                                  ),
                                ),
                              ),

                            // Loading spinner when regenerating heavy preview
                            if (_isProcessingPreview)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            // Interactive overlays depending on active tab
                            if (_currentTab == EditTab.crop)
                              if (_usePerspectiveWarp)
                                _buildPerspectiveOverlay(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                )
                              else
                                _buildCropOverlay(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),

                            if (_currentTab == EditTab.cleanup)
                              _buildCleanupTapOverlay(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                          ],
                        );
                      },
                    )
                  : const Center(child: Text('Image file missing')),
            ),
          ),

          // Edit Tools Bottom Panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.surface3Dark
                      : AppColors.surface3Light,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab Switcher (Horizontal scroll for 5 tabs)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(
                          EditTab.filter,
                          'Filters',
                          Icons.auto_awesome,
                        ),
                        const SizedBox(width: 6),
                        _buildTabButton(
                          EditTab.binarize,
                          'Binarize',
                          Icons.contrast,
                        ),
                        const SizedBox(width: 6),
                        _buildTabButton(
                          EditTab.crop,
                          'Crop & Warp',
                          Icons.crop_rotate,
                        ),
                        const SizedBox(width: 6),
                        _buildTabButton(EditTab.adjust, 'Lighting', Icons.tune),
                        const SizedBox(width: 6),
                        _buildTabButton(
                          EditTab.cleanup,
                          'Cleanup',
                          Icons.cleaning_services,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tab 1: Filters & Color Enhancement
                  if (_currentTab == EditTab.filter) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'Original',
                            PageFilter.original,
                            Icons.photo_outlined,
                          ),
                          _buildFilterChip(
                            'Color Boost',
                            PageFilter.colorBoost,
                            Icons.palette,
                          ),
                          _buildFilterChip(
                            'B&W High-Contrast',
                            PageFilter.blackAndWhite,
                            Icons.contrast,
                          ),
                          _buildFilterChip(
                            'Whiteboard',
                            PageFilter.whiteboard,
                            Icons.co_present,
                          ),
                          _buildFilterChip(
                            'Grayscale',
                            PageFilter.grayscale,
                            Icons.filter_b_and_w,
                          ),
                          _buildFilterChip(
                            'Enhanced Text',
                            PageFilter.enhancedText,
                            Icons.auto_fix_high,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tab 2: Otsu & Sauvola Binarization
                  if (_currentTab == EditTab.binarize) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('None'),
                          selected: _binarization == BinarizationMode.none,
                          onSelected: (val) {
                            if (val) {
                              setState(
                                () => _binarization = BinarizationMode.none,
                              );
                              _schedulePreviewUpdate();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.circle, size: 14),
                          label: const Text('Otsu B&W'),
                          selected: _binarization == BinarizationMode.otsu,
                          onSelected: (val) {
                            if (val) {
                              setState(
                                () => _binarization = BinarizationMode.otsu,
                              );
                              _schedulePreviewUpdate();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.blur_on, size: 14),
                          label: const Text('Sauvola Adaptive'),
                          selected: _binarization == BinarizationMode.sauvola,
                          onSelected: (val) {
                            if (val) {
                              setState(
                                () => _binarization = BinarizationMode.sauvola,
                              );
                              _schedulePreviewUpdate();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _binarization == BinarizationMode.otsu
                          ? 'Otsu: Global histogram variance optimization for crisp scans.'
                          : _binarization == BinarizationMode.sauvola
                          ? 'Sauvola: Local adaptive thresholding overcoming uneven lighting.'
                          : 'Retain full color/grayscale dynamic range.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],

                  // Tab 3: Crop, Perspective Warp & Rotation
                  if (_currentTab == EditTab.crop) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _usePerspectiveWarp = !_usePerspectiveWarp;
                            });
                            _schedulePreviewUpdate();
                          },
                          icon: Icon(
                            _usePerspectiveWarp ? Icons.transform : Icons.crop,
                            size: 18,
                            color: _usePerspectiveWarp
                                ? AppColors.brandPrimary
                                : null,
                          ),
                          label: Text(
                            _usePerspectiveWarp
                                ? '4-Point Warp: ON'
                                : 'Mode: Box Crop',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _rotateClockwise,
                          icon: const Icon(
                            Icons.rotate_right_rounded,
                            size: 18,
                          ),
                          label: Text('Rotate ($_rotation°)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _resetCrop,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _usePerspectiveWarp
                          ? 'Drag 4 corner handles to perform full homography rectifying'
                          : 'Drag edge boundaries to crop rectangular area',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],

                  // Tab 4: Lighting & Shadow Correction
                  if (_currentTab == EditTab.adjust) ...[
                    Row(
                      children: [
                        const Icon(Icons.brightness_6, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Brightness',
                          style: TextStyle(fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _brightness,
                            min: -0.5,
                            max: 0.5,
                            divisions: 10,
                            label: _brightness.toStringAsFixed(1),
                            onChanged: (val) {
                              setState(() => _brightness = val);
                              _schedulePreviewUpdate();
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.contrast, size: 16),
                        const SizedBox(width: 8),
                        const Text('Contrast', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _contrast,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            label: _contrast.toStringAsFixed(1),
                            onChanged: (val) {
                              setState(() => _contrast = val);
                              _schedulePreviewUpdate();
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.wb_sunny_outlined, size: 18),
                      title: const Text(
                        'Shadow & Illumination Correction',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Equalize uneven ambient shadows across paper',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _shadowCorrection,
                      onChanged: (val) {
                        setState(() => _shadowCorrection = val);
                        _schedulePreviewUpdate();
                      },
                    ),
                  ],

                  // Tab 5: Manual Cleanup (Hole-punch & Finger Inpainting)
                  if (_currentTab == EditTab.cleanup) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Hole Punch'),
                              selected: _cleanupType == 'holePunch',
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _cleanupType = 'holePunch');
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Finger'),
                              selected: _cleanupType == 'finger',
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _cleanupType = 'finger');
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.undo, size: 20),
                              tooltip: 'Undo last patch',
                              onPressed: _cleanupPatches.isNotEmpty
                                  ? () {
                                      setState(() {
                                        _cleanupPatches.removeLast();
                                      });
                                      _schedulePreviewUpdate();
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, size: 20),
                              tooltip: 'Clear all patches',
                              onPressed: _cleanupPatches.isNotEmpty
                                  ? () {
                                      setState(() {
                                        _cleanupPatches.clear();
                                      });
                                      _schedulePreviewUpdate();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Brush Size',
                          style: TextStyle(fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _cleanupRadius,
                            min: 0.02,
                            max: 0.08,
                            divisions: 6,
                            label: '${(_cleanupRadius * 100).round()}%',
                            onChanged: (val) {
                              setState(() => _cleanupRadius = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tap on document to place clean background patch over hole punches or fingers',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(EditTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
      selectedColor: AppColors.brandPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        final wasCrop = _currentTab == EditTab.crop;
        setState(() => _currentTab = tab);
        if (wasCrop || tab == EditTab.crop) {
          _schedulePreviewUpdate();
        }
      },
    );
  }

  Widget _buildFilterChip(String label, PageFilter filter, IconData icon) {
    final isSelected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onSelected: (_) {
          setState(() {
            _filter = filter;
            if (filter == PageFilter.original) {
              _binarization = BinarizationMode.none;
            }
          });
          _schedulePreviewUpdate();
        },
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE OVERLAYS
  // ===========================================================================

  /// Overlay for standard Axis-Aligned Bounding Box Crop
  Widget _buildCropOverlay(double boxWidth, double boxHeight) {
    final leftPx = _cropLeft * boxWidth;
    final topPx = _cropTop * boxHeight;
    final widthPx = (_cropRight - _cropLeft) * boxWidth;
    final heightPx = (_cropBottom - _cropTop) * boxHeight;

    return Stack(
      children: [
        Positioned(
          left: leftPx,
          top: topPx,
          width: widthPx,
          height: heightPx,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.brandAccent, width: 2),
              color: AppColors.brandAccent.withAlpha(20),
            ),
          ),
        ),
        _buildHandle(
          left: leftPx - 16,
          top: topPx - 16,
          onDrag: (dx, dy) {
            setState(() {
              _cropLeft = (_cropLeft + dx / boxWidth).clamp(
                0.0,
                _cropRight - 0.05,
              );
              _cropTop = (_cropTop + dy / boxHeight).clamp(
                0.0,
                _cropBottom - 0.05,
              );
            });
            _schedulePreviewUpdate();
          },
        ),
        _buildHandle(
          left: leftPx + widthPx - 16,
          top: topPx - 16,
          onDrag: (dx, dy) {
            setState(() {
              _cropRight = (_cropRight + dx / boxWidth).clamp(
                _cropLeft + 0.05,
                1.0,
              );
              _cropTop = (_cropTop + dy / boxHeight).clamp(
                0.0,
                _cropBottom - 0.05,
              );
            });
            _schedulePreviewUpdate();
          },
        ),
        _buildHandle(
          left: leftPx - 16,
          top: topPx + heightPx - 16,
          onDrag: (dx, dy) {
            setState(() {
              _cropLeft = (_cropLeft + dx / boxWidth).clamp(
                0.0,
                _cropRight - 0.05,
              );
              _cropBottom = (_cropBottom + dy / boxHeight).clamp(
                _cropTop + 0.05,
                1.0,
              );
            });
            _schedulePreviewUpdate();
          },
        ),
        _buildHandle(
          left: leftPx + widthPx - 16,
          top: topPx + heightPx - 16,
          onDrag: (dx, dy) {
            setState(() {
              _cropRight = (_cropRight + dx / boxWidth).clamp(
                _cropLeft + 0.05,
                1.0,
              );
              _cropBottom = (_cropBottom + dy / boxHeight).clamp(
                _cropTop + 0.05,
                1.0,
              );
            });
            _schedulePreviewUpdate();
          },
        ),
      ],
    );
  }

  /// Overlay for 4-Point Arbitrary Perspective Homography Warp
  Widget _buildPerspectiveOverlay(double boxWidth, double boxHeight) {
    return Stack(
      children: [
        // Connecting polygon painter
        CustomPaint(
          size: Size(boxWidth, boxHeight),
          painter: _PerspectiveQuadPainter(quad: _quad),
        ),

        // P0: Top-Left Handle
        _buildHandle(
          left: _quad.x1 * boxWidth - 16,
          top: _quad.y1 * boxHeight - 16,
          label: 'TL',
          onDrag: (dx, dy) {
            setState(() {
              _quad = _quad.copyWith(
                x1: (_quad.x1 + dx / boxWidth).clamp(0.0, 1.0),
                y1: (_quad.y1 + dy / boxHeight).clamp(0.0, 1.0),
              );
            });
            _schedulePreviewUpdate();
          },
        ),

        // P1: Top-Right Handle
        _buildHandle(
          left: _quad.x2 * boxWidth - 16,
          top: _quad.y2 * boxHeight - 16,
          label: 'TR',
          onDrag: (dx, dy) {
            setState(() {
              _quad = _quad.copyWith(
                x2: (_quad.x2 + dx / boxWidth).clamp(0.0, 1.0),
                y2: (_quad.y2 + dy / boxHeight).clamp(0.0, 1.0),
              );
            });
            _schedulePreviewUpdate();
          },
        ),

        // P2: Bottom-Right Handle
        _buildHandle(
          left: _quad.x3 * boxWidth - 16,
          top: _quad.y3 * boxHeight - 16,
          label: 'BR',
          onDrag: (dx, dy) {
            setState(() {
              _quad = _quad.copyWith(
                x3: (_quad.x3 + dx / boxWidth).clamp(0.0, 1.0),
                y3: (_quad.y3 + dy / boxHeight).clamp(0.0, 1.0),
              );
            });
            _schedulePreviewUpdate();
          },
        ),

        // P3: Bottom-Left Handle
        _buildHandle(
          left: _quad.x4 * boxWidth - 16,
          top: _quad.y4 * boxHeight - 16,
          label: 'BL',
          onDrag: (dx, dy) {
            setState(() {
              _quad = _quad.copyWith(
                x4: (_quad.x4 + dx / boxWidth).clamp(0.0, 1.0),
                y4: (_quad.y4 + dy / boxHeight).clamp(0.0, 1.0),
              );
            });
            _schedulePreviewUpdate();
          },
        ),
      ],
    );
  }

  /// Overlay for placing non-destructive cleanup patches
  Widget _buildCleanupTapOverlay(double boxWidth, double boxHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final normX = (details.localPosition.dx / boxWidth).clamp(0.0, 1.0);
        final normY = (details.localPosition.dy / boxHeight).clamp(0.0, 1.0);
        setState(() {
          _cleanupPatches.add(
            CleanupPatch(
              x: normX,
              y: normY,
              radius: _cleanupRadius,
              type: _cleanupType,
            ),
          );
        });
        _schedulePreviewUpdate();
      },
      child: CustomPaint(
        size: Size(boxWidth, boxHeight),
        painter: _CleanupPatchesPainter(patches: _cleanupPatches),
      ),
    );
  }

  Widget _buildHandle({
    required double left,
    required double top,
    required Function(double, double) onDrag,
    String? label,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          onDrag(details.delta.dx, details.delta.dy);
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  ColorFilter _getColorFilter() {
    switch (_filter) {
      case PageFilter.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PageFilter.blackAndWhite:
        return const ColorFilter.matrix([
          1.5,
          0,
          0,
          0,
          -50,
          0,
          1.5,
          0,
          0,
          -50,
          0,
          0,
          1.5,
          0,
          -50,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PageFilter.whiteboard:
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          20,
          0,
          1.2,
          0,
          0,
          20,
          0,
          0,
          1.2,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PageFilter.enhancedText:
        return const ColorFilter.matrix([
          1.3,
          0,
          0,
          0,
          -20,
          0,
          1.3,
          0,
          0,
          -20,
          0,
          0,
          1.3,
          0,
          -20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PageFilter.colorBoost:
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PageFilter.original:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }
}

/// Custom painter for the 4-point quadrilateral homography boundaries
class _PerspectiveQuadPainter extends CustomPainter {
  final PerspectiveQuad quad;

  _PerspectiveQuadPainter({required this.quad});

  @override
  void paint(Canvas canvas, Size size) {
    final isValid = quad.isValidConvex();
    final strokeColor = isValid ? AppColors.brandAccent : Colors.redAccent;

    final path = Path()
      ..moveTo(quad.x1 * size.width, quad.y1 * size.height)
      ..lineTo(quad.x2 * size.width, quad.y2 * size.height)
      ..lineTo(quad.x3 * size.width, quad.y3 * size.height)
      ..lineTo(quad.x4 * size.width, quad.y4 * size.height)
      ..close();

    final fillPaint = Paint()
      ..color = (isValid ? AppColors.brandPrimary : Colors.red).withAlpha(30)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PerspectiveQuadPainter oldDelegate) {
    return oldDelegate.quad != quad;
  }
}

/// Custom painter displaying circles for active manual cleanup patches
class _CleanupPatchesPainter extends CustomPainter {
  final List<CleanupPatch> patches;

  _CleanupPatchesPainter({required this.patches});

  @override
  void paint(Canvas canvas, Size size) {
    for (final patch in patches) {
      final center = Offset(patch.x * size.width, patch.y * size.height);
      final radius = patch.radius * size.width;

      final fillPaint = Paint()
        ..color =
            (patch.type == 'holePunch' ? AppColors.brandAccent : Colors.amber)
                .withAlpha(50)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = patch.type == 'holePunch'
            ? AppColors.brandAccent
            : Colors.amber
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);

      // Center cross indicator
      canvas.drawLine(
        Offset(center.dx - 4, center.dy),
        Offset(center.dx + 4, center.dy),
        strokePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - 4),
        Offset(center.dx, center.dy + 4),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CleanupPatchesPainter oldDelegate) {
    return oldDelegate.patches.length != patches.length;
  }
}

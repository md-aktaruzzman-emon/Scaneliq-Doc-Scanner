import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';

enum EditTab { filter, crop, adjust }

class EditPageScreen extends StatefulWidget {
  final DocumentPage page;
  final Function(EditRecipe) onApply;

  const EditPageScreen({super.key, required this.page, required this.onApply});

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  EditTab _currentTab = EditTab.filter;

  late int _rotation;
  late PageFilter _filter;
  late double _contrast;
  late double _brightness;

  // Normalized crop bounds (0.0 to 1.0)
  late double _cropLeft;
  late double _cropTop;
  late double _cropRight;
  late double _cropBottom;

  @override
  void initState() {
    super.initState();
    _rotation = widget.page.editRecipe.rotationDegrees;
    _filter = widget.page.editRecipe.filter;
    _contrast = widget.page.editRecipe.contrast;
    _brightness = widget.page.editRecipe.brightness;
    _cropLeft = widget.page.editRecipe.cropLeft;
    _cropTop = widget.page.editRecipe.cropTop;
    _cropRight = widget.page.editRecipe.cropRight;
    _cropBottom = widget.page.editRecipe.cropBottom;
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
    });
  }

  void _resetAll() {
    setState(() {
      _rotation = 0;
      _filter = PageFilter.original;
      _contrast = 1.0;
      _brightness = 0.0;
      _resetCrop();
    });
  }

  void _applyAndClose() {
    final newRecipe = widget.page.editRecipe.copyWith(
      rotationDegrees: _rotation,
      filter: _filter,
      contrast: _contrast,
      brightness: _brightness,
      cropLeft: _cropLeft,
      cropTop: _cropTop,
      cropRight: _cropRight,
      cropBottom: _cropBottom,
    );
    widget.onApply(newRecipe);
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
          // Main Preview with live filters, rotation, and crop overlay
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
                            Transform.rotate(
                              angle: _rotation * 3.141592653589793 / 180,
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
                            // If in Crop tab, display interactive corner overlay
                            if (_currentTab == EditTab.crop)
                              _buildCropOverlay(
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

          // Edit Tools Panel
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
                  // Tab switcher (Filter, Crop, Adjust)
                  SegmentedButton<EditTab>(
                    segments: const [
                      ButtonSegment(
                        value: EditTab.filter,
                        label: Text('Filters'),
                        icon: Icon(Icons.auto_awesome, size: 16),
                      ),
                      ButtonSegment(
                        value: EditTab.crop,
                        label: Text('Crop & Rotate'),
                        icon: Icon(Icons.crop_rotate, size: 16),
                      ),
                      ButtonSegment(
                        value: EditTab.adjust,
                        label: Text('Adjust'),
                        icon: Icon(Icons.tune, size: 16),
                      ),
                    ],
                    selected: {_currentTab},
                    onSelectionChanged: (set) {
                      setState(() {
                        _currentTab = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Tab 1: Filters
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
                            'B&W Document',
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

                  // Tab 2: Crop & Rotate
                  if (_currentTab == EditTab.crop) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _rotateClockwise,
                          icon: const Icon(
                            Icons.rotate_right_rounded,
                            size: 20,
                          ),
                          label: Text('Rotate ($_rotation°)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _resetCrop,
                          icon: const Icon(Icons.crop_free_rounded, size: 20),
                          label: const Text('Reset Crop'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drag corner handles to adjust boundaries',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],

                  // Tab 3: Adjust Brightness & Contrast
                  if (_currentTab == EditTab.adjust) ...[
                    Row(
                      children: [
                        const Icon(Icons.brightness_6, size: 18),
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
                              setState(() {
                                _brightness = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.contrast, size: 18),
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
                              setState(() {
                                _contrast = val;
                              });
                            },
                          ),
                        ),
                      ],
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
          });
        },
      ),
    );
  }

  Widget _buildCropOverlay(double boxWidth, double boxHeight) {
    final leftPx = _cropLeft * boxWidth;
    final topPx = _cropTop * boxHeight;
    final widthPx = (_cropRight - _cropLeft) * boxWidth;
    final heightPx = (_cropBottom - _cropTop) * boxHeight;

    return Stack(
      children: [
        // Bounding Crop Box
        Positioned(
          left: leftPx,
          top: topPx,
          width: widthPx,
          height: heightPx,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.brandAccent, width: 2.5),
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
            ),
          ),
        ),

        // Corner 1: Top-Left Handle
        _buildHandle(
          left: leftPx - 14,
          top: topPx - 14,
          onPanUpdate: (details) {
            setState(() {
              _cropLeft = (_cropLeft + details.delta.dx / boxWidth).clamp(
                0.0,
                _cropRight - 0.1,
              );
              _cropTop = (_cropTop + details.delta.dy / boxHeight).clamp(
                0.0,
                _cropBottom - 0.1,
              );
            });
          },
        ),

        // Corner 2: Top-Right Handle
        _buildHandle(
          left: leftPx + widthPx - 14,
          top: topPx - 14,
          onPanUpdate: (details) {
            setState(() {
              _cropRight = (_cropRight + details.delta.dx / boxWidth).clamp(
                _cropLeft + 0.1,
                1.0,
              );
              _cropTop = (_cropTop + details.delta.dy / boxHeight).clamp(
                0.0,
                _cropBottom - 0.1,
              );
            });
          },
        ),

        // Corner 3: Bottom-Left Handle
        _buildHandle(
          left: leftPx - 14,
          top: topPx + heightPx - 14,
          onPanUpdate: (details) {
            setState(() {
              _cropLeft = (_cropLeft + details.delta.dx / boxWidth).clamp(
                0.0,
                _cropRight - 0.1,
              );
              _cropBottom = (_cropBottom + details.delta.dy / boxHeight).clamp(
                _cropTop + 0.1,
                1.0,
              );
            });
          },
        ),

        // Corner 4: Bottom-Right Handle
        _buildHandle(
          left: leftPx + widthPx - 14,
          top: topPx + heightPx - 14,
          onPanUpdate: (details) {
            setState(() {
              _cropRight = (_cropRight + details.delta.dx / boxWidth).clamp(
                _cropLeft + 0.1,
                1.0,
              );
              _cropBottom = (_cropBottom + details.delta.dy / boxHeight).clamp(
                _cropTop + 0.1,
                1.0,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildHandle({
    required double left,
    required double top,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandPrimary, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 3,
              backgroundColor: AppColors.brandPrimary,
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
      case PageFilter.original:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }
}

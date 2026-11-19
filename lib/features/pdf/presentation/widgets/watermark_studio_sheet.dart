import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';

/// Opens the Concept A Watermark Studio bottom sheet with live preview.
Future<WatermarkOptions?> showWatermarkStudioSheet(
  BuildContext context, {
  required int currentPage,
  required int totalPages,
}) {
  return showScaneliqBottomSheet<WatermarkOptions>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Watermark Studio',
          style: Theme.of(ctx).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        WatermarkStudioPanel(
          currentPage: currentPage,
          totalPages: totalPages,
        ),
      ],
    ),
  );
}

class WatermarkStudioPanel extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<WatermarkOptions>? onApply;

  const WatermarkStudioPanel({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onApply,
  });

  @override
  State<WatermarkStudioPanel> createState() => _WatermarkStudioPanelState();
}

class _WatermarkStudioPanelState extends State<WatermarkStudioPanel> {
  final TextEditingController _textController = TextEditingController(
    text: 'CONFIDENTIAL',
  );
  Color _color = const Color(0xFFDC2626);
  double _fontSize = 36.0;
  double _opacity = 0.25;
  double _rotation = -45.0;
  WatermarkPosition _position = WatermarkPosition.diagonalCenter;
  WatermarkPageSelection _pageSelection = WatermarkPageSelection.allPages;
  File? _imageFile;

  static const _swatches = <Color>[
    Color(0xFFDC2626), // Confidential Crimson
    Color(0xFF0052FF), // Ultramarine Copy
    Color(0xFF6B7280), // Neutral Draft Slate
    Color(0xFF059669), // Approved Emerald
    Color(0xFFD97706), // Internal Amber
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  WatermarkOptions _buildOptions() {
    final text = _textController.text.trim();
    return WatermarkOptions(
      text: text.isEmpty ? 'CONFIDENTIAL' : text,
      fontSize: _fontSize,
      color: _color,
      opacity: _opacity,
      rotationDegrees: _rotation,
      position: _position,
      pageSelection: _pageSelection,
      customPages1Indexed:
          _pageSelection == WatermarkPageSelection.customPages
              ? [widget.currentPage]
              : null,
      imageFile: _imageFile,
      imageScale: 0.45,
    );
  }

  Future<void> _pickImageWatermark() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked.isNotEmpty && picked.first.path != null && mounted) {
      setState(() => _imageFile = File(picked.first.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live mini-page preview card
          Center(
            child: Container(
              width: 150,
              height: 196,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.paperBorder),
                boxShadow: tokens.paperShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Simulated page lines
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 8, width: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        for (int i = 0; i < 6; i++) ...[
                          Container(
                            height: 4,
                            width: i.isEven ? 110 : 88,
                            color: Colors.grey.shade200,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  _buildLiveWatermarkOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Preset chips + Optional image logo stamp
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in const [
                  ('CONFIDENTIAL', Color(0xFFDC2626)),
                  ('DRAFT', Color(0xFF6B7280)),
                  ('COPY', Color(0xFF0052FF)),
                  ('APPROVED', Color(0xFF059669)),
                ]) ...[
                  ChoiceChip(
                    label: Text(preset.$1),
                    selected:
                        _imageFile == null &&
                        _textController.text.trim().toUpperCase() == preset.$1,
                    onSelected: (_) {
                      setState(() {
                        _imageFile = null;
                        _textController.text = preset.$1;
                        _color = preset.$2;
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                ActionChip(
                  avatar: const Icon(Icons.image_outlined, size: 16),
                  label: Text(
                    _imageFile != null ? 'Image Ready' : 'Image Stamp',
                  ),
                  onPressed: _pickImageWatermark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (_imageFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, size: 18, color: tokens.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _imageFile!.uri.pathSegments.last,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _imageFile = null),
                    child: const Text('Use Text'),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Watermark Text',
                hintText: 'e.g. CONFIDENTIAL',
              ),
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 12),

          // Color swatches
          if (_imageFile == null) ...[
            Row(
              children: [
                Text(
                  'Color',
                  style: ScaneliqTypography.monoStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                for (final c in _swatches) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? tokens.textPrimary : Colors.transparent,
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Position + Page Scope selectors
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<WatermarkPosition>(
                  initialValue: _position,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Position'),
                  items: const [
                    DropdownMenuItem(
                      value: WatermarkPosition.diagonalCenter,
                      child: Text('Diagonal (-45°)'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.horizontalCenter,
                      child: Text('Center'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.headerTop,
                      child: Text('Header Top'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.footerBottom,
                      child: Text('Footer Bottom'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _position = v;
                        if (v == WatermarkPosition.diagonalCenter && _rotation == 0) {
                          _rotation = -45;
                        } else if (v != WatermarkPosition.diagonalCenter) {
                          _rotation = 0;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<WatermarkPageSelection>(
                  initialValue: _pageSelection,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pages'),
                  items: [
                    DropdownMenuItem(
                      value: WatermarkPageSelection.allPages,
                      child: Text('All (${widget.totalPages})'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPageSelection.customPages,
                      child: Text('Current (P${widget.currentPage})'),
                    ),
                    const DropdownMenuItem(
                      value: WatermarkPageSelection.firstPageOnly,
                      child: Text('Page 1 Only'),
                    ),
                    const DropdownMenuItem(
                      value: WatermarkPageSelection.oddPagesOnly,
                      child: Text('Odd Pages'),
                    ),
                    const DropdownMenuItem(
                      value: WatermarkPageSelection.evenPagesOnly,
                      child: Text('Even Pages'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _pageSelection = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Font size + Opacity sliders
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Opacity',
                  style: ScaneliqTypography.monoStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0.10,
                  max: 0.80,
                  value: _opacity,
                  activeColor: tokens.accent,
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(_opacity * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: ScaneliqTypography.monoStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (_imageFile == null)
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    'Size',
                    style: ScaneliqTypography.monoStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: 18,
                    max: 68,
                    value: _fontSize,
                    activeColor: tokens.accent,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_fontSize.round()}pt',
                    textAlign: TextAlign.right,
                    style: ScaneliqTypography.monoStyle(
                      color: tokens.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final opts = _buildOptions();
                if (widget.onApply != null) {
                  widget.onApply!(opts);
                } else {
                  Navigator.of(context).pop(opts);
                }
              },
              icon: const Icon(Icons.branding_watermark_outlined),
              label: const Text('Apply Watermark to Copy'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveWatermarkOverlay() {
    Alignment alignment;
    double angleDeg = 0;
    switch (_position) {
      case WatermarkPosition.headerTop:
        alignment = Alignment.topCenter;
        break;
      case WatermarkPosition.footerBottom:
        alignment = Alignment.bottomCenter;
        break;
      case WatermarkPosition.horizontalCenter:
      case WatermarkPosition.center:
        alignment = Alignment.center;
        break;
      case WatermarkPosition.diagonalCenter:
        alignment = Alignment.center;
        angleDeg = _rotation;
        break;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Transform.rotate(
          angle: angleDeg * math.pi / 180.0,
          child: Opacity(
            opacity: _opacity,
            child: _imageFile != null && _imageFile!.existsSync()
                ? Image.file(
                    _imageFile!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    cacheWidth: 200,
                  )
                : Text(
                    _textController.text.trim().isEmpty
                        ? 'CONFIDENTIAL'
                        : _textController.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _color,
                      fontSize: (_fontSize * 0.42).clamp(9.0, 24.0),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

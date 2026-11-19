import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:share_plus/share_plus.dart';

enum RedactionBrushMode { solidBlackout, mosaicBlur }

class _NormalizedRedactionRect {
  final double x;
  final double y;
  final double w;
  final double h;
  final RedactionBrushMode mode;

  const _NormalizedRedactionRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.mode,
  });
}

/// Interactive Raster Redaction & Mosaic Studio allowing irreversible pixel
/// blackout or mosaic pixelation over image scans using background isolates.
class RasterRedactionScreen extends StatefulWidget {
  final File? initialImage;

  const RasterRedactionScreen({super.key, this.initialImage});

  @override
  State<RasterRedactionScreen> createState() => _RasterRedactionScreenState();
}

class _RasterRedactionScreenState extends State<RasterRedactionScreen> {
  File? _sourceFile;
  File? _outputFile;
  RedactionBrushMode _mode = RedactionBrushMode.solidBlackout;
  final List<_NormalizedRedactionRect> _regions = [];
  Offset? _dragStartNorm;
  Offset? _dragCurrentNorm;
  bool _isApplying = false;
  int _mosaicBlockSize = 14;

  @override
  void initState() {
    super.initState();
    _sourceFile = widget.initialImage;
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty || picked.first.path == null) return;
    setState(() {
      _sourceFile = File(picked.first.path!);
      _outputFile = null;
      _regions.clear();
    });
  }

  Offset _toNormalized(Offset localPos, Size boxSize) {
    if (boxSize.width <= 0 || boxSize.height <= 0) return Offset.zero;
    return Offset(
      (localPos.dx / boxSize.width).clamp(0.0, 1.0),
      (localPos.dy / boxSize.height).clamp(0.0, 1.0),
    );
  }

  void _commitDragBox() {
    if (_dragStartNorm == null || _dragCurrentNorm == null) return;
    final left = _dragStartNorm!.dx < _dragCurrentNorm!.dx
        ? _dragStartNorm!.dx
        : _dragCurrentNorm!.dx;
    final top = _dragStartNorm!.dy < _dragCurrentNorm!.dy
        ? _dragStartNorm!.dy
        : _dragCurrentNorm!.dy;
    final width = (_dragStartNorm!.dx - _dragCurrentNorm!.dx).abs();
    final height = (_dragStartNorm!.dy - _dragCurrentNorm!.dy).abs();

    if (width >= 0.02 && height >= 0.015) {
      _regions.add(
        _NormalizedRedactionRect(
          x: left.clamp(0.0, 0.99),
          y: top.clamp(0.0, 0.99),
          w: width.clamp(0.01, 1.0 - left),
          h: height.clamp(0.01, 1.0 - top),
          mode: _mode,
        ),
      );
    }
    _dragStartNorm = null;
    _dragCurrentNorm = null;
  }

  Future<void> _applyPermanentRedactions() async {
    final src = _sourceFile;
    if (src == null || _regions.isEmpty) return;

    setState(() => _isApplying = true);
    try {
      final exportDir = AppStorageService.instance.exportsDir;
      final workingPath = p.join(
        exportDir.path,
        'Redacted_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      File workingFile = await src.copy(workingPath);

      for (final rect in _regions) {
        if (rect.mode == RedactionBrushMode.solidBlackout) {
          workingFile = await ImageProcessingService.permanentlyRedactImageFile(
            sourceImage: workingFile,
            targetImage: workingFile,
            normX: rect.x,
            normY: rect.y,
            normW: rect.w,
            normH: rect.h,
          );
        } else {
          workingFile = await ImageProcessingService.permanentlyMosaicImageFile(
            sourceImage: workingFile,
            targetImage: workingFile,
            normX: rect.x,
            normY: rect.y,
            normW: rect.w,
            normH: rect.h,
            blockSize: _mosaicBlockSize,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _outputFile = workingFile;
        _sourceFile = workingFile;
        _regions.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Permanent raster redaction saved to ${p.basename(workingFile.path)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Redaction failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text('Raster Redaction Studio', style: textTheme.headlineSmall),
        actions: [
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: 'Undo last box',
              icon: const Icon(Icons.undo_rounded),
              onPressed: _isApplying
                  ? null
                  : () => setState(() => _regions.removeLast()),
            ),
          if (_outputFile != null)
            IconButton(
              tooltip: 'Share redacted image',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  files: [XFile(_outputFile!.path)],
                  text: 'Redacted with Scaneliq',
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tokens.hairline),
        ),
      ),
      body: Column(
        children: [
          // Mode selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(bottom: BorderSide(color: tokens.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<RedactionBrushMode>(
                        segments: const [
                          ButtonSegment(
                            value: RedactionBrushMode.solidBlackout,
                            icon: Icon(Icons.stop_rounded, size: 16),
                            label: Text('Blackout'),
                          ),
                          ButtonSegment(
                            value: RedactionBrushMode.mosaicBlur,
                            icon: Icon(Icons.grid_on_rounded, size: 16),
                            label: Text('Mosaic Blur'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Pick'),
                      onPressed: _isApplying ? null : _pickImage,
                    ),
                  ],
                ),
                if (_mode == RedactionBrushMode.mosaicBlur) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Mosaic Pixel Size:', style: textTheme.labelMedium),
                      Expanded(
                        child: Slider(
                          value: _mosaicBlockSize.toDouble(),
                          min: 8,
                          max: 32,
                          divisions: 6,
                          label: '${_mosaicBlockSize}px',
                          onChanged: (v) =>
                              setState(() => _mosaicBlockSize = v.round()),
                        ),
                      ),
                      Text(
                        '${_mosaicBlockSize}px',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Canvas
          Expanded(
            child: _sourceFile == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.branding_watermark_outlined,
                          size: 48,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pick a scanned page or image to permanently redact or mosaic.',
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Choose Image'),
                          onPressed: _pickImage,
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ScaneliqStatusLabel(
                          text:
                              'Drag across the image to mark regions (${_regions.length} marked)',
                          tone: _regions.isEmpty
                              ? ScaneliqStatusTone.neutral
                              : ScaneliqStatusTone.accent,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 0.72,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final boxSize = constraints.biggest;
                                  return GestureDetector(
                                    onPanStart: (d) => setState(() {
                                      _dragStartNorm = _toNormalized(
                                        d.localPosition,
                                        boxSize,
                                      );
                                      _dragCurrentNorm = _dragStartNorm;
                                    }),
                                    onPanUpdate: (d) => setState(() {
                                      _dragCurrentNorm = _toNormalized(
                                        d.localPosition,
                                        boxSize,
                                      );
                                    }),
                                    onPanEnd: (_) => setState(_commitDragBox),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              ScaneliqRadius.paperBorderRadius,
                                          child: Image.file(
                                            _sourceFile!,
                                            key: ValueKey(_sourceFile!.path),
                                            fit: BoxFit.fill,
                                            cacheWidth: 1400,
                                          ),
                                        ),
                                        CustomPaint(
                                          painter: _RedactionBoxPainter(
                                            regions: _regions,
                                            dragStart: _dragStartNorm,
                                            dragEnd: _dragCurrentNorm,
                                            activeMode: _mode,
                                            accentColor: tokens.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Bottom action bar
          if (_sourceFile != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(top: BorderSide(color: tokens.hairline)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isApplying || _regions.isEmpty
                        ? null
                        : _applyPermanentRedactions,
                    icon: _isApplying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_rounded),
                    label: Text(
                      _isApplying
                          ? 'Zeroing Pixels in Isolate...'
                          : 'Permanently Apply Redaction (${_regions.length})',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RedactionBoxPainter extends CustomPainter {
  final List<_NormalizedRedactionRect> regions;
  final Offset? dragStart;
  final Offset? dragEnd;
  final RedactionBrushMode activeMode;
  final Color accentColor;

  const _RedactionBoxPainter({
    required this.regions,
    required this.dragStart,
    required this.dragEnd,
    required this.activeMode,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.w * size.width,
        r.h * size.height,
      );
      final fill = Paint()
        ..color = r.mode == RedactionBrushMode.solidBlackout
            ? Colors.black.withValues(alpha: 0.85)
            : accentColor.withValues(alpha: 0.45);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = r.mode == RedactionBrushMode.solidBlackout
            ? Colors.redAccent
            : accentColor;
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }

    if (dragStart != null && dragEnd != null) {
      final rect = Rect.fromPoints(
        Offset(dragStart!.dx * size.width, dragStart!.dy * size.height),
        Offset(dragEnd!.dx * size.width, dragEnd!.dy * size.height),
      );
      final previewPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = activeMode == RedactionBrushMode.solidBlackout
            ? Colors.redAccent
            : accentColor;
      canvas.drawRect(rect, previewPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RedactionBoxPainter oldDelegate) => true;
}

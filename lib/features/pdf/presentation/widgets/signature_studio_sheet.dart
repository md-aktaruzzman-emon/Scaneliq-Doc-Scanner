import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';

/// Result returned when the user creates or selects a visual signature overlay.
class SignatureDraftResult {
  final Uint8List pngBytes;
  final double rotationDegrees;
  final double scale;

  const SignatureDraftResult({
    required this.pngBytes,
    this.rotationDegrees = 0.0,
    this.scale = 1.0,
  });
}

/// Renders touch-drawn signature strokes cleanly onto a transparent PNG buffer.
Future<Uint8List> exportSignatureStrokesToPngBytes({
  required List<List<Offset>> strokes,
  required Size canvasSize,
  required Color inkColor,
  required double strokeWidth,
}) async {
  final double w = canvasSize.width.clamp(120.0, 900.0);
  final double h = canvasSize.height.clamp(60.0, 400.0);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

  final paint = Paint()
    ..color = inkColor
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, strokeWidth * 0.6, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      continue;
    }
    if (stroke.length < 2) continue;
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (int i = 1; i < stroke.length; i++) {
      final prev = stroke[i - 1];
      final curr = stroke[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.last.dx, stroke.last.dy);
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.round(), h.round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

/// Opens the Concept A Visual Signature Studio bottom sheet.
///
/// Explicitly clarifies that this creates a visual handwritten overlay embedded in the PDF,
/// rather than a cryptographic X.509 certificate signature.
Future<SignatureDraftResult?> showSignatureStudioSheet(BuildContext context) {
  return showScaneliqBottomSheet<SignatureDraftResult>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Signature Studio',
          style: Theme.of(ctx).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const SignatureStudioPanel(),
      ],
    ),
  );
}

class SignatureStudioPanel extends StatefulWidget {
  final ValueChanged<SignatureDraftResult>? onApply;

  const SignatureStudioPanel({super.key, this.onApply});

  @override
  State<SignatureStudioPanel> createState() => _SignatureStudioPanelState();
}

class _SignatureStudioPanelState extends State<SignatureStudioPanel> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _inkColor = const Color(0xFF0F172A);
  double _strokeWidth = 3.2;
  double _rotationDegrees = 0.0;
  final double _scale = 1.0;
  bool _isExporting = false;

  static const _inkColors = <Color>[
    Color(0xFF0F172A), // Formal Black Ink
    Color(0xFF0052FF), // Ultramarine Blue Ink
    Color(0xFF1E3A8A), // Fountain Navy
    Color(0xFFB91C1C), // Stamp Red
  ];

  Size _padSize = const Size(340, 150);

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  Future<void> _submit() async {
    if (_strokes.isEmpty || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      final png = await exportSignatureStrokesToPngBytes(
        strokes: _strokes,
        canvasSize: _padSize,
        inkColor: _inkColor,
        strokeWidth: _strokeWidth,
      );
      final result = SignatureDraftResult(
        pngBytes: png,
        rotationDegrees: _rotationDegrees,
        scale: _scale,
      );
      if (widget.onApply != null) {
        widget.onApply!(result);
      } else if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Honest cryptographic boundary disclosure
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.hairline),
          ),
          child: Row(
            children: [
              Icon(Icons.draw_outlined, size: 15, color: tokens.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Creates a visual handwritten signature overlay (non-cryptographic, no X.509 certificate).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Signature Drawing Pad (High-contrast warm paper surface)
        LayoutBuilder(
          builder: (context, constraints) {
            _padSize = Size(constraints.maxWidth, 150);
            return Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.paperBorder, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onPanStart: (d) {
                  setState(() => _currentStroke = [d.localPosition]);
                },
                onPanUpdate: (d) {
                  setState(() {
                    _currentStroke = [..._currentStroke, d.localPosition];
                  });
                },
                onPanEnd: (_) {
                  if (_currentStroke.isNotEmpty) {
                    setState(() {
                      _strokes.add(_currentStroke);
                      _currentStroke = [];
                    });
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Baseline rule
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 34,
                      child: Container(
                        height: 1,
                        color: ScaneliqColorPalette.light.paperBorder,
                      ),
                    ),
                    if (_strokes.isEmpty && _currentStroke.isEmpty)
                      Center(
                        child: Text(
                          'Sign here with finger or stylus',
                          style: TextStyle(
                            fontFamily: ScaneliqTypography.bodyFontFamily,
                            color: ScaneliqColorPalette.light.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    CustomPaint(
                      painter: _SignaturePadPainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        color: _inkColor,
                        strokeWidth: _strokeWidth,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Ink color + Thickness + Undo / Clear controls
        Row(
          children: [
            for (final c in _inkColors) ...[
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _inkColor = c),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _inkColor == c ? tokens.accent : Colors.transparent,
                      width: 2.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _strokes.isNotEmpty ? _undoStroke : null,
              icon: const Icon(Icons.undo_rounded, size: 17),
              label: const Text('Undo'),
            ),
            TextButton.icon(
              onPressed: _strokes.isNotEmpty ? _clear : null,
              icon: const Icon(Icons.delete_sweep_outlined, size: 17),
              label: const Text('Clear'),
            ),
          ],
        ),

        // Pen thickness + Placement rotation + Size scale sliders
        Row(
          children: [
            SizedBox(
              width: 66,
              child: Text(
                'Ink Size',
                style: ScaneliqTypography.monoStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                min: 1.5,
                max: 7.0,
                value: _strokeWidth,
                activeColor: tokens.accent,
                onChanged: (v) => setState(() => _strokeWidth = v),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${_strokeWidth.toStringAsFixed(1)}px',
                textAlign: TextAlign.right,
                style: ScaneliqTypography.monoStyle(
                  color: tokens.textPrimary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 66,
              child: Text(
                'Rotate',
                style: ScaneliqTypography.monoStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                min: -30,
                max: 30,
                value: _rotationDegrees,
                activeColor: tokens.accent,
                onChanged: (v) => setState(() => _rotationDegrees = v),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${_rotationDegrees.round()}°',
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
            onPressed: _strokes.isEmpty || _isExporting ? null : _submit,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Place Signature on Page'),
          ),
        ),
      ],
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;

  _SignaturePadPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final s in [...strokes, if (currentStroke.isNotEmpty) currentStroke]) {
      if (s.length == 1) {
        canvas.drawCircle(
          s.first,
          strokeWidth * 0.6,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      } else if (s.length >= 2) {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (int i = 1; i < s.length; i++) {
          final prev = s[i - 1];
          final curr = s[i];
          path.quadraticBezierTo(
            prev.dx,
            prev.dy,
            (prev.dx + curr.dx) / 2,
            (prev.dy + curr.dy) / 2,
          );
        }
        path.lineTo(s.last.dx, s.last.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter oldDelegate) => true;
}

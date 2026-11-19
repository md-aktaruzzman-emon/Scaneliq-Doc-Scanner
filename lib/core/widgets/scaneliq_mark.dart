import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';

/// Monochrome Concept A viewfinder brand mark (26x26px rounded container
/// with corner brackets and horizontal optical scan bar).
class ScaneliqMark extends StatelessWidget {
  final double size;

  const ScaneliqMark({super.key, this.size = 26.0});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = size == 26.0
        ? ScaneliqRadius.brandMarkBorderRadius
        : BorderRadius.circular(size * 0.27);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.textPrimary,
        borderRadius: radius,
      ),
      padding: EdgeInsets.all(size * 0.21),
      child: CustomPaint(painter: _ViewfinderMarkPainter(color: tokens.bg)),
    );
  }
}

class _ViewfinderMarkPainter extends CustomPainter {
  final Color color;

  const _ViewfinderMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.13).clamp(1.5, 2.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final arm = w * 0.28;

    // Top-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, 0)
        ..lineTo(arm, 0),
      paint,
    );
    // Top-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(w - arm, 0)
        ..lineTo(w, 0)
        ..lineTo(w, arm),
      paint,
    );
    // Bottom-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(0, h - arm)
        ..lineTo(0, h)
        ..lineTo(arm, h),
      paint,
    );
    // Bottom-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(w - arm, h)
        ..lineTo(w, h)
        ..lineTo(w, h - arm),
      paint,
    );
    // Optical scan line across center
    canvas.drawLine(
      Offset(w * 0.14, h * 0.5),
      Offset(w * 0.86, h * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

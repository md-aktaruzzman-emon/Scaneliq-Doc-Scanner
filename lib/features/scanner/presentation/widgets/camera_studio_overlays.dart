import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart';

/// Paints a genuine detected [PerspectiveQuad] with Ultramarine #3B82F6
/// edges, translucent fill, and corner anchor circles.
class DocumentBoundaryOverlay extends StatelessWidget {
  final PerspectiveQuad? quad;
  final double stabilityProgress;

  const DocumentBoundaryOverlay({
    super.key,
    required this.quad,
    this.stabilityProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final activeQuad = quad;
    if (activeQuad == null || !activeQuad.isValidConvex()) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DocumentBoundaryPainter(
            quad: activeQuad,
            stabilityProgress: stabilityProgress,
          ),
        ),
      ),
    );
  }
}

class _DocumentBoundaryPainter extends CustomPainter {
  final PerspectiveQuad quad;
  final double stabilityProgress;

  _DocumentBoundaryPainter({
    required this.quad,
    required this.stabilityProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[
      Offset(quad.x1 * size.width, quad.y1 * size.height),
      Offset(quad.x2 * size.width, quad.y2 * size.height),
      Offset(quad.x3 * size.width, quad.y3 * size.height),
      Offset(quad.x4 * size.width, quad.y4 * size.height),
    ];

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final fillAlpha = 0.09 + (stabilityProgress * 0.07);
    final fillPaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: fillAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final anchorFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final anchorRing = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final pt in pts) {
      canvas.drawCircle(pt, 5.5, anchorFill);
      canvas.drawCircle(pt, 5.5, anchorRing);
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentBoundaryPainter oldDelegate) {
    return oldDelegate.quad != quad ||
        oldDelegate.stabilityProgress != stabilityProgress;
  }
}

/// Rule-of-thirds 3x3 framing grid overlay for camera alignment.
class RuleOfThirdsGridOverlay extends StatelessWidget {
  const RuleOfThirdsGridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _RuleOfThirdsGridPainter()),
      ),
    );
  }
}

class _RuleOfThirdsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 0.8;

    for (final factor in const [1 / 3, 2 / 3]) {
      final dx = size.width * factor;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      final dy = size.height * factor;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hairline frame guides specifically tailored for ID Card, Book, and Whiteboard capture.
class SpecializedScanModeGuide extends StatelessWidget {
  final ScanMode mode;
  final int idCardStep;

  const SpecializedScanModeGuide({
    super.key,
    required this.mode,
    required this.idCardStep,
  });

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      ScanMode.idCard => _buildIdCardGuide(context),
      ScanMode.book => _buildBookGuide(context),
      ScanMode.whiteboard => _buildWhiteboardGuide(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildIdCardGuide(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardW = (constraints.maxWidth * 0.84).clamp(180.0, 360.0);
            final cardH = cardW * 0.63; // ISO/IEC 7810 ID-1 ratio
            return Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3B82F6),
                  width: 1.8,
                ),
                color: Colors.black.withValues(alpha: 0.14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC090A0D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      idCardStep == 0
                          ? 'STEP 1 OF 2 · FRONT SIDE'
                          : 'STEP 2 OF 2 · BACK SIDE',
                      style: ScaneliqTypography.monoStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      idCardStep == 0
                          ? 'Align front of card inside frame'
                          : 'Flip card and align back inside frame',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookGuide(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = (constraints.maxWidth * 0.88).clamp(200.0, 380.0);
            final h = (constraints.maxHeight * 0.64).clamp(160.0, 340.0);
            return Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.85),
                  width: 1.6,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 1.5,
                      height: double.infinity,
                      color: const Color(0xFF34D399).withValues(alpha: 0.85),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _monoOverlayTag('PAGE L'),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _monoOverlayTag('PAGE R'),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _monoOverlayTag('ALIGN SPINE TO CENTER LINE'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWhiteboardGuide(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: _monoOverlayTag('WHITEBOARD · GLARE & TEXT BOOST'),
        ),
      ),
    );
  }

  Widget _monoOverlayTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xCC090A0D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: ScaneliqTypography.monoStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tap-to-focus square reticle shown temporarily on viewfinder tap.
class FocusReticleOverlay extends StatelessWidget {
  final Offset normalizedPoint;

  const FocusReticleOverlay({super.key, required this.normalizedPoint});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const size = 56.0;
            final left =
                (normalizedPoint.dx * constraints.maxWidth - size / 2).clamp(
                  8.0,
                  (constraints.maxWidth - size - 8.0).clamp(8.0, 9999.0),
                );
            final top =
                (normalizedPoint.dy * constraints.maxHeight - size / 2).clamp(
                  8.0,
                  (constraints.maxHeight - size - 8.0).clamp(8.0, 9999.0),
                );
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF3B82F6),
                        width: 1.8,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Studio recovery panel displayed when camera permission is denied or blocked.
class CameraPermissionDeniedStudioView extends StatelessWidget {
  final bool permanentlyDenied;
  final String message;
  final VoidCallback onRetryPermission;
  final VoidCallback onImportGallery;

  const CameraPermissionDeniedStudioView({
    super.key,
    required this.permanentlyDenied,
    required this.message,
    required this.onRetryPermission,
    required this.onImportGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ScaneliqColorPalette.cameraStageBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ScaneliqColorPalette.cameraStageBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0x24F59E0B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  color: Color(0xFFFBBF24),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  permanentlyDenied
                      ? 'PERMISSION RESTRICTED'
                      : 'CAMERA PERMISSION REQUIRED',
                  style: ScaneliqTypography.monoStyle(
                    color: const Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Camera Access Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                permanentlyDenied
                    ? 'Camera permission is disabled in Android Settings for Scaneliq. Enable Camera access in Settings or import document photos from Gallery.'
                    : message,
                style: const TextStyle(
                  color: Color(0xFF9CA0AB),
                  fontSize: 13.5,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onRetryPermission,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    permanentlyDenied
                        ? 'Re-check Permission'
                        : 'Allow Camera Access',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: ScaneliqColorPalette.cameraStageBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onImportGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Import from Gallery Instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Studio recovery panel for camera hardware unavailable or initialization errors.
class CameraErrorStudioView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onImportGallery;

  const CameraErrorStudioView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onImportGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ScaneliqColorPalette.cameraStageBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ScaneliqColorPalette.cameraStageBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0x24F87171),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.videocam_off_outlined,
                  color: Color(0xFFF87171),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CAMERA UNAVAILABLE',
                  style: ScaneliqTypography.monoStyle(
                    color: const Color(0xFFF87171),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF9CA0AB),
                  fontSize: 13.5,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Camera'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: ScaneliqColorPalette.cameraStageBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onImportGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Pick Images from Gallery'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

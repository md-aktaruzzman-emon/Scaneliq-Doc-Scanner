import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';

/// Main document stage for the Concept A Scan Editor, supporting:
/// - High-contrast document paper framing + pinch zoom/pan
/// - Interactive Before/After split slider comparing Original vs Enhanced bitmaps
/// - Axis-aligned Box Crop and 4-point Perspective Quad corner handles
/// - Cleanup patch placement overlay
class EditorPreviewStage extends StatelessWidget {
  final File originalFile;
  final Uint8List? originalPreviewBytes;
  final Uint8List? processedPreviewBytes;
  final bool isProcessing;
  final bool isComparing;
  final double compareSplit;
  final ValueChanged<double> onCompareSplitChanged;
  final bool isCropMode;
  final bool usePerspectiveWarp;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final PerspectiveQuad perspectiveQuad;
  final void Function(double l, double t, double r, double b) onBoxCropChanged;
  final ValueChanged<PerspectiveQuad> onPerspectiveQuadChanged;
  final bool isCleanupMode;
  final List<CleanupPatch> cleanupPatches;
  final void Function(double normX, double normY) onAddCleanupPatch;

  const EditorPreviewStage({
    super.key,
    required this.originalFile,
    required this.originalPreviewBytes,
    required this.processedPreviewBytes,
    required this.isProcessing,
    required this.isComparing,
    required this.compareSplit,
    required this.onCompareSplitChanged,
    required this.isCropMode,
    required this.usePerspectiveWarp,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.perspectiveQuad,
    required this.onBoxCropChanged,
    required this.onPerspectiveQuadChanged,
    required this.isCleanupMode,
    required this.cleanupPatches,
    required this.onAddCleanupPatch,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (!originalFile.existsSync() && originalPreviewBytes == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: tokens.textTertiary,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                'Original image unavailable on storage',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = (constraints.maxWidth - 16).clamp(160.0, 900.0);
        final double maxH = (constraints.maxHeight - 12).clamp(160.0, 900.0);

        return Center(
          child: SizedBox(
            width: maxW,
            height: maxH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base document canvas (Before/After split or interactive zoomable page)
                if (isComparing)
                  _buildBeforeAfterComparison(tokens, maxW, maxH)
                else
                  _buildInteractiveDocumentView(tokens, maxW, maxH),

                // Subtle non-blocking isolate render spinner
                if (isProcessing)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ScaneliqColorPalette.cameraStudioBg
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tokens.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RENDERING',
                            style: ScaneliqTypography.monoStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOriginalImageWidget(double w, double h) {
    if (originalPreviewBytes != null) {
      return Image.memory(
        originalPreviewBytes!,
        width: w,
        height: h,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return Image.file(
      originalFile,
      width: w,
      height: h,
      fit: BoxFit.contain,
      cacheWidth: 960,
      gaplessPlayback: true,
    );
  }

  Widget _buildProcessedImageWidget(double w, double h) {
    if (processedPreviewBytes != null) {
      return Image.memory(
        processedPreviewBytes!,
        width: w,
        height: h,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return _buildOriginalImageWidget(w, h);
  }

  Widget _buildInteractiveDocumentView(
    ScaneliqTokens tokens,
    double maxW,
    double maxH,
  ) {
    final Widget baseContent = Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ScaneliqRadius.paper),
        border: Border.all(color: tokens.paperBorder, width: 1),
        boxShadow: tokens.paperShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          isCropMode
              ? _buildOriginalImageWidget(maxW, maxH)
              : _buildProcessedImageWidget(maxW, maxH),
          if (isCropMode)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (_, box) {
                  return usePerspectiveWarp
                      ? _buildPerspectiveOverlay(
                          box.maxWidth,
                          box.maxHeight,
                          tokens,
                        )
                      : _buildBoxCropOverlay(
                          box.maxWidth,
                          box.maxHeight,
                          tokens,
                        );
                },
              ),
            ),
          if (isCleanupMode && !isCropMode)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (_, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final nx = (d.localPosition.dx / box.maxWidth).clamp(
                      0.0,
                      1.0,
                    );
                    final ny = (d.localPosition.dy / box.maxHeight).clamp(
                      0.0,
                      1.0,
                    );
                    onAddCleanupPatch(nx, ny);
                  },
                  child: CustomPaint(
                    painter: _CleanupPatchesPainter(
                      patches: cleanupPatches,
                      accentColor: tokens.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isCropMode || isCleanupMode) {
      return baseContent;
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: baseContent,
    );
  }

  Widget _buildBeforeAfterComparison(
    ScaneliqTokens tokens,
    double maxW,
    double maxH,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final next = (details.localPosition.dx / maxW).clamp(0.05, 0.95);
        onCompareSplitChanged(next);
      },
      onTapDown: (details) {
        final next = (details.localPosition.dx / maxW).clamp(0.05, 0.95);
        onCompareSplitChanged(next);
      },
      child: Container(
        width: maxW,
        height: maxH,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ScaneliqRadius.paper),
          border: Border.all(color: tokens.paperBorder, width: 1),
          boxShadow: tokens.paperShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Enhanced (full layer underneath)
            Center(child: _buildProcessedImageWidget(maxW, maxH)),

            // Original (clipped to left portion [0..compareSplit])
            ClipRect(
              clipper: _HorizontalSplitClipper(compareSplit),
              child: Center(child: _buildOriginalImageWidget(maxW, maxH)),
            ),

            // Vertical divider line + grab handle
            Positioned(
              left: (maxW * compareSplit - 1.2).clamp(0.0, maxW - 2.4),
              top: 0,
              bottom: 0,
              child: Container(width: 2.4, color: tokens.accent),
            ),
            Positioned(
              left: (maxW * compareSplit - 15).clamp(2.0, maxW - 32),
              top: (maxH / 2) - 15,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Clear Original / Enhanced labels
            Positioned(
              top: 10,
              left: 10,
              child: _compareBadge('ORIGINAL', ScaneliqColorPalette.cameraStudioBg),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _compareBadge('ENHANCED', tokens.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareBadge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: ScaneliqTypography.monoStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBoxCropOverlay(
    double boxW,
    double boxH,
    ScaneliqTokens tokens,
  ) {
    final double leftPx = cropLeft * boxW;
    final double topPx = cropTop * boxH;
    final double rectW = (cropRight - cropLeft) * boxW;
    final double rectH = (cropBottom - cropTop) * boxH;

    return Stack(
      children: [
        Positioned(
          left: leftPx,
          top: topPx,
          width: rectW,
          height: rectH,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.accent, width: 2),
              color: tokens.accent.withValues(alpha: 0.10),
            ),
          ),
        ),
        _cornerHandle(
          left: leftPx - 16,
          top: topPx - 16,
          accent: tokens.accent,
          semanticLabel: 'Top-left crop handle',
          onDrag: (dx, dy) {
            final nl = (cropLeft + dx / boxW).clamp(0.0, cropRight - 0.08);
            final nt = (cropTop + dy / boxH).clamp(0.0, cropBottom - 0.08);
            onBoxCropChanged(nl, nt, cropRight, cropBottom);
          },
        ),
        _cornerHandle(
          left: leftPx + rectW - 16,
          top: topPx - 16,
          accent: tokens.accent,
          semanticLabel: 'Top-right crop handle',
          onDrag: (dx, dy) {
            final nr = (cropRight + dx / boxW).clamp(cropLeft + 0.08, 1.0);
            final nt = (cropTop + dy / boxH).clamp(0.0, cropBottom - 0.08);
            onBoxCropChanged(cropLeft, nt, nr, cropBottom);
          },
        ),
        _cornerHandle(
          left: leftPx + rectW - 16,
          top: topPx + rectH - 16,
          accent: tokens.accent,
          semanticLabel: 'Bottom-right crop handle',
          onDrag: (dx, dy) {
            final nr = (cropRight + dx / boxW).clamp(cropLeft + 0.08, 1.0);
            final nb = (cropBottom + dy / boxH).clamp(cropTop + 0.08, 1.0);
            onBoxCropChanged(cropLeft, cropTop, nr, nb);
          },
        ),
        _cornerHandle(
          left: leftPx - 16,
          top: topPx + rectH - 16,
          accent: tokens.accent,
          semanticLabel: 'Bottom-left crop handle',
          onDrag: (dx, dy) {
            final nl = (cropLeft + dx / boxW).clamp(0.0, cropRight - 0.08);
            final nb = (cropBottom + dy / boxH).clamp(cropTop + 0.08, 1.0);
            onBoxCropChanged(nl, cropTop, cropRight, nb);
          },
        ),
      ],
    );
  }

  Widget _buildPerspectiveOverlay(
    double boxW,
    double boxH,
    ScaneliqTokens tokens,
  ) {
    return Stack(
      children: [
        CustomPaint(
          size: Size(boxW, boxH),
          painter: _QuadPainter(quad: perspectiveQuad, accent: tokens.accent),
        ),
        _cornerHandle(
          left: perspectiveQuad.x1 * boxW - 16,
          top: perspectiveQuad.y1 * boxH - 16,
          accent: tokens.accent,
          label: 'TL',
          semanticLabel: 'Top-left perspective corner',
          onDrag: (dx, dy) {
            onPerspectiveQuadChanged(
              perspectiveQuad.copyWith(
                x1: (perspectiveQuad.x1 + dx / boxW).clamp(0.0, 0.92),
                y1: (perspectiveQuad.y1 + dy / boxH).clamp(0.0, 0.92),
              ),
            );
          },
        ),
        _cornerHandle(
          left: perspectiveQuad.x2 * boxW - 16,
          top: perspectiveQuad.y2 * boxH - 16,
          accent: tokens.accent,
          label: 'TR',
          semanticLabel: 'Top-right perspective corner',
          onDrag: (dx, dy) {
            onPerspectiveQuadChanged(
              perspectiveQuad.copyWith(
                x2: (perspectiveQuad.x2 + dx / boxW).clamp(0.08, 1.0),
                y2: (perspectiveQuad.y2 + dy / boxH).clamp(0.0, 0.92),
              ),
            );
          },
        ),
        _cornerHandle(
          left: perspectiveQuad.x3 * boxW - 16,
          top: perspectiveQuad.y3 * boxH - 16,
          accent: tokens.accent,
          label: 'BR',
          semanticLabel: 'Bottom-right perspective corner',
          onDrag: (dx, dy) {
            onPerspectiveQuadChanged(
              perspectiveQuad.copyWith(
                x3: (perspectiveQuad.x3 + dx / boxW).clamp(0.08, 1.0),
                y3: (perspectiveQuad.y3 + dy / boxH).clamp(0.08, 1.0),
              ),
            );
          },
        ),
        _cornerHandle(
          left: perspectiveQuad.x4 * boxW - 16,
          top: perspectiveQuad.y4 * boxH - 16,
          accent: tokens.accent,
          label: 'BL',
          semanticLabel: 'Bottom-left perspective corner',
          onDrag: (dx, dy) {
            onPerspectiveQuadChanged(
              perspectiveQuad.copyWith(
                x4: (perspectiveQuad.x4 + dx / boxW).clamp(0.0, 0.92),
                y4: (perspectiveQuad.y4 + dy / boxH).clamp(0.08, 1.0),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _cornerHandle({
    required double left,
    required double top,
    required Color accent,
    required String semanticLabel,
    required void Function(double dx, double dy) onDrag,
    String? label,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onDrag(d.delta.dx, d.delta.dy),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x45000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: label != null
                  ? Text(
                      label,
                      style: ScaneliqTypography.monoStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitFraction;

  _HorizontalSplitClipper(this.splitFraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * splitFraction, size.height);

  @override
  bool shouldReclip(covariant _HorizontalSplitClipper oldClipper) =>
      oldClipper.splitFraction != splitFraction;
}

class _QuadPainter extends CustomPainter {
  final PerspectiveQuad quad;
  final Color accent;

  _QuadPainter({required this.quad, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final bool valid = quad.isValidConvex();
    final Color strokeColor = valid ? accent : const Color(0xFFDC2626);

    final path = Path()
      ..moveTo(quad.x1 * size.width, quad.y1 * size.height)
      ..lineTo(quad.x2 * size.width, quad.y2 * size.height)
      ..lineTo(quad.x3 * size.width, quad.y3 * size.height)
      ..lineTo(quad.x4 * size.width, quad.y4 * size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) =>
      oldDelegate.quad != quad || oldDelegate.accent != accent;
}

class _CleanupPatchesPainter extends CustomPainter {
  final List<CleanupPatch> patches;
  final Color accentColor;

  _CleanupPatchesPainter({required this.patches, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (final patch in patches) {
      final center = Offset(patch.x * size.width, patch.y * size.height);
      final radius = patch.radius * size.width;
      final color = patch.type == 'holePunch'
          ? accentColor
          : const Color(0xFFF59E0B);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CleanupPatchesPainter oldDelegate) =>
      oldDelegate.patches.length != patches.length;
}

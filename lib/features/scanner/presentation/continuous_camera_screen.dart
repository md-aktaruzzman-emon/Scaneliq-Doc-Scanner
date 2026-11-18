import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaneliq/core/navigation/app_router.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/scanner/data/camera_studio_controller.dart';
import 'package:scaneliq/features/scanner/data/document_edge_detector.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart';
import 'package:scaneliq/features/scanner/presentation/widgets/camera_studio_overlays.dart';

export 'package:scaneliq/features/scanner/presentation/scanner_studio_provider.dart'
    show ScanMode;

/// Concept A Always-Dark Optical Camera Studio (`#090A0D`).
///
/// Supports Auto/Manual capture, genuine pure-Dart luma edge detection,
/// multi-page capture sessions, gallery import, retake replacement, flash/grid/lens
/// controls, and safe lifecycle transitions.
class ContinuousCameraScreen extends ConsumerStatefulWidget {
  final ScanMode mode;
  final String? initialTitle;
  final String? retakePageId;
  final bool initialAutoMode;

  const ContinuousCameraScreen({
    super.key,
    this.mode = ScanMode.batch,
    this.initialTitle,
    this.retakePageId,
    this.initialAutoMode = true,
  });

  @override
  ConsumerState<ContinuousCameraScreen> createState() =>
      _ContinuousCameraScreenState();
}

class _ContinuousCameraScreenState extends ConsumerState<ContinuousCameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sessionNotifier = ref.read(scanSessionProvider.notifier);
      if (widget.initialTitle != null &&
          widget.initialTitle!.trim().isNotEmpty) {
        sessionNotifier.updateTitle(widget.initialTitle!.trim());
      }
      final studio = ref.read(scannerStudioProvider.notifier);
      studio.onAutoCaptured = _handleActionOutcome;
      studio.startSession(
        mode: widget.mode,
        retakePageId: widget.retakePageId,
        autoMode: widget.initialAutoMode,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(scannerStudioProvider.notifier).handleAppLifecycleState(state);
  }

  Future<void> _handleCapturePressed() async {
    final outcome = await ref
        .read(scannerStudioProvider.notifier)
        .capturePhoto();
    if (!mounted) return;
    _handleActionOutcome(outcome);
  }

  Future<void> _handleGalleryImport() async {
    final outcome = await ref
        .read(scannerStudioProvider.notifier)
        .importFromGallery();
    if (!mounted) return;
    _handleActionOutcome(outcome);
  }

  Future<void> _launchMlKitFallbackScanner() async {
    final success = await ref
        .read(scanSessionProvider.notifier)
        .startScannerCapture();
    if (!mounted) return;
    if (success) {
      _finishToReview();
    }
  }

  void _handleActionOutcome(StudioActionOutcome outcome) {
    if (!mounted) return;
    if (outcome.message != null && outcome.message!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.message!),
          backgroundColor: outcome.isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF15171C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: outcome.isError ? 3 : 2),
        ),
      );
    }
    if (outcome.shouldNavigateToReview) {
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mounted) _finishToReview();
      });
    }
  }

  void _finishToReview() {
    final session = ref.read(scanSessionProvider);
    if (session.pages.isEmpty) {
      showScaneliqToast(context, 'Capture or import at least 1 page first.');
      return;
    }
    if (widget.retakePageId != null) {
      Navigator.of(context).pop(true);
      return;
    }
    navigateToReviewPages(context, replace: true);
  }

  void _openCameraSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScaneliqColorPalette.cameraStageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final studio = sheetRef.watch(scannerStudioProvider);
          final notifier = sheetRef.read(scannerStudioProvider.notifier);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera Studio Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Resolution, boundary capture, and fallback engine',
                    style: TextStyle(color: Color(0xFF9CA0AB), fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: const Color(0xFF0052FF),
                    title: const Text(
                      'Attach Detected Corners on Capture',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Non-destructively save detected page quad to EditRecipe',
                      style: TextStyle(color: Color(0xFF9CA0AB), fontSize: 12),
                    ),
                    value: studio.autoApplyDetectedQuad,
                    onChanged: notifier.setAutoApplyDetectedQuad,
                  ),
                  const Divider(color: Color(0xFF222632), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Capture Resolution',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      SegmentedButton<ResolutionPreset>(
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : const Color(0xFF9CA0AB),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? const Color(0xFF0052FF)
                                : const Color(0xFF15171C),
                          ),
                          side: const WidgetStatePropertyAll(
                            BorderSide(color: Color(0xFF222632)),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: ResolutionPreset.medium,
                            label: Text('720p', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: ResolutionPreset.high,
                            label: Text('High', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: ResolutionPreset.veryHigh,
                            label: Text('Max', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {studio.resolutionPreset},
                        onSelectionChanged: (selected) {
                          if (selected.isNotEmpty) {
                            notifier.setResolutionPreset(selected.first);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF222632), height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF3B82F6),
                    ),
                    title: const Text(
                      'Open Google ML Kit Scanner',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Native Android system scanner with auto-deskew',
                      style: TextStyle(color: Color(0xFF9CA0AB), fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA0AB),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _launchMlKitFallbackScanner();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(scannerStudioProvider);
    final studioNotifier = ref.read(scannerStudioProvider.notifier);
    final backend = ref.watch(scannerCameraBackendProvider);
    final session = ref.watch(scanSessionProvider);
    final pageCount = session.pages.length;

    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: ScaneliqColorPalette.cameraStudioBg,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Optical Studio Control Bar
              _buildTopControlBar(studio, studioNotifier),

              // 2. Main Camera Viewfinder Stage
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ScaneliqColorPalette.cameraStageBg,
                        border: Border.all(
                          color: ScaneliqColorPalette.cameraStageBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _buildViewfinderStage(
                        context,
                        studio,
                        studioNotifier,
                        backend,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Scan Mode Selector Strip
              if (widget.retakePageId == null)
                _buildModeSelectorStrip(studio, studioNotifier)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'RETAKE PAGE MODE',
                    style: ScaneliqTypography.monoStyle(
                      color: const Color(0xFF3B82F6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // 4. Bottom Shutter & Session Dock
              _buildBottomShutterDock(
                studio,
                studioNotifier,
                session,
                pageCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControlBar(
    ScannerStudioState studio,
    ScannerStudioNotifier notifier,
  ) {
    final IconData flashIcon = switch (studio.flashMode) {
      FlashMode.torch => Icons.flashlight_on_rounded,
      FlashMode.auto => Icons.flash_auto_rounded,
      _ => Icons.flash_off_rounded,
    };

    final bool compact = MediaQuery.sizeOf(context).width < 360;
    final double iconBtnSize = compact ? 36 : 42;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: 8,
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Close camera',
            button: true,
            child: SizedBox(
              width: iconBtnSize,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Close camera',
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),

          const Spacer(),

          // Auto · Manual interactive capsule toggle
          if (studio.mode != ScanMode.idCard && studio.mode != ScanMode.book)
            Semantics(
              label: studio.isAutoMode
                  ? 'Auto document detection enabled'
                  : 'Manual capture mode enabled',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: notifier.toggleAutoMode,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: studio.isAutoMode
                        ? const Color(0x293B82F6)
                        : const Color(0xFF15171C),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: studio.isAutoMode
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF262A34),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: studio.isAutoMode
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF636773),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        studio.isAutoMode ? 'AUTO' : 'MANUAL',
                        style: ScaneliqTypography.monoStyle(
                          color: Colors.white,
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Spacer(),

          // Flash toggle
          SizedBox(
            width: iconBtnSize,
            height: 42,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Flash mode',
              icon: Icon(
                flashIcon,
                color: studio.flashMode == FlashMode.off
                    ? Colors.white
                    : const Color(0xFFFBBF24),
                size: 20,
              ),
              onPressed: studio.isReady ? notifier.cycleFlashMode : null,
            ),
          ),

          // Rule-of-thirds grid toggle
          SizedBox(
            width: iconBtnSize,
            height: 42,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Framing grid',
              icon: Icon(
                studio.showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                color: studio.showGrid ? const Color(0xFF3B82F6) : Colors.white,
                size: 19,
              ),
              onPressed: notifier.toggleGrid,
            ),
          ),

          // Switch camera lens when multiple lenses supported
          if (studio.canSwitchCamera)
            SizedBox(
              width: iconBtnSize,
              height: 42,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Switch camera',
                icon: const Icon(
                  Icons.cameraswitch_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: studio.isReady && !studio.isCapturing
                    ? notifier.switchCamera
                    : null,
              ),
            ),

          // Camera settings popover
          SizedBox(
            width: iconBtnSize,
            height: 42,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Camera settings',
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _openCameraSettingsSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderStage(
    BuildContext context,
    ScannerStudioState studio,
    ScannerStudioNotifier notifier,
    ScannerCameraBackend backend,
  ) {
    if (studio.isPermissionDenied) {
      return CameraPermissionDeniedStudioView(
        permanentlyDenied:
            studio.status == CameraStudioStatus.permissionPermanentlyDenied,
        message:
            studio.errorMessage ??
            'Grant camera access to capture documents in Optical Studio.',
        onRetryPermission: notifier.initializeCamera,
        onImportGallery: _handleGalleryImport,
      );
    }

    if (studio.status == CameraStudioStatus.noCamera ||
        studio.status == CameraStudioStatus.error) {
      return CameraErrorStudioView(
        title: studio.status == CameraStudioStatus.noCamera
            ? 'No Camera Detected'
            : 'Camera Studio Unavailable',
        message:
            studio.errorMessage ??
            'Could not open device camera hardware. Retry or import images from gallery.',
        onRetry: notifier.initializeCamera,
        onImportGallery: _handleGalleryImport,
      );
    }

    if (!studio.isReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFF3B82F6),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'INITIALIZING CAMERA STUDIO',
              style: ScaneliqTypography.monoStyle(
                color: const Color(0xFF9CA0AB),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final dx = (details.localPosition.dx / constraints.maxWidth).clamp(
              0.0,
              1.0,
            );
            final dy = (details.localPosition.dy / constraints.maxHeight).clamp(
              0.0,
              1.0,
            );
            notifier.focusAt(Offset(dx, dy));
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live camera preview maintaining sensor aspect ratio
              Center(
                child: AspectRatio(
                  aspectRatio: backend.previewAspectRatio,
                  child: backend.buildPreview(context),
                ),
              ),

              // Rule-of-thirds grid overlay
              if (studio.showGrid) const RuleOfThirdsGridOverlay(),

              // Genuine document boundary quad overlay (ONLY when real quad detected)
              if (studio.isAutoMode && studio.detection.quad != null)
                DocumentBoundaryOverlay(
                  quad: studio.detection.quad,
                  stabilityProgress: studio.detection.stabilityProgress,
                ),

              // Specialized overlay guides for ID Card / Book / Whiteboard
              SpecializedScanModeGuide(
                mode: studio.mode,
                idCardStep: studio.idCardStep,
              ),

              // Tap-to-focus reticle
              if (studio.focusIndicatorPoint != null)
                FocusReticleOverlay(
                  normalizedPoint: studio.focusIndicatorPoint!,
                ),

              // Capture shutter visual pulse
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: studio.captureFlashPulse ? 0.35 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(color: Colors.white),
                ),
              ),

              // Live optical detection / mode status guidance pill
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Center(
                  child: _buildDetectionStatusPill(studio),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetectionStatusPill(ScannerStudioState studio) {
    final det = studio.detection;
    final Color indicatorColor = switch (det.status) {
      DocumentDetectionStatus.readyToCapture => const Color(0xFF34D399),
      DocumentDetectionStatus.alignedHoldSteady => const Color(0xFF3B82F6),
      DocumentDetectionStatus.lowLight ||
      DocumentDetectionStatus.unstableMotion ||
      DocumentDetectionStatus.partialOrTooClose => const Color(0xFFFBBF24),
      _ => const Color(0xFF9CA0AB),
    };

    final String labelText;
    if (studio.isCapturing) {
      labelText = 'CAPTURING FRAME...';
    } else if (studio.isImporting) {
      labelText = 'IMPORTING GALLERY IMAGES...';
    } else if (!studio.isAutoMode) {
      labelText = 'MANUAL MODE · TAP SHUTTER';
    } else {
      labelText = det.guidanceText.toUpperCase();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD9090A0D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: det.hasValidBoundary
              ? const Color(0xFF3B82F6)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ScaneliqTypography.monoStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (studio.isAutoMode && det.stabilityProgress > 0) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: det.stabilityProgress.clamp(0.0, 1.0),
                minHeight: 2.5,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelectorStrip(
    ScannerStudioState studio,
    ScannerStudioNotifier notifier,
  ) {
    const items = <(ScanMode, String)>[
      (ScanMode.document, 'Document'),
      (ScanMode.batch, 'Batch'),
      (ScanMode.idCard, 'ID Card'),
      (ScanMode.book, 'Book'),
      (ScanMode.whiteboard, 'Whiteboard'),
      (ScanMode.questionSet, 'Questions'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final (mode, label) = items[index];
          final selected = studio.mode == mode;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: studio.isCapturing ? null : () => notifier.setScanMode(mode),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF8C909B),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: selected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomShutterDock(
    ScannerStudioState studio,
    ScannerStudioNotifier notifier,
    ScanSessionState session,
    int pageCount,
  ) {
    final bool canCapture =
        studio.isReady && !studio.isCapturing && !studio.isImporting;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: ScaneliqColorPalette.cameraStudioBg,
        border: Border(
          top: BorderSide(color: Color(0xFF1A1D24), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left: Page thumbnail stack (when pages exist) + Gallery Import button
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageCount > 0) ...[
                  _buildPageThumbnailStack(session, pageCount),
                  const SizedBox(width: 8),
                ],
                Semantics(
                  label: 'Import from gallery',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: studio.isCapturing || studio.isImporting
                        ? null
                        : _handleGalleryImport,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ScaneliqColorPalette.cameraStageBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ScaneliqColorPalette.cameraStageBorder,
                        ),
                      ),
                      child: studio.isImporting
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 21,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center: Precision Shutter Button
          Semantics(
            label: 'Capture document page',
            button: true,
            child: GestureDetector(
              onTap: canCapture ? _handleCapturePressed : null,
              child: SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (studio.isAutoMode &&
                        studio.detection.stabilityProgress > 0)
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: studio.detection.stabilityProgress,
                          strokeWidth: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: canCapture ? Colors.white : Colors.white30,
                            width: 2.5,
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: studio.isCapturing ? 50 : 58,
                      height: studio.isCapturing ? 50 : 58,
                      decoration: BoxDecoration(
                        color: canCapture
                            ? Colors.white
                            : const Color(0xFF2D313D),
                        shape: BoxShape.circle,
                      ),
                      child: studio.isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Review / Done CTA or ML Kit fallback shortcut
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: pageCount > 0
                  ? Semantics(
                      label: 'Review $pageCount captured pages',
                      button: true,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0052FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed:
                            studio.isCapturing ? null : _finishToReview,
                        child: Text(
                          'Review ($pageCount)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : Semantics(
                      label: 'Auto-scan with ML Kit',
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _launchMlKitFallbackScanner,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ScaneliqColorPalette.cameraStageBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: ScaneliqColorPalette.cameraStageBorder,
                            ),
                          ),
                          child: Text(
                            'ML KIT',
                            style: ScaneliqTypography.monoStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageThumbnailStack(ScanSessionState session, int pageCount) {
    final lastPage = session.pages.last;
    final previewFile = File(lastPage.processedPath ?? lastPage.originalPath);
    final badgeText = pageCount < 10 ? '0$pageCount' : '$pageCount';

    return Semantics(
      label: 'Preview captured pages stack, $pageCount pages',
      button: true,
      child: GestureDetector(
        onTap: _finishToReview,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 54,
              decoration: BoxDecoration(
                color: ScaneliqColorPalette.cameraStageBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white38, width: 1.4),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewFile.existsSync()
                  ? Image.file(
                      previewFile,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.description_outlined,
                        color: Colors.white54,
                        size: 20,
                      ),
                    )
                  : const Icon(
                      Icons.description_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
            ),
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0052FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ScaneliqColorPalette.cameraStudioBg,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: ScaneliqTypography.monoStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

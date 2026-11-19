import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';
import 'package:scaneliq/features/scanner/data/camera_studio_controller.dart';
import 'package:scaneliq/features/scanner/data/document_edge_detector.dart';
import 'package:scaneliq/features/scanner/data/gallery_import_service.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:uuid/uuid.dart';

/// Scanning modes supported by Scaneliq Optical Camera Studio.
enum ScanMode { document, batch, idCard, questionSet, book, whiteboard }

/// Outcome of a capture or gallery import operation.
class StudioActionOutcome {
  final bool succeeded;
  final int pagesAdded;
  final bool shouldNavigateToReview;
  final String? message;
  final bool isError;

  const StudioActionOutcome({
    required this.succeeded,
    this.pagesAdded = 0,
    this.shouldNavigateToReview = false,
    this.message,
    this.isError = false,
  });
}

/// Immutable state for [ScannerStudioNotifier].
class ScannerStudioState {
  final CameraStudioStatus status;
  final ScanMode mode;
  final bool isAutoMode;
  final FlashMode flashMode;
  final ResolutionPreset resolutionPreset;
  final bool showGrid;
  final bool autoApplyDetectedQuad;
  final bool isCapturing;
  final bool isImporting;
  final List<CameraDescription> cameras;
  final int selectedCameraIndex;
  final int idCardStep;
  final Offset? focusIndicatorPoint;
  final DocumentDetectionResult detection;
  final String? errorMessage;
  final String? retakePageId;
  final bool captureFlashPulse;

  const ScannerStudioState({
    this.status = CameraStudioStatus.uninitialized,
    this.mode = ScanMode.batch,
    this.isAutoMode = true,
    this.flashMode = FlashMode.off,
    this.resolutionPreset = ResolutionPreset.high,
    this.showGrid = false,
    this.autoApplyDetectedQuad = true,
    this.isCapturing = false,
    this.isImporting = false,
    this.cameras = const [],
    this.selectedCameraIndex = 0,
    this.idCardStep = 0,
    this.focusIndicatorPoint,
    this.detection = DocumentDetectionResult.idle,
    this.errorMessage,
    this.retakePageId,
    this.captureFlashPulse = false,
  });

  bool get isReady => status == CameraStudioStatus.ready;
  bool get isPermissionDenied =>
      status == CameraStudioStatus.permissionDenied ||
      status == CameraStudioStatus.permissionPermanentlyDenied;
  bool get canSwitchCamera => cameras.length > 1;

  ScannerStudioState copyWith({
    CameraStudioStatus? status,
    ScanMode? mode,
    bool? isAutoMode,
    FlashMode? flashMode,
    ResolutionPreset? resolutionPreset,
    bool? showGrid,
    bool? autoApplyDetectedQuad,
    bool? isCapturing,
    bool? isImporting,
    List<CameraDescription>? cameras,
    int? selectedCameraIndex,
    int? idCardStep,
    Offset? focusIndicatorPoint,
    bool clearFocusIndicator = false,
    DocumentDetectionResult? detection,
    String? errorMessage,
    bool clearError = false,
    String? retakePageId,
    bool? captureFlashPulse,
  }) {
    return ScannerStudioState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      isAutoMode: isAutoMode ?? this.isAutoMode,
      flashMode: flashMode ?? this.flashMode,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      showGrid: showGrid ?? this.showGrid,
      autoApplyDetectedQuad:
          autoApplyDetectedQuad ?? this.autoApplyDetectedQuad,
      isCapturing: isCapturing ?? this.isCapturing,
      isImporting: isImporting ?? this.isImporting,
      cameras: cameras ?? this.cameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      idCardStep: idCardStep ?? this.idCardStep,
      focusIndicatorPoint: clearFocusIndicator
          ? null
          : (focusIndicatorPoint ?? this.focusIndicatorPoint),
      detection: detection ?? this.detection,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retakePageId: retakePageId ?? this.retakePageId,
      captureFlashPulse: captureFlashPulse ?? this.captureFlashPulse,
    );
  }
}

final scannerCameraBackendProvider = Provider<ScannerCameraBackend>((ref) {
  return FlutterCameraBackend();
});

final galleryImportServiceProvider = Provider<GalleryImportService>((ref) {
  return const GalleryImportService();
});

final documentEdgeDetectorProvider = Provider<DocumentEdgeDetector>((ref) {
  return const DocumentEdgeDetector();
});

final scannerStudioProvider =
    NotifierProvider.autoDispose<ScannerStudioNotifier, ScannerStudioState>(
      ScannerStudioNotifier.new,
    );

/// Coordinates camera initialization, lifecycle transitions, live edge detection,
/// stability auto-capture, manual shutter capture, and gallery import.
class ScannerStudioNotifier extends Notifier<ScannerStudioState> {
  static const Duration _frameProcessInterval = Duration(milliseconds: 180);

  late ScannerCameraBackend _backend;
  late DocumentEdgeDetector _detector;
  DocumentStabilityTracker _stabilityTracker = DocumentStabilityTracker();

  CameraFrameData? _previousFrame;
  DateTime? _lastFrameProcessedAt;
  bool _isDisposed = false;
  bool _isFrameProcessing = false;
  bool _inLifecyclePause = false;
  int _initEpoch = 0;

  void Function(StudioActionOutcome outcome)? onAutoCaptured;

  @override
  ScannerStudioState build() {
    _backend = ref.watch(scannerCameraBackendProvider);
    _detector = ref.watch(documentEdgeDetectorProvider);
    _isDisposed = false;

    ref.onDispose(() {
      _isDisposed = true;
      _initEpoch++;
      onAutoCaptured = null;
      _backend.disposeCamera();
    });

    return const ScannerStudioState();
  }

  /// Sets initial session parameters cleanly when opening the camera studio.
  Future<void> startSession({
    required ScanMode mode,
    String? retakePageId,
    bool autoMode = true,
  }) async {
    _stabilityTracker = DocumentStabilityTracker();
    _previousFrame = null;
    final bool effectiveAuto =
        autoMode && mode != ScanMode.idCard && mode != ScanMode.book;
    state = ScannerStudioState(
      status: CameraStudioStatus.initializing,
      mode: mode,
      isAutoMode: effectiveAuto,
      retakePageId: retakePageId,
      detection: effectiveAuto
          ? const DocumentDetectionResult(
              status: DocumentDetectionStatus.searching,
              guidanceText: 'Initializing optical studio...',
            )
          : DocumentDetectionResult.idle,
    );
    await initializeCamera();
  }

  /// Discovers cameras and initializes the selected camera lens safely.
  Future<void> initializeCamera() async {
    if (_isDisposed) return;
    final epoch = ++_initEpoch;
    state = state.copyWith(
      status: CameraStudioStatus.initializing,
      clearError: true,
    );

    try {
      final cameras = state.cameras.isEmpty
          ? await _backend.getAvailableCameras()
          : state.cameras;
      if (_isDisposed || epoch != _initEpoch) return;

      if (cameras.isEmpty) {
        state = state.copyWith(
          status: CameraStudioStatus.noCamera,
          cameras: const [],
          errorMessage: 'No camera hardware detected on this device.',
        );
        return;
      }

      int targetIndex = state.selectedCameraIndex;
      if (targetIndex < 0 || targetIndex >= cameras.length) {
        targetIndex = 0;
      }
      // Prefer rear lens initially if available.
      if (state.cameras.isEmpty) {
        final rearIdx = cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (rearIdx != -1) targetIndex = rearIdx;
      }

      await _backend.initialize(
        cameras[targetIndex],
        preset: state.resolutionPreset,
      );
      if (_isDisposed || epoch != _initEpoch) {
        await _backend.disposeCamera();
        return;
      }

      try {
        await _backend.setFlashMode(state.flashMode);
      } catch (_) {}

      state = state.copyWith(
        status: CameraStudioStatus.ready,
        cameras: cameras,
        selectedCameraIndex: targetIndex,
        clearError: true,
        detection: state.isAutoMode
            ? const DocumentDetectionResult(
                status: DocumentDetectionStatus.searching,
                guidanceText: 'Position document inside frame',
              )
            : DocumentDetectionResult.idle,
      );

      await _syncFrameStream();
    } on CameraPermissionException catch (e) {
      if (_isDisposed || epoch != _initEpoch) return;
      state = state.copyWith(
        status: e.permanentlyDenied
            ? CameraStudioStatus.permissionPermanentlyDenied
            : CameraStudioStatus.permissionDenied,
        errorMessage: e.message,
      );
    } on CameraException catch (e) {
      if (_isDisposed || epoch != _initEpoch) return;
      final code = e.code.toLowerCase();
      if (code == 'cameraaccessdenied') {
        state = state.copyWith(
          status: CameraStudioStatus.permissionDenied,
          errorMessage:
              e.description ??
              'Camera access is required to scan documents. Grant permission or import from gallery.',
        );
      } else if (code == 'cameraaccessdeniedwithoutprompt' ||
          code == 'cameraaccessrestricted') {
        state = state.copyWith(
          status: CameraStudioStatus.permissionPermanentlyDenied,
          errorMessage:
              e.description ??
              'Camera permission is disabled in system settings. Enable camera access or import images from gallery.',
        );
      } else {
        state = state.copyWith(
          status: CameraStudioStatus.error,
          errorMessage: e.description ?? 'Could not initialize camera: ${e.code}',
        );
      }
    } catch (e) {
      if (_isDisposed || epoch != _initEpoch) return;
      state = state.copyWith(
        status: CameraStudioStatus.error,
        errorMessage: 'Could not initialize camera: $e',
      );
    }
  }

  /// Lifecycle handler for inactive/paused/resumed transitions without leaks.
  Future<void> handleAppLifecycleState(AppLifecycleState appState) async {
    if (_isDisposed) return;

    if (appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      if (_inLifecyclePause) return;
      _inLifecyclePause = true;
      _initEpoch++;
      _isFrameProcessing = false;
      _stabilityTracker.reset();
      _previousFrame = null;
      await _backend.disposeCamera();
      if (!_isDisposed && state.status == CameraStudioStatus.ready) {
        state = state.copyWith(status: CameraStudioStatus.uninitialized);
      }
      return;
    }

    if (appState == AppLifecycleState.resumed) {
      if (!_inLifecyclePause && state.isReady) return;
      _inLifecyclePause = false;
      // Re-attempt initialization after returning from system Settings if previously permanently denied.
      final shouldRetry =
          state.status != CameraStudioStatus.permissionDenied;
      if (!_isDisposed && shouldRetry) {
        await initializeCamera();
      }
    }
  }

  /// Toggles Auto-Detect + Auto-Capture vs Manual capture mode.
  Future<void> toggleAutoMode() async {
    final nextAuto = !state.isAutoMode;
    _stabilityTracker.reset();
    _previousFrame = null;
    state = state.copyWith(
      isAutoMode: nextAuto,
      detection: nextAuto
          ? const DocumentDetectionResult(
              status: DocumentDetectionStatus.searching,
              guidanceText: 'Looking for document edges',
            )
          : DocumentDetectionResult.idle,
    );
    await _syncFrameStream();
  }

  void setScanMode(ScanMode mode) {
    if (mode == state.mode) return;
    _stabilityTracker.reset();
    state = state.copyWith(
      mode: mode,
      idCardStep: 0,
      isAutoMode: (mode == ScanMode.idCard || mode == ScanMode.book)
          ? false
          : state.isAutoMode,
    );
    _syncFrameStream();
  }

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void setAutoApplyDetectedQuad(bool enabled) {
    state = state.copyWith(autoApplyDetectedQuad: enabled);
  }

  Future<void> setResolutionPreset(ResolutionPreset preset) async {
    if (preset == state.resolutionPreset) return;
    state = state.copyWith(resolutionPreset: preset);
    if (state.cameras.isNotEmpty && !state.isPermissionDenied) {
      await initializeCamera();
    }
  }

  /// Cycles flash modes: off -> auto -> torch -> off.
  Future<void> cycleFlashMode() async {
    final FlashMode next = switch (state.flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.torch,
      _ => FlashMode.off,
    };
    try {
      await _backend.setFlashMode(next);
      if (!_isDisposed) {
        state = state.copyWith(flashMode: next);
      }
    } catch (_) {
      // Some emulators or front lenses do not support torch; fall back cleanly.
      try {
        await _backend.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!_isDisposed) {
        state = state.copyWith(flashMode: FlashMode.off);
      }
    }
  }

  /// Switches between available camera lenses (e.g., back <-> front).
  Future<void> switchCamera() async {
    if (state.cameras.length < 2 || state.isCapturing) return;
    final nextIndex = (state.selectedCameraIndex + 1) % state.cameras.length;
    _stabilityTracker.reset();
    _previousFrame = null;
    state = state.copyWith(
      selectedCameraIndex: nextIndex,
      flashMode: FlashMode.off,
    );
    await initializeCamera();
  }

  /// Focuses and meters exposure at a normalized [0..1] viewfinder coordinate.
  Future<void> focusAt(Offset normalizedPoint) async {
    if (!state.isReady) return;
    state = state.copyWith(focusIndicatorPoint: normalizedPoint);
    await _backend.setFocusAndExposurePoint(normalizedPoint);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!_isDisposed && state.focusIndicatorPoint == normalizedPoint) {
        state = state.copyWith(clearFocusIndicator: true);
      }
    });
  }

  /// Processes a live camera frame through [DocumentEdgeDetector] and triggers
  /// auto-capture if stability threshold is met.
  @visibleForTesting
  Future<void> processFrame(CameraFrameData frame) async {
    if (_isDisposed || !state.isAutoMode || state.isCapturing) return;

    final now = DateTime.now();
    if (_lastFrameProcessedAt != null &&
        now.difference(_lastFrameProcessedAt!) < _frameProcessInterval) {
      return;
    }
    if (_isFrameProcessing) return;
    _isFrameProcessing = true;
    _lastFrameProcessedAt = now;

    try {
      final raw = _detector.detect(frame, previousFrame: _previousFrame);
      _previousFrame = frame;
      final evaluated = _stabilityTracker.evaluate(raw, now: now);

      if (_isDisposed || !state.isAutoMode) return;
      state = state.copyWith(detection: evaluated);

      if (evaluated.status == DocumentDetectionStatus.readyToCapture &&
          !state.isCapturing) {
        _stabilityTracker.markCaptured(now);
        final outcome = await capturePhoto(
          detectedQuad: state.autoApplyDetectedQuad ? evaluated.quad : null,
        );
        onAutoCaptured?.call(outcome);
      }
    } finally {
      _isFrameProcessing = false;
    }
  }

  /// Captures a single document frame safely without overlapping operations.
  Future<StudioActionOutcome> capturePhoto({
    PerspectiveQuad? detectedQuad,
  }) async {
    if (_isDisposed || !state.isReady || state.isCapturing || state.isImporting) {
      return const StudioActionOutcome(succeeded: false);
    }

    state = state.copyWith(
      isCapturing: true,
      captureFlashPulse: true,
      clearError: true,
    );

    try {
      final File capturedFile = await _backend.takePicture();
      if (!await capturedFile.exists()) {
        return const StudioActionOutcome(
          succeeded: false,
          message: 'Captured file is missing on storage.',
          isError: true,
        );
      }

      // Compute non-destructive initial recipe from current mode & real quad.
      final activeQuad =
          detectedQuad ??
          (state.autoApplyDetectedQuad && state.detection.hasValidBoundary
              ? state.detection.quad
              : null);
      final EditRecipe baseRecipe = _buildRecipeForMode(
        state.mode,
        quad: activeQuad,
      );

      final sessionNotifier = ref.read(scanSessionProvider.notifier);

      // Retake mode replaces exact page non-destructively and returns.
      if (state.retakePageId != null) {
        final ok = await sessionNotifier.retakePageWithFile(
          state.retakePageId!,
          capturedFile,
          recipe: baseRecipe,
        );
        return StudioActionOutcome(
          succeeded: ok,
          pagesAdded: ok ? 1 : 0,
          shouldNavigateToReview: ok,
          message: ok
              ? 'Page retaken cleanly.'
              : 'Could not replace captured page.',
          isError: !ok,
        );
      }

      if (state.mode == ScanMode.book) {
        final splitPages = await ImageProcessingService.splitBookSpreadFile(
          spreadFile: capturedFile,
          outputDir: AppStorageService.instance.tempDir,
          baseId: const Uuid().v4(),
        );
        final count = await sessionNotifier.importFiles(
          splitPages,
          defaultRecipe: baseRecipe,
        );
        // Clean up temporary split staging files after safe copy to originalsDir.
        for (final f in splitPages) {
          try {
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
        return StudioActionOutcome(
          succeeded: count > 0,
          pagesAdded: count,
          message: 'Book spread split into $count pages.',
        );
      }

      final added = await sessionNotifier.addCapturedPage(
        capturedFile,
        recipe: baseRecipe,
      );
      if (!added) {
        return const StudioActionOutcome(
          succeeded: false,
          message: 'Failed to store captured image safely.',
          isError: true,
        );
      }

      if (state.mode == ScanMode.idCard) {
        if (state.idCardStep == 0) {
          state = state.copyWith(idCardStep: 1);
          return const StudioActionOutcome(
            succeeded: true,
            pagesAdded: 1,
            message: 'Front side captured. Align back side next.',
          );
        } else {
          final session = ref.read(scanSessionProvider);
          if (session.pages.length >= 2) {
            final frontPage = session.pages[session.pages.length - 2];
            final backPage = session.pages[session.pages.length - 1];
            final frontFile = File(
              frontPage.processedPath ?? frontPage.originalPath,
            );
            final backFile = File(
              backPage.processedPath ?? backPage.originalPath,
            );

            final stitchedJpg = await PdfService.stitchIdCard2In1(
              frontImage: frontFile,
              backImage: backFile,
              baseTitle: '${session.title}_2in1',
            );
            await sessionNotifier.replaceWithSinglePage(stitchedJpg);
          }
          return const StudioActionOutcome(
            succeeded: true,
            pagesAdded: 1,
            shouldNavigateToReview: true,
            message: 'Combined Front & Back into 2-in-1 ID Card sheet.',
          );
        }
      }

      if (state.mode == ScanMode.document) {
        return const StudioActionOutcome(
          succeeded: true,
          pagesAdded: 1,
          shouldNavigateToReview: true,
          message: 'Page captured.',
        );
      }

      return const StudioActionOutcome(
        succeeded: true,
        pagesAdded: 1,
        message: 'Page added to scan session.',
      );
    } catch (e) {
      return StudioActionOutcome(
        succeeded: false,
        message: 'Capture failed: $e',
        isError: true,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isCapturing: false, captureFlashPulse: false);
        _stabilityTracker.markCaptured();
        await _syncFrameStream();
      }
    }
  }

  /// Opens gallery picker via [GalleryImportService] and imports validated images.
  Future<StudioActionOutcome> importFromGallery() async {
    if (_isDisposed || state.isCapturing || state.isImporting) {
      return const StudioActionOutcome(succeeded: false);
    }

    state = state.copyWith(isImporting: true, clearError: true);

    try {
      final importService = ref.read(galleryImportServiceProvider);
      final result = await importService.pickAndValidateImages();

      if (result.cancelled) {
        return const StudioActionOutcome(succeeded: false);
      }

      if (!result.hasAccepted) {
        final reason = result.rejections.isNotEmpty
            ? result.rejections.first.reason
            : 'No valid images selected.';
        return StudioActionOutcome(
          succeeded: false,
          message: reason,
          isError: true,
        );
      }

      final sessionNotifier = ref.read(scanSessionProvider.notifier);
      final recipe = _buildRecipeForMode(state.mode);
      final validFiles = result.accepted.map((a) => a.file).toList();

      if (state.retakePageId != null) {
        final ok = await sessionNotifier.retakePageWithFile(
          state.retakePageId!,
          validFiles.first,
          recipe: recipe,
        );
        return StudioActionOutcome(
          succeeded: ok,
          pagesAdded: ok ? 1 : 0,
          shouldNavigateToReview: ok,
          message: ok ? 'Replacement image imported.' : 'Import failed.',
          isError: !ok,
        );
      }

      int totalAdded = 0;
      if (state.mode == ScanMode.book) {
        for (final file in validFiles) {
          final splitPages = await ImageProcessingService.splitBookSpreadFile(
            spreadFile: file,
            outputDir: AppStorageService.instance.tempDir,
            baseId: const Uuid().v4(),
          );
          totalAdded += await sessionNotifier.importFiles(
            splitPages,
            defaultRecipe: recipe,
          );
          for (final sp in splitPages) {
            try {
              if (await sp.exists()) await sp.delete();
            } catch (_) {}
          }
        }
      } else {
        totalAdded = await sessionNotifier.importFiles(
          validFiles,
          defaultRecipe: recipe,
        );
      }

      final skippedNote = result.hasRejections
          ? ' (${result.rejections.length} skipped)'
          : '';
      return StudioActionOutcome(
        succeeded: totalAdded > 0,
        pagesAdded: totalAdded,
        message:
            'Imported $totalAdded ${totalAdded == 1 ? 'image' : 'images'}$skippedNote.',
      );
    } catch (e) {
      return StudioActionOutcome(
        succeeded: false,
        message: 'Gallery import failed: $e',
        isError: true,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isImporting: false);
      }
    }
  }

  Future<void> _syncFrameStream() async {
    if (_isDisposed || !state.isReady || !_backend.supportsImageStream) return;
    if (state.isAutoMode && !state.isCapturing) {
      try {
        await _backend.startFrameStream(processFrame);
      } catch (_) {}
    } else {
      try {
        await _backend.stopFrameStream();
      } catch (_) {}
    }
  }

  static EditRecipe _buildRecipeForMode(
    ScanMode mode, {
    PerspectiveQuad? quad,
  }) {
    final safeQuad = (quad != null && quad.isValidConvex()) ? quad : null;
    return switch (mode) {
      ScanMode.whiteboard => EditRecipe(
        filter: PageFilter.whiteboard,
        perspectiveQuad: safeQuad,
      ),
      ScanMode.questionSet => EditRecipe(
        filter: PageFilter.blackAndWhite,
        binarization: BinarizationMode.otsu,
        perspectiveQuad: safeQuad,
      ),
      _ => EditRecipe(perspectiveQuad: safeQuad),
    };
  }
}

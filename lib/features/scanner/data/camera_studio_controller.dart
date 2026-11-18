import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/features/scanner/data/document_edge_detector.dart';

/// Explicit status states for the Scaneliq Optical Camera Studio.
enum CameraStudioStatus {
  uninitialized,
  initializing,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  noCamera,
  error,
  disposed,
}

/// Exception thrown when camera access permission is denied or restricted.
class CameraPermissionException implements Exception {
  final bool permanentlyDenied;
  final String message;

  const CameraPermissionException({
    required this.permanentlyDenied,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Testable camera hardware abstraction separating controller lifecycle from UI.
abstract class ScannerCameraBackend {
  bool get isInitialized;
  double get previewAspectRatio;
  bool get supportsImageStream;

  Future<List<CameraDescription>> getAvailableCameras();
  Future<void> initialize(
    CameraDescription camera, {
    ResolutionPreset preset = ResolutionPreset.high,
  });
  Future<void> disposeCamera();
  Future<void> setFlashMode(FlashMode mode);
  Future<void> setFocusAndExposurePoint(Offset normalizedPoint);
  Future<File> takePicture();
  Future<void> startFrameStream(void Function(CameraFrameData frame) onFrame);
  Future<void> stopFrameStream();
  Widget buildPreview(BuildContext context);
}

/// Production Flutter `package:camera` backend with serialized lifecycle & stream safety.
class FlutterCameraBackend implements ScannerCameraBackend {
  CameraController? _controller;
  bool _isStreaming = false;
  Future<void> _opLock = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _opLock = _opLock.then((_) async {
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  bool get supportsImageStream => true;

  @override
  double get previewAspectRatio {
    final ratio = _controller?.value.aspectRatio;
    if (ratio == null || ratio <= 0) return 3 / 4;
    // CameraController reports landscape aspect ratio on portrait sensors.
    return ratio > 1.0 ? 1.0 / ratio : ratio;
  }

  @override
  Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      return await availableCameras();
    } on CameraException catch (e) {
      throw _mapCameraException(e);
    }
  }

  @override
  Future<void> initialize(
    CameraDescription camera, {
    ResolutionPreset preset = ResolutionPreset.high,
  }) {
    return _serialized(() async {
      await _disposeCurrentInternal();

      final controller = CameraController(
        camera,
        preset,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      try {
        await controller.initialize();
        try {
          await controller.setFocusMode(FocusMode.auto);
        } catch (_) {}
        _controller = controller;
      } on CameraException catch (e) {
        try {
          await controller.dispose();
        } catch (_) {}
        throw _mapCameraException(e);
      }
    });
  }

  @override
  Future<void> disposeCamera() {
    return _serialized(_disposeCurrentInternal);
  }

  Future<void> _disposeCurrentInternal() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (_isStreaming) {
      _isStreaming = false;
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
    }
    try {
      await controller.dispose();
    } catch (_) {}
  }

  @override
  Future<void> setFlashMode(FlashMode mode) {
    return _serialized(() async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      await controller.setFlashMode(mode);
    });
  }

  @override
  Future<void> setFocusAndExposurePoint(Offset normalizedPoint) {
    return _serialized(() async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      final clamped = Offset(
        normalizedPoint.dx.clamp(0.0, 1.0),
        normalizedPoint.dy.clamp(0.0, 1.0),
      );
      try {
        await controller.setFocusPoint(clamped);
      } catch (_) {}
      try {
        await controller.setExposurePoint(clamped);
      } catch (_) {}
    });
  }

  @override
  Future<File> takePicture() {
    return _serialized(() async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        throw StateError('Camera is not initialized');
      }

      // Stop image stream cleanly during hardware JPEG capture on Android/iOS.
      final wasStreaming = _isStreaming;
      if (wasStreaming && controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
        _isStreaming = false;
      }

      final XFile picture = await controller.takePicture();
      return File(picture.path);
    });
  }

  @override
  Future<void> startFrameStream(
    void Function(CameraFrameData frame) onFrame,
  ) {
    return _serialized(() async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      if (_isStreaming || controller.value.isStreamingImages) return;

      _isStreaming = true;
      await controller.startImageStream((CameraImage image) {
        if (!_isStreaming) return;
        final frame = CameraFrameData.fromCameraImage(image);
        if (frame != null) {
          onFrame(frame);
        }
      });
    });
  }

  @override
  Future<void> stopFrameStream() {
    return _serialized(() async {
      final controller = _controller;
      _isStreaming = false;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
    });
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  static Exception _mapCameraException(CameraException e) {
    final code = e.code.toLowerCase();
    if (code == 'cameraaccessdenied') {
      return CameraPermissionException(
        permanentlyDenied: false,
        message:
            e.description ??
            'Camera access is required to scan documents. Grant permission or import from gallery.',
      );
    }
    if (code == 'cameraaccessdeniedwithoutprompt' ||
        code == 'cameraaccessrestricted') {
      return CameraPermissionException(
        permanentlyDenied: true,
        message:
            e.description ??
            'Camera permission is disabled in system settings. Enable camera access or import images from gallery.',
      );
    }
    return Exception(
      e.description ?? 'Camera error (${e.code})',
    );
  }
}

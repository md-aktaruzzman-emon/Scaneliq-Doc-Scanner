import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/scanner/data/object_counter_service.dart';
import 'package:scaneliq/features/subscription/data/subscription_service.dart';
import 'package:scaneliq/features/subscription/presentation/subscription_sheet.dart';
import 'package:share_plus/share_plus.dart';

class CountCamScreen extends StatefulWidget {
  const CountCamScreen({super.key});

  @override
  State<CountCamScreen> createState() => _CountCamScreenState();
}

class _CountCamScreenState extends State<CountCamScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isProcessing = false;
  File? _capturedImage;
  List<DetectedCountObject> _detectedObjects = [];
  int _manualAdjustOffset = 0;
  String _engineUsed = 'morphological_cluster_detector';
  String _selectedCategory = 'Boxes & Cartons (Dense)';

  final Map<String, CountDetectionPreset> _categoryPresets = const {
    'Boxes & Cartons (Dense)': CountDetectionPreset.denseCluster,
    'Coins & Small Items': CountDetectionPreset.smallItems,
    'Prominent Objects (ML Kit)': CountDetectionPreset.prominentObjects,
    'Auto Hybrid Detection': CountDetectionPreset.autoHybrid,
  };

  int get _effectiveCount =>
      (_detectedObjects.length + _manualAdjustOffset).clamp(0, 9999);

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final controller = CameraController(
          _cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await controller.initialize();
        if (mounted) {
          setState(() {
            _cameraController = controller;
            _isCameraReady = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _captureAndCount() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      setState(() => _isProcessing = true);
      final picture = await _cameraController!.takePicture();
      await _processImageForCounting(File(picture.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImageAndCount() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result.isNotEmpty && result.first.path != null) {
        setState(() => _isProcessing = true);
        await _processImageForCounting(File(result.first.path!));
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processImageForCounting(File imageFile) async {
    final quota = await SubscriptionService.instance.consumeQuota(
      QuotaFeature.objectCountCam,
    );
    if (!quota.allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(quota.message)),
        );
        await SubscriptionSheet.show(context);
      }
      return;
    }

    final preset =
        _categoryPresets[_selectedCategory] ?? CountDetectionPreset.autoHybrid;
    final res = await ObjectCounterService.instance.detectObjects(
      imageFile,
      preset: preset,
    );

    if (!mounted) return;
    setState(() {
      _capturedImage = imageFile;
      _detectedObjects = List<DetectedCountObject>.from(res.objects);
      _manualAdjustOffset = 0;
      _engineUsed = res.engineUsed;
    });
  }

  void _handleCanvasTap(TapDownDetails details, Size canvasSize) {
    if (_capturedImage == null || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return;
    }
    final nx = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);

    // If user tapped near an existing marker, remove it; otherwise add a new manual pin marker.
    int removeIdx = -1;
    for (int i = 0; i < _detectedObjects.length; i++) {
      final c = _detectedObjects[i].normalizedCenter;
      final dx = (c.dx - nx) * canvasSize.width;
      final dy = (c.dy - ny) * canvasSize.height;
      if (dx * dx + dy * dy <= 24 * 24) {
        removeIdx = i;
        break;
      }
    }

    setState(() {
      if (removeIdx != -1) {
        _detectedObjects.removeAt(removeIdx);
      } else {
        _detectedObjects.add(
          DetectedCountObject(
            index: _detectedObjects.length + 1,
            normalizedRect: Rect.fromCenter(
              center: Offset(nx, ny),
              width: 0.08,
              height: 0.08,
            ),
            normalizedCenter: Offset(nx, ny),
            label: 'Manual',
            confidence: 1.0,
            isManual: true,
          ),
        );
      }
      for (int i = 0; i < _detectedObjects.length; i++) {
        _detectedObjects[i] = _detectedObjects[i].copyWith(index: i + 1);
      }
    });
  }

  void _manualAdjust(int delta) {
    setState(() {
      final nextTotal = _effectiveCount + delta;
      _manualAdjustOffset = (nextTotal - _detectedObjects.length).clamp(-9999, 9999);
    });
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _detectedObjects = [];
      _manualAdjustOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'CountCam — Object Counter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_capturedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset and recount',
              onPressed: _reset,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_capturedImage != null)
            Center(
              child: LayoutBuilder(
                builder: (ctx, constraints) => GestureDetector(
                  onTapDown: (d) => _handleCanvasTap(
                    d,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        _capturedImage!,
                        fit: BoxFit.contain,
                        cacheWidth: 1200,
                      ),
                      CustomPaint(
                        painter: _CountBoxesPainter(_detectedObjects),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isCameraReady && _cameraController != null)
            Center(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Top Preset Selector Pill
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.grey.shade900,
                        value: _selectedCategory,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _categoryPresets.keys
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                            if (_capturedImage != null) {
                              _processImageForCounting(_capturedImage!);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_capturedImage != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.remove),
                            onPressed: () => _manualAdjust(-1),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              Text(
                                '$_effectiveCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Tap image to add/remove markers ($_engineUsed)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add),
                            onPressed: () => _manualAdjust(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Share Count Result'),
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'CountCam Count: $_effectiveCount ($_selectedCategory) counted via Scaneliq.',
                              files: [XFile(_capturedImage!.path)],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      const Text(
                        'Place separated objects cleanly inside frame',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton.outlined(
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                            ),
                            tooltip: 'Count from Gallery image',
                            onPressed: _isProcessing ? null : _pickImageAndCount,
                          ),
                          GestureDetector(
                            onTap: _isProcessing ? null : _captureAndCount,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    color: AppColors.brandPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isProcessing
                                      ? const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBoxesPainter extends CustomPainter {
  final List<DetectedCountObject> objects;

  const _CountBoxesPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF34D399);

    final manualPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF3B82F6);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (final obj in objects) {
      final rect = Rect.fromLTWH(
        obj.normalizedRect.left * size.width,
        obj.normalizedRect.top * size.height,
        obj.normalizedRect.width * size.width,
        obj.normalizedRect.height * size.height,
      );
      canvas.drawRect(rect, obj.isManual ? manualPaint : boxPaint);

      final center = Offset(
        obj.normalizedCenter.dx * size.width,
        obj.normalizedCenter.dy * size.height,
      );
      fillPaint.color = obj.isManual
          ? const Color(0xFF3B82F6)
          : const Color(0xFF059669);
      canvas.drawCircle(center, 11, fillPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${obj.index}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CountBoxesPainter oldDelegate) => true;
}

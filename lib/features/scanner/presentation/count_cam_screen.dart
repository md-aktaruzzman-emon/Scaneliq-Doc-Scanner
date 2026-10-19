import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
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
  int _estimatedCount = 0;
  String _selectedCategory = 'Items / Labels';

  final List<String> _categories = [
    'Items / Labels',
    'Books & Notebooks',
    'Classroom Stationery',
    'Cartons & Packages',
  ];

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
      setState(() {
        _isProcessing = true;
      });
      final picture = await _cameraController!.takePicture();
      final file = File(picture.path);
      await _processImageForCounting(file);
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
        setState(() {
          _isProcessing = false;
        });
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
        setState(() {
          _isProcessing = true;
        });
        await _processImageForCounting(File(result.first.path!));
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processImageForCounting(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await recognizer.processImage(inputImage);

      final boxes = <Rect>[];
      for (final block in recognizedText.blocks) {
        boxes.add(block.boundingBox);
      }

      setState(() {
        _capturedImage = imageFile;
        // Count distinct blocks or minimum 1 if detected
        _estimatedCount = boxes.length;
      });
    } finally {
      recognizer.close();
    }
  }

  void _manualAdjust(int delta) {
    setState(() {
      _estimatedCount = (_estimatedCount + delta).clamp(0, 9999);
    });
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _estimatedCount = 0;
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
            Center(child: Image.file(_capturedImage!, fit: BoxFit.contain))
          else if (_isCameraReady && _cameraController != null)
            Center(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Top Category Selector Pill
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
                    Icons.category,
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
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
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
                                '$_estimatedCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Estimated Count (Review & adjust)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
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
                                  'CountCam Estimate: $_estimatedCount $_selectedCategory counted via Scaneliq.',
                              files: [XFile(_capturedImage!.path)],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      const Text(
                        'Align items clearly inside camera frame',
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
                            onPressed: _isProcessing
                                ? null
                                : _pickImageAndCount,
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
                          const SizedBox(width: 48), // Spacer balance
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

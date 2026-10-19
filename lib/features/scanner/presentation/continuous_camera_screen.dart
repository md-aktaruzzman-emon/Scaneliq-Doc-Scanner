import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';

enum ScanMode { document, batch, idCard, questionSet, book, whiteboard }

class ContinuousCameraScreen extends ConsumerStatefulWidget {
  final ScanMode mode;
  final String? initialTitle;

  const ContinuousCameraScreen({
    super.key,
    this.mode = ScanMode.batch,
    this.initialTitle,
  });

  @override
  ConsumerState<ContinuousCameraScreen> createState() =>
      _ContinuousCameraScreenState();
}

class _ContinuousCameraScreenState extends ConsumerState<ContinuousCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _flashOn = false;
  final int _selectedCameraIndex = 0;
  String? _errorMessage;

  // ID Card sub-step: 0 = front, 1 = back
  int _idCardStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }
      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera initialization failed: $e';
      });
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not access camera: $e';
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _flashOn = !_flashOn;
      });
    } catch (_) {}
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      final File imageFile = File(picture.path);

      if (await imageFile.exists()) {
        final recipe = widget.mode == ScanMode.whiteboard
            ? const EditRecipe(filter: PageFilter.whiteboard)
            : const EditRecipe();

        await ref.read(scanSessionProvider.notifier).importFiles([
          imageFile,
        ], defaultRecipe: recipe);

        if (widget.mode == ScanMode.idCard) {
          if (_idCardStep == 0) {
            setState(() {
              _idCardStep = 1;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Front side captured! Now flip the card and scan Back side.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Both ID card sides captured! Advancing to review...',
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _finishScan();
                }
              });
            }
          }
        }
      }
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
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles
            .where((p) => p.path != null)
            .map((p) => File(p.path!))
            .toList();

        if (files.isNotEmpty) {
          final recipe = widget.mode == ScanMode.whiteboard
              ? const EditRecipe(filter: PageFilter.whiteboard)
              : const EditRecipe();

          final count = await ref
              .read(scanSessionProvider.notifier)
              .importFiles(files, defaultRecipe: recipe);

          if (count > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Imported $count ${count == 1 ? 'image' : 'images'} successfully.',
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _finishScan() {
    final session = ref.read(scanSessionProvider);
    if (session.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture at least one page before finishing.'),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReviewPagesScreen()),
    );
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case ScanMode.document:
        return 'Document Scan';
      case ScanMode.batch:
        return 'Batch Photo Scan';
      case ScanMode.idCard:
        return _idCardStep == 0 ? 'ID Card — Front' : 'ID Card — Back';
      case ScanMode.questionSet:
        return 'Question Set Scanner';
      case ScanMode.book:
        return 'Book Scanner';
      case ScanMode.whiteboard:
        return 'Whiteboard Scanner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final pageCount = session.pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _getModeTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: _flashOn ? Colors.amber : Colors.white,
            ),
            tooltip: 'Flash / Torch',
            onPressed: _toggleFlash,
          ),
          if (pageCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _finishScan,
                icon: const Icon(Icons.check, size: 18),
                label: Text('Finish ($pageCount)'),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            Center(child: CameraPreview(_cameraController!))
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _initCameras,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Camera'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _importFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Images'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ID Card Guide Overlay
          if (widget.mode == ScanMode.idCard)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                height:
                    MediaQuery.of(context).size.width *
                    0.88 *
                    0.63, // Standard ID-1 aspect ratio
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.brandLight, width: 2.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _idCardStep == 0
                        ? 'Align Front of Card Here'
                        : 'Align Back of Card Here',
                    style: const TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Book Mode Guide Overlay
          if (widget.mode == ScanMode.book)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.92,
                height: MediaQuery.of(context).size.width * 0.92 * 0.75,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.tealAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 2,
                        height: double.infinity,
                        color: Colors.tealAccent.withValues(alpha: 0.7),
                      ),
                    ),
                    const Positioned(
                      top: 10,
                      left: 12,
                      child: Text(
                        'Left Page',
                        style: TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 10,
                      right: 12,
                      child: Text(
                        'Right Page',
                        style: TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          'Align book spine with center line',
                          style: TextStyle(
                            color: Colors.white70,
                            backgroundColor: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Whiteboard Guide Overlay
          if (widget.mode == ScanMode.whiteboard)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.92,
                height: MediaQuery.of(context).size.width * 0.92 * 0.65,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.deepPurpleAccent,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Frame whiteboard inside border · Auto contrast active',
                      style: TextStyle(
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Shutter Controls Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: Colors.black87,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Recent Thumbnail Preview with badge
                    GestureDetector(
                      onTap: pageCount > 0 ? _finishScan : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white30,
                                width: 1.5,
                              ),
                            ),
                            child: pageCount > 0
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(
                                        session.pages.last.processedPath ??
                                            session.pages.last.originalPath,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_library,
                                    color: Colors.white54,
                                  ),
                          ),
                          if (pageCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$pageCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Shutter Button
                    GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isCapturing
                                  ? Colors.grey
                                  : AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // Gallery Import Action
                    GestureDetector(
                      onTap: _importFromGallery,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30, width: 1.5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Import',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

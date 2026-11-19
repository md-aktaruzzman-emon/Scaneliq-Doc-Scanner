import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/editor/presentation/raster_redaction_screen.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_page_organizer_screen.dart';
import 'package:scaneliq/features/pdf/presentation/widgets/watermark_studio_sheet.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

enum PdfToolAction {
  organizePages,
  extractPages,
  mergePdfs,
  splitSinglePages,
  splitByRanges,
  stitchLongImage,
  compressPdf,
  pdfToImages,
  encryptPdf,
  unlockPdf,
  watermarkPdf,
  annotatePdf,
  redactPdf,
  inspectPdf,
}

class PdfToolsScreen extends StatefulWidget {
  final PdfToolAction? initialAction;

  const PdfToolsScreen({super.key, this.initialAction});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    if (action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerAction(action);
      });
    }
  }

  void _triggerAction(PdfToolAction action) {
    switch (action) {
      case PdfToolAction.organizePages:
        _organizePages();
        break;
      case PdfToolAction.extractPages:
        _extractPages();
        break;
      case PdfToolAction.mergePdfs:
        _mergePdfs();
        break;
      case PdfToolAction.splitSinglePages:
        _splitPdf();
        break;
      case PdfToolAction.splitByRanges:
        _splitByRanges();
        break;
      case PdfToolAction.stitchLongImage:
        _stitchLongImage();
        break;
      case PdfToolAction.compressPdf:
        _compressPdf();
        break;
      case PdfToolAction.pdfToImages:
        _pdfToImages();
        break;
      case PdfToolAction.encryptPdf:
        _encryptPdf();
        break;
      case PdfToolAction.unlockPdf:
        _unlockPdf();
        break;
      case PdfToolAction.watermarkPdf:
        _watermarkPdf();
        break;
      case PdfToolAction.annotatePdf:
        _annotatePdf();
        break;
      case PdfToolAction.redactPdf:
        _redactPdf();
        break;
      case PdfToolAction.inspectPdf:
        _inspectPdf();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. PAGE MANAGEMENT & ORGANIZATION
  // ---------------------------------------------------------------------------

  Future<void> _organizePages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfPageOrganizerScreen(pdfFile: file)),
    );
  }

  Future<void> _extractPages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    final pageCount = await AdvancedPdfService.instance.getPageCount(file);
    if (!mounted) return;

    final rangeController = TextEditingController(text: '1-$pageCount');
    final nameController = TextEditingController(
      text: 'Extracted_${DateTime.now().millisecondsSinceEpoch}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extract Pages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document has $pageCount pages.'),
            const SizedBox(height: 12),
            TextField(
              controller: rangeController,
              decoration: const InputDecoration(
                labelText: 'Page Numbers / Range',
                hintText: 'e.g. 1, 3, 5-7',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Output PDF Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Extract'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final rawRange = rangeController.text.trim();
    final pagesToExtract = _parsePageRange(rawRange, pageCount);

    if (pagesToExtract.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid page range entered.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Extracting ${pagesToExtract.length} pages...';
    });

    try {
      final extracted = await AdvancedPdfService.instance.extractPages(
        sourcePdf: file,
        pageNumbers: pagesToExtract,
        outputFileName: nameController.text.trim(),
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('Pages Extracted Successfully', extracted);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<int> _parsePageRange(String input, int maxPages) {
    final result = <int>[];
    final parts = input.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final bounds = trimmed.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0].trim());
          final end = int.tryParse(bounds[1].trim());
          if (start != null && end != null) {
            final mn = math.min(start, end).clamp(1, maxPages);
            final mx = math.max(start, end).clamp(1, maxPages);
            for (int i = mn; i <= mx; i++) {
              result.add(i);
            }
          }
        }
      } else {
        final p = int.tryParse(trimmed);
        if (p != null && p >= 1 && p <= maxPages) {
          result.add(p);
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 2. MERGE & SPLIT
  // ---------------------------------------------------------------------------

  Future<void> _mergePdfs() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least 2 PDF files to merge.'),
            ),
          );
        }
        return;
      }

      final files = picked
          .where((p) => p.path != null)
          .map((p) => File(p.path!))
          .toList();

      if (files.length < 2) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Merging ${files.length} PDFs...';
      });

      final mergedFile = await AdvancedPdfService.instance.mergePdfs(
        sourcePdfs: files,
        outputFileName: 'Merged_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('PDFs Merged Successfully', mergedFile);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _splitPdf() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked.isEmpty || picked.first.path == null) return;
      final file = File(picked.first.path!);

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Splitting PDF into pages...';
      });

      final splitFiles = await AdvancedPdfService.instance.splitPdfIntoPages(
        sourcePdf: file,
        baseOutputName: 'Split_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _registerSplitFilesInVault(splitFiles);

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Split Completed'),
            content: Text(
              'Generated ${splitFiles.length} single-page PDF files and added them to your Vault.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _splitByRanges() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    final pageCount = await AdvancedPdfService.instance.getPageCount(file);
    if (!mounted) return;

    final rangeController = TextEditingController(text: '1-2, 3-$pageCount');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Split by Custom Ranges'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document has $pageCount pages.'),
            const SizedBox(height: 12),
            TextField(
              controller: rangeController,
              decoration: const InputDecoration(
                labelText: 'Ranges separated by commas',
                hintText: 'e.g. 1-2, 3-5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Split'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final rawRanges = rangeController.text.trim();
    final parts = rawRanges.split(',');
    final parsedRanges = <List<int>>[];

    for (final p in parts) {
      final range = _parsePageRange(p, pageCount);
      if (range.isNotEmpty) parsedRanges.add(range);
    }

    if (parsedRanges.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No valid ranges found.')));
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Splitting into ${parsedRanges.length} parts...';
    });

    try {
      final results = await AdvancedPdfService.instance.splitPdfByRanges(
        sourcePdf: file,
        ranges1Indexed: parsedRanges,
        baseOutputName: 'RangeSplit_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _registerSplitFilesInVault(results);

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Split by Ranges Complete'),
            content: Text(
              'Generated ${results.length} split PDF files and saved them to your Vault.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stitchLongImage() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (picked.isEmpty) return;

    if (picked.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least 2 images to stitch'),
          ),
        );
      }
      return;
    }

    final imageFiles = picked
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    setState(() {
      _isProcessing = true;
      _statusMessage =
          'Stitching ${imageFiles.length} pages into a long image...';
    });

    try {
      final outDir = AppStorageService.instance.exportsDir;
      final outName =
          'Stitched_LongImage_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetFile = File(p.join(outDir.path, outName));

      await ImageProcessingService.stitchImageFilesVertically(
        imageFiles: imageFiles,
        targetFile: targetFile,
        spacing: 12,
        quality: 90,
      );

      final docId = const Uuid().v4();
      final pageId = const Uuid().v4();
      final savedOriginal = await AppStorageService.instance.copyToOriginals(
        pageId,
        targetFile,
        extension: 'jpg',
      );
      final stitchedDoc = ScannedDocument(
        id: docId,
        title: p.basenameWithoutExtension(outName),
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: 1,
      );
      final stitchedPage = DocumentPage(
        id: pageId,
        documentId: docId,
        pageOrder: 0,
        originalPath: savedOriginal.path,
      );
      await AppDatabaseService.instance.saveDocumentWithPages(stitchedDoc, [
        stitchedPage,
      ]);
      _invalidateLibraryProviders();

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Long Image Created (${imageFiles.length} Pages)'),
            content: Text(
              'Saved continuous vertical scan as "${stitchedDoc.title}.jpg" and indexed it into your Vault.',
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Open / Convert PDF'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final fullDoc =
                      await AppDatabaseService.instance.getDocument(docId) ??
                      stitchedDoc.copyWith(pages: [stitchedPage]);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentViewerScreen(document: fullDoc),
                      ),
                    );
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share JPEG'),
                onPressed: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      text: stitchedDoc.title,
                      files: [XFile(targetFile.path, mimeType: 'image/jpeg')],
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Long Image stitching failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 3. COMPRESSION & OPTIMIZATION
  // ---------------------------------------------------------------------------

  Future<void> _compressPdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    PdfCompressionPreset selected = PdfCompressionPreset.balanced;

    if (!mounted) return;
    final confirmed = await showDialog<PdfCompressionPreset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: const Text('Compress PDF Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select target compression level:'),
              RadioGroup<PdfCompressionPreset>(
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.highQuality,
                      title: Text('High Quality'),
                      subtitle: Text('Minimal compression (~85% quality)'),
                    ),
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.balanced,
                      title: Text('Balanced (Recommended)'),
                      subtitle: Text('Optimal balance (~65% quality)'),
                    ),
                    RadioListTile<PdfCompressionPreset>(
                      value: PdfCompressionPreset.smallerFile,
                      title: Text('Smaller File'),
                      subtitle: Text('Maximum size reduction (~45% quality)'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, selected),
              child: const Text('Compress'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Compressing PDF...';
    });

    try {
      final outName = 'Compressed_${DateTime.now().millisecondsSinceEpoch}';
      final result = await AdvancedPdfService.instance.compressPdf(
        sourcePdf: file,
        preset: confirmed,
        outputFileName: outName,
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      final origKb = (result.originalSizeBytes / 1024).toStringAsFixed(1);
      final compKb = (result.compressedSizeBytes / 1024).toStringAsFixed(1);
      final pct = result.percentageReduction.toStringAsFixed(1);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Compression Complete'),
            content: Text(
              'Original: $origKb KB\nCompressed: $compKb KB\nSpace Saved: $pct%\n\nFile saved to: ${result.outputFile.path}',
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                onPressed: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Compressed PDF',
                      files: [XFile(result.outputFile.path)],
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compression failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 4. SECURITY & WATERMARKS
  // ---------------------------------------------------------------------------

  Future<void> _encryptPdf() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked.isEmpty || picked.first.path == null) return;
      final file = File(picked.first.path!);

      if (!mounted) return;
      final passwordController = TextEditingController();
      final enteredPassword = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Protect PDF with Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter password',
              hintText: 'e.g. Secret123',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, passwordController.text.trim()),
              child: const Text('Protect'),
            ),
          ],
        ),
      );

      if (enteredPassword == null || enteredPassword.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Encrypting PDF with AES-256...';
      });

      final encryptedFile = await AdvancedPdfService.instance.encryptPdf(
        sourcePdf: file,
        userPassword: enteredPassword,
        outputFileName: 'Protected_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('Password Protection Applied', encryptedFile);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Encryption failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _unlockPdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    if (!mounted) return;
    final passwordController = TextEditingController();
    final enteredPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PDF Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Current Document Password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, passwordController.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (enteredPassword == null || enteredPassword.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying and removing password...';
    });

    try {
      final outName = 'Unlocked_${DateTime.now().millisecondsSinceEpoch}';
      final unlocked = await AdvancedPdfService.instance.removePassword(
        sourcePdf: file,
        password: enteredPassword,
        outputFileName: outName,
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('PDF Successfully Unlocked', unlocked);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unlock failed: Invalid password or unsupported file.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _watermarkPdf() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked.isEmpty || picked.first.path == null) return;
      final file = File(picked.first.path!);
      final totalPages = await AdvancedPdfService.instance.getPageCount(file);

      if (!mounted) return;
      final opts = await showWatermarkStudioSheet(
        context,
        currentPage: 1,
        totalPages: totalPages > 0 ? totalPages : 1,
      );
      if (opts == null || !mounted) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Applying watermark...';
      });

      final watermarkedFile = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: file,
        options: opts,
        outputFileName: 'Watermarked_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('Watermark Applied', watermarkedFile);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watermark failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _annotatePdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null || !mounted) return;
    final file = File(picked.first.path!);
    final pageCount = await AdvancedPdfService.instance.getPageCount(file);
    if (!mounted) return;

    final now = DateTime.now();
    final adHocDoc = ScannedDocument(
      id: 'ext_${const Uuid().v4()}',
      title: p.basenameWithoutExtension(file.path),
      createdAt: now,
      modifiedAt: now,
      pageCount: math.max(1, pageCount),
      exportPath: file.path,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentViewerScreen(document: adHocDoc, startInAnnotateMode: true),
      ),
    );
  }

  Future<void> _pdfToImages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked.isEmpty || picked.first.path == null || !mounted) return;
    final file = File(picked.first.path!);

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Rendering PDF pages to high-res JPEGs...';
    });

    try {
      final baseName = p.basenameWithoutExtension(file.path);
      final images = await AdvancedPdfService.instance.exportPdfToImages(
        sourcePdf: file,
        baseOutputName: baseName,
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (!mounted) return;
      if (images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pages could be rendered from PDF.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF Exported to Images'),
          content: Text(
            'Exported ${images.length} JPEG page${images.length == 1 ? '' : 's'} to exports folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(
                  ShareParams(
                    text: '$baseName (Pages)',
                    files: images.map((f) => XFile(f.path)).toList(),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share Images'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF-to-image export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _redactPdf() async {
    final redactionMode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Redaction Engine'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'flatten'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.layers_clear_rounded),
              title: Text('Flatten & Scrub PDF (Irreversible)'),
              subtitle: Text(
                'Rasterizes pages, zeros out pixels in selected region & strips vector text',
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'raster_studio'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.grid_on_rounded),
              title: Text('Raster Pixel / Mosaic Studio (Images)'),
              subtitle: Text(
                'Draw custom blackout or mosaic boxes over scanned page images',
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'visual_mask'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shield_outlined),
              title: Text('PDF Visual Mask Overlay'),
              subtitle: Text(
                'Adds opaque blackout overlay box & strips document metadata',
              ),
            ),
          ),
        ],
      ),
    );

    if (redactionMode == null || !mounted) return;

    if (redactionMode == 'raster_studio') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RasterRedactionScreen()),
      );
      return;
    }

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    final pageCount = await AdvancedPdfService.instance.getPageCount(file);
    if (!mounted) return;

    int targetPage = 1;
    String region = 'top';
    final bool isFlattenMode = redactionMode == 'flatten';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isFlattenMode
                    ? Icons.layers_clear_rounded
                    : Icons.shield_outlined,
                color: Colors.black87,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFlattenMode
                      ? 'Irreversible Flatten & Scrub'
                      : 'Visual Masking & Metadata',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFlattenMode
                    ? 'Rasterizes every page into flat images, permanently zeroes pixels inside the chosen band, and destroys extractable vector text and metadata.'
                    : 'Notice: Applies an opaque blackout overlay and strips document metadata.\n\n'
                          'Security Warning: For digital vector PDFs, underlying text streams remain beneath visual overlays. Choose Flatten & Scrub for irreversible destruction.',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: targetPage,
                decoration: const InputDecoration(
                  labelText: 'Target Page',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int i = 1; i <= pageCount; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('Page $i of $pageCount'),
                    ),
                ],
                onChanged: (val) => setDState(() => targetPage = val ?? 1),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: region,
                decoration: const InputDecoration(
                  labelText: 'Area to Redact',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'top',
                    child: Text('Top Header Area'),
                  ),
                  DropdownMenuItem(
                    value: 'center',
                    child: Text('Center Body Box'),
                  ),
                  DropdownMenuItem(
                    value: 'bottom',
                    child: Text('Bottom Footer Area'),
                  ),
                ],
                onChanged: (val) => setDState(() => region = val ?? 'top'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(
                isFlattenMode ? 'Flatten & Redact PDF' : 'Apply Visual Mask',
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = isFlattenMode
          ? 'Rasterizing PDF & permanently zeroing pixels...'
          : 'Applying visual mask and sanitizing metadata...';
    });

    try {
      double ry = 40;
      if (region == 'center') ry = 300;
      if (region == 'bottom') ry = 650;

      final outName = isFlattenMode
          ? 'Scrubbed_${DateTime.now().millisecondsSinceEpoch}'
          : 'Masked_${DateTime.now().millisecondsSinceEpoch}';
      final areas = [
        PdfRedactionArea(
          pageIndex: targetPage - 1,
          x: 50,
          y: ry,
          width: 500,
          height: 60,
          overlayText: '[REDACTED]',
        ),
      ];
      final redacted = isFlattenMode
          ? await AdvancedPdfService.instance.flattenAndRedactPdf(
              sourcePdf: file,
              redactions: areas,
              outputFileName: outName,
            )
          : await AdvancedPdfService.instance.applyRedaction(
              sourcePdf: file,
              redactions: areas,
              outputFileName: outName,
              sanitizeMetadata: true,
            );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog(
          isFlattenMode
              ? 'Irreversible Flattened Redaction Complete'
              : 'Visual Mask Applied & Metadata Sanitized',
          redacted,
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redaction failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 5. INSPECTION & METADATA
  // ---------------------------------------------------------------------------

  Future<void> _inspectPdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    try {
      final info = await AdvancedPdfService.instance.inspectPdf(file);
      if (!mounted) return;

      final sizeMb = (info.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      final sizeKb = (info.fileSizeBytes / 1024).toStringAsFixed(1);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF Inspection Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Pages', '${info.pageCount} pages'),
              _detailRow('File Size', '$sizeMb MB ($sizeKb KB)'),
              _detailRow(
                'Dimensions',
                '${info.firstPageWidth.toStringAsFixed(0)} × ${info.firstPageHeight.toStringAsFixed(0)} pt',
              ),
              _detailRow(
                'Encrypted',
                info.isEncrypted ? 'Yes (Protected)' : 'No',
              ),
              if (info.title != null) _detailRow('Title', info.title!),
              if (info.producer != null) _detailRow('Producer', info.producer!),
              if (info.creationDate != null)
                _detailRow(
                  'Created',
                  '${info.creationDate!.year}-${info.creationDate!.month.toString().padLeft(2, '0')}-${info.creationDate!.day.toString().padLeft(2, '0')}',
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to inspect PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _registerSplitFilesInVault(List<File> files) async {
    for (final f in files) {
      int pageCount = 1;
      try {
        pageCount = await AdvancedPdfService.instance.getPageCount(f);
      } catch (_) {}
      try {
        await AppDatabaseService.instance.saveDocument(
          ScannedDocument(
            id: const Uuid().v4(),
            title: p.basenameWithoutExtension(f.path),
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            pageCount: pageCount,
            exportPath: f.path,
          ),
        );
      } catch (_) {}
    }
    _invalidateLibraryProviders();
  }

  void _invalidateLibraryProviders() {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(documentsListProvider);
      container.invalidate(searchedDocumentsProvider);
    } catch (_) {}
  }

  Future<void> _showSuccessDialog(String title, File file) async {
    int pageCount = 1;
    try {
      pageCount = await AdvancedPdfService.instance.getPageCount(file);
    } catch (_) {}
    final sizeBytes = await file.length();
    final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);

    final doc = ScannedDocument(
      id: const Uuid().v4(),
      title: p.basenameWithoutExtension(file.path),
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      pageCount: pageCount,
      exportPath: file.path,
    );

    try {
      await AppDatabaseService.instance.saveDocument(doc);
      _invalidateLibraryProviders();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved to Documents library:\n${p.basename(file.path)}'),
            const SizedBox(height: 8),
            Text(
              'Total Pages: $pageCount · $sizeKb KB',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('View'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: doc),
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(
                  text: title,
                  files: [XFile(file.path, mimeType: 'application/pdf')],
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Row(
          children: [
            Flexible(
              child: Text(
                'PDF Workbench',
                style: textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const ScaneliqStatusLabel(
              text: 'ON-DEVICE',
              tone: ScaneliqStatusTone.accent,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tokens.hairline),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 32),
            children: [
              const ScaneliqSectionHeader(
                title: 'Organize & Structure',
                trailing: ScaneliqStatusLabel(text: 'IMPLEMENTED'),
              ),
              _buildHairlineToolRow(
                icon: Icons.dashboard_customize_outlined,
                title: 'Organize & Rotate Pages',
                subtitle: 'Reorder, rotate, delete, duplicate, or insert pages into PDF',
                badge: 'ORGANIZE',
                onTap: _isProcessing ? null : _organizePages,
              ),
              _buildHairlineToolRow(
                icon: Icons.file_upload_outlined,
                title: 'Extract Custom Pages',
                subtitle: 'Extract specific pages or ranges (e.g. 1, 3, 5-8) to new PDF',
                badge: 'EXTRACT',
                onTap: _isProcessing ? null : _extractPages,
              ),
              _buildHairlineToolRow(
                icon: Icons.call_merge_rounded,
                title: 'Merge PDFs',
                subtitle: 'Combine 2 or more PDF files into one consolidated document',
                badge: 'MERGE',
                onTap: _isProcessing ? null : _mergePdfs,
              ),
              _buildHairlineToolRow(
                icon: Icons.call_split_rounded,
                title: 'Split into Single Pages',
                subtitle: 'Deconstruct a multi-page PDF into independent 1-page files',
                badge: 'SPLIT',
                onTap: _isProcessing ? null : _splitPdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.splitscreen_outlined,
                title: 'Split by Custom Ranges',
                subtitle: 'Partition a document into parts (e.g. 1-2, 3-6)',
                badge: 'RANGES',
                onTap: _isProcessing ? null : _splitByRanges,
              ),

              const SizedBox(height: 22),
              const ScaneliqSectionHeader(
                title: 'Optimize & Convert',
                trailing: ScaneliqStatusLabel(
                  text: 'LOCAL',
                  tone: ScaneliqStatusTone.success,
                ),
              ),
              _buildHairlineToolRow(
                icon: Icons.compress_rounded,
                title: 'Compress PDF',
                subtitle: 'High Quality, Balanced (200 DPI), or Compact preset compression',
                badge: 'COMPRESS',
                tone: ScaneliqStatusTone.success,
                onTap: _isProcessing ? null : _compressPdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.view_stream_outlined,
                title: 'Stitch to Long Image',
                subtitle:
                    'Combine receipt or document pages into one vertical JPEG',
                badge: 'STITCH',
                onTap: _isProcessing ? null : _stitchLongImage,
              ),
              _buildHairlineToolRow(
                icon: Icons.photo_library_outlined,
                title: 'PDF to Images (JPEG)',
                subtitle: 'Rasterize external PDF pages into high-res JPEGs via PDFium',
                badge: 'PDF → JPG',
                onTap: _isProcessing ? null : _pdfToImages,
              ),

              const SizedBox(height: 22),
              const ScaneliqSectionHeader(
                title: 'Edit, Sign & Protect',
                trailing: ScaneliqStatusLabel(text: 'AES-256'),
              ),
              _buildHairlineToolRow(
                icon: Icons.edit_note_outlined,
                title: 'Sign & Annotate PDF',
                subtitle:
                    'Stamp approvals, verified notes, or text annotations',
                badge: 'SIGN',
                onTap: _isProcessing ? null : _annotatePdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.branding_watermark_outlined,
                title: 'Add Watermark',
                subtitle:
                    'Overlay CONFIDENTIAL, DRAFT, COPY, or custom watermark',
                badge: 'MARK',
                onTap: _isProcessing ? null : _watermarkPdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.lock_outline_rounded,
                title: 'Password Encryption',
                subtitle: 'Protect sensitive files with AES-256 encryption',
                badge: 'ENCRYPT',
                tone: ScaneliqStatusTone.accent,
                onTap: _isProcessing ? null : _encryptPdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.lock_open_outlined,
                title: 'Unlock / Remove Password',
                subtitle:
                    'Decrypt password-protected PDF to an open local copy',
                badge: 'UNLOCK',
                onTap: _isProcessing ? null : _unlockPdf,
              ),
              _buildHairlineToolRow(
                icon: Icons.shield_outlined,
                title: 'Masking & Metadata Sanitizer',
                subtitle: 'Blackout areas and sanitize metadata (visual overlay on vector PDFs)',
                badge: 'SANITIZE',
                tone: ScaneliqStatusTone.warning,
                onTap: _isProcessing ? null : _redactPdf,
              ),

              const SizedBox(height: 22),
              const ScaneliqSectionHeader(title: 'Inspection & Details'),
              _buildHairlineToolRow(
                icon: Icons.info_outline_rounded,
                title: 'Inspect PDF Details',
                subtitle: 'View page count, file size, dimensions, and encryption status',
                badge: 'INFO',
                onTap: _isProcessing ? null : _inspectPdf,
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.48),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: ScaneliqRadius.folioBorderRadius,
                    border: Border.all(color: tokens.hairline),
                  ),
                  child: ScaneliqLoadingIndicator(
                    message: _statusMessage ?? 'Processing PDF…',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHairlineToolRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    ScaneliqStatusTone tone = ScaneliqStatusTone.neutral,
    required VoidCallback? onTap,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: tokens.textPrimary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ScaneliqStatusLabel(text: badge, tone: tone),
          ],
        ),
      ),
    );
  }
}

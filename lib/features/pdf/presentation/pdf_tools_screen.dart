import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/documents/presentation/document_viewer_screen.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_page_organizer_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

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
              'Generated ${splitFiles.length} single-page PDF files in exports.',
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

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Split by Ranges Complete'),
            content: Text('Generated ${results.length} split PDF files.'),
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

      if (!mounted) return;
      final watermarkController = TextEditingController(text: 'CONFIDENTIAL');
      WatermarkPosition position = WatermarkPosition.diagonalCenter;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dCtx, setDialogState) => AlertDialog(
            title: const Text('Add PDF Watermark'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: watermarkController,
                  decoration: const InputDecoration(
                    labelText: 'Watermark Text',
                    hintText: 'e.g. CONFIDENTIAL / DRAFT',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WatermarkPosition>(
                  initialValue: position,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: WatermarkPosition.diagonalCenter,
                      child: Text('Diagonal Center (-45°)'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.horizontalCenter,
                      child: Text('Horizontal Center'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.headerTop,
                      child: Text('Header (Top)'),
                    ),
                    DropdownMenuItem(
                      value: WatermarkPosition.footerBottom,
                      child: Text('Footer (Bottom)'),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => position = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Applying watermark...';
      });

      final watermarkedFile = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: file,
        options: WatermarkOptions(
          text: watermarkController.text.trim(),
          position: position,
          color: const Color(0xFFDC2626),
          opacity: 0.25,
        ),
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

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    final pageCount = await AdvancedPdfService.instance.getPageCount(file);
    if (!mounted) return;

    final textController = TextEditingController(text: 'APPROVED');
    int targetPage = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: const Text('Add Text Annotation / Stamp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Annotation / Stamp Text',
                  hintText: 'e.g. APPROVED / SIGNED / REVIEWED',
                  border: OutlineInputBorder(),
                ),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Apply Stamp'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Applying annotation to document...';
    });

    try {
      final outName = 'Annotated_${DateTime.now().millisecondsSinceEpoch}';
      final annotated = await AdvancedPdfService.instance.applyAnnotations(
        sourcePdf: file,
        annotations: [
          PdfAnnotationItem(
            type: PdfAnnotationType.text,
            pageIndex: targetPage - 1,
            x: 50,
            y: 50,
            width: 250,
            height: 30,
            text: textController.text.trim(),
            fontSize: 16,
            color: const Color(0xFF059669),
          ),
        ],
        outputFileName: outName,
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('Annotation Applied', annotated);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Annotation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _redactPdf() async {
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.black87),
              SizedBox(width: 8),
              Text('Permanent Redaction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Redaction permanently zeroes out the selected area and sanitizes metadata. '
                'The underlying content cannot be recovered.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
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
              child: const Text('Confirm Redaction'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage =
          'Permanently redacting content and sanitizing metadata...';
    });

    try {
      double ry = 40;
      if (region == 'center') ry = 300;
      if (region == 'bottom') ry = 650;

      final outName = 'Redacted_${DateTime.now().millisecondsSinceEpoch}';
      final redacted = await AdvancedPdfService.instance.applyRedaction(
        sourcePdf: file,
        redactions: [
          PdfRedactionArea(
            pageIndex: targetPage - 1,
            x: 50,
            y: ry,
            width: 500,
            height: 60,
            overlayText: '[REDACTED]',
          ),
        ],
        outputFileName: outName,
        sanitizeMetadata: true,
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (mounted) {
        _showSuccessDialog('Content Redacted & Sanitized', redacted);
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

  Future<void> _showSuccessDialog(String title, File file) async {
    int pageCount = 1;
    try {
      pageCount = await AdvancedPdfService.instance.getPageCount(file);
    } catch (_) {}

    final doc = ScannedDocument(
      id: const Uuid().v4(),
      title: file.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll('.pdf', ''),
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      pageCount: pageCount,
      exportPath: file.path,
    );

    try {
      await AppDatabaseService.instance.saveDocument(doc);
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
            Text('Saved to Documents library:\n${file.path}'),
            const SizedBox(height: 8),
            Text(
              'Total Pages: $pageCount',
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
                ShareParams(text: title, files: [XFile(file.path)]),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Advanced PDF Tools',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Page Management & Organization
              const Text(
                'Page Management & Organization',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.dashboard_customize_outlined,
                color: Colors.teal,
                title: 'Organize Pages',
                subtitle: 'Reorder, rotate, delete, duplicate, or insert pages into existing PDF',
                onTap: _isProcessing ? null : _organizePages,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.file_upload_outlined,
                color: Colors.blue,
                title: 'Extract Custom Pages',
                subtitle: 'Extract specific pages or page ranges (e.g. 1, 3, 5-8) into a new PDF',
                onTap: _isProcessing ? null : _extractPages,
              ),

              const SizedBox(height: 20),

              // Merge & Split
              const Text(
                'Merge & Split',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.call_merge,
                color: Colors.indigo,
                title: 'Merge PDFs',
                subtitle: 'Combine 2 or more PDF files into a single consolidated document',
                onTap: _isProcessing ? null : _mergePdfs,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.call_split,
                color: Colors.orange,
                title: 'Split into Single Pages',
                subtitle: 'Deconstruct a multi-page PDF into independent 1-page documents',
                onTap: _isProcessing ? null : _splitPdf,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.splitscreen_outlined,
                color: Colors.deepOrange,
                title: 'Split by Custom Ranges',
                subtitle: 'Partition document into multiple separate parts (e.g. 1-2, 3-6)',
                onTap: _isProcessing ? null : _splitByRanges,
              ),

              const SizedBox(height: 20),

              // Compression & Optimization
              const Text(
                'Document Optimization',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.compress,
                color: Colors.green,
                title: 'Compress PDF',
                subtitle: 'Reduce file size with High Quality, Balanced, or Smaller File presets',
                onTap: _isProcessing ? null : _compressPdf,
              ),

              const SizedBox(height: 20),

              // Security & Watermarks
              const Text(
                'Security & Watermarks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.lock_outline,
                color: Colors.redAccent,
                title: 'Password Encryption',
                subtitle: 'Protect sensitive files with industrial AES-256 bit encryption',
                onTap: _isProcessing ? null : _encryptPdf,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.lock_open_outlined,
                color: Colors.pink,
                title: 'Unlock / Remove Password',
                subtitle: 'Decrypt password-protected document and export an open PDF copy',
                onTap: _isProcessing ? null : _unlockPdf,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.branding_watermark_outlined,
                color: Colors.purple,
                title: 'Add Watermark',
                subtitle: 'Overlay CONFIDENTIAL, DRAFT, COPY, or custom text across pages',
                onTap: _isProcessing ? null : _watermarkPdf,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.edit_note_outlined,
                color: Colors.teal,
                title: 'Sign & Annotate PDF',
                subtitle: 'Add stamped approvals, verified notes, or text annotations',
                onTap: _isProcessing ? null : _annotatePdf,
              ),
              const SizedBox(height: 10),
              _buildToolCard(
                icon: Icons.shield_outlined,
                color: Colors.black87,
                title: 'Redact Content Permanently',
                subtitle: 'Blackout sensitive text/boxes and permanently sanitize document metadata',
                onTap: _isProcessing ? null : _redactPdf,
              ),

              const SizedBox(height: 20),

              // Inspection & Details
              const Text(
                'Inspection & Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.info_outline,
                color: Colors.blueGrey,
                title: 'Inspect PDF Details',
                subtitle: 'View page count, file size, page dimensions, and security information',
                onTap: _isProcessing ? null : _inspectPdf,
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage ?? 'Processing PDF...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

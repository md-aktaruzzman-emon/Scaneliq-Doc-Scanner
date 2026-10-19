import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_tools_screen.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/count_cam_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_code_screen.dart';
import 'package:scaneliq/features/scanner/presentation/translate_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _isProcessingOcr = false;
  String? _extractedText;

  void _runDirectOcrOnPickedFile() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (pickedFiles.isNotEmpty && pickedFiles.first.path != null) {
        setState(() {
          _isProcessingOcr = true;
          _extractedText = null;
        });

        final file = File(pickedFiles.first.path!);
        final text = await OcrService.instance.extractText(file);

        setState(() {
          _isProcessingOcr = false;
          _extractedText = text.trim().isEmpty
              ? 'No text detected in this image.'
              : text;
        });

        if (mounted) {
          _showTextResultDialog(_extractedText!);
        }
      }
    } catch (e) {
      setState(() {
        _isProcessingOcr = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showTextResultDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extracted Text'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied text to clipboard!')),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Document Tools',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Productivity & OCR Tools Section
            _buildSectionHeader(
              'Productivity & OCR Tools',
              'Utilities for text extraction, sharing, and PDF manipulation',
              isDark,
            ),
            const SizedBox(height: 10),

            // Instant Image OCR
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: AppColors.brandPrimary,
                  ),
                ),
                title: const Text(
                  'Instant Image OCR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Extract selectable text from any image file on your phone',
                ),
                trailing: _isProcessingOcr
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _isProcessingOcr ? null : _runDirectOcrOnPickedFile,
              ),
            ),
            const SizedBox(height: 10),

            // PDF Productivity Tools
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: const Text(
                  'PDF Productivity Tools',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Merge multiple PDFs, split pages, encrypt with password & watermark',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfToolsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Share & Export
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: AppColors.success,
                  ),
                ),
                title: const Text(
                  'Share & Export',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Send scanned documents via email, messaging, or system drive',
                ),
                trailing: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sharing is integrated inside every document card and viewer.',
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            // Specialized Capture Modes Section
            _buildSectionHeader(
              'Specialized Capture Modes',
              'Direct access to advanced camera workflows',
              isDark,
            ),
            const SizedBox(height: 10),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.burst_mode,
                      color: Color(0xFF2563EB),
                    ),
                    title: const Text('Batch Scanning'),
                    subtitle: const Text(
                      'Continuous rapid capture with live counter',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContinuousCameraScreen(
                            mode: ScanMode.batch,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.badge, color: Color(0xFF4F46E5)),
                    title: const Text('ID Card 2-in-1'),
                    subtitle: const Text(
                      'Scan front and back on a single page',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContinuousCameraScreen(
                            mode: ScanMode.idCard,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.menu_book,
                      color: Color(0xFF0D9488),
                    ),
                    title: const Text('Book Mode'),
                    subtitle: const Text(
                      'Scan open books with curve flatten guidance',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ContinuousCameraScreen(mode: ScanMode.book),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF059669),
                    ),
                    title: const Text('QR & Barcode Scanner'),
                    subtitle: const Text('Instant code detection and copy'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanCodeScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.calculate,
                      color: Color(0xFFD97706),
                    ),
                    title: const Text('CountCam'),
                    subtitle: const Text(
                      'AI object detection and inventory counting',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CountCamScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.translate,
                      color: Color(0xFFE11D48),
                    ),
                    title: const Text('Translate Lens'),
                    subtitle: const Text('Live optical translation overlay'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TranslateScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Upcoming Platform Integrations Section
            _buildSectionHeader(
              'Upcoming Platform Integrations',
              'Features scheduled in the Scaneliq Master Blueprint roadmap',
              isDark,
            ),
            const SizedBox(height: 10),

            Card(
              color: isDark ? AppColors.surface2Dark : AppColors.surface1Light,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_sync_outlined,
                      color: Colors.grey,
                    ),
                    title: const Text(
                      'Cloud Backup & Multi-device Sync',
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: const Text(
                      'Phase 8 — Privacy-preserving optional cloud sync',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Planned',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.draw_outlined,
                      color: Colors.grey,
                    ),
                    title: const Text(
                      'E-Signature & Document Annotations',
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: const Text(
                      'Phase 4 — Freehand signature & stamp overlay',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Planned',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.table_chart_outlined,
                      color: Colors.grey,
                    ),
                    title: const Text(
                      'Table & Expense Extraction to Excel',
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: const Text(
                      'Phase 10 — Receipt ledger & CSV export',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Planned',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

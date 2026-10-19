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
import 'package:scaneliq/features/intelligence/presentation/business_card_dialog.dart';
import 'package:scaneliq/features/intelligence/presentation/receipt_dialog.dart';
import 'package:scaneliq/features/intelligence/presentation/ai_document_sheet.dart';

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
        if (!mounted) return;

        final chosenScript = await showDialog<OcrScript>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Select Recognition Script'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('English / Latin'),
                  subtitle: const Text('Latin alphabet documents'),
                  onTap: () => Navigator.pop(ctx, OcrScript.latin),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Bengali (বাংলা) & Indic'),
                  subtitle: const Text('Bengali script & numerals'),
                  onTap: () => Navigator.pop(ctx, OcrScript.bengali),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Devanagari (Hindi / Nepali)'),
                  subtitle: const Text('Devanagari script documents'),
                  onTap: () => Navigator.pop(ctx, OcrScript.devanagari),
                ),
              ],
            ),
          ),
        );

        if (chosenScript == null) return;

        setState(() {
          _isProcessingOcr = true;
          _extractedText = null;
        });

        final file = File(pickedFiles.first.path!);
        final text = await OcrService.instance.extractText(
          file,
          script: chosenScript,
        );

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Productivity & OCR Tools Section
            _buildSectionHeader(
              'Productivity & OCR Tools',
              'Extract text, recognize codes, and translate documents',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildCardGroup(
              isDark: isDark,
              children: [
                _buildToolTile(
                  icon: Icons.document_scanner_rounded,
                  title: 'Instant Image OCR',
                  subtitle: 'Extract selectable text from any image file on your phone',
                  isDark: isDark,
                  trailing: _isProcessingOcr
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _isProcessingOcr ? null : _runDirectOcrOnPickedFile,
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'QR & Barcode Scanner',
                  subtitle:
                      'Instant code detection, URL open, and clipboard copy',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanCodeScreen()),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.translate_rounded,
                  title: 'Translate Lens',
                  subtitle:
                      'Optical camera translation overlay across languages',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TranslateScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.calculate_outlined,
                  title: 'CountCam',
                  subtitle: 'AI object detection and inventory item counting',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CountCamScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Document Intelligence & AI
            _buildSectionHeader(
              'Document Intelligence & AI',
              'Extract business contacts, parse receipt totals, and ask questions',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildCardGroup(
              isDark: isDark,
              children: [
                _buildToolTile(
                  icon: Icons.contact_mail_outlined,
                  title: 'Business Card Reader',
                  subtitle: 'Extract contact details and export standard vCard (.vcf)',
                  isDark: isDark,
                  onTap: () => BusinessCardDialog.show(context),
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Receipt & Invoice Scanner',
                  subtitle: 'Extract totals, tax, line items with math verification & CSV export',
                  isDark: isDark,
                  onTap: () => ReceiptDialog.show(context),
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Document Summary & Q&A',
                  subtitle: 'Offline TextRank executive summary and semantic passage answering',
                  isDark: isDark,
                  onTap: () => AiDocumentSheet.show(context),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 2. PDF Productivity Section
            _buildSectionHeader(
              'PDF Productivity Suite',
              'Merge, split, organize pages, watermark, and encrypt PDFs',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildCardGroup(
              isDark: isDark,
              children: [
                _buildToolTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'PDF Productivity Tools',
                  subtitle: 'Merge multiple PDFs, split pages, encrypt with password & watermark',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PdfToolsScreen()),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.share_outlined,
                  title: 'Share & Export',
                  subtitle: 'Send scanned documents via email, messaging, or system drive',
                  isDark: isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sharing is integrated inside every document card and viewer.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 3. Specialized Capture Modes Section
            _buildSectionHeader(
              'Specialized Capture Modes',
              'Direct access to camera capture workflows',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildCardGroup(
              isDark: isDark,
              children: [
                _buildToolTile(
                  icon: Icons.burst_mode_rounded,
                  title: 'Batch Scanning',
                  subtitle:
                      'Continuous rapid multi-page capture with live counter',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ContinuousCameraScreen(mode: ScanMode.batch),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.badge_outlined,
                  title: 'ID Card 2-in-1',
                  subtitle:
                      'Scan front and back sides onto a single formatted page',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ContinuousCameraScreen(mode: ScanMode.idCard),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.quiz_outlined,
                  title: 'Q&A / Exam Mode',
                  subtitle:
                      'Structured capture for question sets and worksheets',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContinuousCameraScreen(
                          mode: ScanMode.questionSet,
                        ),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Book Mode',
                  subtitle:
                      'Scan open book spreads with curve flattening guidance',
                  isDark: isDark,
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
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.co_present_outlined,
                  title: 'Whiteboard',
                  subtitle: 'Capture meeting boards with glare elimination',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContinuousCameraScreen(
                          mode: ScanMode.whiteboard,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 4. Upcoming Platform Integrations Section
            _buildSectionHeader(
              'Upcoming Platform Integrations',
              'Features scheduled in the Scaneliq Master Blueprint roadmap',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildCardGroup(
              isDark: isDark,
              children: [
                _buildToolTile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Cloud Backup & Multi-device Sync',
                  subtitle: 'Zero-knowledge encrypted cloud backup and cross-device sync',
                  isDark: isDark,
                  trailing: _buildComingSoonBadge(isDark),
                  onTap: null,
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.draw_outlined,
                  title: 'E-Signature & Annotations',
                  subtitle: 'Freehand signatures, stamp overlays, and page annotations',
                  isDark: isDark,
                  trailing: _buildComingSoonBadge(isDark),
                  onTap: null,
                ),
                _buildDivider(isDark),
                _buildToolTile(
                  icon: Icons.table_chart_outlined,
                  title: 'Table & Expense Extraction',
                  subtitle: 'Receipt ledger parsing and CSV spreadsheet export',
                  isDark: isDark,
                  trailing: _buildComingSoonBadge(isDark),
                  onTap: null,
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGroup({
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface1Dark : AppColors.surface0Light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.brandLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? AppColors.brandLight : AppColors.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 70,
      endIndent: 14,
      color: isDark
          ? AppColors.borderDark.withValues(alpha: 0.5)
          : AppColors.borderLight.withValues(alpha: 0.7),
    );
  }

  Widget _buildComingSoonBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Coming soon',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
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

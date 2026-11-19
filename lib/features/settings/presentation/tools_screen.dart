import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_overlays.dart';
import 'package:scaneliq/features/intelligence/presentation/ai_document_sheet.dart';
import 'package:scaneliq/features/intelligence/presentation/business_card_dialog.dart';
import 'package:scaneliq/features/intelligence/presentation/receipt_dialog.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';
import 'package:scaneliq/features/pdf/presentation/pdf_tools_screen.dart';
import 'package:scaneliq/features/scanner/presentation/continuous_camera_screen.dart';
import 'package:scaneliq/features/scanner/presentation/count_cam_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_code_screen.dart';
import 'package:scaneliq/features/scanner/presentation/translate_screen.dart';

/// Concept A (Editorial Gallery Minimal) consolidated PDF Suite & Productivity Hub (Tab 3).
///
/// Unifies Organize, Edit, Optimize, Convert, OCR, and Document Intelligence workflows
/// with honest disclosure badges for planned/beta capabilities.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _isProcessingOcr = false;

  Future<void> _runDirectOcrOnPickedFile() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (pickedFiles.isNotEmpty && pickedFiles.first.path != null) {
        if (!mounted) return;

        final chosenScript = await showScaneliqBottomSheet<OcrScript>(
          context: context,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Recognition Script',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              ScaneliqContextMenuRow(
                icon: Icons.language_rounded,
                title: 'English / Latin',
                subtitle: 'Latin alphabet documents (Active on-device)',
                trailing: const ScaneliqStatusLabel(
                  text: 'ACTIVE',
                  tone: ScaneliqStatusTone.success,
                ),
                onTap: () => Navigator.pop(ctx, OcrScript.latin),
              ),
              ScaneliqContextMenuRow(
                icon: Icons.translate_rounded,
                title: 'Bengali (বাংলা)',
                subtitle: 'Offline Tesseract Bengali script engine',
                trailing: const ScaneliqStatusLabel(
                  text: 'OFFLINE BN',
                  tone: ScaneliqStatusTone.success,
                ),
                onTap: () => Navigator.pop(ctx, OcrScript.bengali),
              ),
              ScaneliqContextMenuRow(
                icon: Icons.spellcheck_rounded,
                title: 'Mixed বাংলা + English',
                subtitle: 'Offline bilingual ben+eng recognition',
                trailing: const ScaneliqStatusLabel(
                  text: 'BN + EN',
                  tone: ScaneliqStatusTone.accent,
                ),
                onTap: () => Navigator.pop(ctx, OcrScript.mixedBengaliEnglish),
              ),
              ScaneliqContextMenuRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Devanagari (Hindi / Nepali)',
                subtitle: 'Devanagari script recognition',
                onTap: () => Navigator.pop(ctx, OcrScript.devanagari),
              ),
            ],
          ),
        );

        if (chosenScript == null) return;

        setState(() {
          _isProcessingOcr = true;
        });

        final file = File(pickedFiles.first.path!);
        final ocrResult = await OcrService.instance.extractPageOcr(
          file,
          script: chosenScript,
        );

        setState(() {
          _isProcessingOcr = false;
        });

        if (mounted) {
          _showTextResultSheet(ocrResult);
        }
      }
    } catch (e) {
      setState(() => _isProcessingOcr = false);
      if (mounted) {
        showScaneliqToast(context, 'OCR Failed: $e');
      }
    }
  }

  void _showTextResultSheet(PageOcrResult ocrResult) {
    final editController = TextEditingController(
      text: ocrResult.fullText.trim().isEmpty
          ? 'No text detected in this image.'
          : ocrResult.fullText,
    );
    final table = OcrTableExtractor.extract(ocrResult);

    showScaneliqBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Extracted & Editable Text',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: editController.text));
                  Navigator.pop(ctx);
                  showScaneliqToast(context, 'Copied text to clipboard.');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: TextField(
              controller: editController,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined, size: 17),
                label: const Text('Export .TXT'),
                onPressed: () async {
                  final f = await OcrService.instance.exportTextFile(
                    content: editController.text,
                    baseName: 'OCR_${DateTime.now().millisecondsSinceEpoch}',
                    extension: 'txt',
                  );
                  if (mounted) {
                    showScaneliqToast(context, 'Saved ${f.path.split(Platform.pathSeparator).last}');
                  }
                },
              ),
              if (!table.isEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 17),
                  label: const Text('Export Table CSV'),
                  onPressed: () async {
                    final f = await OcrService.instance.exportTextFile(
                      content: table.toCsv(),
                      baseName: 'Table_${DateTime.now().millisecondsSinceEpoch}',
                      extension: 'csv',
                    );
                    if (mounted) {
                      showScaneliqToast(context, 'Exported ${f.path.split(Platform.pathSeparator).last}');
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPdfTool([PdfToolAction? action]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfToolsScreen(initialAction: action)),
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
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            ScaneliqSpacing.headerVerticalTop,
            horizontalPad,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Editorial PDF Suite Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('PDF Suite', style: textTheme.headlineLarge),
                ),
                const ScaneliqStatusLabel(
                  text: '100% ON-DEVICE',
                  tone: ScaneliqStatusTone.accent,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. ORGANIZE
            const ScaneliqSectionHeader(
              title: 'Organize',
              trailing: ScaneliqStatusLabel(text: 'IMPLEMENTED'),
            ),
            _SuiteHairlineRow(
              icon: Icons.call_merge_rounded,
              title: 'Merge PDF',
              subtitle: 'Combine multiple PDF documents into one ordered file',
              badge: 'MERGE',
              onTap: () => _openPdfTool(PdfToolAction.mergePdfs),
            ),
            _SuiteHairlineRow(
              icon: Icons.call_split_rounded,
              title: 'Split PDF',
              subtitle: 'Split into single pages or partition by custom ranges',
              badge: 'SPLIT',
              onTap: () => _openPdfTool(PdfToolAction.splitSinglePages),
            ),
            _SuiteHairlineRow(
              icon: Icons.dashboard_customize_outlined,
              title: 'Reorder & Delete Pages',
              subtitle: 'Organize, duplicate, insert, or remove individual PDF pages',
              badge: 'ORGANIZE',
              onTap: () => _openPdfTool(PdfToolAction.organizePages),
            ),
            _SuiteHairlineRow(
              icon: Icons.file_upload_outlined,
              title: 'Extract Pages',
              subtitle: 'Save custom page ranges (e.g. 1-3, 5) into a new PDF',
              badge: 'EXTRACT',
              onTap: () => _openPdfTool(PdfToolAction.extractPages),
            ),

            const SizedBox(height: 22),

            // 2. EDIT & PROTECT
            const ScaneliqSectionHeader(title: 'Edit & Protect'),
            _SuiteHairlineRow(
              icon: Icons.rotate_right_rounded,
              title: 'Rotate PDF Pages',
              subtitle: 'Inspect thumbnails and rotate individual or all pages 90°',
              badge: 'ROTATE',
              onTap: () => _openPdfTool(PdfToolAction.organizePages),
            ),
            _SuiteHairlineRow(
              icon: Icons.draw_outlined,
              title: 'Annotate & Add Signature',
              subtitle: 'Place approval stamps, text notes, and signature overlays',
              badge: 'SIGN',
              onTap: () => _openPdfTool(PdfToolAction.annotatePdf),
            ),
            _SuiteHairlineRow(
              icon: Icons.branding_watermark_outlined,
              title: 'Add Watermark',
              subtitle: 'Overlay CONFIDENTIAL, DRAFT, or custom diagonal text',
              badge: 'MARK',
              onTap: () => _openPdfTool(PdfToolAction.watermarkPdf),
            ),
            _SuiteHairlineRow(
              icon: Icons.lock_outline_rounded,
              title: 'Password Lock & Sanitizer',
              subtitle: 'AES-256 encryption, unlock PDF, or blackout sensitive areas',
              badge: 'AES-256',
              tone: ScaneliqStatusTone.accent,
              onTap: () => _openPdfTool(PdfToolAction.encryptPdf),
            ),

            const SizedBox(height: 22),

            // 3. OPTIMIZE & CONVERT
            const ScaneliqSectionHeader(title: 'Optimize & Convert'),
            _SuiteHairlineRow(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              subtitle: 'Reduce file size with High Quality, Balanced, or Compact presets',
              badge: 'COMPRESS',
              tone: ScaneliqStatusTone.success,
              onTap: () => _openPdfTool(PdfToolAction.compressPdf),
            ),
            _SuiteHairlineRow(
              icon: Icons.photo_camera_back_outlined,
              title: 'Image to PDF Scan',
              subtitle: 'Capture or import images and export clean A4 searchable PDF',
              badge: 'JPG → PDF',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ContinuousCameraScreen(mode: ScanMode.document),
                  ),
                );
              },
            ),
            _SuiteHairlineRow(
              icon: Icons.view_stream_outlined,
              title: 'Stitch to Long Image',
              subtitle: 'Join multi-page receipts or bills into a continuous vertical JPEG',
              badge: 'STITCH',
              onTap: () => _openPdfTool(PdfToolAction.stitchLongImage),
            ),
            _SuiteHairlineRow(
              icon: Icons.info_outline_rounded,
              title: 'Inspect PDF Properties',
              subtitle: 'Check page dimensions, file size, and encryption flags',
              badge: 'INSPECT',
              onTap: () => _openPdfTool(PdfToolAction.inspectPdf),
            ),

            const SizedBox(height: 22),

            // 4. PRODUCTIVITY & OCR TOOLS (Preserved Group Title & Keys)
            const ScaneliqSectionHeader(
              title: 'Productivity & OCR Tools',
              trailing: ScaneliqStatusLabel(
                text: 'OCR & AI',
                tone: ScaneliqStatusTone.accent,
              ),
            ),
            _SuiteHairlineRow(
              icon: Icons.document_scanner_outlined,
              title: 'Instant Image OCR',
              subtitle: 'Extract selectable text from any image file on your phone',
              badge: _isProcessingOcr ? 'RUNNING…' : 'OCR',
              tone: ScaneliqStatusTone.accent,
              onTap: _isProcessingOcr ? null : _runDirectOcrOnPickedFile,
            ),
            _SuiteHairlineRow(
              icon: Icons.qr_code_scanner_rounded,
              title: 'QR & Barcode Scanner',
              subtitle: 'Instant code detection, URL open, and clipboard copy',
              badge: 'QR',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanCodeScreen()),
                );
              },
            ),
            _SuiteHairlineRow(
              icon: Icons.translate_rounded,
              title: 'Translate Lens',
              subtitle: 'Offline ML Kit En ↔ Bn models + optional online translation',
              badge: 'OFFLINE / EN-BN',
              tone: ScaneliqStatusTone.success,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TranslateScreen()),
                );
              },
            ),
            _SuiteHairlineRow(
              icon: Icons.calculate_outlined,
              title: 'CountCam',
              subtitle: 'ML Kit object detector + dense item cluster counter with tap pins',
              badge: 'OBJECT AI',
              tone: ScaneliqStatusTone.success,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CountCamScreen()),
                );
              },
            ),
            _SuiteHairlineRow(
              icon: Icons.contact_mail_outlined,
              title: 'Business Card Reader',
              subtitle: 'Extract contact details and export standard vCard (.vcf)',
              badge: 'VCARD',
              onTap: () => BusinessCardDialog.show(context),
            ),
            _SuiteHairlineRow(
              icon: Icons.receipt_long_outlined,
              title: 'Receipt & Invoice Scanner',
              subtitle: 'Extract totals, VAT/tax math check & CSV spreadsheet export',
              badge: 'CSV',
              tone: ScaneliqStatusTone.success,
              onTap: () => ReceiptDialog.show(context),
            ),
            _SuiteHairlineRow(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Document Summary & Q&A',
              subtitle: '100% offline TextRank executive summary and TF-IDF citations',
              badge: 'OFFLINE AI',
              onTap: () => AiDocumentSheet.show(context),
            ),
            _SuiteHairlineRow(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF Productivity Tools',
              subtitle: 'Open complete PDF manipulation, encryption & watermark workbench',
              badge: 'ALL TOOLS',
              tone: ScaneliqStatusTone.accent,
              onTap: () => _openPdfTool(),
            ),
            _SuiteHairlineRow(
              icon: Icons.ios_share_rounded,
              title: 'Share & Export',
              subtitle: 'Export unwatermarked PDFs or text inside any document sheet',
              badge: 'EXPORT',
              onTap: () => showScaneliqToast(
                context,
                'Sharing is integrated inside every document row and viewer.',
              ),
            ),

            const SizedBox(height: 22),

            // 5. PLANNED / UNAVAILABLE INTEGRATIONS (Clearly Distinguished)
            const ScaneliqSectionHeader(
              title: 'Upcoming Platform Integrations',
              trailing: ScaneliqStatusLabel(
                text: 'PLANNED',
                tone: ScaneliqStatusTone.warning,
              ),
            ),
            const _SuiteHairlineRow(
              icon: Icons.table_chart_outlined,
              title: 'PDF to Word / Excel Conversion',
              subtitle: 'Not yet available in this local-first release',
              badge: 'UNAVAILABLE',
              tone: ScaneliqStatusTone.warning,
              onTap: null,
            ),
            const _SuiteHairlineRow(
              icon: Icons.cloud_sync_outlined,
              title: 'Cloud Backup & Multi-device Sync',
              subtitle: 'Remote Drive AppData & WebDAV sync transport scheduled',
              badge: 'PLANNED',
              tone: ScaneliqStatusTone.warning,
              onTap: null,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SuiteHairlineRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final ScaneliqStatusTone tone;
  final VoidCallback? onTap;

  const _SuiteHairlineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.tone = ScaneliqStatusTone.neutral,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.62,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.hairline, width: 1),
            ),
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
      ),
    );
  }
}

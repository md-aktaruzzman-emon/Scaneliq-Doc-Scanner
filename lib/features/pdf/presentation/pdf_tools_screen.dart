import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';
import 'package:share_plus/share_plus.dart';

class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

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
        _statusMessage = 'Encrypting PDF...';
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
      final enteredText = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add PDF Watermark'),
          content: TextField(
            controller: watermarkController,
            decoration: const InputDecoration(
              labelText: 'Watermark Text',
              hintText: 'e.g. CONFIDENTIAL / COPY',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, watermarkController.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        ),
      );

      if (enteredText == null || enteredText.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Applying watermark...';
      });

      final watermarkedFile = await AdvancedPdfService.instance.addWatermark(
        sourcePdf: file,
        watermarkText: enteredText,
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

  void _showSuccessDialog(String title, File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('File created:\n${file.path}'),
        actions: [
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
              const Text(
                'Professional Document Operations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                icon: Icons.call_merge,
                color: Colors.blue,
                title: 'Merge PDFs',
                subtitle: 'Combine 2 or more PDF documents into a single consolidated file',
                onTap: _isProcessing ? null : _mergePdfs,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                icon: Icons.call_split,
                color: Colors.orange,
                title: 'Split PDF into Pages',
                subtitle: 'Deconstruct a multi-page PDF into independent single-page files',
                onTap: _isProcessing ? null : _splitPdf,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                icon: Icons.lock,
                color: Colors.green,
                title: 'Password Encryption',
                subtitle:
                    'Protect sensitive documents with AES-256 bit encryption',
                onTap: _isProcessing ? null : _encryptPdf,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                icon: Icons.branding_watermark,
                color: Colors.purple,
                title: 'Add Watermark',
                subtitle: 'Overlay diagonal watermarks (e.g. CONFIDENTIAL) on all pages',
                onTap: _isProcessing ? null : _watermarkPdf,
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
        contentPadding: const EdgeInsets.all(16),
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

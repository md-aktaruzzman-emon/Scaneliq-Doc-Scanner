import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

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
          _extractedText = text.trim().isEmpty ? 'No text detected in this image.' : text;
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
          SnackBar(content: Text('OCR Failed: $e'), backgroundColor: AppColors.error),
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
          child: SingleChildScrollView(
            child: SelectableText(text),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Tools', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Productivity & OCR Tools',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.document_scanner, color: AppColors.brandPrimary),
              ),
              title: const Text('Instant Image OCR', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Extract selectable text from any image file on your phone'),
              trailing: _isProcessingOcr
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isProcessingOcr ? null : _runDirectOcrOnPickedFile,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share, color: Colors.green),
              ),
              title: const Text('Share & Export', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Send scanned documents via email, messaging, or system drive'),
              trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share is integrated directly inside every document view.')),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Roadmap Features',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).cardColor.withValues(alpha: 0.6),
            child: const ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Icon(Icons.lock_outline, color: Colors.grey),
              title: Text('PDF Encryption & Password', style: TextStyle(color: Colors.grey)),
              subtitle: Text('Phase 7 — Secure password-protected PDF exports', style: TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).cardColor.withValues(alpha: 0.6),
            child: const ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Icon(Icons.cloud_sync_outlined, color: Colors.grey),
              title: Text('Cloud Backup & Multi-device Sync', style: TextStyle(color: Colors.grey)),
              subtitle: Text('Phase 8 — Privacy-preserving optional cloud sync', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}

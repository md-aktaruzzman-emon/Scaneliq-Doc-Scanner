import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/intelligence/data/business_card_service.dart';

class BusinessCardDialog extends StatefulWidget {
  final File? initialImage;

  const BusinessCardDialog({super.key, this.initialImage});

  static Future<void> show(BuildContext context, {File? imageFile}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BusinessCardDialog(initialImage: imageFile),
    );
  }

  @override
  State<BusinessCardDialog> createState() => _BusinessCardDialogState();
}

class _BusinessCardDialogState extends State<BusinessCardDialog> {
  bool _isProcessing = false;
  BusinessCardContact? _contact;

  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _webCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _processImage(widget.initialImage!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _titleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _webCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked.isNotEmpty && picked.first.path != null) {
      _processImage(File(picked.first.path!));
    }
  }

  Future<void> _processImage(File file) async {
    setState(() => _isProcessing = true);
    try {
      final contact = await BusinessCardService.instance.extractFromImage(file);
      setState(() {
        _contact = contact;
        _nameCtrl.text = contact.name;
        _companyCtrl.text = contact.company;
        _titleCtrl.text = contact.jobTitle;
        _phoneCtrl.text = contact.phone;
        _emailCtrl.text = contact.email;
        _webCtrl.text = contact.website;
        _addressCtrl.text = contact.address;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read business card: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportVCard() async {
    final updatedContact = BusinessCardContact(
      name: _nameCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      jobTitle: _titleCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _webCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );

    try {
      final vcfFile = await BusinessCardService.instance.exportVCardFile(
        updatedContact,
      );
      if (mounted) {
        SharePlus.instance.share(
          ShareParams(
            files: [XFile(vcfFile.path)],
            text: 'Contact: ${updatedContact.name}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surface1Dark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_mail_outlined,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Business Card Reader',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing business card & extracting contact fields...',
                  ),
                ],
              ),
            )
          else if (_contact == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a photo of a business card to extract info',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Card Image'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company / Organization',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Job Title',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Website / URL',
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Pick Another'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportVCard,
                          icon: const Icon(Icons.share),
                          label: const Text('Export vCard (.vcf)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';
import 'package:scaneliq/features/documents/presentation/trash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = AppStorageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Branding & About Header
          _buildSectionHeader('Branding & About', isDark),
          const SizedBox(height: 8),

          // Brand Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ScaneliqLogo(size: 52, borderRadius: 12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scaneliq',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Scan documents. Keep everything organized.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Version 1.0.0 (Production Architecture)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Privacy & Storage Policy
          _buildSectionHeader('Privacy & Storage Policy', isDark),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Local-First Document Safety',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Scans stay in app-private storage. No automatic uploads or tracking.',
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_special_rounded,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'App Storage Paths',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Exports: ${storage.exportsDir.path}\nOriginals: ${storage.originalsDir.path}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_sweep_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Trash & Recovery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'View soft-deleted documents with 30-day retention.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Supported OCR Languages
          _buildSectionHeader('Supported OCR Languages', isDark),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'English & Latin Scripts (Active)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Bangla OCR support architecture ready via benchmark interface.',
                  ),
                  trailing: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scan Quality & Preferences
          _buildSectionHeader('Scan & PDF Preferences', isDark),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Default Page Format'),
                  subtitle: Text('ISO A4 (210 × 297 mm)'),
                  trailing: Chip(
                    label: Text('A4', style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                const ListTile(
                  leading: Icon(Icons.crop_rotate_outlined),
                  title: Text('Auto-Crop & Edge Detection'),
                  subtitle: Text('Google ML Kit on-device boundary detection'),
                  trailing: Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Open Source Licenses'),
                  subtitle: const Text('View software third-party licenses'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Scaneliq',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: ScaneliqLogo(size: 48),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }
}

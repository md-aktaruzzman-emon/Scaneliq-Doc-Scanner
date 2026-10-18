import 'package:flutter/material.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = AppStorageService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Branding & About',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ScaneliqLogo(size: 72, borderRadius: 16),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scaneliq',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Scan documents. Keep everything organized.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Version 1.0.0 (Production Architecture)',
                          style: TextStyle(
                            fontSize: 12,
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
          const Text(
            'Privacy & Storage Policy',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.security, color: AppColors.success),
                  title: Text('Local-First Document Safety'),
                  subtitle: Text(
                    'Scans stay in app-private storage. No automatic uploads or tracking.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.folder_special,
                    color: AppColors.brandPrimary,
                  ),
                  title: const Text('App Storage Paths'),
                  subtitle: Text(
                    'Exports: ${storage.exportsDir.path}\nOriginals: ${storage.originalsDir.path}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Supported OCR Languages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.translate, color: AppColors.brandDeep),
              title: Text('English & Latin Scripts (Active)'),
              subtitle: Text(
                'Bangla OCR support architecture ready via benchmark interface.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

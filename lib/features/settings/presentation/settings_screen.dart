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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Branding & About Header
          _buildSectionHeader('Branding & About', isDark),
          const SizedBox(height: 10),

          // Brand Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface1Dark : AppColors.surface0Light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surface2Dark
                              : AppColors.brandLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Privacy & Storage Policy
          _buildSectionHeader('Privacy & Storage Policy', isDark),
          const SizedBox(height: 10),

          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.security_rounded,
                iconColor: AppColors.success,
                title: 'Local-First Document Safety',
                subtitle:
                    'Scans stay in app-private storage. No automatic uploads or tracking.',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.folder_special_rounded,
                iconColor: AppColors.brandPrimary,
                title: 'App Storage Paths',
                subtitle:
                    'Private on-device sandbox · Tap to view directory details',
                isDark: isDark,
                trailing: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Storage Locations'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exports Directory:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            storage.exportsDir.path,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Originals Directory:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            storage.originalsDir.path,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.auto_delete_outlined,
                iconColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                title: 'Trash & Recovery',
                subtitle:
                    'View soft-deleted documents with 30-day retention.',
                isDark: isDark,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrashScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Supported OCR Languages
          _buildSectionHeader('Supported OCR Languages', isDark),
          const SizedBox(height: 10),

          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.translate_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'English & Latin Scripts (Active)',
                subtitle:
                    'On-device ML Kit text recognition with offline Bangla support architecture.',
                isDark: isDark,
                trailing: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Scan Quality & Preferences
          _buildSectionHeader('Scan & PDF Preferences', isDark),
          const SizedBox(height: 10),

          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.palette_outlined,
                iconColor: AppColors.brandPrimary,
                title: 'Theme Mode',
                subtitle: 'System default (follows device appearance)',
                isDark: isDark,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surface2Dark
                        : AppColors.surface2Light,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDark ? 'Dark' : 'Light',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.picture_as_pdf_outlined,
                iconColor: AppColors.brandPrimary,
                title: 'Default Page Format',
                subtitle: 'ISO A4 (210 × 297 mm)',
                isDark: isDark,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surface2Dark
                        : AppColors.surface2Light,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'A4',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.crop_rotate_outlined,
                iconColor: AppColors.brandPrimary,
                title: 'Auto-Crop & Edge Detection',
                subtitle: 'Google ML Kit on-device boundary detection',
                isDark: isDark,
                trailing: const Icon(
                  Icons.check,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.brandPrimary,
                title: 'Open Source Licenses',
                subtitle: 'View software third-party licenses',
                isDark: isDark,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
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

          const SizedBox(height: 24),
        ],
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

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 14,
      color: isDark
          ? AppColors.borderDark.withValues(alpha: 0.5)
          : AppColors.borderLight.withValues(alpha: 0.7),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}

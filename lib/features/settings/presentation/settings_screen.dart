import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';
import 'package:scaneliq/features/cloud_sync/data/cloud_backup_service.dart';
import 'package:scaneliq/features/cloud_sync/data/device_sync_service.dart';
import 'package:scaneliq/features/documents/presentation/trash_screen.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:scaneliq/features/security/presentation/app_lock_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppLockService _lockService = AppLockService.instance;
  final CloudBackupService _backupService = CloudBackupService.instance;
  final DeviceSyncService _syncService = DeviceSyncService.instance;

  bool _isLockEnabled = false;
  bool _isBiometricsEnabled = false;
  bool _canUseBiometrics = false;
  int _timeoutSeconds = 0;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityState();
  }

  Future<void> _loadSecurityState() async {
    await _lockService.init();
    final canBio = await _lockService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _isLockEnabled = _lockService.isAppLockEnabled;
        _isBiometricsEnabled = _lockService.isBiometricsEnabled;
        _timeoutSeconds = _lockService.lockTimeoutSeconds;
        _canUseBiometrics = canBio;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // Prompt to set PIN
      final success = await AppLockDialog.showSetPin(context);
      if (success) {
        _loadSecurityState();
      }
    } else {
      // Prompt to verify current PIN before disabling
      final verified = await AppLockDialog.showVerifyCurrent(context);
      if (verified) {
        await _lockService.disableAppLock();
        _loadSecurityState();
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    await _lockService.setBiometricsEnabled(value);
    _loadSecurityState();
  }

  Future<void> _changePin() async {
    final verified = await AppLockDialog.showVerifyCurrent(context);
    if (verified && mounted) {
      await AppLockDialog.showSetPin(context);
      _loadSecurityState();
    }
  }

  Future<void> _selectTimeout() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-Lock Timeout'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Immediately (when app closes)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 60),
            child: const Text('After 1 minute'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 300),
            child: const Text('After 5 minutes'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _lockService.setTimeoutSeconds(selected);
      _loadSecurityState();
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final file = await _backupService.createBackupArchive();
      setState(() => _isBackingUp = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup archive created: ${file.path.split('/').last.split('\\').last}',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Scaneliq Database & Documents Backup',
          ),
        );
      }
    } catch (e) {
      setState(() => _isBackingUp = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['scaneliq', 'zip'],
    );

    if (picked.isEmpty || picked.first.path == null) return;
    final file = File(picked.first.path!);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup Archive'),
        content: const Text(
          'This will import all documents, folders, tags, and pages from the backup package non-destructively. Existing documents will not be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _backupService.restoreBackupArchive(file);
    if (!mounted) return;

    if (result.success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Completed'),
          content: Text(
            'Successfully restored ${result.restoredDocuments} documents and ${result.restoredFolders} folders.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Restore failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openSyncModal() async {
    final deviceId = await _syncService.getDeviceId();
    final deviceName = await _syncService.getDeviceName();
    final lastSync = await _syncService.getLastSyncTime();
    final nameCtrl = TextEditingController(text: deviceName);
    final passCtrl = TextEditingController();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface1Dark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sync_lock_rounded,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Encrypted Multi-Device Sync (E2EE)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Device ID: ${deviceId.substring(0, 8)}... (UUIDv4)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (lastSync != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last Synced: ${lastSync.toLocal().toString().split('.').first}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _syncService.setDeviceName(val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'End-to-End Encryption Passphrase',
                    hintText: 'Must match across your devices',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Export Package'),
                        onPressed: () async {
                          if (passCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a passphrase'),
                              ),
                            );
                            return;
                          }
                          try {
                            final env = await _syncService
                                .createEncryptedEnvelope(
                                  encryptionPassphrase: passCtrl.text,
                                );
                            final jsonStr = jsonEncode(env.toJson());
                            final tempFile = File(
                              '${AppStorageService.instance.exportsDir.path}/SyncEnvelope_${DateTime.now().millisecondsSinceEpoch}.json',
                            );
                            await tempFile.writeAsString(jsonStr);
                            if (sheetCtx.mounted) {
                              SharePlus.instance.share(
                                ShareParams(
                                  files: [XFile(tempFile.path)],
                                  text: 'Scaneliq Encrypted Sync Package',
                                ),
                              );
                            }
                          } catch (e) {
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text('Export error: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Import Package'),
                        onPressed: () async {
                          if (passCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Enter passphrase first'),
                              ),
                            );
                            return;
                          }
                          final picked = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );
                          if (picked.isEmpty || picked.first.path == null) {
                            return;
                          }
                          try {
                            final file = File(picked.first.path!);
                            final content = await file.readAsString();
                            final envMap =
                                jsonDecode(content) as Map<String, dynamic>;
                            final env = EncryptedSyncEnvelope.fromJson(envMap);
                            final merged = await _syncService
                                .processIncomingEnvelope(
                                  envelope: env,
                                  decryptionPassphrase: passCtrl.text,
                                );
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Merged $merged documents & folders!',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                  content: Text('Import failed: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
                subtitle: 'Scans stay in app-private storage. No automatic uploads or tracking.',
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
                subtitle: 'View soft-deleted documents with 30-day retention.',
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
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
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
                subtitle: 'On-device ML Kit text recognition with offline Bangla support architecture.',
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

          // Security & App Lock (F-46)
          _buildSectionHeader('Security & App Lock', isDark),
          const SizedBox(height: 10),
          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.brandPrimary,
                title: 'App Lock (PIN)',
                subtitle: _isLockEnabled
                    ? 'Protected with 4-digit security PIN'
                    : 'Lock Scaneliq with a PIN code',
                isDark: isDark,
                trailing: Switch(
                  value: _isLockEnabled,
                  onChanged: _toggleAppLock,
                ),
              ),
              if (_isLockEnabled && _canUseBiometrics) ...[
                _buildDivider(isDark),
                _buildSettingTile(
                  icon: Icons.fingerprint_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Biometric Unlock',
                  subtitle: 'Use fingerprint or facial recognition',
                  isDark: isDark,
                  trailing: Switch(
                    value: _isBiometricsEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                ),
              ],
              if (_isLockEnabled) ...[
                _buildDivider(isDark),
                _buildSettingTile(
                  icon: Icons.password_rounded,
                  iconColor: AppColors.brandPrimary,
                  title: 'Change PIN',
                  subtitle: 'Update your 4-digit security code',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  onTap: _changePin,
                ),
                _buildDivider(isDark),
                _buildSettingTile(
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.brandPrimary,
                  title: 'Auto-Lock Timeout',
                  subtitle: _timeoutSeconds == 0
                      ? 'Immediately on exit'
                      : 'After ${_timeoutSeconds ~/ 60} min',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  onTap: _selectTimeout,
                ),
              ],
            ],
          ),

          const SizedBox(height: 22),

          // Cloud Backup & Multi-Device Sync (F-42, F-43)
          _buildSectionHeader('Cloud Backup & Multi-Device Sync', isDark),
          const SizedBox(height: 10),
          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.cloud_upload_outlined,
                iconColor: const Color(0xFF0284C7),
                title: 'Create Backup Archive (.scaneliq)',
                subtitle: _isBackingUp ? 'Packaging database & documents...' : 'Export complete ZIP backup package with SHA-256 verification',
                isDark: isDark,
                trailing: _isBackingUp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                onTap: _isBackingUp ? null : _createBackup,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.cloud_download_outlined,
                iconColor: const Color(0xFF0284C7),
                title: 'Restore Backup Archive',
                subtitle:
                    'Import documents from .scaneliq backup non-destructively',
                isDark: isDark,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                onTap: _restoreBackup,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.sync_lock_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Encrypted Multi-Device Sync (E2EE)',
                subtitle: 'Peer-to-peer sync with AES-256 passphrase & LWW conflict resolution',
                isDark: isDark,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                onTap: _openSyncModal,
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
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

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
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
            content: Text('Backup archive created: ${p.basename(file.path)}'),
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text('Settings', style: textTheme.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tokens.hairline),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branding & About Header
            const ScaneliqSectionHeader(
              title: 'Branding & About',
              trailing: ScaneliqStatusLabel(text: 'v1.0.0+1'),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: ScaneliqRadius.folioBorderRadius,
                border: Border.all(color: tokens.hairline),
              ),
              child: Row(
                children: [
                  const ScaneliqLogo(size: 48, borderRadius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scaneliq', style: textTheme.headlineMedium),
                        const SizedBox(height: 3),
                        Text(
                          'Scan documents. Keep everything organized.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        const ScaneliqStatusLabel(
                          text: 'LOCAL-FIRST EDITION',
                          tone: ScaneliqStatusTone.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Appearance & Theme (Live Connected to themeModeProvider)
            const ScaneliqSectionHeader(
              title: 'Appearance',
              trailing: ScaneliqStatusLabel(
                text: 'PERSISTENT',
                tone: ScaneliqStatusTone.accent,
              ),
            ),
            const SizedBox(height: 8),
            const _ThemeModeSelectorCard(),

            const SizedBox(height: 22),

            // Security & App Lock (F-46)
            const ScaneliqSectionHeader(
              title: 'Security & App Lock',
              trailing: ScaneliqStatusLabel(text: 'PBKDF2 · 100K'),
            ),
            _buildHairlineSettingRow(
              icon: Icons.lock_outline_rounded,
              title: 'App Lock (PIN)',
              subtitle: _isLockEnabled
                  ? 'Protected with full-screen security PIN'
                  : 'Lock Scaneliq with a PIN code',
              trailing: Switch(
                value: _isLockEnabled,
                onChanged: _toggleAppLock,
              ),
            ),
            if (_isLockEnabled && _canUseBiometrics)
              _buildHairlineSettingRow(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric Unlock',
                subtitle: 'Use fingerprint or facial recognition',
                trailing: Switch(
                  value: _isBiometricsEnabled,
                  onChanged: _toggleBiometrics,
                ),
              ),
            if (_isLockEnabled) ...[
              _buildHairlineSettingRow(
                icon: Icons.password_rounded,
                title: 'Change PIN',
                subtitle: 'Update your security PIN code',
                trailing: const ScaneliqStatusLabel(text: 'EDIT'),
                onTap: _changePin,
              ),
              _buildHairlineSettingRow(
                icon: Icons.timer_outlined,
                title: 'Auto-Lock Timeout',
                subtitle: _timeoutSeconds == 0
                    ? 'Immediately on exit'
                    : 'After ${_timeoutSeconds ~/ 60} min',
                trailing: const ScaneliqStatusLabel(text: 'TIMER'),
                onTap: _selectTimeout,
              ),
            ],

            const SizedBox(height: 22),

            // Privacy & Storage Policy
            const ScaneliqSectionHeader(title: 'Privacy & Storage Policy'),
            _buildHairlineSettingRow(
              icon: Icons.security_rounded,
              title: 'Local-First Document Safety',
              subtitle: 'Scans stay in app-private storage. No automatic uploads or tracking.',
              trailing: const ScaneliqStatusLabel(
                text: 'LOCAL',
                tone: ScaneliqStatusTone.success,
              ),
            ),
            _buildHairlineSettingRow(
              icon: Icons.folder_special_outlined,
              title: 'App Storage Paths',
              subtitle:
                  'Private on-device sandbox · Tap to view directory details',
              trailing: const ScaneliqStatusLabel(text: 'PATHS'),
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
                          style: Theme.of(ctx).textTheme.bodySmall,
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
                          style: Theme.of(ctx).textTheme.bodySmall,
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
            _buildHairlineSettingRow(
              icon: Icons.auto_delete_outlined,
              title: 'Trash & Recovery',
              subtitle: 'View soft-deleted documents with 30-day retention.',
              trailing: const ScaneliqStatusLabel(text: '30 DAYS'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
                );
              },
            ),

            const SizedBox(height: 22),

            // Cloud Backup & Local E2EE Sync
            const ScaneliqSectionHeader(
              title: 'Backup & Encrypted Vault Sync',
              trailing: ScaneliqStatusLabel(text: 'AES-256'),
            ),
            _buildHairlineSettingRow(
              icon: Icons.cloud_upload_outlined,
              title: 'Create Backup Archive (.scaneliq)',
              subtitle: _isBackingUp
                  ? 'Packaging database & documents…'
                  : 'Export encrypted backup archive with SHA-256 verification',
              trailing: _isBackingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const ScaneliqStatusLabel(
                      text: 'EXPORT',
                      tone: ScaneliqStatusTone.accent,
                    ),
              onTap: _isBackingUp ? null : _createBackup,
            ),
            _buildHairlineSettingRow(
              icon: Icons.cloud_download_outlined,
              title: 'Restore Backup Archive',
              subtitle:
                  'Import documents from .scaneliq archive non-destructively',
              trailing: const ScaneliqStatusLabel(text: 'RESTORE'),
              onTap: _restoreBackup,
            ),
            _buildHairlineSettingRow(
              icon: Icons.sync_lock_outlined,
              title: 'Encrypted Sync Envelope (Local E2EE)',
              subtitle:
                  'Offline device sync package (Cloud remote sync planned)',
              trailing: const ScaneliqStatusLabel(text: 'LOCAL E2EE'),
              onTap: _openSyncModal,
            ),

            const SizedBox(height: 22),

            // Supported OCR Languages
            const ScaneliqSectionHeader(title: 'Supported OCR Languages'),
            _buildHairlineSettingRow(
              icon: Icons.translate_rounded,
              title: 'English & Latin Scripts (Active)',
              subtitle: 'On-device ML Kit text recognition with Indic/Bangla architecture.',
              trailing: const ScaneliqStatusLabel(
                text: 'ACTIVE',
                tone: ScaneliqStatusTone.success,
              ),
            ),

            const SizedBox(height: 22),

            // Scan & PDF Defaults
            const ScaneliqSectionHeader(title: 'Scan & PDF Preferences'),
            _buildHairlineSettingRow(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Default Page Format',
              subtitle: 'ISO A4 (210 × 297 mm) · Zero watermarks',
              trailing: const ScaneliqStatusLabel(text: 'ISO A4'),
            ),
            _buildHairlineSettingRow(
              icon: Icons.crop_rotate_outlined,
              title: 'Auto-Crop & Edge Detection',
              subtitle: 'Google ML Kit on-device boundary detection',
              trailing: const ScaneliqStatusLabel(
                text: 'ENABLED',
                tone: ScaneliqStatusTone.success,
              ),
            ),
            _buildHairlineSettingRow(
              icon: Icons.verified_outlined,
              title: 'About Scaneliq',
              subtitle: 'Version 1.0.0+1 · com.scaneliq.scaneliq',
              trailing: const ScaneliqStatusLabel(text: 'ABOUT'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Scaneliq',
                  applicationVersion: '1.0.0+1',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: ScaneliqLogo(size: 56, borderRadius: 14),
                  ),
                  applicationLegalese: 'Local-first document scanner & PDF workspace · com.scaneliq.scaneliq',
                );
              },
            ),
            _buildHairlineSettingRow(
              icon: Icons.info_outline_rounded,
              title: 'Open Source Licenses',
              subtitle: 'View software third-party licenses',
              trailing: const ScaneliqStatusLabel(text: 'LICENSES'),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Scaneliq',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ScaneliqLogo(size: 48, borderRadius: 12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHairlineSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
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
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Theme Mode Selector card wired directly to `themeModeProvider`, with a
/// defensive fallback when mounted outside `ProviderScope` in isolated tests.
class _ThemeModeSelectorCard extends StatefulWidget {
  const _ThemeModeSelectorCard();

  @override
  State<_ThemeModeSelectorCard> createState() => _ThemeModeSelectorCardState();
}

class _ThemeModeSelectorCardState extends State<_ThemeModeSelectorCard> {
  ThemeMode _standaloneMode = ThemeMode.system;

  bool _hasProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasProviderScope(context)) {
      return Consumer(
        builder: (ctx, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          return _buildSelector(
            context: ctx,
            currentMode: currentMode,
            onSelect: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
          );
        },
      );
    }

    return _buildSelector(
      context: context,
      currentMode: _standaloneMode,
      onSelect: (mode) => setState(() => _standaloneMode = mode),
    );
  }

  Widget _buildSelector({
    required BuildContext context,
    required ThemeMode currentMode,
    required ValueChanged<ThemeMode> onSelect,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final activeSubtitle = switch (currentMode) {
      ThemeMode.system => 'System Default (Follows device appearance)',
      ThemeMode.light => 'Gallery Alabaster (#FAF9F6)',
      ThemeMode.dark => 'Carbon Studio (#0D0E11)',
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 21, color: tokens.textPrimary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Mode', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(activeSubtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeOptionPill(
                label: 'System Default',
                selected: currentMode == ThemeMode.system,
                onTap: () => onSelect(ThemeMode.system),
              ),
              const SizedBox(width: 8),
              _ThemeOptionPill(
                label: 'Light',
                selected: currentMode == ThemeMode.light,
                onTap: () => onSelect(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOptionPill(
                label: 'Dark',
                selected: currentMode == ThemeMode.dark,
                onTap: () => onSelect(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: Material(
        color: selected ? tokens.accentSoft : tokens.surface,
        borderRadius: ScaneliqRadius.inputBorderRadius,
        child: InkWell(
          borderRadius: ScaneliqRadius.inputBorderRadius,
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: ScaneliqRadius.inputBorderRadius,
              border: Border.all(
                color: selected ? tokens.accent : tokens.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

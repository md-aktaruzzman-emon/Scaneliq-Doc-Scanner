import 'package:flutter/foundation.dart';

/// Build-time compliance and external integration configuration.
///
/// Values are supplied exclusively via `--dart-define` at build/CI time so zero
/// API keys, OAuth client secrets, or commercial license keys are committed.
class AppComplianceConfig {
  AppComplianceConfig._();

  /// Syncfusion license/acknowledgment injected via `--dart-define=SYNCFUSION_LICENSE_KEY=...`
  /// or `--dart-define=SYNCFUSION_LICENSE_ACK=community|commercial`.
  static const String syncfusionLicenseKey = String.fromEnvironment(
    'SYNCFUSION_LICENSE_KEY',
  );
  static const String syncfusionLicenseAck = String.fromEnvironment(
    'SYNCFUSION_LICENSE_ACK',
  );

  /// Optional Google Drive OAuth Server/Android Client ID passed via `--dart-define`.
  static const String googleDriveClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_CLIENT_ID',
  );

  static bool get hasSyncfusionComplianceConfigured =>
      syncfusionLicenseKey.trim().isNotEmpty ||
      syncfusionLicenseAck.trim().isNotEmpty;

  static String get syncfusionComplianceSummary {
    if (syncfusionLicenseKey.trim().isNotEmpty) {
      return 'License key configured via build-time dart-define.';
    }
    if (syncfusionLicenseAck.trim().toLowerCase() == 'community') {
      return 'Community License tier acknowledged (< \$1M annual revenue, < 5 developers).';
    }
    if (syncfusionLicenseAck.trim().toLowerCase() == 'commercial') {
      return 'Commercial Essential Studio license tier acknowledged.';
    }
    return 'Requires Syncfusion Community (< \$1M / < 5 devs) or Commercial license verification before Play Store release.';
  }

  /// Logs non-sensitive build compliance diagnostics in debug mode only.
  static void logStartupDiagnostics() {
    if (kDebugMode && !hasSyncfusionComplianceConfigured) {
      debugPrint(
        '[Scaneliq Compliance] Syncfusion Essential Studio license ack/key not set via --dart-define.',
      );
    }
  }
}

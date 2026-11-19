import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls Android `WindowManager.LayoutParams.FLAG_SECURE` via the native
/// `com.scaneliq.scaneliq/security` MethodChannel to hide app previews from
/// the OS task switcher and block unauthorized screenshots/screen recordings.
class PrivacyShieldService {
  PrivacyShieldService._();
  static final PrivacyShieldService instance = PrivacyShieldService._();

  static const MethodChannel _channel = MethodChannel(
    'com.scaneliq.scaneliq/security',
  );
  static const String _prefFlagSecure = 'privacy_flag_secure_enabled';

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  SharedPreferences? _prefsOverride;

  @visibleForTesting
  void setPreferencesForTesting(SharedPreferences prefs) {
    _prefsOverride = prefs;
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  /// Loads persisted preference and applies `FLAG_SECURE` on startup.
  Future<void> init() async {
    final prefs = await _getPrefs();
    _isEnabled = prefs.getBool(_prefFlagSecure) ?? false;
    await _applyNativeFlag(_isEnabled);
  }

  /// Enables or disables Android screen capture / app switcher preview blocking.
  Future<bool> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await _getPrefs();
    await prefs.setBool(_prefFlagSecure, enabled);
    return _applyNativeFlag(enabled);
  }

  /// Queries the live native `FLAG_SECURE` window state when supported.
  Future<bool> queryNativeFlagState() async {
    try {
      final result = await _channel.invokeMethod<bool>('getFlagSecure');
      if (result != null) {
        _isEnabled = result;
      }
      return _isEnabled;
    } on MissingPluginException {
      return _isEnabled;
    } on PlatformException {
      return _isEnabled;
    }
  }

  Future<bool> _applyNativeFlag(bool enabled) async {
    try {
      final applied = await _channel.invokeMethod<bool>('setFlagSecure', {
        'enabled': enabled,
      });
      return applied ?? enabled;
    } on MissingPluginException {
      // Host VM / desktop unit tests do not mount Android Activity Window.
      return enabled;
    } on PlatformException catch (e) {
      debugPrint('[PrivacyShieldService] Failed to set FLAG_SECURE: $e');
      return _isEnabled;
    }
  }
}

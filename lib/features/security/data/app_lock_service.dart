import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinVerificationResult {
  final bool success;
  final bool isLockedOut;
  final int remainingCooldownSeconds;
  final int remainingAttempts;

  const PinVerificationResult({
    required this.success,
    this.isLockedOut = false,
    this.remainingCooldownSeconds = 0,
    this.remainingAttempts = 5,
  });
}

/// Service providing Biometric & salted PIN app lock security (F-46).
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const String _prefLockEnabled = 'app_lock_enabled';
  static const String _prefBiometricsEnabled = 'app_lock_biometrics_enabled';
  static const String _prefPinHash = 'app_lock_pin_hash';
  static const String _prefPinSalt = 'app_lock_pin_salt';
  static const String _prefTimeoutSeconds = 'app_lock_timeout_seconds';
  static const String _prefFailedAttempts = 'app_lock_failed_attempts';
  static const String _prefLockoutUntilEpoch = 'app_lock_lockout_until_epoch';

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;

  final LocalAuthentication _localAuth = LocalAuthentication();
  SharedPreferences? _prefs;

  DateTime? _lastBackgroundTime;
  bool _isSessionUnlocked = false;

  Future<void> init([SharedPreferences? testPrefs]) async {
    _prefs = testPrefs ?? await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // Status Getters
  // ---------------------------------------------------------------------------

  bool get isAppLockEnabled {
    return _prefs?.getBool(_prefLockEnabled) ?? false;
  }

  bool get isBiometricsEnabled {
    return _prefs?.getBool(_prefBiometricsEnabled) ?? false;
  }

  bool get hasPinSet {
    final hash = _prefs?.getString(_prefPinHash);
    return hash != null && hash.isNotEmpty;
  }

  int get lockTimeoutSeconds {
    return _prefs?.getInt(_prefTimeoutSeconds) ?? 0; // 0 = immediate
  }

  bool get isSessionUnlocked => _isSessionUnlocked;

  void markSessionUnlocked() {
    _isSessionUnlocked = true;
  }

  void markSessionLocked() {
    _isSessionUnlocked = false;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle Management
  // ---------------------------------------------------------------------------

  void onAppPaused() {
    _lastBackgroundTime = DateTime.now();
  }

  bool shouldRequireUnlockOnResume() {
    if (!isAppLockEnabled || !hasPinSet) return false;
    if (!_isSessionUnlocked) return true;

    final lastBg = _lastBackgroundTime;
    if (lastBg == null) return false;

    final elapsed = DateTime.now().difference(lastBg).inSeconds;
    if (elapsed >= lockTimeoutSeconds) {
      _isSessionUnlocked = false;
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // PIN Operations (Salted SHA-256)
  // ---------------------------------------------------------------------------

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin::scaneliq_security_salt');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> setPin(String newPin) async {
    final p = await prefs;
    final salt = _generateSalt();
    final hash = _hashPin(newPin, salt);

    await p.setString(_prefPinSalt, salt);
    await p.setString(_prefPinHash, hash);
    await p.setBool(_prefLockEnabled, true);
    await p.setInt(_prefFailedAttempts, 0);
    await p.remove(_prefLockoutUntilEpoch);
    _isSessionUnlocked = true;
  }

  Future<void> disableAppLock() async {
    final p = await prefs;
    await p.setBool(_prefLockEnabled, false);
    await p.setBool(_prefBiometricsEnabled, false);
    await p.remove(_prefPinHash);
    await p.remove(_prefPinSalt);
    await p.setInt(_prefFailedAttempts, 0);
    await p.remove(_prefLockoutUntilEpoch);
    _isSessionUnlocked = true;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_prefBiometricsEnabled, enabled);
  }

  Future<void> setTimeoutSeconds(int seconds) async {
    final p = await prefs;
    await p.setInt(_prefTimeoutSeconds, seconds);
  }

  int getRemainingCooldownSeconds() {
    final epoch = _prefs?.getInt(_prefLockoutUntilEpoch);
    if (epoch == null) return 0;
    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(epoch);
    final now = DateTime.now();
    if (now.isBefore(lockoutUntil)) {
      return lockoutUntil.difference(now).inSeconds;
    }
    return 0;
  }

  Future<PinVerificationResult> verifyPin(String inputPin) async {
    final p = await prefs;

    // Check existing lockout
    final cooldown = getRemainingCooldownSeconds();
    if (cooldown > 0) {
      return PinVerificationResult(
        success: false,
        isLockedOut: true,
        remainingCooldownSeconds: cooldown,
      );
    }

    final storedHash = p.getString(_prefPinHash);
    final salt = p.getString(_prefPinSalt);

    if (storedHash == null || salt == null) {
      // No PIN set
      _isSessionUnlocked = true;
      return const PinVerificationResult(success: true);
    }

    final computedHash = _hashPin(inputPin, salt);
    if (computedHash == storedHash) {
      // Success! Reset attempts
      await p.setInt(_prefFailedAttempts, 0);
      await p.remove(_prefLockoutUntilEpoch);
      _isSessionUnlocked = true;
      return const PinVerificationResult(success: true);
    } else {
      // Failed attempt
      int failed = (p.getInt(_prefFailedAttempts) ?? 0) + 1;
      if (failed >= maxFailedAttempts) {
        final lockoutUntil = DateTime.now().add(
          const Duration(seconds: lockoutDurationSeconds),
        );
        await p.setInt(
          _prefLockoutUntilEpoch,
          lockoutUntil.millisecondsSinceEpoch,
        );
        await p.setInt(
          _prefFailedAttempts,
          0,
        ); // reset after triggering lockout
        return const PinVerificationResult(
          success: false,
          isLockedOut: true,
          remainingCooldownSeconds: lockoutDurationSeconds,
          remainingAttempts: 0,
        );
      } else {
        await p.setInt(_prefFailedAttempts, failed);
        return PinVerificationResult(
          success: false,
          remainingAttempts: maxFailedAttempts - failed,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Biometric Operations
  // ---------------------------------------------------------------------------

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      return canCheck;
    } on PlatformException catch (e) {
      debugPrint('Biometrics check error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to unlock Scaneliq',
  }) async {
    if (!isBiometricsEnabled) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        _isSessionUnlocked = true;
        final p = await prefs;
        await p.setInt(_prefFailedAttempts, 0);
        await p.remove(_prefLockoutUntilEpoch);
      }
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth failed with PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }
}

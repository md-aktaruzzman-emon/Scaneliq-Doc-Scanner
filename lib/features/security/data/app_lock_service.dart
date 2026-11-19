import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over hardware-backed secret persistence (Android KeyStore / iOS Keychain)
/// so tests can verify migrations deterministically without platform channels.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageKeyStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _vmFallback = {};
  bool _useVmFallback = false;

  FlutterSecureStorageKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    if (_useVmFallback) return _vmFallback[key];
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      // Host VM unit tests without registered secure_storage plugin bindings.
      _useVmFallback = true;
      return _vmFallback[key];
    } on PlatformException catch (e) {
      debugPrint('Secure storage read error ($key): $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (_useVmFallback) {
      _vmFallback[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      _useVmFallback = true;
      _vmFallback[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async {
    if (_useVmFallback) {
      _vmFallback.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      _useVmFallback = true;
      _vmFallback.remove(key);
    } on PlatformException {
      // Ignore missing entry on delete.
    }
  }
}

class InMemorySecureKeyStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

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

/// Service providing Biometric & standard RFC 2898 PBKDF2-HMAC-SHA256 (100,000 iterations)
/// salted PIN app lock security persisted in KeyStore-backed secure storage.
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
  SecureKeyValueStore _secureStore = FlutterSecureStorageKeyStore();

  DateTime? _lastBackgroundTime;
  bool _isSessionUnlocked = false;
  bool _hasPinCached = false;
  int? _lockoutUntilEpochCached;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isUsingHardwareBackedStore =>
      _secureStore is! FlutterSecureStorageKeyStore ||
      !(_secureStore as FlutterSecureStorageKeyStore)._useVmFallback;

  Future<void> init([
    SharedPreferences? testPrefs,
    SecureKeyValueStore? testSecureStore,
  ]) async {
    _prefs = testPrefs ?? await SharedPreferences.getInstance();
    if (testSecureStore != null) {
      _secureStore = testSecureStore;
    } else if (testPrefs != null) {
      // Fresh test setup with injected prefs uses an isolated store unless explicitly overridden.
      _secureStore = FlutterSecureStorageKeyStore();
    }

    await _migrateLegacySecretsFromPrefs();
    await _refreshSecurityCaches();
    _initialized = true;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Migrates legacy plaintext PIN secrets/lockout counters out of SharedPreferences
  /// into Android KeyStore / Keychain secure storage and scrubs the plaintext keys.
  Future<void> _migrateLegacySecretsFromPrefs() async {
    final p = await prefs;
    final legacyHash = p.getString(_prefPinHash);
    final legacySalt = p.getString(_prefPinSalt);
    final legacyFailed = p.getInt(_prefFailedAttempts);
    final legacyLockout = p.getInt(_prefLockoutUntilEpoch);

    if (legacyHash != null && legacyHash.isNotEmpty) {
      await _secureStore.write(_prefPinHash, legacyHash);
      await p.remove(_prefPinHash);
    } else if (legacyHash != null) {
      await p.remove(_prefPinHash);
    }

    if (legacySalt != null && legacySalt.isNotEmpty) {
      await _secureStore.write(_prefPinSalt, legacySalt);
      await p.remove(_prefPinSalt);
    } else if (legacySalt != null) {
      await p.remove(_prefPinSalt);
    }

    if (legacyFailed != null) {
      await _secureStore.write(_prefFailedAttempts, legacyFailed.toString());
      await p.remove(_prefFailedAttempts);
    }

    if (legacyLockout != null) {
      await _secureStore.write(
        _prefLockoutUntilEpoch,
        legacyLockout.toString(),
      );
      await p.remove(_prefLockoutUntilEpoch);
    }
  }

  Future<void> _refreshSecurityCaches() async {
    final storedHash = await _secureStore.read(_prefPinHash);
    _hasPinCached = storedHash != null && storedHash.isNotEmpty;
    final lockoutStr = await _secureStore.read(_prefLockoutUntilEpoch);
    _lockoutUntilEpochCached = lockoutStr == null
        ? null
        : int.tryParse(lockoutStr);
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
    if (_hasPinCached) return true;
    final legacyHash = _prefs?.getString(_prefPinHash);
    return legacyHash != null && legacyHash.isNotEmpty;
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
  // PIN Operations (Standard RFC 2898 PBKDF2-HMAC-SHA256, 100k Iterations)
  // ---------------------------------------------------------------------------

  static const int pinHashIterationsV3 = 100000;
  static const int pinHashIterationsV2 = 10000;

  /// Standard RFC 2898 PBKDF2-HMAC-SHA256 derivation with 100,000 iterations
  String _hashPinV3(
    String pin,
    Uint8List saltBytes, {
    int iterations = pinHashIterationsV3,
  }) {
    final pbkdf2 = pc.KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = pc.Pbkdf2Parameters(saltBytes, iterations, 32);
    pbkdf2.init(params);
    final key = pbkdf2.process(utf8.encode('scaneliq_pin::$pin'));
    return base64Url.encode(key);
  }

  /// Phase 4 V2 iterative HMAC loop (for transparent backward compatibility migration)
  String _hashPinV2(
    String pin,
    String salt, {
    int iterations = pinHashIterationsV2,
  }) {
    List<int> key = utf8.encode('$salt::$pin::scaneliq_security_salt');
    final saltBytes = utf8.encode(salt);
    for (int i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, key);
      key = hmac.convert([...key, ...saltBytes, i & 0xFF]).bytes;
    }
    return base64Url.encode(key);
  }

  /// Legacy single-round SHA-256 fallback (for seamless V1 backward compatibility)
  String _legacyHashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin::scaneliq_security_salt');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time string equality check to mitigate timing side-channel attacks
  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    int diff = 0;
    for (int i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }

  Uint8List _decodeSalt(String saltStr) {
    try {
      return base64Url.decode(saltStr);
    } catch (_) {
      return Uint8List.fromList(utf8.encode(saltStr));
    }
  }

  Future<void> setPin(String newPin) async {
    final cleanPin = newPin.trim();
    if (cleanPin.isEmpty || !RegExp(r'^\d{4,8}$').hasMatch(cleanPin)) {
      throw ArgumentError('PIN must be between 4 and 8 numeric digits');
    }

    final p = await prefs;
    final salt = _generateSalt();
    final saltBytes = _decodeSalt(salt);
    final hash = _hashPinV3(cleanPin, saltBytes);
    final encodedHash = 'v3:$pinHashIterationsV3:$hash';

    await _secureStore.write(_prefPinSalt, salt);
    await _secureStore.write(_prefPinHash, encodedHash);
    await _secureStore.write(_prefFailedAttempts, '0');
    await _secureStore.delete(_prefLockoutUntilEpoch);

    // Ensure plaintext preferences contain zero secret fields.
    await p.remove(_prefPinSalt);
    await p.remove(_prefPinHash);
    await p.remove(_prefFailedAttempts);
    await p.remove(_prefLockoutUntilEpoch);
    await p.setBool(_prefLockEnabled, true);

    _hasPinCached = true;
    _lockoutUntilEpochCached = null;
    _isSessionUnlocked = true;
    _initialized = true;
  }

  Future<void> disableAppLock() async {
    final p = await prefs;
    await p.setBool(_prefLockEnabled, false);
    await p.setBool(_prefBiometricsEnabled, false);
    await p.remove(_prefPinHash);
    await p.remove(_prefPinSalt);
    await p.remove(_prefFailedAttempts);
    await p.remove(_prefLockoutUntilEpoch);

    await _secureStore.delete(_prefPinHash);
    await _secureStore.delete(_prefPinSalt);
    await _secureStore.write(_prefFailedAttempts, '0');
    await _secureStore.delete(_prefLockoutUntilEpoch);

    _hasPinCached = false;
    _lockoutUntilEpochCached = null;
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
    final epoch =
        _lockoutUntilEpochCached ?? _prefs?.getInt(_prefLockoutUntilEpoch);
    if (epoch == null) return 0;
    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(epoch);
    final now = DateTime.now();
    if (now.isBefore(lockoutUntil)) {
      return lockoutUntil.difference(now).inSeconds;
    }
    return 0;
  }

  Future<PinVerificationResult> verifyPin(String inputPin) async {
    await _migrateLegacySecretsFromPrefs();
    await _refreshSecurityCaches();

    // Check existing lockout before running key derivation (DoS mitigation)
    final cooldown = getRemainingCooldownSeconds();
    if (cooldown > 0) {
      return PinVerificationResult(
        success: false,
        isLockedOut: true,
        remainingCooldownSeconds: cooldown,
        remainingAttempts: 0,
      );
    }

    final storedHash = await _secureStore.read(_prefPinHash);
    final salt = await _secureStore.read(_prefPinSalt);

    // Fail-safe handling for corrupted or unconfigured authentication state
    if (isAppLockEnabled &&
        (storedHash == null ||
            salt == null ||
            storedHash.isEmpty ||
            salt.isEmpty)) {
      _isSessionUnlocked = false;
      return const PinVerificationResult(success: false, remainingAttempts: 0);
    }

    if (!isAppLockEnabled && (storedHash == null || salt == null)) {
      _isSessionUnlocked = true;
      return const PinVerificationResult(success: true);
    }

    final saltBytes = _decodeSalt(salt!);
    bool isMatch = false;

    if (storedHash!.startsWith('v3:')) {
      final parts = storedHash.split(':');
      if (parts.length == 3) {
        final iters = int.tryParse(parts[1]) ?? pinHashIterationsV3;
        final expectedHash = parts[2];
        final computed = _hashPinV3(inputPin, saltBytes, iterations: iters);
        isMatch = _constantTimeEquals(computed, expectedHash);
      }
    } else {
      // V2 Phase 4 format check
      final v2Hash = _hashPinV2(inputPin, salt);
      if (_constantTimeEquals(v2Hash, storedHash)) {
        isMatch = true;
        final newV3Hash = _hashPinV3(inputPin, saltBytes);
        await _secureStore.write(
          _prefPinHash,
          'v3:$pinHashIterationsV3:$newV3Hash',
        );
      } else {
        // V1 single-round SHA-256 legacy check
        final v1Hash = _legacyHashPin(inputPin, salt);
        if (_constantTimeEquals(v1Hash, storedHash)) {
          isMatch = true;
          final newV3Hash = _hashPinV3(inputPin, saltBytes);
          await _secureStore.write(
            _prefPinHash,
            'v3:$pinHashIterationsV3:$newV3Hash',
          );
        }
      }
    }

    if (isMatch) {
      await _secureStore.write(_prefFailedAttempts, '0');
      await _secureStore.delete(_prefLockoutUntilEpoch);
      _lockoutUntilEpochCached = null;
      _hasPinCached = true;
      _isSessionUnlocked = true;
      return const PinVerificationResult(success: true);
    } else {
      _isSessionUnlocked = false;
      final failedStr = await _secureStore.read(_prefFailedAttempts);
      int failed = (int.tryParse(failedStr ?? '') ?? 0) + 1;
      if (failed >= maxFailedAttempts) {
        final lockoutUntil = DateTime.now().add(
          const Duration(seconds: lockoutDurationSeconds),
        );
        final epoch = lockoutUntil.millisecondsSinceEpoch;
        await _secureStore.write(_prefLockoutUntilEpoch, epoch.toString());
        await _secureStore.write(_prefFailedAttempts, '0');
        _lockoutUntilEpochCached = epoch;
        return const PinVerificationResult(
          success: false,
          isLockedOut: true,
          remainingCooldownSeconds: lockoutDurationSeconds,
          remainingAttempts: 0,
        );
      } else {
        await _secureStore.write(_prefFailedAttempts, failed.toString());
        return PinVerificationResult(
          success: false,
          remainingAttempts: maxFailedAttempts - failed,
        );
      }
    }
  }

  @visibleForTesting
  Future<String?> debugReadStoredPinHash() => _secureStore.read(_prefPinHash);

  @visibleForTesting
  Future<void> debugOverrideSecretStateForTest({
    String? pinHash,
    bool clearLockout = false,
  }) async {
    if (pinHash != null) {
      await _secureStore.write(_prefPinHash, pinHash);
      _hasPinCached = pinHash.isNotEmpty;
    }
    if (clearLockout) {
      await _secureStore.delete(_prefLockoutUntilEpoch);
      await _secureStore.write(_prefFailedAttempts, '0');
      _lockoutUntilEpochCached = null;
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
        await _secureStore.write(_prefFailedAttempts, '0');
        await _secureStore.delete(_prefLockoutUntilEpoch);
        _lockoutUntilEpochCached = null;
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

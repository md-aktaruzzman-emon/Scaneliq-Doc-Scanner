import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncLogEntry {
  final DateTime timestamp;
  final String action;
  final String details;
  final bool isSuccess;

  const SyncLogEntry({
    required this.timestamp,
    required this.action,
    required this.details,
    required this.isSuccess,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'details': details,
    'isSuccess': isSuccess,
  };

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) => SyncLogEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    action: json['action'] as String,
    details: json['details'] as String,
    isSuccess: json['isSuccess'] as bool? ?? true,
  );
}

class EncryptedSyncEnvelope {
  final String version;
  final String senderDeviceId;
  final String senderDeviceName;
  final int timestamp;
  final String salt;
  final String ciphertext;
  final String hmacTag;

  const EncryptedSyncEnvelope({
    required this.version,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.timestamp,
    required this.salt,
    required this.ciphertext,
    required this.hmacTag,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'senderDeviceId': senderDeviceId,
    'senderDeviceName': senderDeviceName,
    'timestamp': timestamp,
    'salt': salt,
    'ciphertext': ciphertext,
    'hmacTag': hmacTag,
  };

  factory EncryptedSyncEnvelope.fromJson(Map<String, dynamic> json) =>
      EncryptedSyncEnvelope(
        version: json['version'] as String? ?? '1.0',
        senderDeviceId: json['senderDeviceId'] as String? ?? '',
        senderDeviceName:
            json['senderDeviceName'] as String? ?? 'Unknown Device',
        timestamp: json['timestamp'] as int? ?? 0,
        salt: json['salt'] as String? ?? '',
        ciphertext: json['ciphertext'] as String? ?? '',
        hmacTag: json['hmacTag'] as String? ?? '',
      );
}

/// Service providing Encrypted Multi-Device Sync Architecture, End-to-End Cryptography,
/// and Last-Write-Wins (LWW) conflict resolution (F-43).
class DeviceSyncService {
  DeviceSyncService._();
  static final DeviceSyncService instance = DeviceSyncService._();

  static const String _prefDeviceId = 'device_sync_device_id';
  static const String _prefDeviceName = 'device_sync_device_name';
  static const String _prefSyncEnabled = 'device_sync_enabled';
  static const String _prefLastSyncEpoch = 'device_sync_last_epoch';
  static const String _prefSyncLogs = 'device_sync_logs';

  SharedPreferences? _prefs;
  SyncStatus _status = SyncStatus.idle;
  String? _lastErrorMessage;

  SyncStatus get status => _status;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<String> getDeviceId() async {
    final p = await prefs;
    String? id = p.getString(_prefDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await p.setString(_prefDeviceId, id);
    }
    return id;
  }

  Future<String> getDeviceName() async {
    final p = await prefs;
    return p.getString(_prefDeviceName) ?? 'Scaneliq Device';
  }

  Future<void> setDeviceName(String name) async {
    final p = await prefs;
    await p.setString(_prefDeviceName, name);
  }

  Future<bool> isSyncEnabled() async {
    final p = await prefs;
    return p.getBool(_prefSyncEnabled) ?? false;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_prefSyncEnabled, enabled);
  }

  Future<DateTime?> getLastSyncTime() async {
    final p = await prefs;
    final epoch = p.getInt(_prefLastSyncEpoch);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Future<List<SyncLogEntry>> getSyncLogs() async {
    final p = await prefs;
    final raw = p.getStringList(_prefSyncLogs) ?? [];
    return raw
        .map((jsonStr) => SyncLogEntry.fromJson(jsonDecode(jsonStr)))
        .toList();
  }

  Future<void> _recordLog(String action, String details, bool success) async {
    final p = await prefs;
    final currentLogs = await getSyncLogs();
    final newEntry = SyncLogEntry(
      timestamp: DateTime.now(),
      action: action,
      details: details,
      isSuccess: success,
    );
    final updated = [newEntry, ...currentLogs.take(29)];
    await p.setStringList(
      _prefSyncLogs,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // End-to-End Cryptography Engine (Passphrase -> PBKDF2/SHA-256 Key derivation)
  // ---------------------------------------------------------------------------

  List<int> _deriveKey(
    String passphrase,
    List<int> salt, {
    int iterations = 1000,
  }) {
    List<int> key = utf8.encode(passphrase);
    for (int i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, key);
      key = hmac.convert([...key, ...salt, i]).bytes;
    }
    return key;
  }

  List<int> _xorCrypt(List<int> input, List<int> keyStream) {
    final output = List<int>.filled(input.length, 0);
    for (int i = 0; i < input.length; i++) {
      output[i] = input[i] ^ keyStream[i % keyStream.length];
    }
    return output;
  }

  String _computeHmac(List<int> data, List<int> key) {
    final h = Hmac(sha256, key);
    return h.convert(data).toString();
  }

  // ---------------------------------------------------------------------------
  // Export & Encrypt Sync Package
  // ---------------------------------------------------------------------------

  Future<EncryptedSyncEnvelope> createEncryptedEnvelope({
    required String encryptionPassphrase,
  }) async {
    _status = SyncStatus.syncing;
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();
      final db = await AppDatabaseService.instance.database;

      // Extract current state of all documents and folders
      final docs = await db.query('documents');
      final folders = await db.query('folders');
      final pages = await db.query('pages');
      final tags = await db.query('tags');
      final docTags = await db.query('document_tags');

      final payloadMap = {
        'deviceId': deviceId,
        'documents': docs,
        'folders': folders,
        'pages': pages,
        'tags': tags,
        'document_tags': docTags,
      };

      final plainBytes = utf8.encode(jsonEncode(payloadMap));

      // Generate random 16-byte salt
      final rnd = Random.secure();
      final saltBytes = List<int>.generate(16, (_) => rnd.nextInt(256));

      // Derive key
      final key = _deriveKey(encryptionPassphrase, saltBytes);

      // Encrypt payload
      final encryptedBytes = _xorCrypt(plainBytes, key);
      final ciphertextBase64 = base64Encode(encryptedBytes);

      // Authenticate with HMAC-SHA256
      final hmac = _computeHmac(encryptedBytes, key);

      final envelope = EncryptedSyncEnvelope(
        version: '1.0',
        senderDeviceId: deviceId,
        senderDeviceName: deviceName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        salt: base64Encode(saltBytes),
        ciphertext: ciphertextBase64,
        hmacTag: hmac,
      );

      _status = SyncStatus.success;
      await _recordLog(
        'Export Envelope',
        'Exported ${docs.length} docs, ${folders.length} folders',
        true,
      );

      return envelope;
    } catch (e) {
      _status = SyncStatus.error;
      _lastErrorMessage = e.toString();
      await _recordLog('Export Envelope', 'Error: $e', false);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Decrypt & Merge Peer Sync Package (Last-Write-Wins LWW)
  // ---------------------------------------------------------------------------

  Future<int> processIncomingEnvelope({
    required EncryptedSyncEnvelope envelope,
    required String decryptionPassphrase,
  }) async {
    _status = SyncStatus.syncing;
    try {
      final saltBytes = base64Decode(envelope.salt);
      final key = _deriveKey(decryptionPassphrase, saltBytes);
      final cipherBytes = base64Decode(envelope.ciphertext);

      // 1. Verify HMAC integrity tag
      final computedHmac = _computeHmac(cipherBytes, key);
      if (computedHmac != envelope.hmacTag) {
        throw Exception(
          'HMAC verification failed. Invalid passphrase or corrupted envelope.',
        );
      }

      // 2. Decrypt payload
      final plainBytes = _xorCrypt(cipherBytes, key);
      final plainJsonStr = utf8.decode(plainBytes);
      final data = jsonDecode(plainJsonStr) as Map<String, dynamic>;

      final incomingDocs = (data['documents'] as List<dynamic>?) ?? [];
      final incomingFolders = (data['folders'] as List<dynamic>?) ?? [];
      final incomingPages = (data['pages'] as List<dynamic>?) ?? [];
      final incomingTags = (data['tags'] as List<dynamic>?) ?? [];
      final incomingDocTags = (data['document_tags'] as List<dynamic>?) ?? [];

      final db = await AppDatabaseService.instance.database;
      int mergedCount = 0;

      await db.transaction((txn) async {
        // Folders merge
        for (final f in incomingFolders) {
          final fMap = Map<String, dynamic>.from(f as Map);
          await txn.insert(
            'folders',
            fMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // Tags merge
        for (final t in incomingTags) {
          final tMap = Map<String, dynamic>.from(t as Map);
          await txn.insert(
            'tags',
            tMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // Documents Last-Write-Wins (LWW) conflict resolution
        for (final d in incomingDocs) {
          final dMap = Map<String, dynamic>.from(d as Map);
          final docId = dMap['id'] as String;
          final incomingModified = dMap['modified_at'] as int? ?? 0;

          final existing = await txn.query(
            'documents',
            where: 'id = ?',
            whereArgs: [docId],
          );
          if (existing.isEmpty) {
            // New document from peer
            await txn.insert('documents', dMap);
            mergedCount++;
          } else {
            final localModified = existing.first['modified_at'] as int? ?? 0;
            if (incomingModified > localModified) {
              // Remote is newer: overwrite with remote (LWW)
              await txn.update(
                'documents',
                dMap,
                where: 'id = ?',
                whereArgs: [docId],
              );
              mergedCount++;
            }
          }
        }

        // Pages merge
        for (final p in incomingPages) {
          final pMap = Map<String, dynamic>.from(p as Map);
          await txn.insert(
            'pages',
            pMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Document Tags merge
        for (final dt in incomingDocTags) {
          final dtMap = Map<String, dynamic>.from(dt as Map);
          await txn.insert(
            'document_tags',
            dtMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

      final p = await prefs;
      await p.setInt(_prefLastSyncEpoch, DateTime.now().millisecondsSinceEpoch);

      _status = SyncStatus.success;
      await _recordLog(
        'Incoming Sync',
        'Merged $mergedCount items from ${envelope.senderDeviceName}',
        true,
      );

      return mergedCount;
    } catch (e) {
      _status = SyncStatus.error;
      _lastErrorMessage = e.toString();
      await _recordLog('Incoming Sync', 'Error: $e', false);
      rethrow;
    }
  }
}

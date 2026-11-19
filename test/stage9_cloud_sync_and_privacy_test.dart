import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/cloud_sync/data/cloud_transport_service.dart';
import 'package:scaneliq/features/cloud_sync/data/device_sync_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:scaneliq/features/security/data/privacy_shield_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scaneliq_stage9_test_');
    await AppStorageService.instance.init(tempDir);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.scaneliq.scaneliq/security'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Stage 9A: PrivacyShieldService (FLAG_SECURE)', () {
    test('Persists state and invokes Android security MethodChannel', () async {
      bool nativeFlagState = false;
      final recordedCalls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.scaneliq.scaneliq/security'),
            (MethodCall call) async {
              recordedCalls.add(call.method);
              if (call.method == 'setFlagSecure') {
                final args = Map<String, dynamic>.from(call.arguments as Map);
                nativeFlagState = args['enabled'] == true;
                return nativeFlagState;
              }
              if (call.method == 'getFlagSecure') {
                return nativeFlagState;
              }
              return null;
            },
          );

      final prefs = await SharedPreferences.getInstance();
      final shield = PrivacyShieldService.instance;
      shield.setPreferencesForTesting(prefs);

      await shield.init();
      expect(shield.isEnabled, isFalse);

      await shield.setEnabled(true);
      expect(shield.isEnabled, isTrue);
      expect(nativeFlagState, isTrue);
      expect(prefs.getBool('privacy_flag_secure_enabled'), isTrue);

      final queried = await shield.queryNativeFlagState();
      expect(queried, isTrue);
      expect(recordedCalls, containsAll(['setFlagSecure', 'getFlagSecure']));
    });
  });

  group(
    'Stage 9B: DeviceSyncService V2 Crypto, Legacy V1 Compat & Offline Queue',
    () {
      test(
        'Creates V2 AES-256-CBC EtM envelope, rejects tamper, and merges LWW',
        () async {
          final db = await openDatabase(
            '${tempDir.path}/src_sync.db',
            version: 1,
            onCreate: (db, v) async {
              await db.execute(
                'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, modified_at INTEGER)',
              );
              await db.execute(
                'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
              );
              await db.execute('CREATE TABLE pages (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE document_tags (id TEXT)');
            },
          );
          await db.insert('documents', {
            'id': 'doc_v2',
            'title': 'National NID Card',
            'modified_at': 1700000000000,
          });
          AppDatabaseService.instance.setDatabaseForTesting(db);

          final syncService = DeviceSyncService.instance;
          final envelope = await syncService.createEncryptedEnvelope(
            encryptionPassphrase: 'Strong-Vault-Passphrase!',
          );

          expect(envelope.version, '2.0');
          expect(envelope.ciphertext.contains(':'), isTrue);

          // Tamper with ciphertext must trigger HMAC failure
          final parts = envelope.ciphertext.split(':');
          final tamperedCipher = '${parts[0]}:AAAA${parts[1].substring(4)}';
          final tamperedEnvelope = EncryptedSyncEnvelope(
            version: envelope.version,
            senderDeviceId: envelope.senderDeviceId,
            senderDeviceName: envelope.senderDeviceName,
            timestamp: envelope.timestamp,
            salt: envelope.salt,
            ciphertext: tamperedCipher,
            hmacTag: envelope.hmacTag,
          );

          final peerDb = await openDatabase(
            '${tempDir.path}/peer_v2.db',
            version: 1,
            onCreate: (db, v) async {
              await db.execute(
                'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, modified_at INTEGER)',
              );
              await db.execute(
                'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
              );
              await db.execute('CREATE TABLE pages (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE document_tags (id TEXT)');
            },
          );
          AppDatabaseService.instance.setDatabaseForTesting(peerDb);

          await expectLater(
            syncService.processIncomingEnvelope(
              envelope: tamperedEnvelope,
              decryptionPassphrase: 'Strong-Vault-Passphrase!',
            ),
            throwsA(isA<Exception>()),
          );

          final merged = await syncService.processIncomingEnvelope(
            envelope: envelope,
            decryptionPassphrase: 'Strong-Vault-Passphrase!',
          );
          expect(merged, 1);

          final peerDocs = await peerDb.query('documents');
          expect(peerDocs.length, 1);
          expect(peerDocs.first['title'], 'National NID Card');

          await db.close();
          await peerDb.close();
        },
      );

      test(
        'Backward-compatible decryption of legacy V1.0 sync envelopes',
        () async {
          final db = await openDatabase(
            '${tempDir.path}/peer_v1.db',
            version: 1,
            onCreate: (db, v) async {
              await db.execute(
                'CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, modified_at INTEGER)',
              );
              await db.execute(
                'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)',
              );
              await db.execute('CREATE TABLE pages (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY)');
              await db.execute('CREATE TABLE document_tags (id TEXT)');
            },
          );
          AppDatabaseService.instance.setDatabaseForTesting(db);

          const pass = 'legacy_pass';
          final salt = List<int>.filled(16, 7);
          List<int> key = utf8.encode(pass);
          for (int i = 0; i < 1000; i++) {
            key = Hmac(sha256, key).convert([...key, ...salt, i]).bytes;
          }
          final payload = utf8.encode(
            jsonEncode({
              'deviceId': 'legacy-dev',
              'documents': [
                {
                  'id': 'doc_legacy',
                  'title': 'Legacy Sync Doc',
                  'modified_at': 500,
                },
              ],
              'folders': [],
              'pages': [],
              'tags': [],
              'document_tags': [],
            }),
          );
          final cipher = List<int>.generate(
            payload.length,
            (i) => payload[i] ^ key[i % key.length],
          );
          final tag = Hmac(sha256, key).convert(cipher).toString();

          final legacyEnvelope = EncryptedSyncEnvelope(
            version: '1.0',
            senderDeviceId: 'legacy-dev',
            senderDeviceName: 'Old Phone',
            timestamp: 500,
            salt: base64Encode(salt),
            ciphertext: base64Encode(cipher),
            hmacTag: tag,
          );

          final merged = await DeviceSyncService.instance
              .processIncomingEnvelope(
                envelope: legacyEnvelope,
                decryptionPassphrase: pass,
              );
          expect(merged, 1);

          await db.close();
        },
      );

      test(
        'Offline sync operation queue deduplicates and persists cleanly',
        () async {
          final sync = DeviceSyncService.instance;
          await sync.clearPendingQueue();

          final op1 = await sync.enqueueSyncOperation(
            type: SyncOperationType.upsertDocument,
            entityId: 'doc_1',
            details: 'Created scan',
          );
          await sync.enqueueSyncOperation(
            type: SyncOperationType.upsertDocument,
            entityId: 'doc_1',
            details: 'Updated title',
          );
          await sync.enqueueSyncOperation(
            type: SyncOperationType.fullBackupUpload,
            entityId: 'vault_archive',
          );

          final queue = await sync.getPendingQueue();
          expect(queue.length, 2);
          expect(queue.first.details, 'Updated title');

          await sync.removePendingOperation(op1.id);
          // Coalesced op got a new UUID, so removing queue.first deletes it cleanly
          await sync.removePendingOperation(queue.first.id);
          final remaining = await sync.getPendingQueue();
          expect(remaining.length, 1);
          expect(remaining.first.type, SyncOperationType.fullBackupUpload);

          await sync.clearPendingQueue();
          expect(await sync.getPendingQueue(), isEmpty);
        },
      );
    },
  );

  group('Stage 9B: CloudTransportService WebDAV & OAuth Pre-Flight', () {
    test(
      'WebDAV MKCOL, PUT upload, PROPFIND listing, and GET download succeed',
      () async {
        final remoteStorage = <String, Uint8List>{};
        final observedMethods = <String>[];
        String? lastAuthHeader;

        final mockClient = MockClient((http.Request req) async {
          observedMethods.add('${req.method} ${req.url.path}');
          lastAuthHeader = req.headers['Authorization'];

          if (req.headers['Authorization'] !=
              'Basic ${base64Encode(utf8.encode('emon:secret123'))}') {
            return http.Response('Unauthorized', 401);
          }

          if (req.method == 'PROPFIND' && req.url.path == '/') {
            return http.Response('<D:multistatus/>', 207);
          }

          if (req.method == 'MKCOL') {
            return http.Response('', 201);
          }

          if (req.method == 'PUT') {
            remoteStorage[req.url.path] = Uint8List.fromList(req.bodyBytes);
            return http.Response('', 201);
          }

          if (req.method == 'PROPFIND' &&
              req.url.path.contains('ScaneliqBackups')) {
            return http.Response('''<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/ScaneliqBackups/Scaneliq_Backup_1001.scaneliq</D:href>
    <D:propstat><D:prop>
      <D:getcontentlength>42</D:getcontentlength>
      <D:getlastmodified>Thu, 19 Nov 2026 10:00:00 GMT</D:getlastmodified>
    </D:prop></D:propstat>
  </D:response>
</D:multistatus>''', 207);
          }

          if (req.method == 'GET') {
            final bytes = remoteStorage[req.url.path];
            if (bytes == null) return http.Response('Not Found', 404);
            return http.Response.bytes(bytes, 200);
          }

          return http.Response('Unsupported', 400);
        });

        final secureStore = _InMemorySecureStore();
        final prefs = await SharedPreferences.getInstance();
        final cloud = CloudTransportService.instance;
        cloud.configureForTesting(
          httpClient: mockClient,
          secureStore: secureStore,
          prefs: prefs,
        );

        await cloud.saveWebDavConfig(
          endpointUrl: 'https://cloud.example.com',
          username: 'emon',
          password: 'secret123',
          remoteFolder: 'ScaneliqBackups',
        );

        // Verify credentials live ONLY in secureStore, never plaintext prefs
        expect(prefs.getString('cloud_webdav_password'), isNull);
        expect(secureStore.data['scaneliq_webdav_password'], 'secret123');

        final connRes = await cloud.testWebDavConnection();
        expect(connRes.success, isTrue);

        final localBackup = File(
          '${tempDir.path}/Scaneliq_Backup_1001.scaneliq',
        );
        await localBackup.writeAsBytes(
          utf8.encode('SCANELIQ_ENC_V2:{"ok":true}'),
        );

        final uploadRes = await cloud.uploadBackupToWebDav(localBackup);
        expect(uploadRes.success, isTrue);
        expect(lastAuthHeader, startsWith('Basic '));
        expect(observedMethods, contains('MKCOL /ScaneliqBackups/'));
        expect(
          observedMethods,
          contains('PUT /ScaneliqBackups/Scaneliq_Backup_1001.scaneliq'),
        );

        final listRes = await cloud.listWebDavBackups();
        expect(listRes.success, isTrue);
        expect(listRes.remoteFiles.length, 1);
        expect(listRes.remoteFiles.first.name, 'Scaneliq_Backup_1001.scaneliq');
        expect(listRes.remoteFiles.first.sizeBytes, 42);

        final restoredDest = File('${tempDir.path}/downloaded.scaneliq');
        final dlRes = await cloud.downloadWebDavBackup(
          'Scaneliq_Backup_1001.scaneliq',
          destinationFile: restoredDest,
        );
        expect(dlRes.success, isTrue);
        expect(
          await restoredDest.readAsString(),
          'SCANELIQ_ENC_V2:{"ok":true}',
        );

        // Backup schedule tracking
        await cloud.setBackupSchedule(BackupScheduleFrequency.daily);
        expect(await cloud.getBackupSchedule(), BackupScheduleFrequency.daily);
        expect(await cloud.isScheduledBackupDue(), isFalse); // just uploaded
        expect(
          await cloud.isScheduledBackupDue(
            now: DateTime.now().add(const Duration(hours: 25)),
          ),
          isTrue,
        );
      },
    );

    test(
      'OAuth providers honestly report requiresCredentials when keys missing',
      () {
        final cloud = CloudTransportService.instance;
        for (final provider in [
          CloudProviderType.googleDrive,
          CloudProviderType.dropbox,
          CloudProviderType.oneDrive,
        ]) {
          final res = cloud.checkOAuthProviderAvailability(provider);
          expect(res.success, isFalse);
          expect(res.status, CloudTransferStatus.requiresCredentials);
        }
      },
    );
  });
}

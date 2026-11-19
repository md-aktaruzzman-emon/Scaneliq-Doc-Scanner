import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:scaneliq/core/config/app_compliance_config.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CloudProviderType { webdav, googleDrive, dropbox, oneDrive }

enum BackupScheduleFrequency { manual, daily, weekly }

enum CloudTransferStatus {
  success,
  requiresCredentials,
  authenticationFailed,
  networkError,
  invalidConfiguration,
}

class CloudRemoteBackupEntry {
  final String name;
  final String href;
  final int sizeBytes;
  final String? lastModified;

  const CloudRemoteBackupEntry({
    required this.name,
    required this.href,
    this.sizeBytes = 0,
    this.lastModified,
  });
}

class CloudTransferResult {
  final bool success;
  final CloudTransferStatus status;
  final String message;
  final List<CloudRemoteBackupEntry> remoteFiles;
  final File? downloadedFile;

  const CloudTransferResult({
    required this.success,
    required this.status,
    required this.message,
    this.remoteFiles = const [],
    this.downloadedFile,
  });
}

class WebDavConfiguration {
  final String endpointUrl;
  final String remoteFolder;
  final String username;
  final bool hasPassword;

  const WebDavConfiguration({
    required this.endpointUrl,
    required this.remoteFolder,
    required this.username,
    required this.hasPassword,
  });

  bool get isConfigured =>
      endpointUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      hasPassword;
}

/// Real cloud & WebDAV transport engine backing encrypted backup upload/restore
/// and explicit OAuth credential status reporting without mock/fake cloud calls.
class CloudTransportService {
  CloudTransportService._();
  static final CloudTransportService instance = CloudTransportService._();

  static const String _prefWebDavUrl = 'cloud_webdav_endpoint_url';
  static const String _prefWebDavFolder = 'cloud_webdav_remote_folder';
  static const String _prefBackupSchedule = 'cloud_backup_schedule';
  static const String _prefLastCloudUploadEpoch = 'cloud_last_upload_epoch';

  static const String _secKeyWebDavUser = 'scaneliq_webdav_username';
  static const String _secKeyWebDavPassword = 'scaneliq_webdav_password';

  SecureKeyValueStore _secureStore = FlutterSecureStorageKeyStore();
  http.Client? _clientOverride;
  SharedPreferences? _prefsOverride;

  @visibleForTesting
  void configureForTesting({
    http.Client? httpClient,
    SecureKeyValueStore? secureStore,
    SharedPreferences? prefs,
  }) {
    _clientOverride = httpClient;
    if (secureStore != null) {
      _secureStore = secureStore;
    }
    _prefsOverride = prefs;
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  http.Client _createClient() => _clientOverride ?? http.Client();

  void _disposeClientIfOwned(http.Client client) {
    if (_clientOverride == null) {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Backup Schedule Management
  // ---------------------------------------------------------------------------

  Future<BackupScheduleFrequency> getBackupSchedule() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_prefBackupSchedule);
    return BackupScheduleFrequency.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => BackupScheduleFrequency.manual,
    );
  }

  Future<void> setBackupSchedule(BackupScheduleFrequency schedule) async {
    final prefs = await _getPrefs();
    await prefs.setString(_prefBackupSchedule, schedule.name);
  }

  Future<DateTime?> getLastCloudUploadTime() async {
    final prefs = await _getPrefs();
    final epoch = prefs.getInt(_prefLastCloudUploadEpoch);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Future<bool> isScheduledBackupDue({DateTime? now}) async {
    final schedule = await getBackupSchedule();
    if (schedule == BackupScheduleFrequency.manual) return false;
    final last = await getLastCloudUploadTime();
    if (last == null) return true;
    final current = now ?? DateTime.now();
    final elapsed = current.difference(last);
    return schedule == BackupScheduleFrequency.daily
        ? elapsed >= const Duration(hours: 24)
        : elapsed >= const Duration(days: 7);
  }

  // ---------------------------------------------------------------------------
  // WebDAV Configuration (Secrets in KeyStore/Keychain via FlutterSecureStorage)
  // ---------------------------------------------------------------------------

  Future<void> saveWebDavConfig({
    required String endpointUrl,
    required String username,
    required String password,
    String remoteFolder = 'ScaneliqBackups',
  }) async {
    final normalizedUrl = endpointUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.host.isEmpty) {
      throw ArgumentError('WebDAV endpoint must be a valid http(s) URL.');
    }

    final cleanFolder = remoteFolder
        .trim()
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceAll('..', '');
    final prefs = await _getPrefs();
    await prefs.setString(_prefWebDavUrl, normalizedUrl);
    await prefs.setString(
      _prefWebDavFolder,
      cleanFolder.isEmpty ? 'ScaneliqBackups' : cleanFolder,
    );
    await _secureStore.write(_secKeyWebDavUser, username.trim());
    await _secureStore.write(_secKeyWebDavPassword, password);
  }

  Future<void> clearWebDavConfig() async {
    final prefs = await _getPrefs();
    await prefs.remove(_prefWebDavUrl);
    await prefs.remove(_prefWebDavFolder);
    await _secureStore.delete(_secKeyWebDavUser);
    await _secureStore.delete(_secKeyWebDavPassword);
  }

  Future<WebDavConfiguration> getWebDavConfig() async {
    final prefs = await _getPrefs();
    final url = prefs.getString(_prefWebDavUrl) ?? '';
    final folder = prefs.getString(_prefWebDavFolder) ?? 'ScaneliqBackups';
    final username = await _secureStore.read(_secKeyWebDavUser) ?? '';
    final password = await _secureStore.read(_secKeyWebDavPassword) ?? '';
    return WebDavConfiguration(
      endpointUrl: url,
      remoteFolder: folder,
      username: username,
      hasPassword: password.isNotEmpty,
    );
  }

  Future<(WebDavConfiguration, String)> _loadCredentials() async {
    final config = await getWebDavConfig();
    final password = await _secureStore.read(_secKeyWebDavPassword) ?? '';
    return (config, password);
  }

  Map<String, String> _basicAuthHeaders(
    String username,
    String password, {
    Map<String, String>? extra,
  }) {
    final token = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $token', ...?extra};
  }

  Uri _folderUri(WebDavConfiguration config) =>
      Uri.parse('${config.endpointUrl}/${config.remoteFolder}/');

  Uri _fileUri(WebDavConfiguration config, String fileName) {
    final safeName = p.basename(fileName);
    return Uri.parse('${config.endpointUrl}/${config.remoteFolder}/$safeName');
  }

  Future<CloudTransferResult> testWebDavConnection() async {
    final (config, password) = await _loadCredentials();
    if (!config.isConfigured) {
      return const CloudTransferResult(
        success: false,
        status: CloudTransferStatus.requiresCredentials,
        message:
            'Configure your WebDAV server URL, username, and password first.',
      );
    }

    final client = _createClient();
    try {
      final req = http.Request('PROPFIND', Uri.parse('${config.endpointUrl}/'));
      req.headers.addAll(
        _basicAuthHeaders(config.username, password, extra: {'Depth': '0'}),
      );
      final streamed = await client.send(req);
      final status = streamed.statusCode;
      if (status == 401 || status == 403) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.authenticationFailed,
          message: 'WebDAV rejected credentials (HTTP $status).',
        );
      }
      if (status >= 200 && status < 300) {
        return CloudTransferResult(
          success: true,
          status: CloudTransferStatus.success,
          message: 'Connected to WebDAV endpoint (HTTP $status).',
        );
      }
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'Unexpected WebDAV response: HTTP $status.',
      );
    } catch (e) {
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV connection error: $e',
      );
    } finally {
      _disposeClientIfOwned(client);
    }
  }

  Future<CloudTransferResult> uploadBackupToWebDav(File backupFile) async {
    if (!await backupFile.exists()) {
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.invalidConfiguration,
        message: 'Backup file does not exist: ${backupFile.path}',
      );
    }

    final (config, password) = await _loadCredentials();
    if (!config.isConfigured) {
      return const CloudTransferResult(
        success: false,
        status: CloudTransferStatus.requiresCredentials,
        message: 'WebDAV credentials are not configured.',
      );
    }

    final client = _createClient();
    try {
      // Ensure target folder exists (MKCOL returns 201 Created, or 405/200/301 if already present).
      final mkcolReq = http.Request('MKCOL', _folderUri(config));
      mkcolReq.headers.addAll(_basicAuthHeaders(config.username, password));
      final mkcolRes = await client.send(mkcolReq);
      if (mkcolRes.statusCode == 401 || mkcolRes.statusCode == 403) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.authenticationFailed,
          message: 'WebDAV rejected credentials (HTTP ${mkcolRes.statusCode}).',
        );
      }

      final bytes = await backupFile.readAsBytes();
      final targetUri = _fileUri(config, p.basename(backupFile.path));
      final putRes = await client.put(
        targetUri,
        headers: _basicAuthHeaders(
          config.username,
          password,
          extra: {'Content-Type': 'application/octet-stream'},
        ),
        body: bytes,
      );

      if (putRes.statusCode == 401 || putRes.statusCode == 403) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.authenticationFailed,
          message: 'WebDAV upload unauthorized (HTTP ${putRes.statusCode}).',
        );
      }

      if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
        final prefs = await _getPrefs();
        await prefs.setInt(
          _prefLastCloudUploadEpoch,
          DateTime.now().millisecondsSinceEpoch,
        );
        return CloudTransferResult(
          success: true,
          status: CloudTransferStatus.success,
          message:
              'Uploaded ${p.basename(backupFile.path)} (${bytes.length} bytes) to WebDAV.',
        );
      }

      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV PUT failed with HTTP ${putRes.statusCode}.',
      );
    } catch (e) {
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV upload error: $e',
      );
    } finally {
      _disposeClientIfOwned(client);
    }
  }

  Future<CloudTransferResult> listWebDavBackups() async {
    final (config, password) = await _loadCredentials();
    if (!config.isConfigured) {
      return const CloudTransferResult(
        success: false,
        status: CloudTransferStatus.requiresCredentials,
        message: 'WebDAV credentials are not configured.',
      );
    }

    final client = _createClient();
    try {
      final req = http.Request('PROPFIND', _folderUri(config));
      req.headers.addAll(
        _basicAuthHeaders(
          config.username,
          password,
          extra: {
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
        ),
      );
      req.body =
          '<?xml version="1.0" encoding="utf-8" ?>'
          '<D:propfind xmlns:D="DAV:"><D:prop>'
          '<D:displayname/><D:getcontentlength/><D:getlastmodified/>'
          '</D:prop></D:propfind>';

      final streamed = await client.send(req);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 401 || streamed.statusCode == 403) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.authenticationFailed,
          message:
              'WebDAV authentication failed (HTTP ${streamed.statusCode}).',
        );
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.networkError,
          message:
              'Failed to list WebDAV folder (HTTP ${streamed.statusCode}).',
        );
      }

      final entries = parseWebDavPropfindXml(body);
      return CloudTransferResult(
        success: true,
        status: CloudTransferStatus.success,
        message: 'Found ${entries.length} backup archive(s).',
        remoteFiles: entries,
      );
    } catch (e) {
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV listing error: $e',
      );
    } finally {
      _disposeClientIfOwned(client);
    }
  }

  Future<CloudTransferResult> downloadWebDavBackup(
    String fileName, {
    required File destinationFile,
  }) async {
    final (config, password) = await _loadCredentials();
    if (!config.isConfigured) {
      return const CloudTransferResult(
        success: false,
        status: CloudTransferStatus.requiresCredentials,
        message: 'WebDAV credentials are not configured.',
      );
    }

    final client = _createClient();
    try {
      final res = await client.get(
        _fileUri(config, fileName),
        headers: _basicAuthHeaders(config.username, password),
      );
      if (res.statusCode == 401 || res.statusCode == 403) {
        return CloudTransferResult(
          success: false,
          status: CloudTransferStatus.authenticationFailed,
          message: 'WebDAV download unauthorized (HTTP ${res.statusCode}).',
        );
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await destinationFile.parent.create(recursive: true);
        await destinationFile.writeAsBytes(res.bodyBytes, flush: true);
        return CloudTransferResult(
          success: true,
          status: CloudTransferStatus.success,
          message: 'Downloaded ${p.basename(fileName)}.',
          downloadedFile: destinationFile,
        );
      }
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV GET failed with HTTP ${res.statusCode}.',
      );
    } catch (e) {
      return CloudTransferResult(
        success: false,
        status: CloudTransferStatus.networkError,
        message: 'WebDAV download error: $e',
      );
    } finally {
      _disposeClientIfOwned(client);
    }
  }

  /// Parses `<response>` blocks from WebDAV PROPFIND XML responses regardless of namespace prefix (`D:`, `d:`, default).
  @visibleForTesting
  static List<CloudRemoteBackupEntry> parseWebDavPropfindXml(String xmlBody) {
    final responseRegex = RegExp(
      r'<(?:\w+:)?response\b[^>]*>([\s\S]*?)<\/(?:\w+:)?response>',
      caseSensitive: false,
    );
    final hrefRegex = RegExp(
      r'<(?:\w+:)?href\b[^>]*>([\s\S]*?)<\/(?:\w+:)?href>',
      caseSensitive: false,
    );
    final lenRegex = RegExp(
      r'<(?:\w+:)?getcontentlength\b[^>]*>(\d+)<\/(?:\w+:)?getcontentlength>',
      caseSensitive: false,
    );
    final modRegex = RegExp(
      r'<(?:\w+:)?getlastmodified\b[^>]*>([\s\S]*?)<\/(?:\w+:)?getlastmodified>',
      caseSensitive: false,
    );

    final results = <CloudRemoteBackupEntry>[];
    for (final match in responseRegex.allMatches(xmlBody)) {
      final block = match.group(1) ?? '';
      final href = hrefRegex.firstMatch(block)?.group(1)?.trim() ?? '';
      if (href.isEmpty || href.endsWith('/')) continue;
      final decodedName = Uri.decodeComponent(p.basename(href));
      if (!decodedName.endsWith('.scaneliq') && !decodedName.endsWith('.zip')) {
        continue;
      }
      final sizeBytes =
          int.tryParse(lenRegex.firstMatch(block)?.group(1) ?? '') ?? 0;
      final lastMod = modRegex.firstMatch(block)?.group(1)?.trim();
      results.add(
        CloudRemoteBackupEntry(
          name: decodedName,
          href: href,
          sizeBytes: sizeBytes,
          lastModified: lastMod,
        ),
      );
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Honest OAuth Cloud Provider Pre-Flight (No Fake Cloud Mocks)
  // ---------------------------------------------------------------------------

  CloudTransferResult checkOAuthProviderAvailability(
    CloudProviderType provider,
  ) {
    switch (provider) {
      case CloudProviderType.webdav:
        return const CloudTransferResult(
          success: true,
          status: CloudTransferStatus.success,
          message: 'WebDAV / Nextcloud / OwnCloud transport is ready locally.',
        );
      case CloudProviderType.googleDrive:
        if (AppComplianceConfig.googleDriveClientId.trim().isEmpty) {
          return const CloudTransferResult(
            success: false,
            status: CloudTransferStatus.requiresCredentials,
            message: 'Blocked: Google Drive OAuth requires --dart-define=GOOGLE_DRIVE_CLIENT_ID=<client_id> and Google Cloud OAuth consent configuration.',
          );
        }
        return const CloudTransferResult(
          success: false,
          status: CloudTransferStatus.requiresCredentials,
          message: 'Google Drive OAuth interactive token exchange must be triggered on a signed Android build with configured OAuth SHA-1.',
        );
      case CloudProviderType.dropbox:
        return const CloudTransferResult(
          success: false,
          status: CloudTransferStatus.requiresCredentials,
          message: 'Blocked: Dropbox App Key / OAuth redirect URI is not configured in this build.',
        );
      case CloudProviderType.oneDrive:
        return const CloudTransferResult(
          success: false,
          status: CloudTransferStatus.requiresCredentials,
          message: 'Blocked: Microsoft Entra / OneDrive Client ID is not configured in this build.',
        );
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/services/drive_backup_service.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final backupEngineRepositoryProvider = Provider<BackupEngineRepository>((ref) {
  return BackupEngineRepository(
    databaseHelper: DatabaseHelper.instance,
    secureStorageService: SecureStorageService.instance,
  );
});

class BackupCreateResult {
  const BackupCreateResult({
    required this.filePath,
    required this.fileSizeBytes,
    required this.destination,
  });

  final String filePath;
  final int fileSizeBytes;
  final String destination;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.filePath,
    required this.createdAt,
    required this.tableCount,
    required this.totalRows,
    required this.secureItemCount,
  });

  final String filePath;
  final DateTime createdAt;
  final int tableCount;
  final int totalRows;
  final int secureItemCount;
}

class BackupEngineRepository {
  BackupEngineRepository({
    required this.databaseHelper,
    required this.secureStorageService,
  });

  final DatabaseHelper databaseHelper;
  final SecureStorageService secureStorageService;
  static const Uuid _uuid = Uuid();
  static const String _backupFormat = 'SANCHITA_BACKUP_V1';
  static const String googleDriveFileScope =
      'https://www.googleapis.com/auth/drive.file';
  static const Set<String> _allowedBackupDestinations = <String>{
    'drive',
    'local',
    'share',
  };
  static const Set<String> _allowedRestoreSources = <String>{
    'drive',
    'file',
    'local',
  };
  static const int _kdfIterations = 4000;
  static const List<String> _restoreTableOrder = <String>[
    'app_settings',
    'security',
    'categories',
    'groups',
    'group_members',
    'budgets',
    'recurring_rules',
    'group_budgets',
    'transactions',
    'group_transactions',
    'group_recurring_rules',
    'recurring_log',
    'search_history',
    'backup_log',
  ];

  Future<Result<BackupCreateResult>> createEncryptedBackup({
    required String destination,
    required String secret,
    List<String> oauthScopes = const <String>[],
  }) async {
    final normalizedDestination = destination.trim().toLowerCase();
    if (normalizedDestination.isEmpty) {
      return const Result<BackupCreateResult>.failure(
        'Backup destination is required.',
      );
    }
    if (!_allowedBackupDestinations.contains(normalizedDestination)) {
      return Result<BackupCreateResult>.failure(
        'Unsupported backup destination "$normalizedDestination".',
      );
    }
    final destinationScopeError = _validateDriveScopePolicy(
      channel: normalizedDestination,
      oauthScopes: oauthScopes,
    );
    if (destinationScopeError != null) {
      return Result<BackupCreateResult>.failure(destinationScopeError);
    }

    final normalizedSecret = secret.trim();
    if (normalizedSecret.isEmpty) {
      return const Result<BackupCreateResult>.failure(
        'PIN/password is required for backup encryption.',
      );
    }

    try {
      final payload = await _buildPayload();
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final envelope = _encryptPayload(
        payloadBytes: payloadBytes,
        secret: normalizedSecret,
      );

      final backupDirectory = await _ensureBackupDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeDestination = normalizedDestination
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName = 'sanchita_${safeDestination}_$timestamp.sanchita';
      final file = File(join(backupDirectory.path, fileName));
      final encodedEnvelope = jsonEncode(envelope);
      await file.writeAsString(encodedEnvelope, flush: true);
      final bytes = await file.length();

      // Handle different destinations
      String finalPath = file.path;
      if (normalizedDestination == 'drive') {
        // Upload to Google Drive
        final driveService = DriveBackupService();
        final fileBytes = await file.readAsBytes();
        try {
          await driveService.uploadBackup(fileBytes, fileName);
          // Delete local copy after successful upload
          await file.delete();
          finalPath = 'drive:$fileName'; // Mark as uploaded to Drive
        } catch (uploadError) {
          // If upload fails, keep local copy and log error
          await _insertBackupLog(
            destination: normalizedDestination,
            fileSizeBytes: bytes,
            status: 'failed',
            errorMessage: 'Google Drive upload failed: $uploadError',
          );
          return Result<BackupCreateResult>.failure(
            'Failed to upload backup to Google Drive: $uploadError',
          );
        }
      }
      // For 'local' and 'share', file is already saved locally

      await _insertBackupLog(
        destination: normalizedDestination,
        fileSizeBytes: bytes,
        status: 'success',
      );

      return Result<BackupCreateResult>.success(
        BackupCreateResult(
          filePath: finalPath,
          fileSizeBytes: bytes,
          destination: normalizedDestination,
        ),
      );
    } catch (error) {
      await _insertBackupLog(
        destination: normalizedDestination,
        fileSizeBytes: 0,
        status: 'failed',
        errorMessage: '$error',
      );
      return Result<BackupCreateResult>.failure(
        'Failed to create encrypted backup: $error',
      );
    }
  }

  Future<Result<BackupRestoreResult>> restoreLatestBackup({
    required String source,
    required String secret,
    List<String> oauthScopes = const <String>[],
  }) async {
    final normalizedSource = source.trim().toLowerCase();
    final normalizedSecret = secret.trim();
    if (normalizedSource.isEmpty) {
      return const Result<BackupRestoreResult>.failure(
        'Backup source is required.',
      );
    }
    if (!_allowedRestoreSources.contains(normalizedSource)) {
      return Result<BackupRestoreResult>.failure(
        'Unsupported restore source "$normalizedSource".',
      );
    }
    final sourceScopeError = _validateDriveScopePolicy(
      channel: normalizedSource,
      oauthScopes: oauthScopes,
    );
    if (sourceScopeError != null) {
      return Result<BackupRestoreResult>.failure(sourceScopeError);
    }
    if (normalizedSecret.isEmpty) {
      return const Result<BackupRestoreResult>.failure(
        'PIN/password is required for backup decryption.',
      );
    }

    File? backupFile;
    try {
      backupFile = await _resolveLatestBackupFile(normalizedSource);
      if (backupFile == null) {
        return Result<BackupRestoreResult>.failure(
          'No .sanchita backup file found for source "$normalizedSource".',
        );
      }

      final content = await backupFile.readAsString();
      final payloadResult = _decryptPayload(
        envelopeString: content,
        secret: normalizedSecret,
      );

      return await payloadResult.when(
        success: (payload) async {
          final validationError = _validatePayload(payload);
          if (validationError != null) {
            return Result<BackupRestoreResult>.failure(validationError);
          }

          final restoreSummary = await _replaceAppState(payload);
          final backupSizeBytes = await backupFile!.length();
          await _insertBackupLog(
            destination: 'restore:$normalizedSource',
            fileSizeBytes: backupSizeBytes,
            status: 'success',
          );

          return Result<BackupRestoreResult>.success(
            BackupRestoreResult(
              filePath: backupFile.path,
              createdAt: restoreSummary.createdAt,
              tableCount: restoreSummary.tableCount,
              totalRows: restoreSummary.totalRows,
              secureItemCount: restoreSummary.secureItemCount,
            ),
          );
        },
        failure: (message) async {
          final failedSize = backupFile == null ? 0 : await backupFile.length();
          await _insertBackupLog(
            destination: 'restore:$normalizedSource',
            fileSizeBytes: failedSize,
            status: 'failed',
            errorMessage: message,
          );
          return Result<BackupRestoreResult>.failure(message);
        },
      );
    } catch (error) {
      final failedSize = backupFile == null ? 0 : await backupFile.length();
      await _insertBackupLog(
        destination: 'restore:$normalizedSource',
        fileSizeBytes: failedSize,
        status: 'failed',
        errorMessage: '$error',
      );
      return Result<BackupRestoreResult>.failure(
        'Restore failed before data replacement: $error',
      );
    }
  }

  Future<Map<String, Object?>> _buildPayload() async {
    final db = await databaseHelper.database;
    final tableRows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ORDER BY name ASC
      ''',
    );

    final tables = <String, Object?>{};
    for (final row in tableRows) {
      final tableName = row['name'] as String? ?? '';
      if (tableName.isEmpty ||
          tableName == 'android_metadata' ||
          tableName.startsWith('sqlite_')) {
        continue;
      }
      final rows = await db.query(tableName);
      tables[tableName] = rows
          .map<Map<String, Object?>>(_encodeDatabaseRow)
          .toList(growable: false);
    }

    final secureValues = await secureStorageService.readAll();
    final now = DateTime.now().toIso8601String();

    return <String, Object?>{
      'format': _backupFormat,
      'app': 'sanchita',
      'createdAt': now,
      'database': <String, Object?>{'tables': tables},
      'secureStorage': secureValues,
    };
  }

  Map<String, Object?> _encodeDatabaseRow(Map<String, Object?> row) {
    final encoded = <String, Object?>{};
    for (final entry in row.entries) {
      final value = entry.value;
      if (value is Uint8List) {
        encoded[entry.key] = <String, Object?>{
          '@type': 'bytes',
          'data': base64Encode(value),
        };
      } else {
        encoded[entry.key] = value;
      }
    }
    return encoded;
  }

  Map<String, Object?> _encryptPayload({
    required List<int> payloadBytes,
    required String secret,
  }) {
    final salt = _randomBytes(16);
    final iv = _randomBytes(16);
    final key = _deriveKey(secret: secret, salt: salt);
    final stream = _buildStream(key: key, iv: iv, length: payloadBytes.length);

    final encrypted = Uint8List(payloadBytes.length);
    for (var index = 0; index < payloadBytes.length; index++) {
      encrypted[index] = payloadBytes[index] ^ stream[index];
    }

    final macPayload = <int>[...iv, ...encrypted];
    final mac = Hmac(sha256, key).convert(macPayload).toString();

    return <String, Object?>{
      'format': _backupFormat,
      'kdf': <String, Object?>{
        'name': 'sha256-iter',
        'iterations': _kdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': <String, Object?>{
        'name': 'xor-sha256-stream',
        'iv': base64Encode(iv),
      },
      'mac': mac,
      'data': base64Encode(encrypted),
    };
  }

  Result<Map<String, Object?>> _decryptPayload({
    required String envelopeString,
    required String secret,
  }) {
    try {
      final decodedEnvelope = jsonDecode(envelopeString);
      final envelope = _asMap(decodedEnvelope);
      if (envelope == null) {
        return const Result<Map<String, Object?>>.failure(
          'Backup file format is invalid.',
        );
      }
      if ((envelope['format'] as String?) != _backupFormat) {
        return const Result<Map<String, Object?>>.failure(
          'Unsupported backup file format.',
        );
      }

      final kdf = _asMap(envelope['kdf']);
      final cipher = _asMap(envelope['cipher']);
      if (kdf == null || cipher == null) {
        return const Result<Map<String, Object?>>.failure(
          'Backup key/cipher metadata is missing.',
        );
      }

      final saltString = kdf['salt'] as String?;
      final ivString = cipher['iv'] as String?;
      final dataString = envelope['data'] as String?;
      final macHex = envelope['mac'] as String?;
      if (saltString == null ||
          ivString == null ||
          dataString == null ||
          macHex == null) {
        return const Result<Map<String, Object?>>.failure(
          'Backup file is missing encrypted payload fields.',
        );
      }

      final salt = base64Decode(saltString);
      final iv = base64Decode(ivString);
      final encryptedPayload = base64Decode(dataString);
      final key = _deriveKey(secret: secret, salt: salt);

      final expectedMac = Hmac(
        sha256,
        key,
      ).convert(<int>[...iv, ...encryptedPayload]).bytes;
      final actualMac = _hexToBytes(macHex);
      if (!_constantTimeEquals(actualMac, expectedMac)) {
        return const Result<Map<String, Object?>>.failure(
          'Unable to decrypt backup. PIN/password may be incorrect.',
        );
      }

      final stream = _buildStream(
        key: key,
        iv: iv,
        length: encryptedPayload.length,
      );
      final plainBytes = Uint8List(encryptedPayload.length);
      for (var index = 0; index < encryptedPayload.length; index++) {
        plainBytes[index] = encryptedPayload[index] ^ stream[index];
      }

      final payloadJson = utf8.decode(plainBytes);
      final payload = _asMap(jsonDecode(payloadJson));
      if (payload == null) {
        return const Result<Map<String, Object?>>.failure(
          'Backup payload is invalid.',
        );
      }
      return Result<Map<String, Object?>>.success(payload);
    } catch (error) {
      return Result<Map<String, Object?>>.failure(
        'Backup decode failed: $error',
      );
    }
  }

  String? _validatePayload(Map<String, Object?> payload) {
    if ((payload['format'] as String?) != _backupFormat) {
      return 'Backup payload format is not supported.';
    }
    if ((payload['app'] as String?) != 'sanchita') {
      return 'Backup file does not belong to this app.';
    }

    final database = _asMap(payload['database']);
    if (database == null) {
      return 'Backup database payload is missing.';
    }
    final tables = _asMap(database['tables']);
    if (tables == null || tables.isEmpty) {
      return 'Backup database payload is empty.';
    }

    final secureStorage = _asMap(payload['secureStorage']);
    if (secureStorage == null) {
      return 'Backup secure storage payload is missing.';
    }

    if (!tables.containsKey('app_settings') || !tables.containsKey('security')) {
      return 'Backup file is missing required singleton data.';
    }

    // Defensive null return - validation failed
    return null;
  }

  Future<({DateTime createdAt, int tableCount, int totalRows, int secureItemCount})>
  _replaceAppState(Map<String, Object?> payload) async {
    final databasePayload = _asMap(payload['database'])!;
    final tablePayload = _asMap(databasePayload['tables'])!;
    final securePayload = _asMap(payload['secureStorage'])!;
    final createdAt =
        DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
        DateTime.now();

    await secureStorageService.deleteAll();
    for (final entry in securePayload.entries) {
      final value = entry.value;
      if (value is String) {
        await secureStorageService.write(key: entry.key, value: value);
      } else if (value != null) {
        await secureStorageService.write(key: entry.key, value: '$value');
      }
    }

    await databaseHelper.resetDatabase();
    final db = await databaseHelper.database;
    final existingTables = await _readTableNames(db);

    final tableNames = tablePayload.keys.where(existingTables.contains).toList()
      ..sort();

    final orderedTables = <String>[
      ..._restoreTableOrder.where(tableNames.contains),
      ...tableNames.where((name) => !_restoreTableOrder.contains(name)),
    ];

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.transaction((txn) async {
        for (final tableName in orderedTables) {
          final tableRows = _asList(tablePayload[tableName]);
          if (tableRows == null) {
            continue;
          }

          await txn.delete(tableName);
          for (final rawRow in tableRows) {
            final rowMap = _asMap(rawRow);
            if (rowMap == null || rowMap.isEmpty) {
              continue;
            }

            final decoded = <String, Object?>{};
            for (final entry in rowMap.entries) {
              final value = entry.value;
              final typedValue = _decodePayloadValue(value);
              decoded[entry.key] = typedValue;
            }

            if (decoded.isNotEmpty) {
              await txn.insert(
                tableName,
                decoded,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    var rowCount = 0;
    for (final tableName in orderedTables) {
      final rows = _asList(tablePayload[tableName]);
      rowCount += rows?.length ?? 0;
    }

    return (
      createdAt: createdAt,
      tableCount: orderedTables.length,
      totalRows: rowCount,
      secureItemCount: securePayload.length,
    );
  }

  Object? _decodePayloadValue(Object? value) {
    final map = _asMap(value);
    if (map == null) {
      return value;
    }
    if (map['@type'] == 'bytes') {
      final data = map['data'] as String? ?? '';
      try {
        return base64Decode(data);
      } catch (_) {
        return Uint8List(0);
      }
    }
    return value;
  }

  Future<Directory> _ensureBackupDirectory() async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(join(rootDirectory.path, 'backups'));
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }
    return backupDirectory;
  }

  Future<File?> _resolveLatestBackupFile(String source) async {
    // 'file' source: let user pick a .sanchita file from device storage
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final path = result.files.single.path;
      if (path == null) {
        return null;
      }
      return File(path);
    }

    // 'drive' source: download latest from Google Drive
    if (source == 'drive') {
      final driveService = DriveBackupService();
      final backups = await driveService.listBackups();
      if (backups.isEmpty) {
        return null;
      }
      final latest = backups.first;
      final bytes = await driveService.downloadBackup(latest.id);
      final backupDirectory = await _ensureBackupDirectory();
      final tempFile = File(join(backupDirectory.path, '_drive_restore.sanchita'));
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile;
    }

    // 'local' source: find latest backup in internal directory
    final backupDirectory = await _ensureBackupDirectory();
    final entities = await backupDirectory.list().toList();
    final files = entities
        .whereType<File>()
        .where((file) => extension(file.path).toLowerCase() == '.sanchita')
        .toList();

    if (files.isEmpty) {
      return null;
    }

    final preferred = files.where((file) {
      final lower = basename(file.path).toLowerCase();
      return lower.contains('_${source}_');
    }).toList();

    final candidates = preferred.isEmpty ? files : preferred;
    candidates.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });
    return candidates.first;
  }

  Future<Set<String>> _readTableNames(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ''',
    );
    return rows
        .map((row) => row['name'] as String? ?? '')
        .where((name) {
          return name.isNotEmpty &&
              name != 'android_metadata' &&
              !name.startsWith('sqlite_');
        })
        .toSet();
  }

  Future<void> _insertBackupLog({
    required String destination,
    required int fileSizeBytes,
    required String status,
    String? errorMessage,
  }) async {
    try {
      final db = await databaseHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.insert('backup_log', <String, Object?>{
        'id': _uuid.v4(),
        'backup_date': now,
        'destination': destination,
        'file_size_bytes': fileSizeBytes,
        'status': status,
        'error_message': errorMessage,
        'created_at': now,
      });
    } catch (_) {
      // Backup log write errors should not hide primary operation result.
    }
  }

  List<int> _deriveKey({required String secret, required List<int> salt}) {
    final seed = <int>[...salt, ...utf8.encode(secret)];
    var digest = sha256.convert(seed).bytes;
    for (var round = 1; round < _kdfIterations; round++) {
      digest = sha256.convert(<int>[...digest, ...seed]).bytes;
    }
    return digest;
  }

  List<int> _buildStream({
    required List<int> key,
    required List<int> iv,
    required int length,
  }) {
    final output = <int>[];
    var blockCounter = 0;
    while (output.length < length) {
      final counterData = ByteData(8)..setUint64(0, blockCounter, Endian.big);
      final block = sha256.convert(
        <int>[...key, ...iv, ...counterData.buffer.asUint8List()],
      );
      output.addAll(block.bytes);
      blockCounter++;
    }
    return output.sublist(0, length);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _hexToBytes(String hex) {
    final normalized = hex.trim().toLowerCase();
    if (normalized.length.isOdd) {
      return const <int>[];
    }
    final bytes = <int>[];
    for (var index = 0; index < normalized.length; index += 2) {
      final chunk = normalized.substring(index, index + 2);
      final value = int.tryParse(chunk, radix: 16);
      if (value == null) {
        return const <int>[];
      }
      bytes.add(value);
    }
    return bytes;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var diff = 0;
    for (var index = 0; index < left.length; index++) {
      diff |= left[index] ^ right[index];
    }
    return diff == 0;
  }

  Map<String, Object?>? _asMap(Object? value) {
    if (value is! Map) {
    // Defensive null return - validation failed
      return null;
    }
    final map = <String, Object?>{};
    for (final entry in value.entries) {
      map['${entry.key}'] = entry.value;
    }
    return map;
  }

  List<Object?>? _asList(Object? value) {
    if (value is! List) {
    // Defensive null return - validation failed
      return null;
    }
    return value.cast<Object?>();
  }

  String? _validateDriveScopePolicy({
    required String channel,
    required List<String> oauthScopes,
  }) {
    if (channel != 'drive') {
    // Defensive null return - validation failed
      return null;
    }

    final normalizedScopes = oauthScopes
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toSet();
    if (normalizedScopes.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    if (normalizedScopes.length != 1 ||
        !normalizedScopes.contains(googleDriveFileScope)) {
      return 'Google Drive backup must use only $googleDriveFileScope scope.';
    }
    // Defensive null return - validation failed
    return null;
  }
}

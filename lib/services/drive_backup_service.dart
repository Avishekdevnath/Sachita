import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as ga;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// HTTP client that adds Google auth headers to requests
class _AuthenticatedHttpClient extends http.BaseClient {
  final Map<String, String> _authHeaders;
  final http.Client _innerClient = http.Client();

  _AuthenticatedHttpClient(this._authHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_authHeaders);
    return _innerClient.send(request);
  }
}

class DriveBackupService {
  static const _scopes = [ga.DriveApi.driveFileScope];

  late final GoogleSignIn _googleSignIn;
  ga.DriveApi? _driveApi;

  DriveBackupService() {
    _googleSignIn = GoogleSignIn(scopes: _scopes);
  }

  /// Check if user is signed in to Google
  Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }

  /// Get current signed-in account
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Sign in with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      if (kDebugMode) print('Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
  }

  /// Initialize Drive API after sign-in
  Future<void> _initDriveApi() async {
    if (_driveApi != null) return;

    var user = _googleSignIn.currentUser;
    if (user == null) {
      user = await signIn();
      if (user == null) {
        throw Exception('Failed to sign in to Google');
      }
    }

    final authHeaders = await user.authHeaders;
    final authenticatedClient = _AuthenticatedHttpClient(authHeaders);
    _driveApi = ga.DriveApi(authenticatedClient);
  }

  /// Create or get Sanchita Backups folder in Drive
  Future<String> _getOrCreateBackupFolder() async {
    await _initDriveApi();

    const folderName = 'Sanchita Backups';
    const mimeType = 'application/vnd.google-apps.folder';

    try {
      // Search for existing folder
      // ignore: prefer_const_declarations
      final query = "name='$folderName' and mimeType='$mimeType' and trashed=false";
      final result = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        pageSize: 1,
        $fields: 'files(id, name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id!;
      }

      // Create new folder
      final folder = ga.File()
        ..name = folderName
        ..mimeType = mimeType;

      final created = await _driveApi!.files.create(folder);
      return created.id!;
    } catch (e) {
      if (kDebugMode) print('Error creating backup folder: $e');
      rethrow;
    }
  }

  /// Upload backup file to Drive
  Future<String> uploadBackup(List<int> fileBytes, String fileName) async {
    try {
      final folderId = await _getOrCreateBackupFolder();

      final driveFile = ga.File()
        ..name = fileName
        ..parents = [folderId];

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: ga.Media(Stream.fromIterable([fileBytes]), fileBytes.length),
      );

      return result.id ?? '';
    } catch (e) {
      if (kDebugMode) print('Error uploading backup: $e');
      rethrow;
    }
  }

  /// List all backups in Drive
  Future<List<BackupFile>> listBackups() async {
    try {
      await _initDriveApi();

      final folderId = await _getOrCreateBackupFolder();

      final query = "'$folderId' in parents and trashed=false";
      final result = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        pageSize: 50,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final backups = <BackupFile>[];
      if (result.files != null) {
        for (final file in result.files!) {
          backups.add(BackupFile(
            id: file.id ?? '',
            name: file.name ?? '',
            modifiedTime: file.modifiedTime ?? DateTime.now(),
            size: int.tryParse(file.size ?? '0') ?? 0,
          ));
        }
      }
      return backups;
    } catch (e) {
      if (kDebugMode) print('Error listing backups: $e');
      rethrow;
    }
  }

  /// Download backup file from Drive
  Future<List<int>> downloadBackup(String fileId) async {
    try {
      await _initDriveApi();

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: ga.DownloadOptions.fullMedia,
      ) as ga.Media;

      final bytes = <int>[];
      await media.stream.forEach((chunk) {
        bytes.addAll(chunk);
      });

      return bytes;
    } catch (e) {
      if (kDebugMode) print('Error downloading backup: $e');
      rethrow;
    }
  }

  /// Delete backup from Drive
  Future<void> deleteBackup(String fileId) async {
    try {
      await _initDriveApi();
      await _driveApi!.files.delete(fileId);
    } catch (e) {
      if (kDebugMode) print('Error deleting backup: $e');
      rethrow;
    }
  }
}

/// Backup file metadata
class BackupFile {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final int size;

  BackupFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    required this.size,
  });

  String get formattedDate {
    return DateFormat('MMM dd, yyyy HH:mm').format(modifiedTime);
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

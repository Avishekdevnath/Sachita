import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/drive_backup_service.dart';

class DriveBackupState {
  final GoogleSignInAccount? currentUser;
  final List<BackupFile> backups;
  final bool isLoading;
  final String? error;

  DriveBackupState({
    this.currentUser,
    this.backups = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isSignedIn => currentUser != null;

  DriveBackupState copyWith({
    GoogleSignInAccount? currentUser,
    List<BackupFile>? backups,
    bool? isLoading,
    String? error,
  }) {
    return DriveBackupState(
      currentUser: currentUser ?? this.currentUser,
      backups: backups ?? this.backups,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DriveBackupNotifier extends Notifier<DriveBackupState> {
  late final DriveBackupService _service;
  bool _disposed = false;

  @override
  DriveBackupState build() {
    _service = DriveBackupService();
    ref.onDispose(() => _disposed = true);
    _checkSignInStatus();
    return DriveBackupState();
  }

  /// Check if already signed in
  Future<void> _checkSignInStatus() async {
    try {
      final isSignedIn = await _service.isSignedIn();
      if (_disposed) return;
      if (isSignedIn) {
        final user = _service.currentUser;
        state = state.copyWith(currentUser: user);
      }
    } catch (e) {
      if (kDebugMode) print('Failed to check sign-in status: $e');
    }
  }

  /// Sign in to Google
  Future<void> signIn() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _service.signIn();
      final user = _service.currentUser;
      state = state.copyWith(currentUser: user, isLoading: false, error: null);

      await refreshBackups();
    } catch (e) {
      final error = 'Sign-in failed: $e';
      if (kDebugMode) print(error);
      state = state.copyWith(error: error, isLoading: false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _service.signOut();
      state = DriveBackupState();
    } catch (e) {
      final error = 'Sign-out failed: $e';
      if (kDebugMode) print(error);
      state = DriveBackupState(error: error);
    }
  }

  /// Refresh backup list
  Future<void> refreshBackups() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final backups = await _service.listBackups();
      state = state.copyWith(backups: backups, isLoading: false, error: null);
    } catch (e) {
      final error = 'Failed to load backups: $e';
      if (kDebugMode) print(error);
      state = state.copyWith(error: error, isLoading: false);
    }
  }

  /// Upload backup
  Future<bool> uploadBackup(List<int> fileBytes, String fileName) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _service.uploadBackup(fileBytes, fileName);
      await refreshBackups();
      return true;
    } catch (e) {
      final error = 'Upload failed: $e';
      if (kDebugMode) print(error);
      state = state.copyWith(error: error, isLoading: false);
      return false;
    }
  }

  /// Download backup
  Future<List<int>?> downloadBackup(String fileId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final bytes = await _service.downloadBackup(fileId);
      state = state.copyWith(isLoading: false);
      return bytes;
    } catch (e) {
      final error = 'Download failed: $e';
      if (kDebugMode) print(error);
      state = state.copyWith(error: error, isLoading: false);
    // Defensive null return - validation failed
      return null;
    }
  }

  /// Delete backup
  Future<bool> deleteBackup(String fileId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _service.deleteBackup(fileId);
      await refreshBackups();
      return true;
    } catch (e) {
      final error = 'Delete failed: $e';
      if (kDebugMode) print(error);
      state = state.copyWith(error: error, isLoading: false);
      return false;
    }
  }
}

// Riverpod provider
final driveBackupProvider = NotifierProvider<DriveBackupNotifier, DriveBackupState>(() {
  return DriveBackupNotifier();
});

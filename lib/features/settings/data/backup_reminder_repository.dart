import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/shared/models/result.dart';

final backupReminderRepositoryProvider = Provider<BackupReminderRepository>((
  ref,
) {
  return BackupReminderRepository(
    databaseHelper: DatabaseHelper.instance,
    secureStorageService: SecureStorageService.instance,
  );
});

class BackupReminderSettingsModel {
  const BackupReminderSettingsModel({
    required this.enabled,
    required this.intervalDays,
    required this.nextReminderAt,
    required this.lastSuccessfulBackupAt,
  });

  final bool enabled;
  final int intervalDays;
  final DateTime? nextReminderAt;
  final DateTime? lastSuccessfulBackupAt;

  bool get isDue {
    if (!enabled || nextReminderAt == null) {
      return false;
    }
    return !nextReminderAt!.isAfter(DateTime.now());
  }
}

class BackupReminderRepository {
  BackupReminderRepository({
    required this.databaseHelper,
    required this.secureStorageService,
  });

  final DatabaseHelper databaseHelper;
  final SecureStorageService secureStorageService;

  static const String _enabledKey = 'backup_reminder_enabled';
  static const String _intervalDaysKey = 'backup_reminder_interval_days';
  static const String _nextDueKey = 'backup_reminder_next_due';
  static const int _defaultIntervalDays = 7;

  Future<Result<BackupReminderSettingsModel>> getSettings() async {
    try {
      final enabledRaw = await secureStorageService.read(_enabledKey);
      final intervalRaw = await secureStorageService.read(_intervalDaysKey);
      final nextDueRaw = await secureStorageService.read(_nextDueKey);

      final enabled = enabledRaw == '1';
      var intervalDays = int.tryParse(intervalRaw ?? '');
      if (intervalDays == null || intervalDays <= 0) {
        intervalDays = _defaultIntervalDays;
      }

      final lastSuccessfulBackupAt = await _readLastSuccessfulBackupDate();
      DateTime? nextReminderAt = DateTime.tryParse(nextDueRaw ?? '');
      if (enabled && nextReminderAt == null) {
        final base = lastSuccessfulBackupAt ?? DateTime.now();
        nextReminderAt = base.add(Duration(days: intervalDays));
      }

      return Result<BackupReminderSettingsModel>.success(
        BackupReminderSettingsModel(
          enabled: enabled,
          intervalDays: intervalDays,
          nextReminderAt: nextReminderAt,
          lastSuccessfulBackupAt: lastSuccessfulBackupAt,
        ),
      );
    } catch (error) {
      return Result<BackupReminderSettingsModel>.failure(
        'Failed to load backup reminder settings: $error',
      );
    }
  }

  Future<Result<void>> updateSettings({
    required bool enabled,
    required int intervalDays,
  }) async {
    try {
      final normalizedInterval = intervalDays <= 0
          ? _defaultIntervalDays
          : intervalDays;
      await secureStorageService.write(
        key: _enabledKey,
        value: enabled ? '1' : '0',
      );
      await secureStorageService.write(
        key: _intervalDaysKey,
        value: '$normalizedInterval',
      );

      if (!enabled) {
        await secureStorageService.delete(_nextDueKey);
        return const Result<void>.success(null);
      }

      final lastSuccessfulBackupAt = await _readLastSuccessfulBackupDate();
      final base = lastSuccessfulBackupAt ?? DateTime.now();
      final nextDue = base.add(Duration(days: normalizedInterval));
      await secureStorageService.write(
        key: _nextDueKey,
        value: nextDue.toIso8601String(),
      );
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to update backup reminder settings: $error',
      );
    }
  }

  Future<Result<void>> markBackupCompleted() async {
    try {
      final settingsResult = await getSettings();
      final settings = settingsResult.when(
        success: (value) => value,
        failure: (_) => null,
      );
      if (settings == null || !settings.enabled) {
        return const Result<void>.success(null);
      }

      final nextDue = DateTime.now().add(Duration(days: settings.intervalDays));
      await secureStorageService.write(
        key: _nextDueKey,
        value: nextDue.toIso8601String(),
      );
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to schedule next reminder: $error');
    }
  }

  Future<DateTime?> _readLastSuccessfulBackupDate() async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      'backup_log',
      columns: <String>['backup_date'],
      where: 'status = ? AND destination NOT LIKE ?',
      whereArgs: <Object>['success', 'restore:%'],
      orderBy: 'backup_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    final raw = rows.first['backup_date'] as String? ?? '';
    return DateTime.tryParse(raw);
  }
}

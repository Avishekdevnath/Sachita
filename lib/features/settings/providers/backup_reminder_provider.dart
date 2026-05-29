import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/settings/data/backup_reminder_repository.dart';

class BackupReminderState {
  const BackupReminderState({
    this.enabled = false,
    this.intervalDays = 7,
    this.nextReminderAt,
    this.lastSuccessfulBackupAt,
    this.errorMessage,
  });

  final bool enabled;
  final int intervalDays;
  final DateTime? nextReminderAt;
  final DateTime? lastSuccessfulBackupAt;
  final String? errorMessage;

  bool get isDue {
    if (!enabled || nextReminderAt == null) {
      return false;
    }
    return !nextReminderAt!.isAfter(DateTime.now());
  }

  BackupReminderState copyWith({
    bool? enabled,
    int? intervalDays,
    DateTime? nextReminderAt,
    bool clearNextReminderAt = false,
    DateTime? lastSuccessfulBackupAt,
    bool clearLastBackupAt = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BackupReminderState(
      enabled: enabled ?? this.enabled,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReminderAt: clearNextReminderAt
          ? null
          : (nextReminderAt ?? this.nextReminderAt),
      lastSuccessfulBackupAt: clearLastBackupAt
          ? null
          : (lastSuccessfulBackupAt ?? this.lastSuccessfulBackupAt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final backupReminderProvider =
    AsyncNotifierProvider<BackupReminderNotifier, BackupReminderState>(
      BackupReminderNotifier.new,
    );

class BackupReminderNotifier extends AsyncNotifier<BackupReminderState> {
  BackupReminderRepository get _repository =>
      ref.read(backupReminderRepositoryProvider);

  @override
  Future<BackupReminderState> build() async {
    return _load(const BackupReminderState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const BackupReminderState();
    state = const AsyncLoading();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.asData?.value ?? const BackupReminderState();
    final result = await _repository.updateSettings(
      enabled: enabled,
      intervalDays: current.intervalDays,
    );

    await result.when(
      success: (_) async {
        await refresh();
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setIntervalDays(int intervalDays) async {
    final current = state.asData?.value ?? const BackupReminderState();
    final result = await _repository.updateSettings(
      enabled: current.enabled,
      intervalDays: intervalDays,
    );

    await result.when(
      success: (_) async {
        await refresh();
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> markBackupCompleted() async {
    final current = state.asData?.value ?? const BackupReminderState();
    final result = await _repository.markBackupCompleted();
    await result.when(
      success: (_) async {
        await refresh();
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<BackupReminderState> _load(BackupReminderState source) async {
    final result = await _repository.getSettings();
    return result.when(
      success: (settings) {
        return source.copyWith(
          enabled: settings.enabled,
          intervalDays: settings.intervalDays,
          nextReminderAt: settings.nextReminderAt,
          clearNextReminderAt: settings.nextReminderAt == null,
          lastSuccessfulBackupAt: settings.lastSuccessfulBackupAt,
          clearLastBackupAt: settings.lastSuccessfulBackupAt == null,
          clearError: true,
        );
      },
      failure: (message) {
        return source.copyWith(errorMessage: message);
      },
    );
  }
}

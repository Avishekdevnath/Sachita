import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/settings/data/backup_overview_repository.dart';

class BackupOverviewState {
  const BackupOverviewState({
    this.storage,
    this.history = const <BackupHistoryModel>[],
    this.errorMessage,
  });

  final StorageOverviewModel? storage;
  final List<BackupHistoryModel> history;
  final String? errorMessage;

  BackupOverviewState copyWith({
    StorageOverviewModel? storage,
    List<BackupHistoryModel>? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BackupOverviewState(
      storage: storage ?? this.storage,
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final backupOverviewProvider =
    AsyncNotifierProvider<BackupOverviewNotifier, BackupOverviewState>(
      BackupOverviewNotifier.new,
    );

class BackupOverviewNotifier extends AsyncNotifier<BackupOverviewState> {
  BackupOverviewRepository get _repository =>
      ref.read(backupOverviewRepositoryProvider);

  @override
  Future<BackupOverviewState> build() async {
    return _load(const BackupOverviewState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const BackupOverviewState();
    state = const AsyncLoading();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  Future<BackupOverviewState> _load(BackupOverviewState source) async {
    final storageResult = await _repository.getStorageOverview();
    final historyResult = await _repository.getBackupHistory();

    final storage = storageResult.when(
      success: (item) => item,
      failure: (_) => source.storage,
    );
    final history = historyResult.when(
      success: (items) => items,
      failure: (_) => source.history,
    );

    final errors = <String>[];
    storageResult.when(
      success: (_) {},
      failure: (message) {
        errors.add(message);
      },
    );
    historyResult.when(
      success: (_) {},
      failure: (message) {
        errors.add(message);
      },
    );

    return source.copyWith(
      storage: storage,
      history: history,
      errorMessage: errors.isEmpty ? null : errors.join('\n'),
      clearError: errors.isEmpty,
    );
  }
}

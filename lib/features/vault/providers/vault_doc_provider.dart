import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/vault/data/vault_doc_repository.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/features/vault/models/vault_doc_storage_usage_model.dart';

class VaultDocState {
  const VaultDocState({
    this.query = '',
    this.folders = const <VaultDocFolderModel>[],
    this.storageUsage = const VaultDocStorageUsageModel(),
    this.errorMessage,
  });

  final String query;
  final List<VaultDocFolderModel> folders;
  final VaultDocStorageUsageModel storageUsage;
  final String? errorMessage;

  List<VaultDocFolderModel> get filteredFolders {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return folders;
    }

    return folders
        .where((folder) {
          final name = folder.name.toLowerCase();
          return name.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  VaultDocState copyWith({
    String? query,
    List<VaultDocFolderModel>? folders,
    VaultDocStorageUsageModel? storageUsage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VaultDocState(
      query: query ?? this.query,
      folders: folders ?? this.folders,
      storageUsage: storageUsage ?? this.storageUsage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final vaultDocProvider = AsyncNotifierProvider<VaultDocNotifier, VaultDocState>(
  VaultDocNotifier.new,
);

class VaultDocNotifier extends AsyncNotifier<VaultDocState> {
  VaultDocRepository get _repository => ref.read(vaultDocRepositoryProvider);

  @override
  Future<VaultDocState> build() async {
    return _load(const VaultDocState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const VaultDocState();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  void setQuery(String query) {
    final current = state.asData?.value ?? const VaultDocState();
    state = AsyncData(current.copyWith(query: query, clearError: true));
  }

  Future<String?> createFolder(String name) async {
    final current = state.asData?.value ?? const VaultDocState();
    final result = await _repository.createFolder(name: name);
    return await result.when(
      success: (_) async {
        state = AsyncData(await _load(current.copyWith(clearError: true)));
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<String?> renameFolder({
    required String folderId,
    required String name,
  }) async {
    final current = state.asData?.value ?? const VaultDocState();
    final result = await _repository.renameFolder(id: folderId, name: name);
    return await result.when(
      success: (_) async {
        state = AsyncData(await _load(current.copyWith(clearError: true)));
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<String?> deleteFolder(String folderId) async {
    final current = state.asData?.value ?? const VaultDocState();
    final result = await _repository.deleteFolder(folderId);
    return await result.when(
      success: (_) async {
        state = AsyncData(await _load(current.copyWith(clearError: true)));
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<VaultDocState> _load(VaultDocState source) async {
    final foldersResult = await _repository.getFolders();
    final storageResult = await _repository.getStorageUsage();

    final folders = foldersResult.when(
      success: (items) => items,
      failure: (_) => const <VaultDocFolderModel>[],
    );
    final storageUsage = storageResult.when(
      success: (usage) => usage,
      failure: (_) => const VaultDocStorageUsageModel(),
    );

    final firstError = foldersResult.when(
      success: (_) => null,
      failure: (message) => message,
    );

    return source.copyWith(
      folders: folders,
      storageUsage: storageUsage,
      errorMessage: firstError,
      clearError: firstError == null,
    );
  }
}

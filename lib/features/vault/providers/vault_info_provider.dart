import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/vault/data/vault_info_repository.dart';
import 'package:sanchita/features/vault/models/vault_info_item_model.dart';

class VaultInfoState {
  const VaultInfoState({
    this.query = '',
    this.filter = 'all',
    this.items = const <VaultInfoItemModel>[],
    this.errorMessage,
  });

  final String query;
  final String filter;
  final List<VaultInfoItemModel> items;
  final String? errorMessage;

  List<VaultInfoItemModel> get filteredItems {
    final normalizedQuery = query.trim().toLowerCase();
    return items
        .where((item) {
          if (!_passesFilter(item)) {
            return false;
          }

          if (normalizedQuery.isEmpty) {
            return true;
          }

          final label = item.label.toLowerCase();
          final category = item.category.toLowerCase();
          return label.contains(normalizedQuery) ||
              category.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  bool _passesFilter(VaultInfoItemModel item) {
    final normalizedFilter = filter.toLowerCase();
    if (normalizedFilter == 'all') {
      return true;
    }

    final category = item.category.trim().toLowerCase();
    if (normalizedFilter == 'custom') {
      return category != 'ids' &&
          category != 'finance' &&
          category != 'medical' &&
          category != 'general';
    }

    return category == normalizedFilter;
  }

  VaultInfoState copyWith({
    String? query,
    String? filter,
    List<VaultInfoItemModel>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VaultInfoState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final vaultInfoProvider =
    AsyncNotifierProvider<VaultInfoNotifier, VaultInfoState>(
      VaultInfoNotifier.new,
    );

class VaultInfoNotifier extends AsyncNotifier<VaultInfoState> {
  VaultInfoRepository get _repository => ref.read(vaultInfoRepositoryProvider);
  Timer? _searchDebounce;

  @override
  Future<VaultInfoState> build() async {
    return _load(const VaultInfoState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const VaultInfoState();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  void setQuery(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final current = state.asData?.value ?? const VaultInfoState();
      state = AsyncData(current.copyWith(query: query, clearError: true));
    });
  }

  void setFilter(String filter) {
    final current = state.asData?.value ?? const VaultInfoState();
    state = AsyncData(current.copyWith(filter: filter, clearError: true));
  }

  Future<String?> createItem({
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    final current = state.asData?.value ?? const VaultInfoState();
    final result = await _repository.createItem(
      category: category,
      label: label,
      value: value,
      notes: notes,
    );

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

  Future<String?> updateItem({
    required String id,
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    final current = state.asData?.value ?? const VaultInfoState();
    final result = await _repository.updateItem(
      id: id,
      category: category,
      label: label,
      value: value,
      notes: notes,
    );

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

  Future<String?> deleteItem(String id) async {
    final current = state.asData?.value ?? const VaultInfoState();
    final result = await _repository.softDeleteItem(id);

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

  Future<VaultInfoState> _load(VaultInfoState source) async {
    final result = await _repository.getItems();
    return result.when(
      success: (items) {
        return source.copyWith(items: items, clearError: true);
      },
      failure: (message) {
        return source.copyWith(
          items: const <VaultInfoItemModel>[],
          errorMessage: message,
        );
      },
    );
  }
}

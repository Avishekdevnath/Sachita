import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/search/data/search_repository.dart';
import 'package:sanchita/features/search/models/search_result_model.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.sourceFilters = const <String>{'finance', 'groups', 'info'},
    this.results = const <SearchResultModel>[],
    this.recentQueries = const <String>[],
    this.isSearching = false,
    this.errorMessage,
  });

  final String query;
  final Set<String> sourceFilters;
  final List<SearchResultModel> results;
  final List<String> recentQueries;
  final bool isSearching;
  final String? errorMessage;

  SearchState copyWith({
    String? query,
    Set<String>? sourceFilters,
    List<SearchResultModel>? results,
    List<String>? recentQueries,
    bool? isSearching,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      sourceFilters: sourceFilters ?? this.sourceFilters,
      results: results ?? this.results,
      recentQueries: recentQueries ?? this.recentQueries,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, List<SearchResultModel>> get groupedResults {
    final grouped = <String, List<SearchResultModel>>{};
    for (final item in results) {
      final list = grouped[item.source];
      if (list == null) {
        grouped[item.source] = <SearchResultModel>[item];
      } else {
        list.add(item);
      }
    }
    return grouped;
  }
}

final searchProvider = AsyncNotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends AsyncNotifier<SearchState> {
  SearchRepository get _repository => ref.read(searchRepositoryProvider);

  Timer? _debounce;
  int _searchToken = 0;

  @override
  Future<SearchState> build() async {
    ref.onDispose(_cancelDebounce);

    final recentResult = await _repository.getRecentQueries();
    return recentResult.when(
      success: (queries) => SearchState(recentQueries: queries),
      failure: (_) => const SearchState(),
    );
  }

  void updateQuery(String query) {
    final current = state.asData?.value ?? const SearchState();
    final trimmed = query.trim();
    final shouldSearch = trimmed.length >= 2;

    state = AsyncData(
      current.copyWith(
        query: query,
        isSearching: shouldSearch,
        results: shouldSearch ? current.results : const <SearchResultModel>[],
        clearError: true,
      ),
    );

    if (!shouldSearch) {
      _cancelDebounce();
      _searchToken++;
      return;
    }

    _scheduleSearch(immediate: false);
  }

  void toggleSource(String source, bool enabled) {
    final current = state.asData?.value ?? const SearchState();
    final updated = <String>{...current.sourceFilters};
    if (enabled) {
      updated.add(source);
    } else {
      updated.remove(source);
    }

    state = AsyncData(
      current.copyWith(
        sourceFilters: updated,
        isSearching: current.query.trim().length >= 2,
        clearError: true,
      ),
    );

    if (current.query.trim().length >= 2) {
      _scheduleSearch(immediate: true);
    }
  }

  void applyRecentQuery(String query) {
    final current = state.asData?.value ?? const SearchState();
    state = AsyncData(
      current.copyWith(
        query: query,
        isSearching: query.trim().length >= 2,
        clearError: true,
      ),
    );
    if (query.trim().length >= 2) {
      _scheduleSearch(immediate: true);
    }
  }

  Future<void> clearRecentQueries() async {
    final current = state.asData?.value ?? const SearchState();
    final result = await _repository.clearRecentQueries();
    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(recentQueries: const <String>[]));
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> refreshRecentQueries() async {
    final current = state.asData?.value ?? const SearchState();
    final result = await _repository.getRecentQueries();
    result.when(
      success: (queries) {
        state = AsyncData(
          current.copyWith(recentQueries: queries, clearError: true),
        );
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  void _scheduleSearch({required bool immediate}) {
    _cancelDebounce();
    final token = ++_searchToken;
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 300);

    _debounce = Timer(delay, () async {
      final current = state.asData?.value;
      if (current == null) {
        return;
      }

      final query = current.query.trim();
      if (query.length < 2 || token != _searchToken) {
        return;
      }

      final searchResult = await _repository.search(
        query: query,
        sources: current.sourceFilters,
      );
      if (token != _searchToken) {
        return;
      }

      await searchResult.when(
        success: (results) async {
          await _repository.saveRecentQuery(query);
          final recentResult = await _repository.getRecentQueries();
          final recentQueries = recentResult.when(
            success: (queries) => queries,
            failure: (_) => current.recentQueries,
          );

          final latest = state.asData?.value ?? current;
          state = AsyncData(
            latest.copyWith(
              results: results,
              recentQueries: recentQueries,
              isSearching: false,
              clearError: true,
            ),
          );
        },
        failure: (message) async {
          final latest = state.asData?.value ?? current;
          state = AsyncData(
            latest.copyWith(
              results: const <SearchResultModel>[],
              isSearching: false,
              errorMessage: message,
            ),
          );
        },
      );
    });
  }

  void _cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }
}

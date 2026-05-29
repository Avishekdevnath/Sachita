import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/data/transaction_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/models/finance_derived_model.dart';
import 'package:sanchita/features/finance/models/finance_filters_model.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';

class FinanceState {
  const FinanceState({
    this.activeType = 'expense',
    required this.activeMonth,
    this.selectedCategoryId,
    this.filters = const FinanceFilters(),
    this.categories = const <CategoryModel>[],
    this.allCategories = const <CategoryModel>[],
    this.transactions = const <TransactionModel>[],
    this.netBalancePaisa = 0,
    this.monthlyIncomePaisa = 0,
    this.monthlyExpensePaisa = 0,
    this.errorMessage,
  });

  final String activeType;
  final DateTime activeMonth;
  final String? selectedCategoryId;
  final FinanceFilters filters;
  final List<CategoryModel> categories;
  final List<CategoryModel> allCategories;
  final List<TransactionModel> transactions;
  final int netBalancePaisa;
  final int monthlyIncomePaisa;
  final int monthlyExpensePaisa;
  final String? errorMessage;

  FinanceState copyWith({
    String? activeType,
    DateTime? activeMonth,
    String? selectedCategoryId,
    FinanceFilters? filters,
    List<CategoryModel>? categories,
    List<CategoryModel>? allCategories,
    List<TransactionModel>? transactions,
    int? netBalancePaisa,
    int? monthlyIncomePaisa,
    int? monthlyExpensePaisa,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FinanceState(
      activeType: activeType ?? this.activeType,
      activeMonth: activeMonth ?? this.activeMonth,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      filters: filters ?? this.filters,
      categories: categories ?? this.categories,
      allCategories: allCategories ?? this.allCategories,
      transactions: transactions ?? this.transactions,
      netBalancePaisa: netBalancePaisa ?? this.netBalancePaisa,
      monthlyIncomePaisa: monthlyIncomePaisa ?? this.monthlyIncomePaisa,
      monthlyExpensePaisa: monthlyExpensePaisa ?? this.monthlyExpensePaisa,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  CategoryModel? get selectedCategory {
    if (categories.isEmpty) {
      // Defensive null return - validation failed
      return null;
    }

    if (selectedCategoryId == null) {
      return categories.first;
    }

    for (final item in categories) {
      if (item.id == selectedCategoryId) {
        return item;
      }
    }

    return categories.first;
  }
}

final financeProvider = AsyncNotifierProvider<FinanceNotifier, FinanceState>(
  FinanceNotifier.new,
);

/// OPTIMIZATION: Use select() to watch only the transactions list
/// This prevents unnecessary recomputes when other state fields change
final financeGroupedTransactionsProvider =
    Provider<List<FinanceTransactionGroup>>((ref) {
      final transactions = ref.watch(
        financeProvider.select(
          (state) =>
              state.asData?.value.transactions ?? const <TransactionModel>[],
        ),
      );

      if (transactions.isEmpty) {
        return const <FinanceTransactionGroup>[];
      }

      final grouped = <String, List<TransactionModel>>{};
      for (final item in transactions) {
        // OPTIMIZATION: Cache date format key generation
        final key = _formatDateKey(item.date);
        grouped.putIfAbsent(key, () => <TransactionModel>[]).add(item);
      }

      final groups = grouped.entries
          .map((entry) {
            final parsedDate = DateTime.tryParse(entry.key) ?? DateTime.now();
            return FinanceTransactionGroup(
              date: parsedDate,
              items: entry.value,
            );
          })
          .toList(growable: false);
      groups.sort((a, b) => b.date.compareTo(a.date));
      return groups;
    });

/// Quick stats reflect MONTH-WIDE totals (not the active income/expense tab).
/// Income and expense come from the unfiltered month totals so the chips
/// don't flip to zero when switching tabs. Transaction count still reflects
/// the currently-filtered list.
final financeQuickStatsProvider = Provider<FinanceQuickStats>((ref) {
  final state = ref.watch(
    financeProvider.select((async) => async.asData?.value),
  );

  if (state == null) {
    return const FinanceQuickStats();
  }

  return FinanceQuickStats(
    transactionCount: state.transactions.length,
    incomePaisa: state.monthlyIncomePaisa,
    expensePaisa: state.monthlyExpensePaisa,
  );
});

/// Helper function for date key generation (cached format)
String _formatDateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class FinanceNotifier extends AsyncNotifier<FinanceState> {
  TransactionRepository get _transactionRepository =>
      ref.read(transactionRepositoryProvider);
  CategoryRepository get _categoryRepository =>
      ref.read(categoryRepositoryProvider);

  @override
  Future<FinanceState> build() async {
    final initial = FinanceState(activeMonth: _monthStart(DateTime.now()));
    return _loadState(initial);
  }

  FinanceState _currentOrInitial() {
    return state.asData?.value ??
        FinanceState(activeMonth: _monthStart(DateTime.now()));
  }

  Future<void> _reloadFrom(FinanceState source) async {
    state = AsyncData(await _loadState(source));
  }

  Future<void> changeType(String type) async {
    final current = _currentOrInitial();
    await _reloadFrom(
      current.copyWith(
        activeType: type,
        selectedCategoryId: null,
        clearError: true,
      ),
    );
  }

  Future<void> changeMonth(DateTime month) async {
    final current = _currentOrInitial();
    await _reloadFrom(
      current.copyWith(activeMonth: _monthStart(month), clearError: true),
    );
  }

  Future<void> addTransaction({
    required int amountPaisa,
    required String categoryId,
    required String note,
    DateTime? date,
  }) async {
    final current = _currentOrInitial();
    final addResult = await _transactionRepository.addTransaction(
      type: current.activeType,
      amountPaisa: amountPaisa,
      categoryId: categoryId,
      note: note,
      date: date ?? DateTime.now(),
    );

    await addResult.when(
      success: (_) async {
        await _reloadFrom(current.copyWith(clearError: true));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> updateTransaction({
    required String id,
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required DateTime date,
  }) async {
    final current = _currentOrInitial();
    final updateResult = await _transactionRepository.updateTransaction(
      id: id,
      type: type,
      amountPaisa: amountPaisa,
      categoryId: categoryId,
      note: note,
      date: date,
    );

    await updateResult.when(
      success: (_) async {
        await _reloadFrom(current.copyWith(clearError: true));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final current = _currentOrInitial();
    final deleteResult = await _transactionRepository.softDeleteTransaction(
      transactionId,
    );

    await deleteResult.when(
      success: (_) async {
        await _reloadFrom(current.copyWith(clearError: true));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> restoreTransaction(String transactionId) async {
    final current = _currentOrInitial();
    final restoreResult = await _transactionRepository.restoreTransaction(
      transactionId,
    );

    await restoreResult.when(
      success: (_) async {
        await _reloadFrom(current.copyWith(clearError: true));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  void selectCategory(String categoryId) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(selectedCategoryId: categoryId, clearError: true),
    );
  }

  Future<void> applyFilters(FinanceFilters filters) async {
    final current = _currentOrInitial();
    await _reloadFrom(current.copyWith(filters: filters, clearError: true));
  }

  Future<void> clearFilters() async {
    final current = _currentOrInitial();
    await _reloadFrom(
      current.copyWith(filters: const FinanceFilters(), clearError: true),
    );
  }

  Future<void> refresh() async {
    final current = _currentOrInitial();
    await _reloadFrom(current.copyWith(clearError: true));
  }

  Future<FinanceState> _loadState(FinanceState source) async {
    final categoriesResult = await _categoryRepository.getCategoriesByType(
      source.activeType,
    );
    final allCategoriesResult = await _categoryRepository.getAllCategories();
    final categories = categoriesResult.when(
      success: (items) => items,
      failure: (_) => const <CategoryModel>[],
    );
    final allCategories = allCategoriesResult.when(
      success: (items) => items,
      failure: (_) => categories,
    );
    final validCategoryIds = allCategories.map((item) => item.id).toSet();
    final normalizedFilters = source.filters.removeInvalidCategories(
      validCategoryIds,
    );

    final transactionsResult = await _transactionRepository
        .getTransactionsForMonth(
          month: source.activeMonth,
          type: null,
          fromDate: normalizedFilters.fromDate,
          toDate: normalizedFilters.toDate,
          categoryIds: normalizedFilters.categoryIds,
          minAmountPaisa: normalizedFilters.minAmountPaisa,
          maxAmountPaisa: normalizedFilters.maxAmountPaisa,
        );
    final totalsResult = await _transactionRepository.getMonthTotals(
      source.activeMonth,
    );

    final transactions = transactionsResult.when(
      success: (items) => items,
      failure: (_) => const <TransactionModel>[],
    );
    final monthTotals = totalsResult.when(
      success: (value) => value,
      failure: (_) => (income: 0, expense: 0),
    );

    final firstError =
        categoriesResult.when(
          success: (_) => null,
          failure: (message) => message,
        ) ??
        allCategoriesResult.when(
          success: (_) => null,
          failure: (message) => message,
        ) ??
        transactionsResult.when(
          success: (_) => null,
          failure: (message) => message,
        ) ??
        totalsResult.when(success: (_) => null, failure: (message) => message);

    final selectedCategory = _resolveSelectedCategoryId(
      source.selectedCategoryId,
      categories,
    );

    return source.copyWith(
      selectedCategoryId: selectedCategory,
      filters: normalizedFilters,
      categories: categories,
      allCategories: allCategories,
      transactions: transactions,
      netBalancePaisa: monthTotals.income - monthTotals.expense,
      monthlyIncomePaisa: monthTotals.income,
      monthlyExpensePaisa: monthTotals.expense,
      errorMessage: firstError,
      clearError: firstError == null,
    );
  }

  static DateTime _monthStart(DateTime value) {
    return DateTime(value.year, value.month);
  }

  static String? _resolveSelectedCategoryId(
    String? currentId,
    List<CategoryModel> categories,
  ) {
    if (categories.isEmpty) {
      // Defensive null return - validation failed
      return null;
    }

    if (currentId == null) {
      return categories.first.id;
    }

    for (final item in categories) {
      if (item.id == currentId) {
        return currentId;
      }
    }

    return categories.first.id;
  }
}

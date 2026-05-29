import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/finance/data/budget_repository.dart';
import 'package:sanchita/features/finance/models/category_budget_model.dart';

class BudgetManagementState {
  const BudgetManagementState({
    required this.activeMonth,
    this.items = const <CategoryBudgetModel>[],
    this.errorMessage,
  });

  final DateTime activeMonth;
  final List<CategoryBudgetModel> items;
  final String? errorMessage;

  BudgetManagementState copyWith({
    DateTime? activeMonth,
    List<CategoryBudgetModel>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BudgetManagementState(
      activeMonth: activeMonth ?? this.activeMonth,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final budgetManagementProvider =
    AsyncNotifierProvider<BudgetManagementNotifier, BudgetManagementState>(
      BudgetManagementNotifier.new,
    );

class BudgetManagementNotifier extends AsyncNotifier<BudgetManagementState> {
  BudgetRepository get _budgetRepository => ref.read(budgetRepositoryProvider);

  @override
  Future<BudgetManagementState> build() async {
    final initial = BudgetManagementState(
      activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
    );
    return _loadState(initial);
  }

  Future<void> changeMonth(DateTime month) async {
    final current =
        state.asData?.value ??
        BudgetManagementState(
          activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
        );
    state = const AsyncLoading();
    state = AsyncData(
      await _loadState(
        current.copyWith(
          activeMonth: DateTime(month.year, month.month),
          clearError: true,
        ),
      ),
    );
  }

  Future<void> setMonthlyLimit({
    required String categoryId,
    required int monthlyLimitPaisa,
  }) async {
    final current =
        state.asData?.value ??
        BudgetManagementState(
          activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
        );
    final result = await _budgetRepository.upsertBudget(
      categoryId: categoryId,
      monthlyLimitPaisa: monthlyLimitPaisa,
    );

    await result.when(
      success: (_) async {
        state = const AsyncLoading();
        state = AsyncData(await _loadState(current.copyWith(clearError: true)));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> refresh() async {
    final current =
        state.asData?.value ??
        BudgetManagementState(
          activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
        );
    state = const AsyncLoading();
    state = AsyncData(await _loadState(current.copyWith(clearError: true)));
  }

  Future<BudgetManagementState> _loadState(BudgetManagementState source) async {
    final result = await _budgetRepository.getCategoryBudgetsForMonth(
      source.activeMonth,
    );

    return result.when(
      success: (items) {
        return source.copyWith(items: items, clearError: true);
      },
      failure: (message) {
        return source.copyWith(
          items: const <CategoryBudgetModel>[],
          errorMessage: message,
        );
      },
    );
  }
}

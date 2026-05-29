import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/dashboard/providers/dashboard_provider.dart';
import 'package:sanchita/features/finance/data/recurring_repository.dart';
import 'package:sanchita/features/finance/models/recurring_rule_model.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';

class RecurringState {
  const RecurringState({
    this.rules = const <RecurringRuleModel>[],
    this.dueRules = const <RecurringRuleModel>[],
    this.errorMessage,
  });

  final List<RecurringRuleModel> rules;
  final List<RecurringRuleModel> dueRules;
  final String? errorMessage;

  RecurringState copyWith({
    List<RecurringRuleModel>? rules,
    List<RecurringRuleModel>? dueRules,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecurringState(
      rules: rules ?? this.rules,
      dueRules: dueRules ?? this.dueRules,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final recurringProvider =
    AsyncNotifierProvider<RecurringNotifier, RecurringState>(
      RecurringNotifier.new,
    );

class RecurringNotifier extends AsyncNotifier<RecurringState> {
  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  @override
  Future<RecurringState> build() async {
    return _load(const RecurringState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const RecurringState();
    state = const AsyncLoading();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  Future<bool> createRule({
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.createRule(
      type: type,
      amountPaisa: amountPaisa,
      categoryId: categoryId,
      note: note,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
    );

    return result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
        return true;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return false;
      },
    );
  }

  Future<bool> updateRule({
    required String ruleId,
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.updateRule(
      ruleId: ruleId,
      type: type,
      amountPaisa: amountPaisa,
      categoryId: categoryId,
      note: note,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
    );

    return result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
        return true;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return false;
      },
    );
  }

  Future<void> togglePaused(RecurringRuleModel rule) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.setPaused(
      ruleId: rule.id,
      paused: !rule.isPaused,
    );

    await result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> deleteRule(String ruleId) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.softDeleteRule(ruleId);

    await result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> approveDueRule({
    required RecurringRuleModel rule,
    int? editedAmountPaisa,
  }) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.approveDueRule(
      rule: rule,
      editedAmountPaisa: editedAmountPaisa,
    );

    await result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> skipDueRule(RecurringRuleModel rule) async {
    final current = state.asData?.value ?? const RecurringState();
    final result = await _repository.skipDueRule(rule);

    await result.when(
      success: (_) async {
        _invalidateLinkedProviders();
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<RecurringState> _load(RecurringState source) async {
    final rulesResult = await _repository.getRules();
    final dueResult = await _repository.getDueRules(DateTime.now());

    final firstError =
        rulesResult.when(success: (_) => null, failure: (message) => message) ??
        dueResult.when(success: (_) => null, failure: (message) => message);

    return source.copyWith(
      rules: rulesResult.when(
        success: (rules) => rules,
        failure: (_) => const <RecurringRuleModel>[],
      ),
      dueRules: dueResult.when(
        success: (items) => items,
        failure: (_) => const <RecurringRuleModel>[],
      ),
      errorMessage: firstError,
      clearError: firstError == null,
    );
  }

  void _invalidateLinkedProviders() {
    ref.invalidate(financeProvider);
    ref.invalidate(dashboardProvider);
  }
}

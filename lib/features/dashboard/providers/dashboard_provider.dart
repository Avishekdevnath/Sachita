import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/dashboard/data/dashboard_repository.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';

class DashboardState {
  const DashboardState({
    required this.now,
    this.currencySymbol = 'BDT',
    this.userName,
    this.hideBalance = false,
    this.netBalancePaisa = 0,
    this.allTimeIncomePaisa = 0,
    this.allTimeExpensePaisa = 0,
    this.weeklyIncomePaisa = 0,
    this.weeklyExpensePaisa = 0,
    this.budgetTrackedCount = 0,
    this.budgetNearLimitCount = 0,
    this.budgetExceededCount = 0,
    this.activeGroupsCount = 0,
    this.vaultItemsCount = 0,
    this.pendingRecurringApprovals = 0,
    this.recentTransactions = const <DashboardRecentTransaction>[],
    this.aiLastRefreshedAt,
    this.errorMessage,
  });

  final DateTime now;
  final String currencySymbol;
  final String? userName;
  final bool hideBalance;
  final int netBalancePaisa;
  final int allTimeIncomePaisa;
  final int allTimeExpensePaisa;
  final int weeklyIncomePaisa;
  final int weeklyExpensePaisa;
  final int budgetTrackedCount;
  final int budgetNearLimitCount;
  final int budgetExceededCount;
  final int activeGroupsCount;
  final int vaultItemsCount;
  final int pendingRecurringApprovals;
  final List<DashboardRecentTransaction> recentTransactions;
  final DateTime? aiLastRefreshedAt;
  final String? errorMessage;

  DashboardState copyWith({
    DateTime? now,
    String? currencySymbol,
    String? userName,
    bool? hideBalance,
    int? netBalancePaisa,
    int? allTimeIncomePaisa,
    int? allTimeExpensePaisa,
    int? weeklyIncomePaisa,
    int? weeklyExpensePaisa,
    int? budgetTrackedCount,
    int? budgetNearLimitCount,
    int? budgetExceededCount,
    int? activeGroupsCount,
    int? vaultItemsCount,
    int? pendingRecurringApprovals,
    List<DashboardRecentTransaction>? recentTransactions,
    DateTime? aiLastRefreshedAt,
    String? errorMessage,
    bool clearAiLastRefreshedAt = false,
    bool clearError = false,
  }) {
    return DashboardState(
      now: now ?? this.now,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      userName: userName ?? this.userName,
      hideBalance: hideBalance ?? this.hideBalance,
      netBalancePaisa: netBalancePaisa ?? this.netBalancePaisa,
      allTimeIncomePaisa: allTimeIncomePaisa ?? this.allTimeIncomePaisa,
      allTimeExpensePaisa: allTimeExpensePaisa ?? this.allTimeExpensePaisa,
      weeklyIncomePaisa: weeklyIncomePaisa ?? this.weeklyIncomePaisa,
      weeklyExpensePaisa: weeklyExpensePaisa ?? this.weeklyExpensePaisa,
      budgetTrackedCount: budgetTrackedCount ?? this.budgetTrackedCount,
      budgetNearLimitCount: budgetNearLimitCount ?? this.budgetNearLimitCount,
      budgetExceededCount: budgetExceededCount ?? this.budgetExceededCount,
      activeGroupsCount: activeGroupsCount ?? this.activeGroupsCount,
      vaultItemsCount: vaultItemsCount ?? this.vaultItemsCount,
      pendingRecurringApprovals:
          pendingRecurringApprovals ?? this.pendingRecurringApprovals,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      aiLastRefreshedAt: clearAiLastRefreshedAt
          ? null
          : (aiLastRefreshedAt ?? this.aiLastRefreshedAt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
      DashboardNotifier.new,
    );

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  @override
  Future<DashboardState> build() async {
    // Re-run when finance state changes (transaction added/edited/deleted).
    ref.watch(financeProvider);
    // Re-run when user updates name/currency/theme in settings.
    ref.watch(settingsProvider);

    final now = DateTime.now();
    final hideBalanceResult = await _repository.getHideBalancePreference();
    final hideBalance = hideBalanceResult.when(
      success: (value) => value,
      failure: (_) => false,
    );
    return _load(now: now, hideBalance: hideBalance);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = AsyncData(
      await _load(
        now: DateTime.now(),
        hideBalance: current?.hideBalance ?? false,
      ),
    );
  }

  Future<void> toggleHideBalance() async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final nextValue = !current.hideBalance;
    state = AsyncData(
      current.copyWith(hideBalance: nextValue, clearError: true),
    );
    final saveResult = await _repository.setHideBalancePreference(nextValue);
    saveResult.when(
      success: (_) {},
      failure: (message) {
        final latest = state.asData?.value;
        if (latest == null) {
          return;
        }
        state = AsyncData(
          latest.copyWith(
            hideBalance: current.hideBalance,
            errorMessage: message,
          ),
        );
      },
    );
  }

  Future<void> refreshAiTeaserTimestamp() async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final result = await _repository.refreshAiTeaserTimestamp();
    result.when(
      success: (now) {
        final latest = state.asData?.value;
        if (latest == null) {
          return;
        }
        state = AsyncData(
          latest.copyWith(aiLastRefreshedAt: now, clearError: true),
        );
      },
      failure: (message) {
        final latest = state.asData?.value;
        if (latest == null) {
          return;
        }
        state = AsyncData(latest.copyWith(errorMessage: message));
      },
    );
  }

  Future<DashboardState> _load({
    required DateTime now,
    required bool hideBalance,
  }) async {
    final snapshotResult = await _repository.getSnapshot(
      month: DateTime(now.year, now.month),
      today: now,
    );

    return snapshotResult.when(
      success: (snapshot) {
        return DashboardState(
          now: now,
          currencySymbol: snapshot.currencySymbol,
          userName: snapshot.userName,
          hideBalance: hideBalance,
          netBalancePaisa: snapshot.netBalancePaisa,
          allTimeIncomePaisa: snapshot.allTimeIncomePaisa,
          allTimeExpensePaisa: snapshot.allTimeExpensePaisa,
          weeklyIncomePaisa: snapshot.weeklyIncomePaisa,
          weeklyExpensePaisa: snapshot.weeklyExpensePaisa,
          budgetTrackedCount: snapshot.budgetTrackedCount,
          budgetNearLimitCount: snapshot.budgetNearLimitCount,
          budgetExceededCount: snapshot.budgetExceededCount,
          activeGroupsCount: snapshot.activeGroupsCount,
          vaultItemsCount: snapshot.vaultItemsCount,
          pendingRecurringApprovals: snapshot.pendingRecurringApprovals,
          recentTransactions: snapshot.recentTransactions,
          aiLastRefreshedAt: snapshot.aiLastRefreshedAt,
        );
      },
      failure: (message) {
        return DashboardState(
          now: now,
          hideBalance: hideBalance,
          errorMessage: message,
        );
      },
    );
  }
}

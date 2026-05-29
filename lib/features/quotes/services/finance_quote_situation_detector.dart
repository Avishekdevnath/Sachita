import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

abstract final class FinanceQuoteSituationDetector {
  static FinanceQuoteSituation detectDashboardSituation({
    required bool hasTransactions,
    required int netBalancePaisa,
    required int budgetNearLimitCount,
    required int budgetExceededCount,
  }) {
    if (budgetExceededCount > 0) {
      return FinanceQuoteSituation.budgetExceeded;
    }
    if (budgetNearLimitCount > 0) {
      return FinanceQuoteSituation.budgetNearLimit;
    }
    if (!hasTransactions) {
      return FinanceQuoteSituation.noTransactions;
    }
    if (netBalancePaisa < 0) {
      return FinanceQuoteSituation.negativeMonth;
    }
    if (netBalancePaisa > 0) {
      return FinanceQuoteSituation.positiveMonth;
    }

    return FinanceQuoteSituation.regularReview;
  }

  static FinanceQuoteSituation detectTransactionAddedSituation({
    required bool wasFirstTransaction,
    required String transactionType,
    required String categoryName,
  }) {
    if (wasFirstTransaction) {
      return FinanceQuoteSituation.firstTransaction;
    }

    final normalizedType = transactionType.trim().toLowerCase();
    final normalizedCategory = categoryName.trim().toLowerCase();
    if (normalizedType == 'income') {
      if (normalizedCategory.contains('salary')) {
        return FinanceQuoteSituation.salaryAdded;
      }
      return FinanceQuoteSituation.positiveMonth;
    }

    if (normalizedCategory.contains('food') ||
        normalizedCategory.contains('meal') ||
        normalizedCategory.contains('restaurant')) {
      return FinanceQuoteSituation.highFoodSpend;
    }

    return FinanceQuoteSituation.expenseAdded;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/services/finance_quote_situation_detector.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test('dashboard situation prioritizes budget risk before balance', () {
    expect(
      FinanceQuoteSituationDetector.detectDashboardSituation(
        hasTransactions: true,
        netBalancePaisa: 50000,
        budgetNearLimitCount: 0,
        budgetExceededCount: 1,
      ),
      FinanceQuoteSituation.budgetExceeded,
    );

    expect(
      FinanceQuoteSituationDetector.detectDashboardSituation(
        hasTransactions: true,
        netBalancePaisa: 50000,
        budgetNearLimitCount: 1,
        budgetExceededCount: 0,
      ),
      FinanceQuoteSituation.budgetNearLimit,
    );
  });

  test('dashboard situation handles empty, negative, and positive months', () {
    expect(
      FinanceQuoteSituationDetector.detectDashboardSituation(
        hasTransactions: false,
        netBalancePaisa: 0,
        budgetNearLimitCount: 0,
        budgetExceededCount: 0,
      ),
      FinanceQuoteSituation.noTransactions,
    );

    expect(
      FinanceQuoteSituationDetector.detectDashboardSituation(
        hasTransactions: true,
        netBalancePaisa: -1,
        budgetNearLimitCount: 0,
        budgetExceededCount: 0,
      ),
      FinanceQuoteSituation.negativeMonth,
    );

    expect(
      FinanceQuoteSituationDetector.detectDashboardSituation(
        hasTransactions: true,
        netBalancePaisa: 1,
        budgetNearLimitCount: 0,
        budgetExceededCount: 0,
      ),
      FinanceQuoteSituation.positiveMonth,
    );
  });

  test(
    'transaction added situation detects first, salary, food, and expense',
    () {
      expect(
        FinanceQuoteSituationDetector.detectTransactionAddedSituation(
          wasFirstTransaction: true,
          transactionType: 'expense',
          categoryName: 'Food',
        ),
        FinanceQuoteSituation.firstTransaction,
      );

      expect(
        FinanceQuoteSituationDetector.detectTransactionAddedSituation(
          wasFirstTransaction: false,
          transactionType: 'income',
          categoryName: 'Salary',
        ),
        FinanceQuoteSituation.salaryAdded,
      );

      expect(
        FinanceQuoteSituationDetector.detectTransactionAddedSituation(
          wasFirstTransaction: false,
          transactionType: 'expense',
          categoryName: 'Food',
        ),
        FinanceQuoteSituation.highFoodSpend,
      );

      expect(
        FinanceQuoteSituationDetector.detectTransactionAddedSituation(
          wasFirstTransaction: false,
          transactionType: 'expense',
          categoryName: 'Transport',
        ),
        FinanceQuoteSituation.expenseAdded,
      );
    },
  );
}

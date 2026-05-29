enum FinanceQuoteSituation {
  positiveMonth('positive_month'),
  negativeMonth('negative_month'),
  noTransactions('no_transactions'),
  firstTransaction('first_transaction'),
  salaryAdded('salary_added'),
  expenseAdded('expense_added'),
  highFoodSpend('high_food_spend'),
  budgetNearLimit('budget_near_limit'),
  budgetExceeded('budget_exceeded'),
  savingStreak('saving_streak'),
  lowSavingMonth('low_saving_month'),
  regularReview('regular_review');

  const FinanceQuoteSituation(this.serializedName);

  final String serializedName;

  static FinanceQuoteSituation fromName(String name) {
    for (final situation in values) {
      if (situation.serializedName == name) {
        return situation;
      }
    }

    return regularReview;
  }
}

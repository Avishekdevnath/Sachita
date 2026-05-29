class CategoryExpenseSummary {
  const CategoryExpenseSummary({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.amountPaisa,
  });

  final String categoryId;
  final String categoryName;
  final String colorHex;
  final int amountPaisa;
}

class DailyExpenseSummary {
  const DailyExpenseSummary({required this.date, required this.amountPaisa});

  final DateTime date;
  final int amountPaisa;
}

class MonthlySummaryModel {
  const MonthlySummaryModel({
    required this.month,
    required this.totalIncomePaisa,
    required this.totalExpensePaisa,
    required this.categoryExpenses,
    required this.dailyExpenses,
  });

  final DateTime month;
  final int totalIncomePaisa;
  final int totalExpensePaisa;
  final List<CategoryExpenseSummary> categoryExpenses;
  final List<DailyExpenseSummary> dailyExpenses;

  int get netPaisa => totalIncomePaisa - totalExpensePaisa;
}

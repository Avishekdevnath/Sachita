class CategoryBudgetModel {
  const CategoryBudgetModel({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColorHex,
    required this.monthlyLimitPaisa,
    required this.spentPaisa,
  });

  final String categoryId;
  final String categoryName;
  final String categoryColorHex;
  final int monthlyLimitPaisa;
  final int spentPaisa;

  double get usageRatio {
    if (monthlyLimitPaisa <= 0) {
      return 0;
    }
    return (spentPaisa / monthlyLimitPaisa).clamp(0.0, 999.0);
  }

  bool get reachedWarning80 {
    if (monthlyLimitPaisa <= 0) {
      return false;
    }
    return spentPaisa >= (monthlyLimitPaisa * 0.8).round();
  }

  bool get exceeded => monthlyLimitPaisa > 0 && spentPaisa > monthlyLimitPaisa;
}

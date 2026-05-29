class GroupCategoryBudgetModel {
  const GroupCategoryBudgetModel({
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
    final ratio = spentPaisa / monthlyLimitPaisa;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  bool get reachedWarning80 {
    if (monthlyLimitPaisa <= 0) {
      return false;
    }
    return spentPaisa >= (monthlyLimitPaisa * 0.8);
  }

  bool get exceeded {
    if (monthlyLimitPaisa <= 0) {
      return false;
    }
    return spentPaisa > monthlyLimitPaisa;
  }
}

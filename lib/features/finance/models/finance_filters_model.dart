class FinanceFilters {
  const FinanceFilters({
    this.fromDate,
    this.toDate,
    this.categoryIds = const <String>{},
    this.minAmountPaisa,
    this.maxAmountPaisa,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final Set<String> categoryIds;
  final int? minAmountPaisa;
  final int? maxAmountPaisa;

  bool get hasAny {
    return fromDate != null ||
        toDate != null ||
        categoryIds.isNotEmpty ||
        minAmountPaisa != null ||
        maxAmountPaisa != null;
  }

  int get activeCount {
    var count = 0;
    if (fromDate != null || toDate != null) {
      count++;
    }
    if (categoryIds.isNotEmpty) {
      count++;
    }
    if (minAmountPaisa != null || maxAmountPaisa != null) {
      count++;
    }
    return count;
  }

  FinanceFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    Set<String>? categoryIds,
    int? minAmountPaisa,
    int? maxAmountPaisa,
    bool clearFromDate = false,
    bool clearToDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return FinanceFilters(
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      categoryIds: categoryIds ?? this.categoryIds,
      minAmountPaisa: clearMinAmount
          ? null
          : (minAmountPaisa ?? this.minAmountPaisa),
      maxAmountPaisa: clearMaxAmount
          ? null
          : (maxAmountPaisa ?? this.maxAmountPaisa),
    );
  }

  FinanceFilters removeInvalidCategories(Set<String> validCategoryIds) {
    final cleaned = categoryIds.where(validCategoryIds.contains).toSet();
    return copyWith(categoryIds: cleaned);
  }
}


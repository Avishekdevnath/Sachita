import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/finance/data/transaction_repository.dart';
import 'package:sanchita/features/finance/models/monthly_summary_model.dart';

/// Aggregates category expenses across the last [months] calendar months.
/// Returns a list sorted by total amount descending.
final categoryRangeProvider =
    FutureProvider.family<List<CategoryExpenseSummary>, int>((ref, months) async {
  final repo = ref.read(transactionRepositoryProvider);
  final now = DateTime.now();

  final futures = List.generate(months, (i) {
    final month = DateTime(now.year, now.month - i);
    return repo.getMonthlySummary(month);
  });

  final results = await Future.wait(futures);

  final totals = <String, _Agg>{};
  for (final result in results) {
    result.when(
      success: (summary) {
        for (final cat in summary.categoryExpenses) {
          final agg = totals.putIfAbsent(
            cat.categoryId,
            () => _Agg(cat.categoryName, cat.colorHex),
          );
          agg.amountPaisa += cat.amountPaisa;
        }
      },
      failure: (_) {},
    );
  }

  final list = totals.entries
      .map((e) => CategoryExpenseSummary(
            categoryId: e.key,
            categoryName: e.value.name,
            colorHex: e.value.colorHex,
            amountPaisa: e.value.amountPaisa,
          ))
      .toList(growable: false)
    ..sort((a, b) => b.amountPaisa.compareTo(a.amountPaisa));

  return list;
});

class _Agg {
  _Agg(this.name, this.colorHex);
  final String name;
  final String colorHex;
  int amountPaisa = 0;
}

import 'dart:math';

import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

class FinanceQuoteSelector {
  FinanceQuoteSelector({int Function(int max)? randomIndex})
    : _randomIndex = randomIndex ?? Random().nextInt;

  final int Function(int max) _randomIndex;

  FinanceQuoteModel? select({
    required List<FinanceQuoteModel> quotes,
    required FinanceQuoteSituation situation,
    List<String> recentQuoteIds = const <String>[],
  }) {
    final candidates = quotes
        .where(
          (quote) =>
              quote.situation == situation && quote.active && quote.verified,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    final freshCandidates = candidates
        .where((quote) => !recentQuoteIds.contains(quote.id))
        .toList(growable: false);
    final pool = freshCandidates.isEmpty ? candidates : freshCandidates;
    return pool[_randomIndex(pool.length)];
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/services/finance_quote_selector.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test(
    'select avoids the most recently shown quote when alternatives exist',
    () {
      final selector = FinanceQuoteSelector(randomIndex: (_) => 0);

      final selected = selector.select(
        quotes: <FinanceQuoteModel>[_quote('first'), _quote('second')],
        situation: FinanceQuoteSituation.positiveMonth,
        recentQuoteIds: const <String>['first'],
      );

      expect(selected?.id, 'second');
    },
  );

  test(
    'select falls back to recent quote when it is the only available quote',
    () {
      final selector = FinanceQuoteSelector(randomIndex: (_) => 0);

      final selected = selector.select(
        quotes: <FinanceQuoteModel>[_quote('only')],
        situation: FinanceQuoteSituation.positiveMonth,
        recentQuoteIds: const <String>['only'],
      );

      expect(selected?.id, 'only');
    },
  );
}

FinanceQuoteModel _quote(String id) {
  return FinanceQuoteModel(
    id: id,
    situation: FinanceQuoteSituation.positiveMonth,
    quote: 'Quote $id',
    source: 'Sanchita',
    sourceType: 'original',
    tone: 'calm',
    title: 'Title',
    actionLabel: 'Action',
    sourceReference: 'original',
    verified: true,
    active: true,
  );
}

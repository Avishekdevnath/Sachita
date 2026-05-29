import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test('FinanceQuoteModel parses verified active quote json', () {
    final quote = FinanceQuoteModel.fromJson(const <String, Object?>{
      'id': 'positive_month_001',
      'situation': 'positive_month',
      'quote': 'A part of all you earn is yours to keep.',
      'source': 'George S. Clason',
      'sourceType': 'famous',
      'tone': 'wise',
      'title': 'Steady progress',
      'actionLabel': 'See summary',
      'sourceReference': 'The Richest Man in Babylon, 1926',
      'verified': true,
      'active': true,
    });

    expect(quote.id, 'positive_month_001');
    expect(quote.situation, FinanceQuoteSituation.positiveMonth);
    expect(quote.sourceType, 'famous');
    expect(quote.verified, isTrue);
    expect(quote.active, isTrue);
  });

  test('FinanceQuoteSituation maps json names safely', () {
    expect(
      FinanceQuoteSituation.fromName('budget_near_limit'),
      FinanceQuoteSituation.budgetNearLimit,
    );
    expect(
      FinanceQuoteSituation.negativeMonth.serializedName,
      'negative_month',
    );
  });
}

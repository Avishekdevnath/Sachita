import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/data/finance_quote_history_repository.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test(
    'history stores recent quote ids per situation with newest first',
    () async {
      final storage = <String, String>{};
      final repository = FinanceQuoteHistoryRepository(
        read: storage.read,
        write: storage.write,
      );

      await repository.recordShown(
        situation: FinanceQuoteSituation.positiveMonth,
        quoteId: 'first',
      );
      await repository.recordShown(
        situation: FinanceQuoteSituation.positiveMonth,
        quoteId: 'second',
      );
      await repository.recordShown(
        situation: FinanceQuoteSituation.positiveMonth,
        quoteId: 'first',
      );

      expect(
        await repository.recentQuoteIdsFor(FinanceQuoteSituation.positiveMonth),
        <String>['first', 'second'],
      );
    },
  );

  test('automatic quote can be shown only once per local day', () async {
    final storage = <String, String>{};
    final repository = FinanceQuoteHistoryRepository(
      read: storage.read,
      write: storage.write,
    );
    final today = DateTime(2026, 5, 1, 20);

    expect(await repository.canShowAutomaticQuoteOn(today), isTrue);

    await repository.recordAutomaticShown(today);

    expect(await repository.canShowAutomaticQuoteOn(today), isFalse);
    expect(
      await repository.canShowAutomaticQuoteOn(DateTime(2026, 5, 2)),
      isTrue,
    );
  });
}

extension on Map<String, String> {
  Future<String?> read(String key) async {
    return this[key];
  }

  Future<void> write({required String key, required String value}) async {
    this[key] = value;
  }
}

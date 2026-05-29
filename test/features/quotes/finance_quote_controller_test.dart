import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/data/finance_quote_history_repository.dart';
import 'package:sanchita/features/quotes/data/finance_quote_repository.dart';
import 'package:sanchita/features/quotes/providers/finance_quote_provider.dart';
import 'package:sanchita/features/quotes/services/finance_quote_selector.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test('controller records shown quote and avoids immediate repeat', () async {
    final storage = <String, String>{};
    final controller = FinanceQuoteController(
      repository: FinanceQuoteRepository(
        assetBundle: _StringAssetBundle(
          jsonEncode(<Map<String, Object?>>[
            _quoteJson(id: 'first'),
            _quoteJson(id: 'second'),
          ]),
        ),
        assetPath: 'ignored.json',
      ),
      historyRepository: FinanceQuoteHistoryRepository(
        read: storage.read,
        write: storage.write,
      ),
      selector: FinanceQuoteSelector(randomIndex: (_) => 0),
    );

    final first = await controller.quoteForSituation(
      FinanceQuoteSituation.positiveMonth,
    );
    final second = await controller.quoteForSituation(
      FinanceQuoteSituation.positiveMonth,
    );

    expect(first?.id, 'first');
    expect(second?.id, 'second');
  });

  test('controller suppresses automatic quote after same-day show', () async {
    final storage = <String, String>{};
    final controller = FinanceQuoteController(
      repository: FinanceQuoteRepository(
        assetBundle: _StringAssetBundle(
          jsonEncode(<Map<String, Object?>>[_quoteJson(id: 'first')]),
        ),
        assetPath: 'ignored.json',
      ),
      historyRepository: FinanceQuoteHistoryRepository(
        read: storage.read,
        write: storage.write,
      ),
      selector: FinanceQuoteSelector(randomIndex: (_) => 0),
    );
    final today = DateTime(2026, 5, 1, 20);

    final first = await controller.automaticQuoteForSituation(
      FinanceQuoteSituation.positiveMonth,
      now: today,
    );
    final second = await controller.automaticQuoteForSituation(
      FinanceQuoteSituation.positiveMonth,
      now: today,
    );

    expect(first?.id, 'first');
    expect(second, isNull);
  });
}

Map<String, Object?> _quoteJson({required String id}) {
  return <String, Object?>{
    'id': id,
    'situation': 'positive_month',
    'quote': 'Quote $id',
    'source': 'Sanchita',
    'sourceType': 'original',
    'tone': 'calm',
    'title': 'Title',
    'actionLabel': 'Action',
    'sourceReference': 'original',
    'verified': true,
    'active': true,
  };
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return value;
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }
}

extension on Map<String, String> {
  Future<String?> read(String key) async {
    return this[key];
  }

  Future<void> write({required String key, required String value}) async {
    this[key] = value;
  }
}

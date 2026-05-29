import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/data/finance_quote_repository.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

void main() {
  test(
    'FinanceQuoteRepository loads only active verified quotes for situation',
    () async {
      final repository = FinanceQuoteRepository(
        assetBundle: _StringAssetBundle(
          jsonEncode(<Map<String, Object?>>[
            _quoteJson(id: 'active', verified: true, active: true),
            _quoteJson(id: 'inactive', verified: true, active: false),
            _quoteJson(id: 'unverified', verified: false, active: true),
            _quoteJson(
              id: 'other',
              situation: 'negative_month',
              verified: true,
              active: true,
            ),
          ]),
        ),
        assetPath: 'ignored.json',
      );

      final quotes = await repository.activeVerifiedQuotesFor(
        FinanceQuoteSituation.positiveMonth,
      );

      expect(quotes.map((quote) => quote.id), <String>['active']);
    },
  );
}

Map<String, Object?> _quoteJson({
  required String id,
  String situation = 'positive_month',
  required bool verified,
  required bool active,
}) {
  return <String, Object?>{
    'id': id,
    'situation': situation,
    'quote': 'Quote $id',
    'source': 'Sanchita',
    'sourceType': 'original',
    'tone': 'calm',
    'title': 'Title',
    'actionLabel': 'Action',
    'sourceReference': 'original',
    'verified': verified,
    'active': active,
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

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

class FinanceQuoteRepository {
  FinanceQuoteRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/quotes/finance_quotes.json',
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final String assetPath;

  List<FinanceQuoteModel>? _cache;

  Future<List<FinanceQuoteModel>> loadQuotes() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }

    final raw = await _assetBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _cache = const <FinanceQuoteModel>[];
      return _cache!;
    }

    final quotes = decoded
        .whereType<Map>()
        .map(
          (item) => FinanceQuoteModel.fromJson(Map<String, Object?>.from(item)),
        )
        .where((quote) => quote.id.isNotEmpty && quote.quote.isNotEmpty)
        .toList(growable: false);
    _cache = quotes;
    return quotes;
  }

  Future<List<FinanceQuoteModel>> activeVerifiedQuotesFor(
    FinanceQuoteSituation situation,
  ) async {
    final quotes = await loadQuotes();
    return quotes
        .where(
          (quote) =>
              quote.situation == situation && quote.active && quote.verified,
        )
        .toList(growable: false);
  }
}

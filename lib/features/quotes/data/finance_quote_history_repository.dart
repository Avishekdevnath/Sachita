import 'dart:convert';

import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

typedef FinanceQuoteStorageRead = Future<String?> Function(String key);

typedef FinanceQuoteStorageWrite =
    Future<void> Function({required String key, required String value});

class FinanceQuoteHistoryRepository {
  FinanceQuoteHistoryRepository({
    FinanceQuoteStorageRead? read,
    FinanceQuoteStorageWrite? write,
  }) : _read = read ?? SecureStorageService.instance.read,
       _write = write ?? SecureStorageService.instance.write;

  static const String _recentKey = 'finance_quote_recent_ids_v1';
  static const String _automaticDateKey = 'finance_quote_auto_date_v1';
  static const int _maxRecentPerSituation = 3;

  final FinanceQuoteStorageRead _read;
  final FinanceQuoteStorageWrite _write;

  Future<List<String>> recentQuoteIdsFor(
    FinanceQuoteSituation situation,
  ) async {
    final history = await _readRecentHistory();
    return history[situation.serializedName] ?? const <String>[];
  }

  Future<void> recordShown({
    required FinanceQuoteSituation situation,
    required String quoteId,
  }) async {
    final history = await _readRecentHistory();
    final current = history[situation.serializedName] ?? const <String>[];
    final updated = <String>[
      quoteId,
      ...current.where((id) => id != quoteId),
    ].take(_maxRecentPerSituation).toList(growable: false);

    history[situation.serializedName] = updated;
    await _write(key: _recentKey, value: jsonEncode(history));
  }

  Future<bool> canShowAutomaticQuoteOn(DateTime date) async {
    final storedDate = await _read(_automaticDateKey);
    return storedDate != _dateKey(date);
  }

  Future<void> recordAutomaticShown(DateTime date) {
    return _write(key: _automaticDateKey, value: _dateKey(date));
  }

  Future<Map<String, List<String>>> _readRecentHistory() async {
    final raw = await _read(_recentKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<String>>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, List<String>>{};
    }

    return decoded.map((key, value) {
      final ids = value is List
          ? value.whereType<String>().toList(growable: false)
          : const <String>[];
      return MapEntry(key.toString(), ids);
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

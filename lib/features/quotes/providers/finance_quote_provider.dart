import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/quotes/data/finance_quote_history_repository.dart';
import 'package:sanchita/features/quotes/data/finance_quote_repository.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/services/finance_quote_selector.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

final financeQuoteRepositoryProvider = Provider<FinanceQuoteRepository>((ref) {
  return FinanceQuoteRepository();
});

final financeQuoteHistoryRepositoryProvider =
    Provider<FinanceQuoteHistoryRepository>((ref) {
      return FinanceQuoteHistoryRepository();
    });

final financeQuoteSelectorProvider = Provider<FinanceQuoteSelector>((ref) {
  return FinanceQuoteSelector();
});

final financeQuoteControllerProvider = Provider<FinanceQuoteController>((ref) {
  return FinanceQuoteController(
    repository: ref.watch(financeQuoteRepositoryProvider),
    historyRepository: ref.watch(financeQuoteHistoryRepositoryProvider),
    selector: ref.watch(financeQuoteSelectorProvider),
  );
});

class FinanceQuoteController {
  const FinanceQuoteController({
    required this.repository,
    required this.historyRepository,
    required this.selector,
  });

  final FinanceQuoteRepository repository;
  final FinanceQuoteHistoryRepository historyRepository;
  final FinanceQuoteSelector selector;

  Future<FinanceQuoteModel?> quoteForSituation(
    FinanceQuoteSituation situation,
  ) async {
    final quotes = await repository.activeVerifiedQuotesFor(situation);
    final recentQuoteIds = await historyRepository.recentQuoteIdsFor(situation);
    final selected = selector.select(
      quotes: quotes,
      situation: situation,
      recentQuoteIds: recentQuoteIds,
    );

    if (selected == null) {
      return null;
    }

    await historyRepository.recordShown(
      situation: situation,
      quoteId: selected.id,
    );
    return selected;
  }

  Future<FinanceQuoteModel?> automaticQuoteForSituation(
    FinanceQuoteSituation situation, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final canShow = await historyRepository.canShowAutomaticQuoteOn(today);
    if (!canShow) {
      return null;
    }

    final quote = await quoteForSituation(situation);
    if (quote != null) {
      await historyRepository.recordAutomaticShown(today);
    }
    return quote;
  }
}

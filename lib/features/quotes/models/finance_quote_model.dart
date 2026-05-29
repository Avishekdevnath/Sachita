import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';

class FinanceQuoteModel {
  const FinanceQuoteModel({
    required this.id,
    required this.situation,
    required this.quote,
    required this.source,
    required this.sourceType,
    required this.tone,
    required this.title,
    required this.actionLabel,
    required this.sourceReference,
    required this.verified,
    required this.active,
  });

  final String id;
  final FinanceQuoteSituation situation;
  final String quote;
  final String source;
  final String sourceType;
  final String tone;
  final String title;
  final String actionLabel;
  final String sourceReference;
  final bool verified;
  final bool active;

  factory FinanceQuoteModel.fromJson(Map<String, Object?> json) {
    return FinanceQuoteModel(
      id: json['id'] as String? ?? '',
      situation: FinanceQuoteSituation.fromName(
        json['situation'] as String? ?? '',
      ),
      quote: json['quote'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      tone: json['tone'] as String? ?? '',
      title: json['title'] as String? ?? '',
      actionLabel: json['actionLabel'] as String? ?? 'OK',
      sourceReference: json['sourceReference'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
    );
  }
}

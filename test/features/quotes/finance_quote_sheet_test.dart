import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';
import 'package:sanchita/features/quotes/widgets/finance_quote_sheet.dart';

void main() {
  testWidgets('FinanceQuoteSheet shows quote, source, and action', (
    tester,
  ) async {
    var acted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanceQuoteSheet(
            quote: const FinanceQuoteModel(
              id: 'quote-id',
              situation: FinanceQuoteSituation.positiveMonth,
              quote: 'A part of all you earn is yours to keep.',
              source: 'George S. Clason',
              sourceType: 'famous',
              tone: 'wise',
              title: 'Steady progress',
              actionLabel: 'See summary',
              sourceReference: 'The Richest Man in Babylon, 1926',
              verified: true,
              active: true,
            ),
            onAction: () {
              acted = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Steady progress'), findsOneWidget);
    expect(
      find.text('"A part of all you earn is yours to keep."'),
      findsOneWidget,
    );
    expect(find.text('George S. Clason'), findsOneWidget);

    await tester.tap(find.text('See summary'));
    await tester.pump();

    expect(acted, isTrue);
  });
}

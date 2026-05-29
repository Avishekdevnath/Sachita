import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';
import 'package:sanchita/features/finance/utils/finance_transaction_view_filter.dart';
import 'package:sanchita/features/finance/widgets/finance_balance_card.dart';
import 'package:sanchita/features/finance/widgets/finance_header_bar.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_section_list.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_view_tabs.dart';

void main() {
  testWidgets(
    'FinanceBalanceCard displays net, income, and expense summaries',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceBalanceCard(
              balanceLabel: 'This month net balance',
              balancePaisa: 3550000,
              balanceText: 'BDT 35,500.00',
              incomeText: 'BDT 38,000.00',
              expenseText: 'BDT 2,500.00',
            ),
          ),
        ),
      );

      expect(find.text('THIS MONTH NET BALANCE'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('BDT 38,000.00'), findsOneWidget);
      expect(find.text('BDT 2,500.00'), findsOneWidget);
    },
  );

  testWidgets('FinanceBalanceCard keeps summaries compact on mobile width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: FinanceBalanceCard(
                balanceLabel: 'This month net balance',
                balancePaisa: 3550000,
                balanceText: 'BDT 35,500.00',
                incomeText: 'BDT 38,000.00',
                expenseText: 'BDT 2,500.00',
              ),
            ),
          ),
        ),
      ),
    );

    final cardHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('finance-balance-card-content')),
        )
        .height;
    expect(cardHeight, lessThanOrEqualTo(220));
  });

  testWidgets('FinanceHeaderBar renders month controls and filter action', (
    tester,
  ) async {
    var filterTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanceHeaderBar(
            monthLabel: 'May 2026',
            activeFilterCount: 2,
            onPreviousMonth: () {},
            onNextMonth: () {},
            onFilterTap: () {
              filterTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('May 2026'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pump();

    expect(filterTapped, isTrue);
  });

  testWidgets('FinanceTransactionSectionSliver shows compact entry count', (
    tester,
  ) async {
    final date = DateTime(2026, 5);
    final transactions = <TransactionModel>[
      _transaction(id: 'income-1', type: 'income', date: date),
      _transaction(id: 'expense-1', type: 'expense', date: date),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              FinanceTransactionSectionSliver(
                sections: <FinanceTransactionSection>[
                  FinanceTransactionSection(date: date, items: transactions),
                ],
                itemBuilder: (context, item) => Text(item.id),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 entries'), findsOneWidget);
  });

  testWidgets('FinanceTransactionViewTabs is compact and tappable', (
    tester,
  ) async {
    var selected = 'all';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: FinanceTransactionViewTabs(
                selectedView: selected,
                onChanged: (value) {
                  selected = value;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final tabsHeight = tester
        .getSize(find.byKey(const ValueKey<String>('finance-view-tabs')))
        .height;
    expect(tabsHeight, lessThanOrEqualTo(48));

    await tester.tap(find.text('Expense'));
    await tester.pump();

    expect(selected, 'expense');
  });

  testWidgets(
    'FinanceTransactionSectionSliver keeps rows away from screen edges',
    (tester) async {
      final date = DateTime(2026, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: CustomScrollView(
                slivers: <Widget>[
                  FinanceTransactionSectionSliver(
                    sections: <FinanceTransactionSection>[
                      FinanceTransactionSection(
                        date: date,
                        items: <TransactionModel>[
                          _transaction(
                            id: 'income-1',
                            type: 'income',
                            date: date,
                          ),
                        ],
                      ),
                    ],
                    itemBuilder: (context, item) => Container(
                      key: const ValueKey<String>('finance-row-probe'),
                      height: 48,
                      width: double.infinity,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final rowFinder = find.byKey(const ValueKey<String>('finance-row-probe'));
      final rowLeft = tester.getTopLeft(rowFinder).dx;
      final rowWidth = tester.getSize(rowFinder).width;

      expect(rowLeft, greaterThanOrEqualTo(16));
      expect(rowWidth, lessThanOrEqualTo(358));
    },
  );

  test(
    'filterFinanceTransactionSections filters grouped transactions by type',
    () {
      final date = DateTime(2026, 5);
      final income = _transaction(id: 'income-1', type: 'income', date: date);
      final expense = _transaction(
        id: 'expense-1',
        type: 'expense',
        date: date,
      );
      final sections = <FinanceTransactionSection>[
        FinanceTransactionSection(
          date: date,
          items: <TransactionModel>[income, expense],
        ),
      ];

      expect(
        filterFinanceTransactionSections(
          sections: sections,
          view: 'all',
        ).single.items,
        <TransactionModel>[income, expense],
      );
      expect(
        filterFinanceTransactionSections(
          sections: sections,
          view: 'income',
        ).single.items,
        <TransactionModel>[income],
      );
      expect(
        filterFinanceTransactionSections(
          sections: sections,
          view: 'expense',
        ).single.items,
        <TransactionModel>[expense],
      );
    },
  );
}

TransactionModel _transaction({
  required String id,
  required String type,
  required DateTime date,
}) {
  return TransactionModel(
    id: id,
    type: type,
    amountPaisa: 100,
    categoryId: 'category',
    note: id,
    date: date,
    createdAt: date,
  );
}

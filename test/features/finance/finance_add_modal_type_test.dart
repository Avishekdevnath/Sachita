import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_form_content.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_type_toggle.dart';

void main() {
  testWidgets('FinanceTransactionTypeToggle is compact and changes type', (
    tester,
  ) async {
    var selected = 'expense';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: FinanceTransactionTypeToggle(
              selectedType: selected,
              onChanged: (value) {
                selected = value;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('finance-type-toggle')))
          .height,
      lessThanOrEqualTo(48),
    );

    await tester.tap(find.text('Income'));
    await tester.pump();

    expect(selected, 'income');
  });

  testWidgets(
    'FinanceTransactionFormContent shows type toggle and submit label',
    (tester) async {
      final amountController = TextEditingController(text: '100.00');
      final noteController = TextEditingController();
      final amountFocusNode = FocusNode();

      addTearDown(amountController.dispose);
      addTearDown(noteController.dispose);
      addTearDown(amountFocusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanceTransactionFormContent(
              amountController: amountController,
              noteController: noteController,
              amountFocusNode: amountFocusNode,
              categories: const <CategoryModel>[],
              selectedCategoryId: null,
              activeType: 'income',
              entryDate: DateTime(2026, 5),
              isBusy: false,
              canSubmit: false,
              submitLabel: 'Add Income',
              showTypeToggle: true,
              onTypeChanged: (_) {},
              onCategoryChanged: (_) {},
              onPickDate: () {},
              onSetToday: () {},
              onSubmit: () async {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('finance-type-toggle')),
        findsOneWidget,
      );
      expect(find.text('Add Income'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
    },
  );

  testWidgets('FinanceTransactionFormContent can hide type toggle', (
    tester,
  ) async {
    final amountController = TextEditingController(text: '100.00');
    final noteController = TextEditingController();
    final amountFocusNode = FocusNode();

    addTearDown(amountController.dispose);
    addTearDown(noteController.dispose);
    addTearDown(amountFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanceTransactionFormContent(
            amountController: amountController,
            noteController: noteController,
            amountFocusNode: amountFocusNode,
            categories: const <CategoryModel>[],
            selectedCategoryId: null,
            activeType: 'expense',
            entryDate: DateTime(2026, 5),
            isBusy: false,
            canSubmit: false,
            submitLabel: 'Add Expense',
            onCategoryChanged: (_) {},
            onPickDate: () {},
            onSetToday: () {},
            onSubmit: () async {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('finance-type-toggle')),
      findsNothing,
    );
    expect(find.text('Add Expense'), findsOneWidget);
  });

  testWidgets('FinanceTransactionFormContent unfocuses input before submit', (
    tester,
  ) async {
    final amountController = TextEditingController(text: '100.00');
    final noteController = TextEditingController();
    final amountFocusNode = FocusNode();

    addTearDown(amountController.dispose);
    addTearDown(noteController.dispose);
    addTearDown(amountFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanceTransactionFormContent(
            amountController: amountController,
            noteController: noteController,
            amountFocusNode: amountFocusNode,
            categories: const <CategoryModel>[],
            selectedCategoryId: null,
            activeType: 'expense',
            entryDate: DateTime(2026, 5),
            isBusy: false,
            canSubmit: true,
            submitLabel: 'Add Expense',
            onCategoryChanged: (_) {},
            onPickDate: () {},
            onSetToday: () {},
            onSubmit: () async {},
          ),
        ),
      ),
    );

    amountFocusNode.requestFocus();
    await tester.pump();

    expect(amountFocusNode.hasFocus, isTrue);

    await tester.tap(find.text('Add Expense'));
    await tester.pump();

    expect(amountFocusNode.hasFocus, isFalse);
  });

  testWidgets(
    'focused transaction form can be removed without framework errors',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _OwnedTransactionForm()));

      final ownerState = tester.state<_OwnedTransactionFormState>(
        find.byType(_OwnedTransactionForm),
      );
      ownerState.amountFocusNode.requestFocus();
      await tester.pump();

      expect(ownerState.amountFocusNode.hasFocus, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}

class _OwnedTransactionForm extends StatefulWidget {
  const _OwnedTransactionForm();

  @override
  State<_OwnedTransactionForm> createState() => _OwnedTransactionFormState();
}

class _OwnedTransactionFormState extends State<_OwnedTransactionForm> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FinanceTransactionFormContent(
        amountController: amountController,
        noteController: noteController,
        amountFocusNode: amountFocusNode,
        categories: const <CategoryModel>[],
        selectedCategoryId: null,
        activeType: 'expense',
        entryDate: DateTime(2026, 5),
        isBusy: false,
        canSubmit: true,
        submitLabel: 'Add Expense',
        onCategoryChanged: (_) {},
        onPickDate: () {},
        onSetToday: () {},
        onSubmit: () async {},
      ),
    );
  }
}

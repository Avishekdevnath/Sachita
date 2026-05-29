import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_deleted_snackbar.dart';

void main() {
  testWidgets('deleted transaction snackbar uses a short undo window', (
    tester,
  ) async {
    var undoPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    buildTransactionDeletedSnackBar(
                      onUndo: () async {
                        undoPressed = true;
                      },
                    ),
                  );
                },
                child: const Text('Delete'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 4));

    snackBar.action!.onPressed();
    await tester.pump();

    expect(undoPressed, isTrue);
  });

  testWidgets('deleted transaction snackbar force closes after undo window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showTransactionDeletedSnackBar(
                    messenger: ScaffoldMessenger.of(context),
                    onUndo: () async {},
                  );
                },
                child: const Text('Delete'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(find.text('Transaction deleted'), findsOneWidget);

    await tester.pump(transactionDeletedUndoDuration);
    await tester.pumpAndSettle();

    expect(find.text('Transaction deleted'), findsNothing);
  });
}

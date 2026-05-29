import 'package:flutter/material.dart';

const Duration transactionDeletedUndoDuration = Duration(seconds: 4);

SnackBar buildTransactionDeletedSnackBar({
  required Future<void> Function() onUndo,
}) {
  return SnackBar(
    duration: transactionDeletedUndoDuration,
    content: const Text('Transaction deleted'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: onUndo,
    ),
  );
}

void showTransactionDeletedSnackBar({
  required ScaffoldMessengerState messenger,
  required Future<void> Function() onUndo,
}) {
  messenger.removeCurrentSnackBar();
  final controller = messenger.showSnackBar(
    buildTransactionDeletedSnackBar(onUndo: onUndo),
  );
  var closed = false;
  controller.closed.then((_) {
    closed = true;
  });
  Future<void>.delayed(transactionDeletedUndoDuration, () {
    if (!closed) {
      controller.close();
    }
  });
}

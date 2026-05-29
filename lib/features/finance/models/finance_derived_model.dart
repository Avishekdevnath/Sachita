import 'package:sanchita/features/finance/models/transaction_model.dart';

class FinanceTransactionGroup {
  const FinanceTransactionGroup({
    required this.date,
    required this.items,
  });

  final DateTime date;
  final List<TransactionModel> items;
}

class FinanceQuickStats {
  const FinanceQuickStats({
    this.transactionCount = 0,
    this.incomePaisa = 0,
    this.expensePaisa = 0,
  });

  final int transactionCount;
  final int incomePaisa;
  final int expensePaisa;

  int get netPaisa => incomePaisa - expensePaisa;
}

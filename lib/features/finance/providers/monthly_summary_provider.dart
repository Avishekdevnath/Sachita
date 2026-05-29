import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/finance/data/transaction_repository.dart';
import 'package:sanchita/features/finance/models/monthly_summary_model.dart';

final monthlySummaryProvider =
    FutureProvider.family<MonthlySummaryModel, DateTime>((ref, month) async {
      final repository = ref.read(transactionRepositoryProvider);
      final result = await repository.getMonthlySummary(month);
      return result.when(
        success: (data) => data,
        failure: (message) => throw Exception(message),
      );
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/features/finance/models/monthly_summary_model.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(DatabaseHelper.instance);
});

class TransactionRepository {
  TransactionRepository(this._databaseHelper);

  static const Uuid _uuid = Uuid();

  final DatabaseHelper _databaseHelper;

  Future<Result<List<TransactionModel>>> getTransactionsForMonth({
    required DateTime month,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    Set<String> categoryIds = const <String>{},
    int? minAmountPaisa,
    int? maxAmountPaisa,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);
      final whereClauses = <String>['is_deleted = 0', 'date LIKE ?'];
      final whereArgs = <Object>['$monthPrefix%'];

      if (type != null && type != 'all') {
        whereClauses.add('type = ?');
        whereArgs.add(type);
      }

      if (fromDate != null) {
        whereClauses.add('date >= ?');
        whereArgs.add(_dateOnly(fromDate));
      }

      if (toDate != null) {
        whereClauses.add('date <= ?');
        whereArgs.add(_dateOnly(toDate));
      }

      if (categoryIds.isNotEmpty) {
        final placeholders = List<String>.filled(
          categoryIds.length,
          '?',
        ).join(',');
        whereClauses.add('category_id IN ($placeholders)');
        whereArgs.addAll(categoryIds);
      }

      if (minAmountPaisa != null) {
        whereClauses.add('amount >= ?');
        whereArgs.add(minAmountPaisa);
      }

      if (maxAmountPaisa != null) {
        whereClauses.add('amount <= ?');
        whereArgs.add(maxAmountPaisa);
      }

      final rows = await db.query(
        'transactions',
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        orderBy: 'date DESC, created_at DESC',
      );
      final items = rows
          .map((row) => TransactionModel.fromMap(row))
          .toList(growable: false);
      return Result<List<TransactionModel>>.success(items);
    } catch (error) {
      return Result<List<TransactionModel>>.failure(
        'Failed to load transactions: $error',
      );
    }
  }

  Future<Result<void>> addTransaction({
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required DateTime date,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final now = DateTime.now().toIso8601String();

      await db.insert('transactions', <String, Object?>{
        'id': _uuid.v4(),
        'type': type,
        'amount': amountPaisa,
        'category_id': categoryId,
        'note': note.trim().isEmpty ? null : note.trim(),
        'date': _dateOnly(date),
        'recurring_rule_id': null,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to add transaction: $error');
    }
  }

  Future<Result<TransactionModel>> getTransactionById(
    String transactionId,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'transactions',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[transactionId],
        limit: 1,
      );

      if (rows.isEmpty) {
        return const Result<TransactionModel>.failure('Transaction not found.');
      }

      return Result<TransactionModel>.success(
        TransactionModel.fromMap(rows.first),
      );
    } catch (error) {
      return Result<TransactionModel>.failure(
        'Failed to load transaction: $error',
      );
    }
  }

  Future<Result<void>> updateTransaction({
    required String id,
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required DateTime date,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'transactions',
        <String, Object?>{
          'type': type,
          'amount': amountPaisa,
          'category_id': categoryId,
          'note': note.trim().isEmpty ? null : note.trim(),
          'date': _dateOnly(date),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[id],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure(
          'Transaction not found or already deleted.',
        );
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update transaction: $error');
    }
  }

  Future<Result<void>> softDeleteTransaction(String transactionId) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'transactions',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[transactionId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure(
          'Transaction not found or already deleted.',
        );
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete transaction: $error');
    }
  }

  Future<Result<void>> restoreTransaction(String transactionId) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'transactions',
        <String, Object?>{
          'is_deleted': 0,
          'deleted_at': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 1',
        whereArgs: <Object>[transactionId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure(
          'Transaction not found or already active.',
        );
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to restore transaction: $error');
    }
  }

  Future<Result<int>> getNetBalanceForMonth(DateTime month) async {
    final totals = await getMonthTotals(month);
    return totals.when(
      success: (data) => Result<int>.success(data.income - data.expense),
      failure: (message) => Result<int>.failure(message),
    );
  }

  Future<Result<({int income, int expense})>> getMonthTotals(
    DateTime month,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);

      final rows = await db.rawQuery(
        '''
          SELECT type, COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE type IN ('income', 'expense')
            AND is_deleted = 0
            AND date LIKE ?
          GROUP BY type
        ''',
        <Object>['$monthPrefix%'],
      );

      var income = 0;
      var expense = 0;
      for (final row in rows) {
        final value = (row['total'] as num?)?.toInt() ?? 0;
        if (row['type'] == 'income') {
          income = value;
        } else if (row['type'] == 'expense') {
          expense = value;
        }
      }

      return Result<({int income, int expense})>.success((
        income: income,
        expense: expense,
      ));
    } catch (error) {
      return Result<({int income, int expense})>.failure(
        'Failed to load month totals: $error',
      );
    }
  }

  Future<Result<MonthlySummaryModel>> getMonthlySummary(DateTime month) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);

      final incomeRows = await db.rawQuery(
        '''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE type = ? AND is_deleted = 0 AND date LIKE ?
        ''',
        <Object>['income', '$monthPrefix%'],
      );
      final expenseRows = await db.rawQuery(
        '''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE type = ? AND is_deleted = 0 AND date LIKE ?
        ''',
        <Object>['expense', '$monthPrefix%'],
      );
      final categoryRows = await db.rawQuery(
        '''
          SELECT
            t.category_id AS category_id,
            c.name AS category_name,
            c.color AS color_hex,
            COALESCE(SUM(t.amount), 0) AS total
          FROM transactions t
          JOIN categories c ON c.id = t.category_id
          WHERE t.type = 'expense'
            AND t.is_deleted = 0
            AND c.is_deleted = 0
            AND t.date LIKE ?
          GROUP BY t.category_id, c.name, c.color
          ORDER BY total DESC
        ''',
        <Object>['$monthPrefix%'],
      );
      final dailyRows = await db.rawQuery(
        '''
          SELECT date, COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE type = 'expense'
            AND is_deleted = 0
            AND date LIKE ?
          GROUP BY date
          ORDER BY date ASC
        ''',
        <Object>['$monthPrefix%'],
      );

      final totalIncome = (incomeRows.first['total'] as num?)?.toInt() ?? 0;
      final totalExpense = (expenseRows.first['total'] as num?)?.toInt() ?? 0;

      final categoryExpenses = categoryRows
          .map((row) {
            return CategoryExpenseSummary(
              categoryId: row['category_id'] as String? ?? '',
              categoryName: row['category_name'] as String? ?? 'Unknown',
              colorHex: row['color_hex'] as String? ?? '#999999',
              amountPaisa: (row['total'] as num?)?.toInt() ?? 0,
            );
          })
          .toList(growable: false);

      final dailyExpenses = dailyRows
          .map((row) {
            final rawDate = row['date'] as String? ?? '';
            return DailyExpenseSummary(
              date:
                  DateTime.tryParse(rawDate) ??
                  DateTime(month.year, month.month, 1),
              amountPaisa: (row['total'] as num?)?.toInt() ?? 0,
            );
          })
          .toList(growable: false);

      return Result<MonthlySummaryModel>.success(
        MonthlySummaryModel(
          month: DateTime(month.year, month.month),
          totalIncomePaisa: totalIncome,
          totalExpensePaisa: totalExpense,
          categoryExpenses: categoryExpenses,
          dailyExpenses: dailyExpenses,
        ),
      );
    } catch (error) {
      return Result<MonthlySummaryModel>.failure(
        'Failed to load monthly summary: $error',
      );
    }
  }

  static String _monthPrefix(DateTime month) {
    final y = month.year.toString().padLeft(4, '0');
    final m = month.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

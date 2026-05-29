import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/features/finance/models/category_budget_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(DatabaseHelper.instance);
});

class BudgetRepository {
  BudgetRepository(this._databaseHelper);

  static const Uuid _uuid = Uuid();
  final DatabaseHelper _databaseHelper;

  Future<Result<List<CategoryBudgetModel>>> getCategoryBudgetsForMonth(
    DateTime month,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);

      final rows = await db.rawQuery(
        '''
          SELECT
            c.id AS category_id,
            c.name AS category_name,
            c.color AS category_color,
            c.sort_order AS category_sort_order,
            COALESCE(b.monthly_limit, 0) AS monthly_limit,
            COALESCE(SUM(t.amount), 0) AS spent
          FROM categories c
          LEFT JOIN budgets b
            ON b.category_id = c.id
           AND b.is_deleted = 0
          LEFT JOIN transactions t
            ON t.category_id = c.id
           AND t.type = 'expense'
           AND t.is_deleted = 0
           AND t.date LIKE ?
          WHERE c.type = 'expense'
            AND c.is_deleted = 0
          GROUP BY
            c.id,
            c.name,
            c.color,
            c.sort_order,
            b.monthly_limit
          ORDER BY c.sort_order ASC, c.name ASC
        ''',
        <Object>['$monthPrefix%'],
      );

      final items = rows
          .map((row) {
            return CategoryBudgetModel(
              categoryId: row['category_id'] as String? ?? '',
              categoryName: row['category_name'] as String? ?? 'Unknown',
              categoryColorHex: row['category_color'] as String? ?? '#999999',
              monthlyLimitPaisa: (row['monthly_limit'] as num?)?.toInt() ?? 0,
              spentPaisa: (row['spent'] as num?)?.toInt() ?? 0,
            );
          })
          .toList(growable: false);

      return Result<List<CategoryBudgetModel>>.success(items);
    } catch (error) {
      return Result<List<CategoryBudgetModel>>.failure(
        'Failed to load budgets: $error',
      );
    }
  }

  Future<Result<void>> upsertBudget({
    required String categoryId,
    required int monthlyLimitPaisa,
  }) async {
    try {
      if (monthlyLimitPaisa < 0) {
        return const Result<void>.failure('Monthly limit cannot be negative.');
      }

      final db = await _databaseHelper.database;
      final existingRows = await db.query(
        'budgets',
        columns: <String>['id'],
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
        limit: 1,
      );

      final now = DateTime.now().toIso8601String();
      if (existingRows.isEmpty) {
        await db.insert('budgets', <String, Object?>{
          'id': _uuid.v4(),
          'category_id': categoryId,
          'monthly_limit': monthlyLimitPaisa,
          'is_deleted': 0,
          'deleted_at': null,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final budgetId = existingRows.first['id'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return const Result<void>.failure('Invalid budget record.');
        }

        await db.update(
          'budgets',
          <String, Object?>{
            'monthly_limit': monthlyLimitPaisa,
            'is_deleted': 0,
            'deleted_at': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object>[budgetId],
        );
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to save budget: $error');
    }
  }

  static String _monthPrefix(DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final monthValue = month.month.toString().padLeft(2, '0');
    return '$year-$monthValue';
  }
}

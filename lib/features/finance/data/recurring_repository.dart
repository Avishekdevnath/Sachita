import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/features/finance/models/recurring_rule_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(DatabaseHelper.instance);
});

class RecurringRepository {
  RecurringRepository(this._databaseHelper);

  static const Uuid _uuid = Uuid();
  static const Set<String> _allowedFrequencies = <String>{
    'daily',
    'weekly',
    'monthly',
    'yearly',
  };

  final DatabaseHelper _databaseHelper;

  Future<Result<List<RecurringRuleModel>>> getRules() async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.rawQuery('''
        SELECT
          rr.*,
          c.name AS category_name
        FROM recurring_rules rr
        JOIN categories c ON c.id = rr.category_id
        WHERE rr.is_deleted = 0
          AND c.is_deleted = 0
        ORDER BY rr.is_paused ASC, rr.next_due_date ASC, rr.created_at DESC
      ''');

      final items = rows
          .map((row) => RecurringRuleModel.fromMap(row))
          .toList(growable: false);
      return Result<List<RecurringRuleModel>>.success(items);
    } catch (error) {
      return Result<List<RecurringRuleModel>>.failure(
        'Failed to load recurring rules: $error',
      );
    }
  }

  Future<Result<List<RecurringRuleModel>>> getDueRules(DateTime today) async {
    try {
      final db = await _databaseHelper.database;
      final todayValue = _dateOnly(today);
      final rows = await db.rawQuery(
        '''
          SELECT
            rr.*,
            c.name AS category_name
          FROM recurring_rules rr
          JOIN categories c ON c.id = rr.category_id
          WHERE rr.is_deleted = 0
            AND rr.is_paused = 0
            AND c.is_deleted = 0
            AND rr.next_due_date <= ?
            AND (rr.end_date IS NULL OR rr.end_date >= rr.next_due_date)
          ORDER BY rr.next_due_date ASC, rr.created_at ASC
        ''',
        <Object>[todayValue],
      );

      final items = rows
          .map((row) => RecurringRuleModel.fromMap(row))
          .toList(growable: false);
      return Result<List<RecurringRuleModel>>.success(items);
    } catch (error) {
      return Result<List<RecurringRuleModel>>.failure(
        'Failed to load due recurring rules: $error',
      );
    }
  }

  Future<Result<void>> createRule({
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      if (amountPaisa <= 0) {
        return const Result<void>.failure(
          'Recurring amount must be greater than zero.',
        );
      }
      if (!_allowedFrequencies.contains(frequency)) {
        return const Result<void>.failure('Invalid recurring frequency.');
      }
      if (endDate != null && endDate.isBefore(startDate)) {
        return const Result<void>.failure(
          'End date cannot be before start date.',
        );
      }

      final db = await _databaseHelper.database;
      final now = DateTime.now().toIso8601String();

      await db.insert('recurring_rules', <String, Object?>{
        'id': _uuid.v4(),
        'type': type,
        'amount': amountPaisa,
        'category_id': categoryId,
        'note': note.trim().isEmpty ? null : note.trim(),
        'frequency': frequency,
        'start_date': _dateOnly(startDate),
        'end_date': endDate == null ? null : _dateOnly(endDate),
        'next_due_date': _dateOnly(startDate),
        'is_paused': 0,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create recurring rule: $error');
    }
  }

  Future<Result<void>> updateRule({
    required String ruleId,
    required String type,
    required int amountPaisa,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      if (amountPaisa <= 0) {
        return const Result<void>.failure(
          'Recurring amount must be greater than zero.',
        );
      }
      if (!_allowedFrequencies.contains(frequency)) {
        return const Result<void>.failure('Invalid recurring frequency.');
      }
      if (endDate != null && endDate.isBefore(startDate)) {
        return const Result<void>.failure(
          'End date cannot be before start date.',
        );
      }

      final db = await _databaseHelper.database;
      final rows = await db.query(
        'recurring_rules',
        columns: <String>['next_due_date'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Result<void>.failure('Recurring rule not found.');
      }

      final currentNextDue =
          DateTime.tryParse(rows.first['next_due_date'] as String? ?? '') ??
          startDate;
      final normalizedNextDue = currentNextDue.isBefore(startDate)
          ? startDate
          : currentNextDue;

      final updatedRows = await db.update(
        'recurring_rules',
        <String, Object?>{
          'type': type,
          'amount': amountPaisa,
          'category_id': categoryId,
          'note': note.trim().isEmpty ? null : note.trim(),
          'frequency': frequency,
          'start_date': _dateOnly(startDate),
          'end_date': endDate == null ? null : _dateOnly(endDate),
          'next_due_date': _dateOnly(normalizedNextDue),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Recurring rule not found.');
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update recurring rule: $error');
    }
  }

  Future<Result<void>> setPaused({
    required String ruleId,
    required bool paused,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'recurring_rules',
        <String, Object?>{
          'is_paused': paused ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Recurring rule not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update recurring status: $error');
    }
  }

  Future<Result<void>> softDeleteRule(String ruleId) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'recurring_rules',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Recurring rule not found.');
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete recurring rule: $error');
    }
  }

  Future<Result<void>> approveDueRule({
    required RecurringRuleModel rule,
    int? editedAmountPaisa,
  }) async {
    try {
      final amountUsed = editedAmountPaisa ?? rule.amountPaisa;
      if (amountUsed <= 0) {
        return const Result<void>.failure(
          'Approved amount must be greater than zero.',
        );
      }

      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        await _writeApproval(txn: txn, rule: rule, amountUsed: amountUsed);
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to approve recurring rule: $error');
    }
  }

  Future<Result<void>> skipDueRule(RecurringRuleModel rule) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        await _writeSkip(txn: txn, rule: rule);
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to skip recurring rule: $error');
    }
  }

  Future<void> _writeApproval({
    required Transaction txn,
    required RecurringRuleModel rule,
    required int amountUsed,
  }) async {
    final now = DateTime.now().toIso8601String();
    final dueDateValue = _dateOnly(rule.nextDueDate);
    final transactionId = _uuid.v4();
    await txn.insert('transactions', <String, Object?>{
      'id': transactionId,
      'type': rule.type,
      'amount': amountUsed,
      'category_id': rule.categoryId,
      'note': rule.note.trim().isEmpty ? null : rule.note.trim(),
      'date': dueDateValue,
      'recurring_rule_id': rule.id,
      'is_deleted': 0,
      'deleted_at': null,
      'created_at': now,
      'updated_at': now,
    });

    final action = amountUsed == rule.amountPaisa ? 'approved' : 'edited';
    await txn.insert('recurring_log', <String, Object?>{
      'id': _uuid.v4(),
      'rule_id': rule.id,
      'due_date': dueDateValue,
      'action': action,
      'amount_used': amountUsed,
      'transaction_id': transactionId,
      'created_at': now,
    });

    await _advanceRuleAfterDue(txn: txn, rule: rule, nowIso: now);
  }

  Future<void> _writeSkip({
    required Transaction txn,
    required RecurringRuleModel rule,
  }) async {
    final now = DateTime.now().toIso8601String();
    final dueDateValue = _dateOnly(rule.nextDueDate);
    await txn.insert('recurring_log', <String, Object?>{
      'id': _uuid.v4(),
      'rule_id': rule.id,
      'due_date': dueDateValue,
      'action': 'skipped',
      'amount_used': null,
      'transaction_id': null,
      'created_at': now,
    });

    await _advanceRuleAfterDue(txn: txn, rule: rule, nowIso: now);
  }

  Future<void> _advanceRuleAfterDue({
    required Transaction txn,
    required RecurringRuleModel rule,
    required String nowIso,
  }) async {
    final nextDue = _nextDueDate(
      currentDueDate: rule.nextDueDate,
      frequency: rule.frequency,
    );

    final endDate = rule.endDate;
    if (endDate != null && nextDue.isAfter(endDate)) {
      await txn.update(
        'recurring_rules',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': nowIso,
          'updated_at': nowIso,
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[rule.id],
      );
      return;
    }

    await txn.update(
      'recurring_rules',
      <String, Object?>{
        'next_due_date': _dateOnly(nextDue),
        'updated_at': nowIso,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: <Object>[rule.id],
    );
  }

  static DateTime _nextDueDate({
    required DateTime currentDueDate,
    required String frequency,
  }) {
    switch (frequency) {
      case 'daily':
        return currentDueDate.add(const Duration(days: 1));
      case 'weekly':
        return currentDueDate.add(const Duration(days: 7));
      case 'monthly':
        return _addMonthsClamped(currentDueDate, 1);
      case 'yearly':
        return _addYearsClamped(currentDueDate, 1);
      default:
        return currentDueDate.add(const Duration(days: 30));
    }
  }

  static DateTime _addMonthsClamped(DateTime source, int monthsToAdd) {
    final targetYear = source.year + ((source.month - 1 + monthsToAdd) ~/ 12);
    final targetMonth = ((source.month - 1 + monthsToAdd) % 12) + 1;
    final maxDay = _daysInMonth(targetYear, targetMonth);
    final day = source.day > maxDay ? maxDay : source.day;
    return DateTime(targetYear, targetMonth, day);
  }

  static DateTime _addYearsClamped(DateTime source, int yearsToAdd) {
    final targetYear = source.year + yearsToAdd;
    final maxDay = _daysInMonth(targetYear, source.month);
    final day = source.day > maxDay ? maxDay : source.day;
    return DateTime(targetYear, source.month, day);
  }

  static int _daysInMonth(int year, int month) {
    final beginningNextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/features/groups/models/group_category_budget_model.dart';
import 'package:sanchita/features/groups/models/group_finance_transaction_model.dart';
import 'package:sanchita/features/groups/models/group_member_breakdown_model.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/models/group_model.dart';
import 'package:sanchita/features/groups/models/group_recurring_rule_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(DatabaseHelper.instance);
});

class GroupRepository {
  GroupRepository(this._databaseHelper);

  static const Uuid _uuid = Uuid();
  static const Set<String> _allowedFrequencies = <String>{
    'daily',
    'weekly',
    'monthly',
    'yearly',
  };
  final DatabaseHelper _databaseHelper;

  Future<Result<List<GroupModel>>> getGroups() async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.rawQuery('''
        SELECT
          g.*,
          (
            SELECT COUNT(*)
            FROM group_members gm
            WHERE gm.group_id = g.id
              AND gm.is_deleted = 0
          ) AS member_count,
          (
            SELECT MAX(gt.date)
            FROM group_transactions gt
            WHERE gt.group_id = g.id
              AND gt.is_deleted = 0
          ) AS last_activity_at
        FROM groups g
        WHERE g.is_deleted = 0
        ORDER BY g.sort_order ASC, g.name ASC
      ''');
      final groups = rows
          .map((row) => GroupModel.fromMap(row))
          .toList(growable: false);
      return Result<List<GroupModel>>.success(groups);
    } catch (error) {
      return Result<List<GroupModel>>.failure('Failed to load groups: $error');
    }
  }

  Future<Result<GroupModel>> getGroupById(String groupId) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          g.*,
          (
            SELECT COUNT(*)
            FROM group_members gm
            WHERE gm.group_id = g.id
              AND gm.is_deleted = 0
          ) AS member_count,
          (
            SELECT MAX(gt.date)
            FROM group_transactions gt
            WHERE gt.group_id = g.id
              AND gt.is_deleted = 0
          ) AS last_activity_at
        FROM groups g
        WHERE g.id = ?
          AND g.is_deleted = 0
        LIMIT 1
        ''',
        <Object>[groupId],
      );
      if (rows.isEmpty) {
        return const Result<GroupModel>.failure('Group not found.');
      }
      return Result<GroupModel>.success(GroupModel.fromMap(rows.first));
    } catch (error) {
      return Result<GroupModel>.failure('Failed to load group: $error');
    }
  }

  Future<Result<void>> createGroup({
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        return const Result<void>.failure('Group name is required.');
      }

      final db = await _databaseHelper.database;
      final nameExists = await _nameExists(db: db, name: trimmedName);
      if (nameExists) {
        return const Result<void>.failure(
          'A group with this name already exists.',
        );
      }

      final nextSortOrder = await _nextSortOrder(db);
      final now = DateTime.now().toIso8601String();
      await db.insert('groups', <String, Object?>{
        'id': _uuid.v4(),
        'name': trimmedName,
        'icon': icon.trim().isEmpty ? 'group' : icon.trim(),
        'color': colorHex.trim().isEmpty ? '#4ECDC4' : colorHex.trim(),
        'sort_order': nextSortOrder,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create group: $error');
    }
  }

  Future<Result<void>> updateGroup({
    required String groupId,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        return const Result<void>.failure('Group name is required.');
      }

      final db = await _databaseHelper.database;
      final rows = await db.query(
        'groups',
        columns: <String>['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[groupId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Result<void>.failure('Group not found.');
      }

      final nameExists = await _nameExists(
        db: db,
        name: trimmedName,
        excludingGroupId: groupId,
      );
      if (nameExists) {
        return const Result<void>.failure(
          'A group with this name already exists.',
        );
      }

      final updatedRows = await db.update(
        'groups',
        <String, Object?>{
          'name': trimmedName,
          'icon': icon.trim().isEmpty ? 'group' : icon.trim(),
          'color': colorHex.trim().isEmpty ? '#4ECDC4' : colorHex.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Group not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update group: $error');
    }
  }

  Future<Result<void>> deleteGroup(String groupId) async {
    try {
      final db = await _databaseHelper.database;
      final existing = await db.query(
        'groups',
        columns: <String>['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[groupId],
        limit: 1,
      );
      if (existing.isEmpty) {
        return const Result<void>.failure('Group not found.');
      }

      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.update(
          'groups',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'id = ? AND is_deleted = 0',
          whereArgs: <Object>[groupId],
        );

        await txn.update(
          'group_members',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[groupId],
        );

        await txn.update(
          'group_transactions',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[groupId],
        );

        await txn.update(
          'group_budgets',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[groupId],
        );

        await txn.update(
          'group_recurring_rules',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[groupId],
        );
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete group: $error');
    }
  }

  Future<Result<List<GroupMemberModel>>> getGroupMembers(String groupId) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'group_members',
        where: 'group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[groupId],
        orderBy: 'sort_order ASC, name ASC',
      );
      final members = rows
          .map((row) => GroupMemberModel.fromMap(row))
          .toList(growable: false);
      return Result<List<GroupMemberModel>>.success(members);
    } catch (error) {
      return Result<List<GroupMemberModel>>.failure(
        'Failed to load group members: $error',
      );
    }
  }

  Future<Result<List<GroupFinanceTransactionModel>>>
  getGroupTransactionsForMonth({
    required String groupId,
    required DateTime month,
    String? memberId,
    String? type,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);
      final normalizedMemberId = (memberId ?? '').trim();
      final normalizedType = (type ?? '').trim().toLowerCase();

      final whereArgs = <Object>[groupId, '$monthPrefix%'];
      final whereBuffer = StringBuffer(
        'gt.group_id = ? AND gt.is_deleted = 0 AND gt.date LIKE ?',
      );

      if (normalizedType == 'income' || normalizedType == 'expense') {
        whereBuffer.write(' AND gt.type = ?');
        whereArgs.add(normalizedType);
      }

      if (normalizedMemberId.isNotEmpty) {
        whereBuffer.write(' AND gt.member_id = ?');
        whereArgs.add(normalizedMemberId);
      }

      final rows = await db.rawQuery(
        '''
        SELECT
          gt.*,
          COALESCE(gm.name, 'Unknown member') AS member_name,
          COALESCE(c.name, 'Unknown category') AS category_name
        FROM group_transactions gt
        LEFT JOIN group_members gm
          ON gm.id = gt.member_id
         AND gm.group_id = gt.group_id
        LEFT JOIN categories c
          ON c.id = gt.category_id
        WHERE ${whereBuffer.toString()}
        ORDER BY gt.date DESC, gt.created_at DESC
        ''',
        whereArgs,
      );

      final items = rows
          .map((row) => GroupFinanceTransactionModel.fromMap(row))
          .toList(growable: false);
      return Result<List<GroupFinanceTransactionModel>>.success(items);
    } catch (error) {
      return Result<List<GroupFinanceTransactionModel>>.failure(
        'Failed to load group transactions: $error',
      );
    }
  }

  Future<Result<int>> getGroupNetBalanceForMonth({
    required String groupId,
    required DateTime month,
    String? memberId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);
      final normalizedMemberId = (memberId ?? '').trim();

      final whereArgs = <Object>[groupId, '$monthPrefix%'];
      final whereBuffer = StringBuffer(
        'group_id = ? AND is_deleted = 0 AND date LIKE ?',
      );
      if (normalizedMemberId.isNotEmpty) {
        whereBuffer.write(' AND member_id = ?');
        whereArgs.add(normalizedMemberId);
      }

      final incomeRows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM group_transactions
        WHERE ${whereBuffer.toString()}
          AND type = 'income'
        ''',
        whereArgs,
      );
      final expenseRows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM group_transactions
        WHERE ${whereBuffer.toString()}
          AND type = 'expense'
        ''',
        whereArgs,
      );

      final income = (incomeRows.first['total'] as num?)?.toInt() ?? 0;
      final expense = (expenseRows.first['total'] as num?)?.toInt() ?? 0;
      return Result<int>.success(income - expense);
    } catch (error) {
      return Result<int>.failure(
        'Failed to calculate group net balance: $error',
      );
    }
  }

  Future<Result<void>> addGroupTransaction({
    required String groupId,
    required String memberId,
    required String type,
    required int amountPaisa,
    required String categoryId,
    String note = '',
    DateTime? date,
  }) async {
    try {
      final normalizedType = type.trim().toLowerCase();
      if (normalizedType != 'income' && normalizedType != 'expense') {
        return const Result<void>.failure('Invalid transaction type.');
      }
      if (amountPaisa <= 0) {
        return const Result<void>.failure(
          'Amount must be greater than zero.',
        );
      }

      final db = await _databaseHelper.database;
      final groupExists = await _groupExists(db: db, groupId: groupId);
      if (!groupExists) {
        return const Result<void>.failure('Group not found.');
      }

      final memberExists = await _memberExists(
        db: db,
        groupId: groupId,
        memberId: memberId,
      );
      if (!memberExists) {
        return const Result<void>.failure('Member not found for this group.');
      }

      final categoryRows = await db.query(
        'categories',
        columns: <String>['id'],
        where: 'id = ? AND type = ? AND is_deleted = 0',
        whereArgs: <Object>[categoryId, normalizedType],
        limit: 1,
      );
      if (categoryRows.isEmpty) {
        return const Result<void>.failure(
          'Category not found for selected transaction type.',
        );
      }

      final now = DateTime.now().toIso8601String();
      await db.insert('group_transactions', <String, Object?>{
        'id': _uuid.v4(),
        'group_id': groupId,
        'member_id': memberId,
        'type': normalizedType,
        'amount': amountPaisa,
        'category_id': categoryId,
        'note': note.trim(),
        'date': _dateOnly(date ?? DateTime.now()),
        'recurring_rule_id': null,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to add group transaction: $error',
      );
    }
  }

  Future<Result<void>> softDeleteGroupTransaction({
    required String groupId,
    required String transactionId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'group_transactions',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[transactionId, groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Group transaction not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to delete group transaction: $error',
      );
    }
  }

  Future<Result<List<GroupMemberBreakdownModel>>> getMemberBreakdown({
    required String groupId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          gm.id AS member_id,
          gm.name AS member_name,
          COALESCE(
            SUM(
              CASE
                WHEN gt.type = 'income' THEN gt.amount
                ELSE 0
              END
            ),
            0
          ) AS income_total,
          COALESCE(
            SUM(
              CASE
                WHEN gt.type = 'expense' THEN gt.amount
                ELSE 0
              END
            ),
            0
          ) AS expense_total
        FROM group_members gm
        LEFT JOIN group_transactions gt
          ON gt.member_id = gm.id
         AND gt.group_id = gm.group_id
         AND gt.is_deleted = 0
        WHERE gm.group_id = ?
          AND gm.is_deleted = 0
        GROUP BY gm.id, gm.name, gm.sort_order
        ORDER BY gm.sort_order ASC, gm.name ASC
        ''',
        <Object>[groupId],
      );

      final breakdown = rows
          .map((row) => GroupMemberBreakdownModel.fromMap(row))
          .toList(growable: false);
      return Result<List<GroupMemberBreakdownModel>>.success(breakdown);
    } catch (error) {
      return Result<List<GroupMemberBreakdownModel>>.failure(
        'Failed to load member breakdown: $error',
      );
    }
  }

  Future<Result<List<GroupCategoryBudgetModel>>> getGroupBudgetsForMonth({
    required String groupId,
    required DateTime month,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final monthPrefix = _monthPrefix(month);

      final rows = await db.rawQuery(
        '''
          SELECT
            c.id AS category_id,
            c.name AS category_name,
            c.color AS category_color,
            COALESCE(gb.monthly_limit, 0) AS monthly_limit,
            COALESCE(SUM(gt.amount), 0) AS spent
          FROM categories c
          LEFT JOIN group_budgets gb
            ON gb.category_id = c.id
           AND gb.group_id = ?
           AND gb.is_deleted = 0
          LEFT JOIN group_transactions gt
            ON gt.category_id = c.id
           AND gt.group_id = ?
           AND gt.type = 'expense'
           AND gt.is_deleted = 0
           AND gt.date LIKE ?
          WHERE c.type = 'expense'
            AND c.is_deleted = 0
          GROUP BY
            c.id,
            c.name,
            c.color,
            c.sort_order,
            gb.monthly_limit
          ORDER BY c.sort_order ASC, c.name ASC
        ''',
        <Object>[groupId, groupId, '$monthPrefix%'],
      );

      final items = rows
          .map(
            (row) => GroupCategoryBudgetModel(
              categoryId: row['category_id'] as String? ?? '',
              categoryName: row['category_name'] as String? ?? 'Unknown',
              categoryColorHex: row['category_color'] as String? ?? '#999999',
              monthlyLimitPaisa: (row['monthly_limit'] as num?)?.toInt() ?? 0,
              spentPaisa: (row['spent'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false);

      return Result<List<GroupCategoryBudgetModel>>.success(items);
    } catch (error) {
      return Result<List<GroupCategoryBudgetModel>>.failure(
        'Failed to load group budgets: $error',
      );
    }
  }

  Future<Result<void>> upsertGroupBudget({
    required String groupId,
    required String categoryId,
    required int monthlyLimitPaisa,
  }) async {
    try {
      if (monthlyLimitPaisa < 0) {
        return const Result<void>.failure('Monthly limit cannot be negative.');
      }

      final db = await _databaseHelper.database;
      final groupExists = await _groupExists(db: db, groupId: groupId);
      if (!groupExists) {
        return const Result<void>.failure('Group not found.');
      }

      final now = DateTime.now().toIso8601String();
      final existingRows = await db.query(
        'group_budgets',
        columns: <String>['id'],
        where: 'group_id = ? AND category_id = ?',
        whereArgs: <Object>[groupId, categoryId],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        await db.insert('group_budgets', <String, Object?>{
          'id': _uuid.v4(),
          'group_id': groupId,
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
          return const Result<void>.failure('Invalid group budget record.');
        }
        final updatedRows = await db.update(
          'group_budgets',
          <String, Object?>{
            'monthly_limit': monthlyLimitPaisa,
            'is_deleted': 0,
            'deleted_at': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object>[budgetId],
        );
        if (updatedRows == 0) {
          return const Result<void>.failure('Group budget not found.');
        }
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to save group budget: $error');
    }
  }

  Future<Result<List<GroupRecurringRuleModel>>> getGroupRecurringRules({
    required String groupId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.rawQuery(
        '''
          SELECT
            gr.*,
            c.name AS category_name,
            COALESCE(gm.name, 'Unknown Member') AS member_name
          FROM group_recurring_rules gr
          JOIN categories c ON c.id = gr.category_id
          LEFT JOIN group_members gm
            ON gm.id = gr.member_id
           AND gm.group_id = gr.group_id
          WHERE gr.group_id = ?
            AND gr.is_deleted = 0
            AND c.is_deleted = 0
          ORDER BY gr.is_paused ASC, gr.next_due_date ASC, gr.created_at DESC
        ''',
        <Object>[groupId],
      );

      final items = rows
          .map((row) => GroupRecurringRuleModel.fromMap(row))
          .toList(growable: false);
      return Result<List<GroupRecurringRuleModel>>.success(items);
    } catch (error) {
      return Result<List<GroupRecurringRuleModel>>.failure(
        'Failed to load group recurring rules: $error',
      );
    }
  }

  Future<Result<void>> createGroupRecurringRule({
    required String groupId,
    required String memberId,
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
      final groupExists = await _groupExists(db: db, groupId: groupId);
      if (!groupExists) {
        return const Result<void>.failure('Group not found.');
      }

      final memberExists = await _memberExists(
        db: db,
        groupId: groupId,
        memberId: memberId,
      );
      if (!memberExists) {
        return const Result<void>.failure('Member not found for this group.');
      }

      final now = DateTime.now().toIso8601String();
      await db.insert('group_recurring_rules', <String, Object?>{
        'id': _uuid.v4(),
        'group_id': groupId,
        'member_id': memberId,
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
      return Result<void>.failure(
        'Failed to create group recurring rule: $error',
      );
    }
  }

  Future<Result<void>> updateGroupRecurringRule({
    required String ruleId,
    required String groupId,
    required String memberId,
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
      final memberExists = await _memberExists(
        db: db,
        groupId: groupId,
        memberId: memberId,
      );
      if (!memberExists) {
        return const Result<void>.failure('Member not found for this group.');
      }

      final rows = await db.query(
        'group_recurring_rules',
        columns: <String>['next_due_date'],
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId, groupId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Result<void>.failure('Group recurring rule not found.');
      }

      final currentNextDue =
          DateTime.tryParse(rows.first['next_due_date'] as String? ?? '') ??
          startDate;
      final normalizedNextDue = currentNextDue.isBefore(startDate)
          ? startDate
          : currentNextDue;

      final updatedRows = await db.update(
        'group_recurring_rules',
        <String, Object?>{
          'member_id': memberId,
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
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId, groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Group recurring rule not found.');
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to update group recurring rule: $error',
      );
    }
  }

  Future<Result<void>> setGroupRecurringPaused({
    required String groupId,
    required String ruleId,
    required bool paused,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final updatedRows = await db.update(
        'group_recurring_rules',
        <String, Object?>{
          'is_paused': paused ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId, groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Group recurring rule not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to update group recurring status: $error',
      );
    }
  }

  Future<Result<void>> softDeleteGroupRecurringRule({
    required String groupId,
    required String ruleId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final now = DateTime.now().toIso8601String();
      final updatedRows = await db.update(
        'group_recurring_rules',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': now,
          'updated_at': now,
        },
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[ruleId, groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Group recurring rule not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to delete group recurring rule: $error',
      );
    }
  }

  Future<Result<void>> createGroupMember({
    required String groupId,
    required String name,
    String? photoKey,
  }) async {
    try {
      final normalizedName = name.trim();
      final normalizedPhotoKey = (photoKey ?? '').trim();
      if (normalizedName.isEmpty) {
        return const Result<void>.failure('Member name is required.');
      }

      final db = await _databaseHelper.database;
      final groupExists = await _groupExists(db: db, groupId: groupId);
      if (!groupExists) {
        return const Result<void>.failure('Group not found.');
      }

      final nameExists = await _memberNameExists(
        db: db,
        groupId: groupId,
        memberName: normalizedName,
      );
      if (nameExists) {
        return const Result<void>.failure(
          'A member with this name already exists in this group.',
        );
      }

      final nextSortOrder = await _nextMemberSortOrder(
        db: db,
        groupId: groupId,
      );
      final now = DateTime.now().toIso8601String();
      await db.insert('group_members', <String, Object?>{
        'id': _uuid.v4(),
        'group_id': groupId,
        'name': normalizedName,
        'photo_key': normalizedPhotoKey.isEmpty ? null : normalizedPhotoKey,
        'sort_order': nextSortOrder,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create group member: $error');
    }
  }

  Future<Result<void>> updateGroupMember({
    required String memberId,
    required String groupId,
    required String name,
    String? photoKey,
  }) async {
    try {
      final normalizedName = name.trim();
      final normalizedPhotoKey = (photoKey ?? '').trim();
      if (normalizedName.isEmpty) {
        return const Result<void>.failure('Member name is required.');
      }

      final db = await _databaseHelper.database;
      final rows = await db.query(
        'group_members',
        columns: <String>['id'],
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[memberId, groupId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Result<void>.failure('Member not found.');
      }

      final nameExists = await _memberNameExists(
        db: db,
        groupId: groupId,
        memberName: normalizedName,
        excludingMemberId: memberId,
      );
      if (nameExists) {
        return const Result<void>.failure(
          'A member with this name already exists in this group.',
        );
      }

      final updatedRows = await db.update(
        'group_members',
        <String, Object?>{
          'name': normalizedName,
          'photo_key': normalizedPhotoKey.isEmpty ? null : normalizedPhotoKey,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[memberId, groupId],
      );
      if (updatedRows == 0) {
        return const Result<void>.failure('Member not found.');
      }
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update group member: $error');
    }
  }

  Future<Result<void>> removeGroupMember({
    required String memberId,
    required String groupId,
    required bool deleteRelatedTransactions,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'group_members',
        columns: <String>['id'],
        where: 'id = ? AND group_id = ? AND is_deleted = 0',
        whereArgs: <Object>[memberId, groupId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Result<void>.failure('Member not found.');
      }

      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.update(
          'group_members',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'id = ? AND group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[memberId, groupId],
        );

        // Removed members should not keep active future recurring rules.
        await txn.update(
          'group_recurring_rules',
          <String, Object?>{
            'is_deleted': 1,
            'deleted_at': now,
            'updated_at': now,
          },
          where: 'member_id = ? AND group_id = ? AND is_deleted = 0',
          whereArgs: <Object>[memberId, groupId],
        );

        if (deleteRelatedTransactions) {
          await txn.update(
            'group_transactions',
            <String, Object?>{
              'is_deleted': 1,
              'deleted_at': now,
              'updated_at': now,
            },
            where: 'member_id = ? AND group_id = ? AND is_deleted = 0',
            whereArgs: <Object>[memberId, groupId],
          );
        }
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to remove group member: $error');
    }
  }

  Future<int> _nextSortOrder(Database db) async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(MAX(sort_order), -1) AS max_order
      FROM groups
      WHERE is_deleted = 0
    ''');
    final maxOrder = (rows.first['max_order'] as num?)?.toInt() ?? -1;
    return maxOrder + 1;
  }

  Future<int> _nextMemberSortOrder({
    required Database db,
    required String groupId,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(sort_order), -1) AS max_order
      FROM group_members
      WHERE group_id = ? AND is_deleted = 0
      ''',
      <Object>[groupId],
    );
    final maxOrder = (rows.first['max_order'] as num?)?.toInt() ?? -1;
    return maxOrder + 1;
  }

  Future<bool> _groupExists({
    required Database db,
    required String groupId,
  }) async {
    final rows = await db.query(
      'groups',
      columns: <String>['id'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: <Object>[groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _memberExists({
    required Database db,
    required String groupId,
    required String memberId,
  }) async {
    final rows = await db.query(
      'group_members',
      columns: <String>['id'],
      where: 'id = ? AND group_id = ? AND is_deleted = 0',
      whereArgs: <Object>[memberId, groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _nameExists({
    required Database db,
    required String name,
    String? excludingGroupId,
  }) async {
    final whereArgs = <Object>[name.trim()];
    final whereBuffer = StringBuffer(
      'LOWER(name) = LOWER(?) AND is_deleted = 0',
    );
    if (excludingGroupId != null) {
      whereBuffer.write(' AND id != ?');
      whereArgs.add(excludingGroupId);
    }

    final rows = await db.query(
      'groups',
      columns: <String>['id'],
      where: whereBuffer.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _memberNameExists({
    required Database db,
    required String groupId,
    required String memberName,
    String? excludingMemberId,
  }) async {
    final whereArgs = <Object>[groupId, memberName.trim()];
    final whereBuffer = StringBuffer(
      'group_id = ? AND LOWER(name) = LOWER(?) AND is_deleted = 0',
    );
    if (excludingMemberId != null) {
      whereBuffer.write(' AND id != ?');
      whereArgs.add(excludingMemberId);
    }

    final rows = await db.query(
      'group_members',
      columns: <String>['id'],
      where: whereBuffer.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static String _monthPrefix(DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final monthValue = month.month.toString().padLeft(2, '0');
    return '$year-$monthValue';
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

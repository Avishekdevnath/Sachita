import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.currencySymbol,
    required this.userName,
    required this.netBalancePaisa,
    required this.allTimeIncomePaisa,
    required this.allTimeExpensePaisa,
    required this.weeklyIncomePaisa,
    required this.weeklyExpensePaisa,
    required this.budgetTrackedCount,
    required this.budgetNearLimitCount,
    required this.budgetExceededCount,
    required this.activeGroupsCount,
    required this.vaultItemsCount,
    required this.pendingRecurringApprovals,
    required this.recentTransactions,
    required this.aiLastRefreshedAt,
  });

  final String currencySymbol;
  final String? userName;
  final int netBalancePaisa;
  final int allTimeIncomePaisa;
  final int allTimeExpensePaisa;
  final int weeklyIncomePaisa;
  final int weeklyExpensePaisa;
  final int budgetTrackedCount;
  final int budgetNearLimitCount;
  final int budgetExceededCount;
  final int activeGroupsCount;
  final int vaultItemsCount;
  final int pendingRecurringApprovals;
  final List<DashboardRecentTransaction> recentTransactions;
  final DateTime? aiLastRefreshedAt;
}

class DashboardRecentTransaction {
  const DashboardRecentTransaction({
    required this.id,
    required this.type,
    required this.amountPaisa,
    required this.note,
    required this.date,
    required this.categoryName,
    required this.categoryColorHex,
  });

  final String id;
  final String type;
  final int amountPaisa;
  final String note;
  final DateTime date;
  final String categoryName;
  final String categoryColorHex;

  factory DashboardRecentTransaction.fromMap(Map<String, Object?> row) {
    return DashboardRecentTransaction(
      id: row['id'] as String? ?? '',
      type: row['type'] as String? ?? 'expense',
      amountPaisa: row['amount'] as int? ?? 0,
      note: row['note'] as String? ?? '',
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      categoryName: row['category_name'] as String? ?? 'Unknown',
      categoryColorHex: row['category_color'] as String? ?? '#999999',
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    databaseHelper: DatabaseHelper.instance,
    secureStorageService: SecureStorageService.instance,
  );
});

class DashboardRepository {
  const DashboardRepository({
    required this.databaseHelper,
    required this.secureStorageService,
    Future<Database> Function()? openDatabase,
  }) : _openDatabase = openDatabase;

  static const String _hideBalanceStorageKey = 'dashboard_hide_balance';
  static const String _aiTeaserLastRefreshStorageKey =
      'dashboard_ai_teaser_last_refresh';

  final DatabaseHelper databaseHelper;
  final SecureStorageService secureStorageService;
  final Future<Database> Function()? _openDatabase;

  Future<Result<DashboardSnapshot>> getSnapshot({
    required DateTime month,
    required DateTime today,
  }) async {
    try {
      final db = await (_openDatabase?.call() ?? databaseHelper.database);
      final monthPrefix = _monthPrefix(month);
      final todayValue = _dateOnly(today);
      final weekStartValue = _dateOnly(today.subtract(const Duration(days: 6)));

      final settingsRows = await db.query(
        'app_settings',
        columns: <String>['currency_symbol', 'user_name'],
        where: 'id = ?',
        whereArgs: <Object>['singleton'],
        limit: 1,
      );

      // Parallelize 8 independent queries
      final results = await Future.wait(<Future<List<Map<String, Object?>>>>[
        db.rawQuery(
          '''
            SELECT COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE type = ? AND is_deleted = 0
          ''',
          <Object>['income'],
        ),
        db.rawQuery(
          '''
            SELECT COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE type = ? AND is_deleted = 0
          ''',
          <Object>['expense'],
        ),
        db.rawQuery(
          '''
            SELECT COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE type = ?
              AND is_deleted = 0
              AND date >= ?
              AND date <= ?
          ''',
          <Object>['income', weekStartValue, todayValue],
        ),
        db.rawQuery(
          '''
            SELECT COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE type = ?
              AND is_deleted = 0
              AND date >= ?
              AND date <= ?
          ''',
          <Object>['expense', weekStartValue, todayValue],
        ),
        db.rawQuery('''
          SELECT COUNT(*) AS total
          FROM groups
          WHERE is_deleted = 0
        '''),
        db.rawQuery(
          '''
            SELECT COUNT(*) AS total
            FROM recurring_rules
            WHERE is_deleted = 0
              AND is_paused = 0
              AND next_due_date <= ?
              AND (end_date IS NULL OR end_date >= ?)
          ''',
          <Object>[todayValue, todayValue],
        ),
        db.rawQuery(
          '''
            SELECT
              b.monthly_limit AS monthly_limit,
              COALESCE(SUM(t.amount), 0) AS spent
            FROM budgets b
            JOIN categories c ON c.id = b.category_id
            LEFT JOIN transactions t
              ON t.category_id = b.category_id
             AND t.type = 'expense'
             AND t.is_deleted = 0
             AND t.date LIKE ?
            WHERE b.is_deleted = 0
              AND c.is_deleted = 0
              AND b.monthly_limit > 0
            GROUP BY b.category_id, b.monthly_limit
          ''',
          <Object>['$monthPrefix%'],
        ),
        db.rawQuery('''
          SELECT
            t.id,
            t.type,
            t.amount,
            t.note,
            t.date,
            c.name AS category_name,
            c.color AS category_color
          FROM transactions t
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE t.is_deleted = 0
          ORDER BY t.created_at DESC
          LIMIT 5
        '''),
      ]);

      final incomeRows = results[0];
      final expenseRows = results[1];
      final weeklyIncomeRows = results[2];
      final weeklyExpenseRows = results[3];
      final groupsRows = results[4];
      final pendingRecurringRows = results[5];
      final budgetRows = results[6];
      final recentRows = results[7];

      final vaultInfoCount = await _countFromSecureIndex(
        indexKey: 'vault_info_index',
        itemPrefix: 'vault_info_',
      );

      final income = (incomeRows.first['total'] as num?)?.toInt() ?? 0;
      final expense = (expenseRows.first['total'] as num?)?.toInt() ?? 0;
      final weeklyIncome =
          (weeklyIncomeRows.first['total'] as num?)?.toInt() ?? 0;
      final weeklyExpense =
          (weeklyExpenseRows.first['total'] as num?)?.toInt() ?? 0;
      final groupsCount = (groupsRows.first['total'] as num?)?.toInt() ?? 0;
      final pendingRecurring =
          (pendingRecurringRows.first['total'] as num?)?.toInt() ?? 0;
      final settingsRow = settingsRows.isEmpty ? null : settingsRows.first;
      final currencySymbol =
          settingsRow?['currency_symbol'] as String? ?? 'BDT';
      final userNameRaw = settingsRow?['user_name'] as String?;
      final normalizedUserName = userNameRaw?.trim();

      final recentTransactions = recentRows
          .map((row) => DashboardRecentTransaction.fromMap(row))
          .toList(growable: false);
      final budgetSummary = _summarizeBudgets(budgetRows);
      final aiLastRefreshRaw = await secureStorageService.read(
        _aiTeaserLastRefreshStorageKey,
      );
      final aiLastRefresh = aiLastRefreshRaw == null
          ? null
          : DateTime.tryParse(aiLastRefreshRaw);

      return Result<DashboardSnapshot>.success(
        DashboardSnapshot(
          currencySymbol: currencySymbol,
          userName: (normalizedUserName?.isEmpty ?? true)
              ? null
              : normalizedUserName,
          netBalancePaisa: income - expense,
          allTimeIncomePaisa: income,
          allTimeExpensePaisa: expense,
          weeklyIncomePaisa: weeklyIncome,
          weeklyExpensePaisa: weeklyExpense,
          budgetTrackedCount: budgetSummary.trackedCount,
          budgetNearLimitCount: budgetSummary.nearLimitCount,
          budgetExceededCount: budgetSummary.exceededCount,
          activeGroupsCount: groupsCount,
          vaultItemsCount: vaultInfoCount,
          pendingRecurringApprovals: pendingRecurring,
          recentTransactions: recentTransactions,
          aiLastRefreshedAt: aiLastRefresh,
        ),
      );
    } catch (error) {
      return Result<DashboardSnapshot>.failure(
        'Failed to load dashboard snapshot: $error',
      );
    }
  }

  Future<Result<bool>> getHideBalancePreference() async {
    try {
      final raw = await secureStorageService.read(_hideBalanceStorageKey);
      return Result<bool>.success(raw == '1');
    } catch (error) {
      return Result<bool>.failure(
        'Failed to load dashboard preference: $error',
      );
    }
  }

  Future<Result<void>> setHideBalancePreference(bool hidden) async {
    try {
      await secureStorageService.write(
        key: _hideBalanceStorageKey,
        value: hidden ? '1' : '0',
      );
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        'Failed to save dashboard preference: $error',
      );
    }
  }

  Future<Result<DateTime>> refreshAiTeaserTimestamp() async {
    try {
      final now = DateTime.now();
      await secureStorageService.write(
        key: _aiTeaserLastRefreshStorageKey,
        value: now.toIso8601String(),
      );
      return Result<DateTime>.success(now);
    } catch (error) {
      return Result<DateTime>.failure(
        'Failed to update AI teaser timestamp: $error',
      );
    }
  }

  _BudgetSummary _summarizeBudgets(List<Map<String, Object?>> rows) {
    var trackedCount = 0;
    var nearLimitCount = 0;
    var exceededCount = 0;

    for (final row in rows) {
      final limit = (row['monthly_limit'] as num?)?.toInt() ?? 0;
      if (limit <= 0) {
        continue;
      }

      trackedCount++;
      final spent = (row['spent'] as num?)?.toInt() ?? 0;
      if (spent >= limit) {
        exceededCount++;
        continue;
      }

      final usagePercent = (spent * 100) / limit;
      if (usagePercent >= 80) {
        nearLimitCount++;
      }
    }

    return _BudgetSummary(
      trackedCount: trackedCount,
      nearLimitCount: nearLimitCount,
      exceededCount: exceededCount,
    );
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

  Future<int> _countFromSecureIndex({
    required String indexKey,
    required String itemPrefix,
  }) async {
    final rawIndex = await secureStorageService.read(indexKey);
    if (rawIndex != null && rawIndex.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawIndex);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((id) => id.trim().isNotEmpty)
              .length;
        }
      } catch (_) {}
    }

    // OPTIMIZATION: Don't use expensive readAll() in dashboard snapshot path.
    // If index is missing/corrupt, return 0 and rely on index maintenance
    // during create/update/delete operations.
    // Missing indexes will be rebuilt during background maintenance tasks.
    return 0;
  }
}

class _BudgetSummary {
  const _BudgetSummary({
    required this.trackedCount,
    required this.nearLimitCount,
    required this.exceededCount,
  });

  final int trackedCount;
  final int nearLimitCount;
  final int exceededCount;
}

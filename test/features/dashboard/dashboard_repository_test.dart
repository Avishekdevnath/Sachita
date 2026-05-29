import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/dashboard/data/dashboard_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createDashboardSchema(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('dashboard net balance includes transactions from every month', () async {
    await _seedSettings(db);
    await _seedCategory(db, id: 'salary', type: 'income');
    await _seedCategory(db, id: 'food', type: 'expense');
    await _seedTransaction(
      db,
      id: 'april-income',
      type: 'income',
      amount: 5000000,
      categoryId: 'salary',
      date: '2026-04-23',
    );
    await _seedTransaction(
      db,
      id: 'april-expense',
      type: 'expense',
      amount: 5555500,
      categoryId: 'food',
      date: '2026-04-23',
    );
    await _seedTransaction(
      db,
      id: 'may-income',
      type: 'income',
      amount: 7625500,
      categoryId: 'salary',
      date: '2026-05-01',
    );
    await _seedTransaction(
      db,
      id: 'may-expense',
      type: 'expense',
      amount: 1554700,
      categoryId: 'food',
      date: '2026-05-01',
    );

    final repository = DashboardRepository(
      databaseHelper: DatabaseHelper.instance,
      secureStorageService: _FakeSecureStorageService(),
      openDatabase: () async => db,
    );

    final result = await repository.getSnapshot(
      month: DateTime(2026, 5),
      today: DateTime(2026, 5),
    );

    result.when(
      success: (snapshot) {
        expect(snapshot.netBalancePaisa, 5515300);
      },
      failure: fail,
    );
  });
}

Future<void> _createDashboardSchema(Database db) async {
  await db.execute('''
    CREATE TABLE app_settings (
      id TEXT PRIMARY KEY,
      currency_symbol TEXT,
      user_name TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL,
      category_id TEXT NOT NULL,
      note TEXT,
      date TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE groups (
      id TEXT PRIMARY KEY,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE recurring_rules (
      id TEXT PRIMARY KEY,
      next_due_date TEXT NOT NULL,
      end_date TEXT,
      is_paused INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      category_id TEXT NOT NULL,
      monthly_limit INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

Future<void> _seedSettings(Database db) async {
  await db.insert('app_settings', <String, Object?>{
    'id': 'singleton',
    'currency_symbol': 'BDT',
    'user_name': 'Avishek',
  });
}

Future<void> _seedCategory(
  Database db, {
  required String id,
  required String type,
}) async {
  await db.insert('categories', <String, Object?>{
    'id': id,
    'name': id,
    'type': type,
    'color': '#ffffff',
    'is_deleted': 0,
  });
}

Future<void> _seedTransaction(
  Database db, {
  required String id,
  required String type,
  required int amount,
  required String categoryId,
  required String date,
}) async {
  await db.insert('transactions', <String, Object?>{
    'id': id,
    'type': type,
    'amount': amount,
    'category_id': categoryId,
    'note': null,
    'date': date,
    'is_deleted': 0,
    'created_at': date,
  });
}

class _FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.unmodifiable(_values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}

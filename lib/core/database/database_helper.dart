import 'package:path/path.dart';
import 'package:sanchita/core/constants/app_constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const Uuid _uuid = Uuid();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    _database = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id TEXT PRIMARY KEY DEFAULT 'singleton',
        currency_code TEXT NOT NULL DEFAULT 'BDT',
        currency_symbol TEXT NOT NULL DEFAULT 'BDT',
        theme TEXT NOT NULL DEFAULT 'system',
        language TEXT NOT NULL DEFAULT 'en',
        auto_lock_mins INTEGER NOT NULL DEFAULT 300,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        onboarding_done INTEGER NOT NULL DEFAULT 0,
        user_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE security (
        id TEXT PRIMARY KEY DEFAULT 'singleton',
        pin_hash TEXT NOT NULL,
        security_question TEXT NOT NULL,
        security_answer TEXT NOT NULL,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        recurring_rule_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL UNIQUE,
        monthly_limit INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE recurring_rules (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_due_date TEXT NOT NULL,
        is_paused INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE recurring_log (
        id TEXT PRIMARY KEY,
        rule_id TEXT NOT NULL,
        due_date TEXT NOT NULL,
        action TEXT NOT NULL,
        amount_used INTEGER,
        transaction_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (rule_id) REFERENCES recurring_rules(id),
        FOREIGN KEY (transaction_id) REFERENCES transactions(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE group_members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        name TEXT NOT NULL,
        photo_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE group_transactions (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        recurring_rule_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (member_id) REFERENCES group_members(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE group_budgets (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        monthly_limit INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(group_id, category_id),
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE group_recurring_rules (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_due_date TEXT NOT NULL,
        is_paused INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (member_id) REFERENCES group_members(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE search_history (
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        searched_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE backup_log (
        id TEXT PRIMARY KEY,
        backup_date TEXT NOT NULL,
        destination TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(date);',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_type ON transactions(type);',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category_id);',
    );
    await db.execute(
      'CREATE INDEX idx_group_transactions_group ON group_transactions(group_id);',
    );
    await db.execute(
      'CREATE INDEX idx_group_transactions_member ON group_transactions(member_id);',
    );
    await db.execute(
      'CREATE INDEX idx_group_transactions_date ON group_transactions(date);',
    );

    // Composite indexes for common query patterns
    await db.execute(
      'CREATE INDEX idx_transactions_deleted_date ON transactions(is_deleted, date);',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_deleted_type ON transactions(is_deleted, type);',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_deleted_category ON transactions(is_deleted, category_id);',
    );
    await db.execute(
      'CREATE INDEX idx_group_transactions_group_deleted ON group_transactions(group_id, is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_group_transactions_date_deleted ON group_transactions(date, is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_categories_deleted_type ON categories(is_deleted, type);',
    );
    await db.execute(
      'CREATE INDEX idx_groups_deleted ON groups(is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_group_members_deleted ON group_members(group_id, is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_recurring_rules_next_due ON recurring_rules(next_due_date, is_paused, is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_recurring_log_rule ON recurring_log(rule_id);',
    );
    await db.execute(
      'CREATE INDEX idx_recurring_log_transaction ON recurring_log(transaction_id);',
    );
    await db.execute(
      'CREATE INDEX idx_search_history_searched_at ON search_history(searched_at);',
    );

    final now = DateTime.now().toIso8601String();

    await db.insert('app_settings', <String, Object?>{
      'id': 'singleton',
      'currency_code': 'BDT',
      'currency_symbol': 'BDT',
      'theme': 'system',
      'language': 'en',
      'auto_lock_mins': 300,
      'biometric_enabled': 0,
      'onboarding_done': 0,
      'user_name': null,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('security', <String, Object?>{
      'id': 'singleton',
      'pin_hash': 'UNSET',
      'security_question': 'UNSET',
      'security_answer': 'UNSET',
      'failed_attempts': 0,
      'locked_until': null,
      'created_at': now,
      'updated_at': now,
    });

    await _seedDefaultCategoriesAndBudgets(db, now);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _runMigration(db, v);
    }
  }

  Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 2:
        // Migration 1 → 2: Add indexes for recurring_log and search_history
        await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_log_rule ON recurring_log(rule_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_log_transaction ON recurring_log(transaction_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history(searched_at);');
        break;
      // Add more migrations here as needed
    }
  }

  Future<void> _seedDefaultCategoriesAndBudgets(Database db, String now) async {
    const expenseCategories = <Map<String, String>>[
      <String, String>{'name': 'Food', 'icon': 'food', 'color': '#FF6B6B'},
      <String, String>{
        'name': 'Transport',
        'icon': 'transport',
        'color': '#4ECDC4',
      },
      <String, String>{
        'name': 'Education',
        'icon': 'education',
        'color': '#45B7D1',
      },
      <String, String>{'name': 'Health', 'icon': 'health', 'color': '#96CEB4'},
      <String, String>{
        'name': 'Utilities',
        'icon': 'utilities',
        'color': '#FFEAA7',
      },
      <String, String>{
        'name': 'Shopping',
        'icon': 'shopping',
        'color': '#DDA0DD',
      },
      <String, String>{
        'name': 'Entertainment',
        'icon': 'entertainment',
        'color': '#98D8C8',
      },
      <String, String>{'name': 'Rent', 'icon': 'rent', 'color': '#F7DC6F'},
      <String, String>{'name': 'Other', 'icon': 'other', 'color': '#AED6F1'},
    ];

    const incomeCategories = <Map<String, String>>[
      <String, String>{'name': 'Salary', 'icon': 'salary', 'color': '#2ECC71'},
      <String, String>{
        'name': 'Freelance',
        'icon': 'freelance',
        'color': '#27AE60',
      },
      <String, String>{
        'name': 'Business',
        'icon': 'business',
        'color': '#1ABC9C',
      },
      <String, String>{'name': 'Gift', 'icon': 'gift', 'color': '#16A085'},
      <String, String>{
        'name': 'Scholarship',
        'icon': 'scholarship',
        'color': '#2980B9',
      },
      <String, String>{'name': 'Other', 'icon': 'other', 'color': '#3498DB'},
    ];

    final expenseIds = <String>[];

    for (var index = 0; index < expenseCategories.length; index++) {
      final category = expenseCategories[index];
      final id = _uuid.v4();
      expenseIds.add(id);
      await db.insert('categories', <String, Object?>{
        'id': id,
        'name': category['name'],
        'type': 'expense',
        'icon': category['icon'],
        'color': category['color'],
        'is_default': 1,
        'sort_order': index,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
    }

    for (var index = 0; index < incomeCategories.length; index++) {
      final category = incomeCategories[index];
      await db.insert('categories', <String, Object?>{
        'id': _uuid.v4(),
        'name': category['name'],
        'type': 'income',
        'icon': category['icon'],
        'color': category['color'],
        'is_default': 1,
        'sort_order': index,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
    }

    for (final expenseCategoryId in expenseIds) {
      await db.insert('budgets', <String, Object?>{
        'id': _uuid.v4(),
        'category_id': expenseCategoryId,
        'monthly_limit': 0,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<bool> getOnboardingDone() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: <String>['onboarding_done'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return (rows.first['onboarding_done'] as int? ?? 0) == 1;
  }

  Future<void> setOnboardingDone(bool done) async {
    final db = await database;
    await db.update(
      'app_settings',
      <String, Object>{
        'onboarding_done': done ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<bool> getBiometricEnabled() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: <String>['biometric_enabled'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return (rows.first['biometric_enabled'] as int? ?? 0) == 1;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final db = await database;
    await db.update(
      'app_settings',
      <String, Object>{
        'biometric_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<int> getFailedAttempts() async {
    final db = await database;
    final rows = await db.query(
      'security',
      columns: <String>['failed_attempts'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 0;
    }

    return rows.first['failed_attempts'] as int? ?? 0;
  }

  Future<void> setFailedAttempts(int attempts) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'failed_attempts': attempts,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<DateTime?> getLockedUntil() async {
    final db = await database;
    final rows = await db.query(
      'security',
      columns: <String>['locked_until'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    final value = rows.first['locked_until'] as String?;
    if (value == null || value.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<void> setLockedUntil(DateTime? lockedUntil) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object?>{
        'locked_until': lockedUntil?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<Map<String, Object?>?> getAppSettings() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    return rows.first;
  }

  Future<void> updateAppSettings(Map<String, Object?> values) async {
    final db = await database;
    await db.update(
      'app_settings',
      <String, Object?>{
        ...values,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<void> setSecurityCredentials({
    required String pinHash,
    required String securityQuestion,
    required String securityAnswerHash,
  }) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'pin_hash': pinHash,
        'security_question': securityQuestion,
        'security_answer': securityAnswerHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<void> updatePinHash(String pinHash) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'pin_hash': pinHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<void> updateSecurityAnswerHash(String securityAnswerHash) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'security_answer': securityAnswerHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<void> updateSecurityQuestion(String securityQuestion) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'security_question': securityQuestion,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<void> updateSecurityQuestionAndAnswer({
    required String securityQuestion,
    required String securityAnswerHash,
  }) async {
    final db = await database;
    await db.update(
      'security',
      <String, Object>{
        'security_question': securityQuestion,
        'security_answer': securityAnswerHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
    );
  }

  Future<String> getPinHash() async {
    final db = await database;
    final rows = await db.query(
      'security',
      columns: <String>['pin_hash'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 'UNSET';
    }

    return rows.first['pin_hash'] as String? ?? 'UNSET';
  }

  Future<String?> getSecurityQuestion() async {
    final db = await database;
    final rows = await db.query(
      'security',
      columns: <String>['security_question'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    final value = rows.first['security_question'] as String?;
    if (value == null || value == 'UNSET') {
    // Defensive null return - validation failed
      return null;
    }

    return value;
  }

  Future<String> getSecurityAnswerHash() async {
    final db = await database;
    final rows = await db.query(
      'security',
      columns: <String>['security_answer'],
      where: 'id = ?',
      whereArgs: <Object>['singleton'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 'UNSET';
    }

    return rows.first['security_answer'] as String? ?? 'UNSET';
  }

  Future<void> resetDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await deleteDatabase(path);
  }
}

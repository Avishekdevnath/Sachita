import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(DatabaseHelper.instance);
});

class CategoryRepository {
  CategoryRepository(this._databaseHelper);

  static const Uuid _uuid = Uuid();
  final DatabaseHelper _databaseHelper;

  Future<Result<List<CategoryModel>>> getCategoriesByType(String type) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'categories',
        where: 'type = ? AND is_deleted = 0',
        whereArgs: <Object>[type],
        orderBy: 'sort_order ASC, name ASC',
      );

      final categories = rows
          .map((row) => CategoryModel.fromMap(row))
          .toList(growable: false);
      return Result<List<CategoryModel>>.success(categories);
    } catch (error) {
      return Result<List<CategoryModel>>.failure(
        'Failed to load categories: $error',
      );
    }
  }

  Future<Result<List<CategoryModel>>> getAllCategories() async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'categories',
        where: 'is_deleted = 0',
        orderBy: 'type ASC, sort_order ASC, name ASC',
      );

      final categories = rows
          .map((row) => CategoryModel.fromMap(row))
          .toList(growable: false);
      return Result<List<CategoryModel>>.success(categories);
    } catch (error) {
      return Result<List<CategoryModel>>.failure(
        'Failed to load categories: $error',
      );
    }
  }

  Future<Result<void>> createCategory({
    required String type,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        return const Result<void>.failure('Category name is required.');
      }

      final db = await _databaseHelper.database;
      final exists = await _nameExists(db: db, type: type, name: trimmedName);
      if (exists) {
        return const Result<void>.failure(
          'A category with this name already exists.',
        );
      }

      final nextOrder = await _nextSortOrder(db: db, type: type);
      final now = DateTime.now().toIso8601String();
      await db.insert('categories', <String, Object?>{
        'id': _uuid.v4(),
        'name': trimmedName,
        'type': type,
        'icon': icon.trim().isEmpty ? 'other' : icon.trim(),
        'color': colorHex.trim().isEmpty ? '#999999' : colorHex.trim(),
        'is_default': 0,
        'sort_order': nextOrder,
        'is_deleted': 0,
        'deleted_at': null,
        'created_at': now,
        'updated_at': now,
      });

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create category: $error');
    }
  }

  Future<Result<void>> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        return const Result<void>.failure('Category name is required.');
      }

      final db = await _databaseHelper.database;
      final categoryRows = await db.query(
        'categories',
        columns: <String>['id', 'type', 'is_default'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[id],
        limit: 1,
      );

      if (categoryRows.isEmpty) {
        return const Result<void>.failure('Category not found.');
      }

      final category = categoryRows.first;
      final type = category['type'] as String? ?? 'expense';
      final isDefault = (category['is_default'] as int? ?? 0) == 1;
      if (isDefault) {
        return const Result<void>.failure(
          'Default categories cannot be edited.',
        );
      }

      final exists = await _nameExists(
        db: db,
        type: type,
        name: trimmedName,
        excludingId: id,
      );
      if (exists) {
        return const Result<void>.failure(
          'A category with this name already exists.',
        );
      }

      await db.update(
        'categories',
        <String, Object?>{
          'name': trimmedName,
          'icon': icon.trim().isEmpty ? 'other' : icon.trim(),
          'color': colorHex.trim().isEmpty ? '#999999' : colorHex.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[id],
      );

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update category: $error');
    }
  }

  Future<Result<void>> softDeleteCategory(String id) async {
    try {
      final db = await _databaseHelper.database;
      final categoryRows = await db.query(
        'categories',
        columns: <String>['is_default'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[id],
        limit: 1,
      );

      if (categoryRows.isEmpty) {
        return const Result<void>.failure('Category not found.');
      }

      final isDefault = (categoryRows.first['is_default'] as int? ?? 0) == 1;
      if (isDefault) {
        return const Result<void>.failure(
          'Default categories cannot be deleted.',
        );
      }

      final hasUsage = await _hasActiveUsage(db: db, categoryId: id);
      if (hasUsage) {
        return const Result<void>.failure(
          'This category is used by active records and cannot be deleted.',
        );
      }

      await db.update(
        'categories',
        <String, Object?>{
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object>[id],
      );

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete category: $error');
    }
  }

  Future<int> _nextSortOrder({
    required Database db,
    required String type,
  }) async {
    final rows = await db.rawQuery(
      '''
        SELECT COALESCE(MAX(sort_order), -1) AS max_order
        FROM categories
        WHERE type = ?
      ''',
      <Object>[type],
    );
    final maxOrder = (rows.first['max_order'] as num?)?.toInt() ?? -1;
    return maxOrder + 1;
  }

  Future<bool> _nameExists({
    required Database db,
    required String type,
    required String name,
    String? excludingId,
  }) async {
    final whereArgs = <Object>[type, name.trim()];
    final whereBuffer = StringBuffer(
      'type = ? AND LOWER(name) = LOWER(?) AND is_deleted = 0',
    );
    if (excludingId != null) {
      whereBuffer.write(' AND id != ?');
      whereArgs.add(excludingId);
    }

    final rows = await db.query(
      'categories',
      columns: <String>['id'],
      where: whereBuffer.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<bool> _hasActiveUsage({
    required Database db,
    required String categoryId,
  }) async {
    final rows = await db.rawQuery(
      '''
        SELECT
          (
            (SELECT COUNT(1) FROM transactions
             WHERE category_id = ? AND is_deleted = 0)
            +
            (SELECT COUNT(1) FROM recurring_rules
             WHERE category_id = ? AND is_deleted = 0)
            +
            (SELECT COUNT(1) FROM group_transactions
             WHERE category_id = ? AND is_deleted = 0)
            +
            (SELECT COUNT(1) FROM group_recurring_rules
             WHERE category_id = ? AND is_deleted = 0)
          ) AS usage_count
      ''',
      <Object>[categoryId, categoryId, categoryId, categoryId],
    );

    final usageCount = (rows.first['usage_count'] as num?)?.toInt() ?? 0;
    return usageCount > 0;
  }
}

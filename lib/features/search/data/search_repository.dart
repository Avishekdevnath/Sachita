import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/search/models/search_result_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    DatabaseHelper.instance,
    SecureStorageService.instance,
  );
});

class SearchRepository {
  SearchRepository(this._databaseHelper, this._secureStorageService);

  static const Uuid _uuid = Uuid();
  static const String _vaultInfoIndexKey = 'vault_info_index';
  static const String _vaultInfoPrefix = 'vault_info_';
  static const String _vaultDocFolderIndexKey = 'vault_doc_index';
  static const String _vaultDocFolderPrefix = 'vault_doc_folder_';
  static const String _vaultDocItemIndexKey = 'vault_doc_item_index';
  static const String _vaultDocItemPrefix = 'vault_doc_item_';
  static const String _groupVaultInfoIndexPrefix = 'group_vault_info_index_';
  static const String _groupVaultInfoItemPrefix = 'group_vault_info_';
  static const String _groupVaultDocFolderIndexPrefix = 'group_vault_doc_index_';
  static const String _groupVaultDocFolderPrefix = 'group_vault_doc_folder_';
  static const String _groupVaultDocItemIndexPrefix = 'group_vault_doc_item_index_';
  static const String _groupVaultDocItemPrefix = 'group_vault_doc_item_';

  final DatabaseHelper _databaseHelper;
  final SecureStorageService _secureStorageService;

  Future<Result<List<SearchResultModel>>> search({
    required String query,
    required Set<String> sources,
  }) async {
    try {
      final normalized = query.trim();
      if (normalized.length < 2) {
        return const Result<List<SearchResultModel>>.success(
          <SearchResultModel>[],
        );
      }

      final db = await _databaseHelper.database;
      final pattern = '%${normalized.toLowerCase()}%';
      final results = <SearchResultModel>[];

      if (sources.contains('finance')) {
        final transactionRows = await db.rawQuery(
          '''
            SELECT
              t.id AS id,
              COALESCE(NULLIF(t.note, ''), c.name) AS title,
              c.name AS category_name,
              t.date AS date,
              t.amount AS amount
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
            WHERE t.is_deleted = 0
              AND c.is_deleted = 0
              AND (
                LOWER(COALESCE(t.note, '')) LIKE ?
                OR LOWER(c.name) LIKE ?
              )
            ORDER BY t.date DESC, t.created_at DESC
            LIMIT 15
          ''',
          <Object>[pattern, pattern],
        );

        for (final row in transactionRows) {
          final amountPaisa = (row['amount'] as num?)?.toInt() ?? 0;
          final amountLabel = (amountPaisa / 100).toStringAsFixed(2);
          final dateValue = row['date'] as String? ?? '';
          final categoryName = row['category_name'] as String? ?? 'Unknown';
          results.add(
            SearchResultModel(
              id: row['id'] as String? ?? '',
              source: 'finance',
              kind: 'transaction',
              title: row['title'] as String? ?? 'Transaction',
              subtitle: '$categoryName - $dateValue - $amountLabel',
            ),
          );
        }

        final recurringRows = await db.rawQuery(
          '''
            SELECT
              rr.id AS id,
              COALESCE(NULLIF(rr.note, ''), c.name) AS title,
              c.name AS category_name,
              rr.frequency AS frequency,
              rr.next_due_date AS next_due_date,
              rr.amount AS amount
            FROM recurring_rules rr
            JOIN categories c ON c.id = rr.category_id
            WHERE rr.is_deleted = 0
              AND c.is_deleted = 0
              AND (
                LOWER(COALESCE(rr.note, '')) LIKE ?
                OR LOWER(c.name) LIKE ?
              )
            ORDER BY rr.next_due_date ASC, rr.created_at DESC
            LIMIT 10
          ''',
          <Object>[pattern, pattern],
        );

        for (final row in recurringRows) {
          final amountPaisa = (row['amount'] as num?)?.toInt() ?? 0;
          final amountLabel = (amountPaisa / 100).toStringAsFixed(2);
          final frequency = row['frequency'] as String? ?? 'recurring';
          final nextDueDate = row['next_due_date'] as String? ?? '';
          final categoryName = row['category_name'] as String? ?? 'Unknown';
          results.add(
            SearchResultModel(
              id: row['id'] as String? ?? '',
              source: 'finance',
              kind: 'recurring',
              title: row['title'] as String? ?? 'Recurring Rule',
              subtitle:
                  'Recurring: $categoryName - $frequency - $nextDueDate - $amountLabel',
            ),
          );
        }
      }

      if (sources.contains('groups')) {
        final groupRows = await db.rawQuery(
          '''
            SELECT id, name
            FROM groups
            WHERE is_deleted = 0
              AND LOWER(name) LIKE ?
            ORDER BY sort_order ASC, name ASC
            LIMIT 10
          ''',
          <Object>[pattern],
        );

        for (final row in groupRows) {
          results.add(
            SearchResultModel(
              id: row['id'] as String? ?? '',
              source: 'groups',
              kind: 'group',
              title: row['name'] as String? ?? 'Group',
              subtitle: 'Group',
            ),
          );
        }

        final memberRows = await db.rawQuery(
          '''
            SELECT
              gm.id AS member_id,
              gm.name AS member_name,
              g.id AS group_id,
              g.name AS group_name
            FROM group_members gm
            JOIN groups g
              ON g.id = gm.group_id
             AND g.is_deleted = 0
            WHERE gm.is_deleted = 0
              AND LOWER(gm.name) LIKE ?
            ORDER BY gm.sort_order ASC, gm.name ASC
            LIMIT 15
          ''',
          <Object>[pattern],
        );

        for (final row in memberRows) {
          results.add(
            SearchResultModel(
              id: row['member_id'] as String? ?? '',
              parentId: row['group_id'] as String? ?? '',
              source: 'groups',
              kind: 'group_member',
              title: row['member_name'] as String? ?? 'Group Member',
              subtitle:
                  'Member in ${row['group_name'] as String? ?? 'Unknown Group'}',
            ),
          );
        }

        final groupNameRows = await db.query(
          'groups',
          columns: <String>['id', 'name'],
          where: 'is_deleted = 0',
          orderBy: 'sort_order ASC, name ASC',
        );
        final groupNamesById = <String, String>{
          for (final row in groupNameRows)
            (row['id'] as String? ?? ''): (row['name'] as String? ?? 'Group'),
        };
        if (groupNamesById.isNotEmpty) {
          await _appendGroupVaultInfoMatches(
            results: results,
            normalizedQuery: normalized.toLowerCase(),
            groupNamesById: groupNamesById,
          );
          await _appendGroupVaultDocMatches(
            results: results,
            normalizedQuery: normalized.toLowerCase(),
            groupNamesById: groupNamesById,
          );
        }
      }

      if (sources.contains('info')) {
        final infoIds = await _loadOrRebuildSecureIndex(
          indexKey: _vaultInfoIndexKey,
          itemPrefix: _vaultInfoPrefix,
        );
        for (final id in infoIds) {
          final raw = await _secureStorageService.read('$_vaultInfoPrefix$id');
          if (raw == null || raw.isEmpty) {
            continue;
          }

          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          if (_isDeletedFlag(decoded['is_deleted'])) {
            continue;
          }

          final label = (decoded['label'] as String? ?? '').trim();
          final category = (decoded['category'] as String? ?? '').trim();
          if (label.isEmpty) {
            continue;
          }

          final searchable = '$label $category'.toLowerCase();
          if (!searchable.contains(normalized.toLowerCase())) {
            continue;
          }

          results.add(
            SearchResultModel(
              id: id,
              source: 'info',
              kind: 'vault_info',
              title: label,
              subtitle: category.isEmpty
                  ? 'Vault info'
                  : 'Vault info - $category',
            ),
          );
        }
      }

      if (sources.contains('docs')) {
        final folderIds = await _loadOrRebuildSecureIndex(
          indexKey: _vaultDocFolderIndexKey,
          itemPrefix: _vaultDocFolderPrefix,
        );
        final folderNamesById = <String, String>{};
        for (final folderId in folderIds) {
          final raw = await _secureStorageService.read(
            '$_vaultDocFolderPrefix$folderId',
          );
          if (raw == null || raw.isEmpty) {
            continue;
          }

          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          if (_isDeletedFlag(decoded['is_deleted'])) {
            continue;
          }

          final name = (decoded['name'] as String? ?? '').trim();
          if (name.isEmpty) {
            continue;
          }
          folderNamesById[folderId] = name;

          if (!name.toLowerCase().contains(normalized.toLowerCase())) {
            continue;
          }

          results.add(
            SearchResultModel(
              id: folderId,
              source: 'docs',
              kind: 'vault_doc_folder',
              title: name,
              subtitle: 'Document folder',
            ),
          );
        }

        final itemIds = await _loadOrRebuildSecureIndex(
          indexKey: _vaultDocItemIndexKey,
          itemPrefix: _vaultDocItemPrefix,
        );
        for (final itemId in itemIds) {
          final raw = await _secureStorageService.read(
            '$_vaultDocItemPrefix$itemId',
          );
          if (raw == null || raw.isEmpty) {
            continue;
          }

          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          if (_isDeletedFlag(decoded['is_deleted'])) {
            continue;
          }

          final label = (decoded['label'] as String? ?? '').trim();
          final notes = (decoded['notes'] as String? ?? '').trim();
          final tags = _decodeTags(decoded['tags']);
          final folderId = (decoded['folder_id'] as String? ?? '').trim();
          if (label.isEmpty || folderId.isEmpty) {
            continue;
          }

          final searchable = '$label $notes ${tags.join(' ')}'.toLowerCase();
          if (!searchable.contains(normalized.toLowerCase())) {
            continue;
          }

          final folderName = folderNamesById[folderId] ?? 'Document folder';
          results.add(
            SearchResultModel(
              id: itemId,
              parentId: folderId,
              source: 'docs',
              kind: 'vault_doc_item',
              title: label,
              subtitle: '$folderName - Document item',
            ),
          );
        }
      }

      return Result<List<SearchResultModel>>.success(results);
    } catch (error) {
      return Result<List<SearchResultModel>>.failure(
        'Failed to search: $error',
      );
    }
  }

  Future<List<String>> _loadOrRebuildSecureIndex({
    required String indexKey,
    required String itemPrefix,
  }) async {
    final raw = await _secureStorageService.read(indexKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
      }
    }

    // OPTIMIZATION: Don't use expensive readAll() in interactive paths.
    // If index is missing/corrupt, return empty list and rely on index maintenance
    // during create/update/delete operations.
    // Missing indexes will be rebuilt during background maintenance tasks.
    return const <String>[];
  }

  bool _isDeletedFlag(Object? rawValue) {
    if (rawValue is bool) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt() == 1;
    }
    return false;
  }

  List<String> _decodeTags(Object? rawValue) {
    if (rawValue is List) {
      return rawValue
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Future<void> _appendGroupVaultInfoMatches({
    required List<SearchResultModel> results,
    required String normalizedQuery,
    required Map<String, String> groupNamesById,
  }) async {
    for (final entry in groupNamesById.entries) {
      final groupId = entry.key.trim();
      if (groupId.isEmpty) {
        continue;
      }

      final groupName = entry.value.trim().isEmpty
          ? 'Group'
          : entry.value.trim();
      final indexKey = '$_groupVaultInfoIndexPrefix$groupId';
      final itemPrefix = '$_groupVaultInfoItemPrefix${groupId}_';
      final itemIds = await _loadOrRebuildScopedSecureIndex(
        indexKey: indexKey,
        itemPrefix: itemPrefix,
      );

      for (final itemId in itemIds) {
        final raw = await _secureStorageService.read('$itemPrefix$itemId');
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        if (_isDeletedFlag(decoded['is_deleted'])) {
          continue;
        }

        final label = (decoded['label'] as String? ?? '').trim();
        final category = (decoded['category'] as String? ?? '').trim();
        if (label.isEmpty) {
          continue;
        }

        final searchable = '$label $category $groupName'.toLowerCase();
        if (!searchable.contains(normalizedQuery)) {
          continue;
        }

        results.add(
          SearchResultModel(
            id: itemId,
            parentId: groupId,
            source: 'groups',
            kind: 'group_vault_info',
            title: label,
            subtitle: '$groupName - Info vault',
          ),
        );
      }
    }
  }

  Future<void> _appendGroupVaultDocMatches({
    required List<SearchResultModel> results,
    required String normalizedQuery,
    required Map<String, String> groupNamesById,
  }) async {
    for (final entry in groupNamesById.entries) {
      final groupId = entry.key.trim();
      if (groupId.isEmpty) {
        continue;
      }

      final groupName = entry.value.trim().isEmpty
          ? 'Group'
          : entry.value.trim();

      // Load folders
      final folderIndexKey = '$_groupVaultDocFolderIndexPrefix$groupId';
      final folderPrefix = '$_groupVaultDocFolderPrefix${groupId}_';
      final folderIds = await _loadOrRebuildScopedSecureIndex(
        indexKey: folderIndexKey,
        itemPrefix: folderPrefix,
      );

      final folderNamesById = <String, String>{};
      for (final folderId in folderIds) {
        final raw = await _secureStorageService.read('$folderPrefix$folderId');
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        if (_isDeletedFlag(decoded['is_deleted'])) {
          continue;
        }

        final name = (decoded['name'] as String? ?? '').trim();
        if (name.isEmpty) {
          continue;
        }
        folderNamesById[folderId] = name;

        final searchable = '$name $groupName'.toLowerCase();
        if (!searchable.contains(normalizedQuery)) {
          continue;
        }

        results.add(
          SearchResultModel(
            id: folderId,
            parentId: groupId,
            source: 'groups',
            kind: 'group_vault_doc_folder',
            title: name,
            subtitle: '$groupName - Document folder',
          ),
        );
      }

      // Load items
      final itemIndexKey = '$_groupVaultDocItemIndexPrefix$groupId';
      final itemPrefix = '$_groupVaultDocItemPrefix${groupId}_';
      final itemIds = await _loadOrRebuildScopedSecureIndex(
        indexKey: itemIndexKey,
        itemPrefix: itemPrefix,
      );

      for (final itemId in itemIds) {
        final raw = await _secureStorageService.read('$itemPrefix$itemId');
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        if (_isDeletedFlag(decoded['is_deleted'])) {
          continue;
        }

        final label = (decoded['label'] as String? ?? '').trim();
        final notes = (decoded['notes'] as String? ?? '').trim();
        final tagsRaw = decoded['tags'];
        final tags = tagsRaw is List
            ? tagsRaw.whereType<String>().toList(growable: false)
            : const <String>[];
        final folderId = (decoded['folder_id'] as String? ?? '').trim();

        if (label.isEmpty || folderId.isEmpty) {
          continue;
        }

        final searchable = '$label $notes ${tags.join(' ')} $groupName'.toLowerCase();
        if (!searchable.contains(normalizedQuery)) {
          continue;
        }

        final folderName = folderNamesById[folderId] ?? 'Document folder';
        results.add(
          SearchResultModel(
            id: itemId,
            parentId: '$groupId::$folderId',
            source: 'groups',
            kind: 'group_vault_doc_item',
            title: label,
            subtitle: '$groupName - $folderName',
          ),
        );
      }
    }
  }

  Future<List<String>> _loadOrRebuildScopedSecureIndex({
    required String indexKey,
    required String itemPrefix,
  }) async {
    final indexRaw = await _secureStorageService.read(indexKey);
    if (indexRaw != null && indexRaw.isNotEmpty) {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
      }
    }

    final all = await _secureStorageService.readAll();
    final ids = all.keys
        .where((key) => key.startsWith(itemPrefix))
        .map((key) => key.substring(itemPrefix.length))
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    await _secureStorageService.write(key: indexKey, value: jsonEncode(ids));
    return ids;
  }

  Future<Result<List<String>>> getRecentQueries({int limit = 5}) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'search_history',
        columns: <String>['query'],
        orderBy: 'searched_at DESC',
        limit: limit,
      );
      final queries = rows
          .map((row) => row['query'] as String? ?? '')
          .where((query) => query.trim().isNotEmpty)
          .toList(growable: false);
      return Result<List<String>>.success(queries);
    } catch (error) {
      return Result<List<String>>.failure(
        'Failed to load recent searches: $error',
      );
    }
  }

  Future<Result<void>> saveRecentQuery(String query) async {
    try {
      final normalized = query.trim();
      if (normalized.length < 2) {
        return const Result<void>.success(null);
      }

      final db = await _databaseHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.delete(
          'search_history',
          where: 'LOWER(query) = LOWER(?)',
          whereArgs: <Object>[normalized],
        );

        await txn.insert('search_history', <String, Object?>{
          'id': _uuid.v4(),
          'query': normalized,
          'searched_at': now,
        });

        await txn.rawDelete('''
            DELETE FROM search_history
            WHERE id IN (
              SELECT id
              FROM search_history
              ORDER BY searched_at DESC
              LIMIT -1 OFFSET 5
            )
          ''');
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to save recent search: $error');
    }
  }

  Future<Result<void>> clearRecentQueries() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('search_history');
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to clear recent searches: $error');
    }
  }
}

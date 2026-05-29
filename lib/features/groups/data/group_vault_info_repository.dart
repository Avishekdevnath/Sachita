import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/groups/models/group_vault_info_item_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final groupVaultInfoRepositoryProvider = Provider<GroupVaultInfoRepository>((
  ref,
) {
  return GroupVaultInfoRepository(
    SecureStorageService.instance,
    DatabaseHelper.instance,
  );
});

class GroupVaultInfoRepository {
  GroupVaultInfoRepository(this._secureStorageService, this._databaseHelper);

  static const Uuid _uuid = Uuid();
  static const String _indexPrefix = 'group_vault_info_index_';
  static const String _itemPrefix = 'group_vault_info_';

  final SecureStorageService _secureStorageService;
  final DatabaseHelper _databaseHelper;

  Future<Result<List<GroupVaultInfoItemModel>>> getItems(String groupId) async {
    try {
      final ids = await _loadOrRebuildIndex(groupId);
      final memberNames = await _memberNamesById(groupId);
      final items = <GroupVaultInfoItemModel>[];
      for (final id in ids) {
        final raw = await _secureStorageService.read(_itemKey(groupId, id));
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final memberIdRaw = (decoded['member_id'] as String? ?? '').trim();
        final item = GroupVaultInfoItemModel.fromMap(
          decoded,
          memberName: memberIdRaw.isEmpty ? null : memberNames[memberIdRaw],
        );
        if (!item.isDeleted) {
          items.add(item);
        }
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result<List<GroupVaultInfoItemModel>>.success(items);
    } catch (error) {
      return Result<List<GroupVaultInfoItemModel>>.failure(
        'Failed to load group vault info items: $error',
      );
    }
  }

  Future<Result<GroupVaultInfoItemModel>> getItemById({
    required String groupId,
    required String itemId,
  }) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(groupId, itemId));
      if (raw == null || raw.isEmpty) {
        return const Result<GroupVaultInfoItemModel>.failure(
          'Group vault item not found.',
        );
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<GroupVaultInfoItemModel>.failure(
          'Group vault item is invalid.',
        );
      }

      final memberIdRaw = (decoded['member_id'] as String? ?? '').trim();
      final memberName = memberIdRaw.isEmpty
          ? null
          : await _memberName(groupId: groupId, memberId: memberIdRaw);
      final item = GroupVaultInfoItemModel.fromMap(
        decoded,
        memberName: memberName,
      );
      if (item.isDeleted) {
        return const Result<GroupVaultInfoItemModel>.failure(
          'Group vault item not found.',
        );
      }

      return Result<GroupVaultInfoItemModel>.success(item);
    } catch (error) {
      return Result<GroupVaultInfoItemModel>.failure(
        'Failed to load group vault item: $error',
      );
    }
  }

  Future<Result<void>> createItem({
    required String groupId,
    String? memberId,
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    try {
      final normalizedGroupId = groupId.trim();
      final normalizedMemberId = (memberId ?? '').trim();
      final normalizedCategory = _normalize(category);
      final normalizedLabel = _normalize(label);
      final normalizedValue = value.trim();
      final normalizedNotes = notes.trim();

      final validation = await _validate(
        groupId: normalizedGroupId,
        memberId: normalizedMemberId.isEmpty ? null : normalizedMemberId,
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
      );
      if (validation != null) {
        return Result<void>.failure(validation);
      }

      final now = DateTime.now();
      final id = _uuid.v4();
      final item = GroupVaultInfoItemModel(
        id: id,
        groupId: normalizedGroupId,
        memberId: normalizedMemberId.isEmpty ? null : normalizedMemberId,
        memberName: null,
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
        notes: normalizedNotes,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );

      await _secureStorageService.write(
        key: _itemKey(normalizedGroupId, id),
        value: jsonEncode(item.toMap()),
      );
      await _appendToIndex(normalizedGroupId, id);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create group vault item: $error');
    }
  }

  Future<Result<void>> updateItem({
    required String groupId,
    required String itemId,
    String? memberId,
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(groupId, itemId));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Group vault item not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Group vault item is invalid.');
      }

      final existing = GroupVaultInfoItemModel.fromMap(decoded);
      if (existing.isDeleted) {
        return const Result<void>.failure('Group vault item not found.');
      }

      final normalizedMemberId = (memberId ?? '').trim();
      final normalizedCategory = _normalize(category);
      final normalizedLabel = _normalize(label);
      final normalizedValue = value.trim();
      final normalizedNotes = notes.trim();

      final validation = await _validate(
        groupId: groupId,
        memberId: normalizedMemberId.isEmpty ? null : normalizedMemberId,
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
      );
      if (validation != null) {
        return Result<void>.failure(validation);
      }

      final updated = existing.copyWith(
        memberId: normalizedMemberId.isEmpty ? null : normalizedMemberId,
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
        notes: normalizedNotes,
        updatedAt: DateTime.now(),
      );
      await _secureStorageService.write(
        key: _itemKey(groupId, itemId),
        value: jsonEncode(updated.toMap()),
      );
      await _ensureInIndex(groupId, itemId);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update group vault item: $error');
    }
  }

  Future<Result<void>> softDeleteItem({
    required String groupId,
    required String itemId,
  }) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(groupId, itemId));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Group vault item not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Group vault item is invalid.');
      }

      final existing = GroupVaultInfoItemModel.fromMap(decoded);
      if (existing.isDeleted) {
        return const Result<void>.success(null);
      }

      final now = DateTime.now();
      final deleted = existing.copyWith(
        isDeleted: true,
        deletedAt: now,
        updatedAt: now,
      );
      await _secureStorageService.write(
        key: _itemKey(groupId, itemId),
        value: jsonEncode(deleted.toMap()),
      );
      await _removeFromIndex(groupId, itemId);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete group vault item: $error');
    }
  }

  Future<List<String>> _loadOrRebuildIndex(String groupId) async {
    final raw = await _secureStorageService.read(_indexKey(groupId));
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
      }
    }

    final prefix = _itemPrefixForGroup(groupId);
    final all = await _secureStorageService.readAll();
    final ids = all.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    await _writeIndex(groupId, ids);
    return ids;
  }

  Future<void> _appendToIndex(String groupId, String itemId) async {
    final ids = await _loadOrRebuildIndex(groupId);
    if (ids.contains(itemId)) {
      return;
    }
    await _writeIndex(groupId, <String>[...ids, itemId]);
  }

  Future<void> _ensureInIndex(String groupId, String itemId) async {
    final ids = await _loadOrRebuildIndex(groupId);
    if (ids.contains(itemId)) {
      return;
    }
    await _writeIndex(groupId, <String>[...ids, itemId]);
  }

  Future<void> _removeFromIndex(String groupId, String itemId) async {
    final ids = await _loadOrRebuildIndex(groupId);
    final nextIds = ids.where((id) => id != itemId).toList(growable: false);
    await _writeIndex(groupId, nextIds);
  }

  Future<void> _writeIndex(String groupId, List<String> ids) async {
    await _secureStorageService.write(
      key: _indexKey(groupId),
      value: jsonEncode(ids),
    );
  }

  Future<Map<String, String>> _memberNamesById(String groupId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'group_members',
      columns: <String>['id', 'name'],
      where: 'group_id = ? AND is_deleted = 0',
      whereArgs: <Object>[groupId],
    );
    return <String, String>{
      for (final row in rows)
        (row['id'] as String? ?? ''): (row['name'] as String? ?? 'Member'),
    };
  }

  Future<String?> _memberName({
    required String groupId,
    required String memberId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'group_members',
      columns: <String>['name'],
      where: 'id = ? AND group_id = ? AND is_deleted = 0',
      whereArgs: <Object>[memberId, groupId],
      limit: 1,
    );
    if (rows.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }
    return rows.first['name'] as String?;
  }

  Future<bool> _groupExists(String groupId) async {
    final db = await _databaseHelper.database;
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
    required String groupId,
    required String memberId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'group_members',
      columns: <String>['id'],
      where: 'id = ? AND group_id = ? AND is_deleted = 0',
      whereArgs: <Object>[memberId, groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> _validate({
    required String groupId,
    required String? memberId,
    required String category,
    required String label,
    required String value,
  }) async {
    if (groupId.trim().isEmpty) {
      return 'Group is required.';
    }
    final groupExists = await _groupExists(groupId);
    if (!groupExists) {
      return 'Group not found.';
    }
    if (memberId != null && memberId.trim().isNotEmpty) {
      final memberExists = await _memberExists(
        groupId: groupId,
        memberId: memberId.trim(),
      );
      if (!memberExists) {
        return 'Selected member was not found in this group.';
      }
    }
    if (category.isEmpty) {
      return 'Category is required.';
    }
    if (label.isEmpty) {
      return 'Label is required.';
    }
    if (value.isEmpty) {
      return 'Value is required.';
    }
    // Defensive null return - validation failed
    return null;
  }

  static String _indexKey(String groupId) => '$_indexPrefix$groupId';

  static String _itemPrefixForGroup(String groupId) =>
      '$_itemPrefix${groupId}_';

  static String _itemKey(String groupId, String itemId) =>
      '${_itemPrefixForGroup(groupId)}$itemId';

  static String _normalize(String value) => value.trim();
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/vault/models/vault_info_item_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final vaultInfoRepositoryProvider = Provider<VaultInfoRepository>((ref) {
  return VaultInfoRepository(SecureStorageService.instance);
});

class VaultInfoRepository {
  VaultInfoRepository(this._secureStorageService);

  static const Uuid _uuid = Uuid();
  static const String _indexKey = 'vault_info_index';
  static const String _itemPrefix = 'vault_info_';

  final SecureStorageService _secureStorageService;

  Future<Result<List<VaultInfoItemModel>>> getItems() async {
    try {
      final ids = await _loadOrRebuildIndex();
      final items = <VaultInfoItemModel>[];
      for (final id in ids) {
        final raw = await _secureStorageService.read(_itemKey(id));
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final item = VaultInfoItemModel.fromMap(decoded);
        if (!item.isDeleted) {
          items.add(item);
        }
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result<List<VaultInfoItemModel>>.success(items);
    } catch (error) {
      return Result<List<VaultInfoItemModel>>.failure(
        'Failed to load vault info items: $error',
      );
    }
  }

  Future<Result<VaultInfoItemModel>> getItemById(String id) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(id));
      if (raw == null || raw.isEmpty) {
        return const Result<VaultInfoItemModel>.failure(
          'Vault item not found.',
        );
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<VaultInfoItemModel>.failure(
          'Vault item is invalid.',
        );
      }

      final item = VaultInfoItemModel.fromMap(decoded);
      if (item.isDeleted) {
        return const Result<VaultInfoItemModel>.failure(
          'Vault item not found.',
        );
      }

      return Result<VaultInfoItemModel>.success(item);
    } catch (error) {
      return Result<VaultInfoItemModel>.failure(
        'Failed to load vault item: $error',
      );
    }
  }

  Future<Result<void>> createItem({
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    try {
      final normalizedCategory = _normalize(category);
      final normalizedLabel = _normalize(label);
      final normalizedValue = value.trim();
      final normalizedNotes = notes.trim();

      final validation = _validate(
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
      );
      if (validation != null) {
        return Result<void>.failure(validation);
      }

      final now = DateTime.now();
      final id = _uuid.v4();
      final item = VaultInfoItemModel(
        id: id,
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
        key: _itemKey(id),
        value: jsonEncode(item.toMap()),
      );
      await _appendToIndex(id);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create vault item: $error');
    }
  }

  Future<Result<void>> updateItem({
    required String id,
    required String category,
    required String label,
    required String value,
    required String notes,
  }) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(id));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Vault item not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Vault item is invalid.');
      }

      final existing = VaultInfoItemModel.fromMap(decoded);
      if (existing.isDeleted) {
        return const Result<void>.failure('Vault item not found.');
      }

      final normalizedCategory = _normalize(category);
      final normalizedLabel = _normalize(label);
      final normalizedValue = value.trim();
      final normalizedNotes = notes.trim();
      final validation = _validate(
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
      );
      if (validation != null) {
        return Result<void>.failure(validation);
      }

      final updated = existing.copyWith(
        category: normalizedCategory,
        label: normalizedLabel,
        value: normalizedValue,
        notes: normalizedNotes,
        updatedAt: DateTime.now(),
      );
      await _secureStorageService.write(
        key: _itemKey(id),
        value: jsonEncode(updated.toMap()),
      );
      await _ensureInIndex(id);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update vault item: $error');
    }
  }

  Future<Result<void>> softDeleteItem(String id) async {
    try {
      final raw = await _secureStorageService.read(_itemKey(id));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Vault item not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Vault item is invalid.');
      }

      final existing = VaultInfoItemModel.fromMap(decoded);
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
        key: _itemKey(id),
        value: jsonEncode(deleted.toMap()),
      );
      await _removeFromIndex(id);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete vault item: $error');
    }
  }

  Future<List<String>> _loadOrRebuildIndex() async {
    final raw = await _secureStorageService.read(_indexKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final ids = decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
        return ids;
      }
    }

    final all = await _secureStorageService.readAll();
    final ids = all.keys
        .where((key) => key.startsWith(_itemPrefix) && key != _indexKey)
        .map((key) => key.substring(_itemPrefix.length))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    await _writeIndex(ids);
    return ids;
  }

  Future<void> _appendToIndex(String id) async {
    final ids = await _loadOrRebuildIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeIndex(<String>[...ids, id]);
  }

  Future<void> _ensureInIndex(String id) async {
    final ids = await _loadOrRebuildIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeIndex(<String>[...ids, id]);
  }

  Future<void> _removeFromIndex(String id) async {
    final ids = await _loadOrRebuildIndex();
    final nextIds = ids.where((currentId) => currentId != id).toList();
    await _writeIndex(nextIds);
  }

  Future<void> _writeIndex(List<String> ids) async {
    await _secureStorageService.write(key: _indexKey, value: jsonEncode(ids));
  }

  static String _itemKey(String id) => '$_itemPrefix$id';

  static String _normalize(String value) => value.trim();

  static String? _validate({
    required String category,
    required String label,
    required String value,
  }) {
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
}

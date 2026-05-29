import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_vault_info_repository.dart';
import 'package:sanchita/features/groups/models/group_vault_info_item_model.dart';

final groupVaultInfoItemsProvider =
    FutureProvider.family<List<GroupVaultInfoItemModel>, String>((
      ref,
      groupId,
    ) async {
      final repository = ref.read(groupVaultInfoRepositoryProvider);
      final result = await repository.getItems(groupId);
      return result.when(
        success: (items) => items,
        failure: (message) => throw StateError(message),
      );
    });

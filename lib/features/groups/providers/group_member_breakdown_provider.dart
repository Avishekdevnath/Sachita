import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_member_breakdown_model.dart';

final groupMemberBreakdownProvider =
    FutureProvider.family<List<GroupMemberBreakdownModel>, String>((
      ref,
      groupId,
    ) async {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getMemberBreakdown(groupId: groupId);
      return result.when(
        success: (items) => items,
        failure: (message) => throw StateError(message),
      );
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';

final groupMembersProvider =
    FutureProvider.family<List<GroupMemberModel>, String>((ref, groupId) async {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupMembers(groupId);
      return result.when(
        success: (members) => members,
        failure: (message) => throw StateError(message),
      );
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_model.dart';

final groupDetailProvider = FutureProvider.family<GroupModel, String>((
  ref,
  groupId,
) async {
  final repository = ref.read(groupRepositoryProvider);
  final result = await repository.getGroupById(groupId);
  return result.when(
    success: (group) => group,
    failure: (message) => throw StateError(message),
  );
});

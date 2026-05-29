import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_recurring_rule_model.dart';

final groupRecurringProvider =
    FutureProvider.family<List<GroupRecurringRuleModel>, String>((
      ref,
      groupId,
    ) async {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupRecurringRules(groupId: groupId);
      return result.when(
        success: (items) => items,
        failure: (message) => throw StateError(message),
      );
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_category_budget_model.dart';

class GroupBudgetQuery {
  const GroupBudgetQuery({required this.groupId, required this.month});

  final String groupId;
  final DateTime month;

  DateTime get monthStart => DateTime(month.year, month.month);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GroupBudgetQuery &&
        other.groupId == groupId &&
        other.month.year == month.year &&
        other.month.month == month.month;
  }

  @override
  int get hashCode => Object.hash(groupId, month.year, month.month);
}

final groupBudgetProvider =
    FutureProvider.family<List<GroupCategoryBudgetModel>, GroupBudgetQuery>((
      ref,
      query,
    ) async {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupBudgetsForMonth(
        groupId: query.groupId,
        month: query.monthStart,
      );
      return result.when(
        success: (items) => items,
        failure: (message) => throw StateError(message),
      );
    });

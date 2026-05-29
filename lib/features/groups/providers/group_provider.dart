import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_model.dart';

class GroupState {
  const GroupState({this.groups = const <GroupModel>[], this.errorMessage});

  final List<GroupModel> groups;
  final String? errorMessage;

  GroupState copyWith({
    List<GroupModel>? groups,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final groupProvider = AsyncNotifierProvider<GroupNotifier, GroupState>(
  GroupNotifier.new,
);

class GroupNotifier extends AsyncNotifier<GroupState> {
  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  @override
  Future<GroupState> build() async {
    return _load(const GroupState());
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const GroupState();
    state = const AsyncLoading();
    state = AsyncData(await _load(current.copyWith(clearError: true)));
  }

  Future<String?> createGroup({
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final current = state.asData?.value ?? const GroupState();
    final result = await _repository.createGroup(
      name: name,
      icon: icon,
      colorHex: colorHex,
    );

    return await result.when(
      success: (_) async {
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
    // Defensive null return - validation failed
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<String?> updateGroup({
    required String groupId,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final current = state.asData?.value ?? const GroupState();
    final result = await _repository.updateGroup(
      groupId: groupId,
      name: name,
      icon: icon,
      colorHex: colorHex,
    );

    return await result.when(
      success: (_) async {
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
    // Defensive null return - validation failed
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<String?> deleteGroup(String groupId) async {
    final current = state.asData?.value ?? const GroupState();
    final result = await _repository.deleteGroup(groupId);

    return await result.when(
      success: (_) async {
        state = const AsyncLoading();
        state = AsyncData(await _load(current.copyWith(clearError: true)));
    // Defensive null return - validation failed
        return null;
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  Future<GroupState> _load(GroupState source) async {
    final result = await _repository.getGroups();
    return result.when(
      success: (groups) => source.copyWith(groups: groups, clearError: true),
      failure: (message) {
        return source.copyWith(
          groups: const <GroupModel>[],
          errorMessage: message,
        );
      },
    );
  }
}

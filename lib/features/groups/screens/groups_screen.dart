import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/utils/format_utils.dart';
import 'package:sanchita/features/groups/models/group_model.dart';
import 'package:sanchita/features/groups/providers/group_provider.dart';
import 'package:sanchita/shared/widgets/empty_state_widget.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});


  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete group?'),
          content: Text('Delete "${group.name}" and all linked group records?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final error = await ref.read(groupProvider.notifier).deleteGroup(group.id);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group deleted.')));
  }

  Widget _buildGroupTile(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) {
    final color = parseColor(group.colorHex);
    final memberLabel = group.memberCount == 1 ? 'member' : 'members';
    final lastActivity = group.lastActivityAt == null
        ? 'No activity yet'
        : DateFormat('dd MMM yyyy').format(group.lastActivityAt!);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space12),
        onTap: () {
          context.push(RoutePaths.groupsDetail(group.id));
        },
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                iconForGroup(group.icon),
                color: color,
                size: AppTokens.iconMd,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    '${group.memberCount} $memberLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Last activity: $lastActivity',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (action) async {
                if (action == 'edit') {
                  final changed = await context.push<bool>(
                    RoutePaths.groupsEdit(group.id),
                  );
                  if (changed == true && context.mounted) {
                    await ref.read(groupProvider.notifier).refresh();
                  }
                  return;
                }

                if (action == 'delete') {
                  await _deleteGroup(context, ref, group);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider);
    final state = groupAsync.asData?.value ?? const GroupState();
    final groups = state.groups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(groupProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(groupProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            96,
          ),
          children: <Widget>[
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: AppTokens.space8),
              Text(
                state.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (groupAsync.isLoading && groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTokens.space24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (groups.isEmpty)
              EmptyStateWidget(
                icon: Icons.group_outlined,
                title: 'No groups yet',
                subtitle:
                    'Create a group for family, friends, or shared expenses.',
                action: FilledButton.icon(
                  onPressed: () async {
                    final changed = await context.push<bool>(
                      RoutePaths.groupsNew,
                    );
                    if (changed == true && context.mounted) {
                      await ref.read(groupProvider.notifier).refresh();
                    }
                  },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Create Group'),
                ),
              )
            else
              ...groups.map((group) => _buildGroupTile(context, ref, group)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await context.push<bool>(RoutePaths.groupsNew);
          if (changed == true && context.mounted) {
            await ref.read(groupProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Create Group'),
      ),
    );
  }
}

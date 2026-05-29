import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/utils/format_utils.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    if (groupAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (groupAsync.hasError || !groupAsync.hasValue) {
      return Scaffold(
        appBar: const AppNavigationBar(title: 'Group', showBackButton: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(groupAsync.error?.toString() ?? 'Group not found.'),
                const SizedBox(height: AppTokens.space12),
                FilledButton.tonal(
                  onPressed: () {
                    ref.invalidate(groupDetailProvider(groupId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final group = groupAsync.requireValue;
    final color = parseColor(group.colorHex);

    return Scaffold(
      appBar: AppNavigationBar(
        title: group.name,
        showBackButton: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              final changed = await context.push<bool>(
                RoutePaths.groupsEdit(group.id),
              );
              if (changed == true) {
                ref.invalidate(groupDetailProvider(groupId));
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withAlpha(51),
                child: Icon(iconForGroup(group.icon), color: color, size: 28),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            onTap: () {
              context.push(RoutePaths.groupsMembers(group.id));
            },
            child: Row(
              children: <Widget>[
                const Icon(Icons.people_outline),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Members',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Add, edit, and remove members with data handling choices.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            onTap: () {
              context.push(RoutePaths.groupsFinance(group.id));
            },
            child: Row(
              children: <Widget>[
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Group Finance',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Open individual and combined finance views.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            onTap: () {
              context.push(RoutePaths.groupsVaultInfo(group.id));
            },
            child: Row(
              children: <Widget>[
                const Icon(Icons.lock_outline),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Group Info Vault',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Store secure group info with member or group-wide ownership.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

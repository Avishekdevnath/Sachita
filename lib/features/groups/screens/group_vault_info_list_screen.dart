import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/models/group_vault_info_item_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/groups/providers/group_members_provider.dart';
import 'package:sanchita/features/groups/providers/group_vault_info_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class GroupVaultInfoListScreen extends ConsumerStatefulWidget {
  const GroupVaultInfoListScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupVaultInfoListScreen> createState() =>
      _GroupVaultInfoListScreenState();
}

class _GroupVaultInfoListScreenState
    extends ConsumerState<GroupVaultInfoListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _memberFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GroupVaultInfoItemModel> _applyFilters(
    List<GroupVaultInfoItemModel> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          if (_memberFilter == 'group_wide' && !item.isGroupWide) {
            return false;
          }
          if (_memberFilter != 'all' &&
              _memberFilter != 'group_wide' &&
              item.memberId != _memberFilter) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }
          final haystack =
              '${item.label} ${item.category} ${item.belongsToLabel}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    ref.invalidate(groupVaultInfoItemsProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final itemsAsync = ref.watch(groupVaultInfoItemsProvider(widget.groupId));

    final groupName = groupAsync.asData?.value.name ?? 'Group';
    final members = membersAsync.asData?.value ?? const <GroupMemberModel>[];
    final allItems =
        itemsAsync.asData?.value ?? const <GroupVaultInfoItemModel>[];
    final filteredItems = _applyFilters(allItems);

    return Scaffold(
      appBar: AppNavigationBar(title: '$groupName Info Vault', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search by label, category, or member',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: _memberFilter == 'all',
                  onSelected: (_) {
                    setState(() {
                      _memberFilter = 'all';
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Group-wide'),
                  selected: _memberFilter == 'group_wide',
                  onSelected: (_) {
                    setState(() {
                      _memberFilter = 'group_wide';
                    });
                  },
                ),
                ...members.map((member) {
                  final id = member.id;
                  final name = member.name;
                  return FilterChip(
                    label: Text(name),
                    selected: _memberFilter == id,
                    onSelected: (_) {
                      setState(() {
                        _memberFilter = id;
                      });
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            if (itemsAsync.isLoading && allItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (itemsAsync.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  itemsAsync.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (filteredItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No group info items found.'),
              )
            else
              ...filteredItems.map((item) {
                final dateLabel = DateFormat(
                  'dd MMM yyyy',
                ).format(item.createdAt);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.category} - ${item.belongsToLabel} - $dateLabel',
                  ),
                  trailing: const Text('********'),
                  onTap: () async {
                    final changed = await context.push<bool>(
                      RoutePaths.groupsVaultInfoItem(
                        groupId: widget.groupId,
                        itemId: item.id,
                      ),
                    );
                    if (changed == true && mounted) {
                      await _refresh();
                    }
                  },
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await context.push<bool>(
            RoutePaths.groupsVaultInfoNew(widget.groupId),
          );
          if (changed == true && mounted) {
            await _refresh();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Info Item'),
      ),
    );
  }
}

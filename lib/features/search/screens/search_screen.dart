import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/search/models/search_result_model.dart';
import 'package:sanchita/features/search/providers/search_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const List<String> _sourceOrder = <String>[
    'finance',
    'groups',
    'info',
  ];

  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(searchProvider).asData?.value.query ?? '';
    _queryController.text = initialQuery;
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    ref.read(searchProvider.notifier).updateQuery(_queryController.text);
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'finance':
        return 'Finance';
      case 'groups':
        return 'Groups';
      case 'info':
        return 'Vault Info';
      default:
        return source;
    }
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'info':
        return Icons.lock_outline;
      default:
        return Icons.search;
    }
  }

  void _openResult(SearchResultModel item) {
    switch (item.kind) {
      case 'transaction':
        context.push(RoutePaths.financeTransaction(item.id));
        return;
      case 'recurring':
        context.go(RoutePaths.financeRecurring);
        return;
      case 'group':
        if (item.id.isEmpty) {
          context.go(RoutePaths.groups);
        } else {
          context.push(RoutePaths.groupsDetail(item.id));
        }
        return;
      case 'group_member':
        final groupId = item.parentId;
        if (groupId == null || groupId.isEmpty) {
          context.go(RoutePaths.groups);
        } else {
          context.push(RoutePaths.groupsDetail(groupId));
        }
        return;
      case 'group_vault_info':
        final groupId = item.parentId;
        if (groupId == null || groupId.isEmpty) {
          context.go(RoutePaths.groups);
        } else {
          context.push(
            RoutePaths.groupsVaultInfoItem(groupId: groupId, itemId: item.id),
          );
        }
        return;
      case 'group_vault_doc_folder':
        final groupId = item.parentId;
        if (groupId == null || groupId.isEmpty) {
          context.go(RoutePaths.groups);
        } else {
          context.push(
            RoutePaths.groupsVaultDocsFolder(
              groupId: groupId,
              folderId: item.id,
            ),
          );
        }
        return;
      case 'group_vault_doc_item':
        final packedParent = item.parentId ?? '';
        final parts = packedParent.split('::');
        if (parts.length != 2) {
          context.go(RoutePaths.groups);
        } else {
          final groupId = parts[0];
          final folderId = parts[1];
          if (groupId.isEmpty || folderId.isEmpty) {
            context.go(RoutePaths.groups);
          } else {
            context.push(
              RoutePaths.groupsVaultDocsItem(
                groupId: groupId,
                folderId: folderId,
                itemId: item.id,
              ),
            );
          }
        }
        return;
      case 'vault_info':
        context.push(RoutePaths.vaultInfoItem(item.id));
        return;
      case 'vault_doc_folder':
        context.push(RoutePaths.vaultDocFolder(item.id));
        return;
      case 'vault_doc_item':
        final folderId = item.parentId;
        if (folderId == null || folderId.isEmpty) {
          context.push(RoutePaths.vaultDocs);
        } else {
          context.push(
            RoutePaths.vaultDocItem(folderId: folderId, itemId: item.id),
          );
        }
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);
    final state = searchAsync.asData?.value ?? const SearchState();
    final trimmedQuery = state.query.trim();

    return Scaffold(
      appBar: const AppNavigationBar(title: 'Search', showBackButton: true),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search finance, groups, vault...',
                suffixIcon: trimmedQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _queryController.clear();
                          ref.read(searchProvider.notifier).updateQuery('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sourceOrder.map((source) {
                final selected = state.sourceFilters.contains(source);
                return FilterChip(
                  label: Text(_sourceLabel(source)),
                  selected: selected,
                  onSelected: (value) {
                    ref
                        .read(searchProvider.notifier)
                        .toggleSource(source, value);
                  },
                );
              }).toList(),
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child: _buildContent(
              context: context,
              state: state,
              trimmedQuery: trimmedQuery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required SearchState state,
    required String trimmedQuery,
  }) {
    if (trimmedQuery.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.recentQueries.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(searchProvider.notifier).clearRecentQueries();
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (state.recentQueries.isEmpty)
            const Text('No recent searches.')
          else
            ...state.recentQueries.map((query) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  _queryController.text = query;
                  _queryController.selection = TextSelection.fromPosition(
                    TextPosition(offset: query.length),
                  );
                  ref.read(searchProvider.notifier).applyRecentQuery(query);
                },
              );
            }),
        ],
      );
    }

    if (trimmedQuery.length < 2) {
      return const Center(child: Text('Type at least 2 characters to search.'));
    }

    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = state.groupedResults;
    var hasAny = false;
    for (final source in _sourceOrder) {
      final items = grouped[source];
      if (items != null && items.isNotEmpty) {
        hasAny = true;
        break;
      }
    }

    if (!hasAny) {
      return const Center(
        child: Text('No matches found for the current filters.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        0,
        AppTokens.space16,
        AppTokens.space16,
      ),
      children: <Widget>[
        for (final source in _sourceOrder)
          if ((grouped[source] ?? const <SearchResultModel>[]).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppTokens.space12,
                bottom: AppTokens.space6,
              ),
              child: Text(
                _sourceLabel(source),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...(grouped[source] ?? const <SearchResultModel>[]).map((item) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_sourceIcon(source)),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _openResult(item);
                },
              );
            }),
          ],
      ],
    );
  }
}

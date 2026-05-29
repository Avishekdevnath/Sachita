import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/vault/providers/vault_info_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class VaultInfoListScreen extends ConsumerStatefulWidget {
  const VaultInfoListScreen({super.key});

  @override
  ConsumerState<VaultInfoListScreen> createState() =>
      _VaultInfoListScreenState();
}

class _VaultInfoListScreenState extends ConsumerState<VaultInfoListScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filters = <String>[
    'all',
    'ids',
    'finance',
    'medical',
    'general',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(vaultInfoProvider).asData?.value.query ?? '';
    _searchController.text = initialQuery;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(vaultInfoProvider.notifier).setQuery(_searchController.text);
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'ids':
        return 'IDs';
      case 'finance':
        return 'Finance';
      case 'medical':
        return 'Medical';
      case 'general':
        return 'General';
      case 'custom':
        return 'Custom';
      default:
        return filter;
    }
  }

  IconData _iconForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'ids':
        return Icons.badge_outlined;
      case 'finance':
        return Icons.account_balance_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'general':
        return Icons.category_outlined;
      default:
        return Icons.folder_shared_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      vaultInfoProvider.select((s) => s.isLoading),
    );
    final state = ref.watch(
      vaultInfoProvider.select((s) => s.asData?.value ?? const VaultInfoState()),
    );
    final items = state.filteredItems;

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Info Vault',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(vaultInfoProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by label or category',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.query.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filters.map((filter) {
                return FilterChip(
                  label: Text(_filterLabel(filter)),
                  selected: state.filter == filter,
                  onSelected: (_) {
                    ref.read(vaultInfoProvider.notifier).setFilter(filter);
                  },
                );
              }).toList(),
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (isLoading && state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No vault info items found.'),
              )
            else
              ...items.map((item) {
                final dateLabel = DateFormat(
                  'dd MMM yyyy',
                ).format(item.createdAt);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconForCategory(item.category)),
                  title: Text(item.label),
                  subtitle: Text('${item.category} - $dateLabel'),
                  trailing: const Text('********'),
                  onTap: () async {
                    final changed = await context.push<bool>(
                      RoutePaths.vaultInfoItem(item.id),
                    );
                    if (changed == true && mounted) {
                      await ref.read(vaultInfoProvider.notifier).refresh();
                    }
                  },
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await context.push<bool>(RoutePaths.vaultInfoNew);
          if (changed == true && mounted) {
            await ref.read(vaultInfoProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Info Item'),
      ),
    );
  }
}

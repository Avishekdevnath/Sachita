import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/features/vault/providers/vault_doc_provider.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class VaultDocFoldersScreen extends ConsumerStatefulWidget {
  const VaultDocFoldersScreen({super.key});

  @override
  ConsumerState<VaultDocFoldersScreen> createState() {
    return _VaultDocFoldersScreenState();
  }
}

class _VaultDocFoldersScreenState extends ConsumerState<VaultDocFoldersScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[index]}';
  }

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(vaultDocProvider).asData?.value.query ?? '';
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
    ref.read(vaultDocProvider.notifier).setQuery(_searchController.text);
  }

  void _showStorageModal() {
    final vaultDocAsync = ref.read(vaultDocProvider);
    final state = vaultDocAsync.asData?.value ?? const VaultDocState();
    final usage = state.storageUsage;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStorageRow('Total Used', _formatBytes(usage.totalBytes), true),
            const SizedBox(height: AppTokens.space12),
            _buildStorageRow('Metadata', _formatBytes(usage.metadataBytes), false),
            const SizedBox(height: AppTokens.space8),
            _buildStorageRow('Images', _formatBytes(usage.imagePayloadBytes), false),
            const SizedBox(height: AppTokens.space16),
            Container(
              padding: const EdgeInsets.all(AppTokens.space12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outlined,
                        size: AppTokens.iconSm,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: AppTokens.space8),
                      Expanded(
                        child: Text(
                          '${usage.folderCount} folder${usage.folderCount == 1 ? '' : 's'}, ${usage.itemCount} document${usage.itemCount == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isTotal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final nameController = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'e.g. ID Cards, Certificates',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(nameController.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    nameController.dispose();

    if (!mounted || folderName == null || folderName.trim().isEmpty) {
      return;
    }

    final error = await ref
        .read(vaultDocProvider.notifier)
        .createFolder(folderName);
    if (!mounted) {
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
    ).showSnackBar(const SnackBar(content: Text('Folder created.')));
  }

  Future<void> _showRenameFolderDialog(VaultDocFolderModel folder) async {
    final nameController = TextEditingController(text: folder.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Folder name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(nameController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    nameController.dispose();

    if (!mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }

    final error = await ref
        .read(vaultDocProvider.notifier)
        .renameFolder(folderId: folder.id, name: nextName);
    if (!mounted) {
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
    ).showSnackBar(const SnackBar(content: Text('Folder renamed.')));
  }

  Future<void> _deleteFolder(VaultDocFolderModel folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete folder?'),
          content: Text('Delete "${folder.name}" and all documents inside it?'),
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
    if (!mounted || confirmed != true) {
      return;
    }

    final error = await ref
        .read(vaultDocProvider.notifier)
        .deleteFolder(folder.id);
    if (!mounted) {
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
    ).showSnackBar(const SnackBar(content: Text('Folder deleted.')));
  }

  String _latestItemLabel(DateTime? latestItemAt) {
    if (latestItemAt == null) {
      return 'No documents yet';
    }
    return 'Latest: ${DateFormat('dd MMM yyyy').format(latestItemAt)}';
  }

  Color _parseColor(String hexColor) {
    final cleaned = hexColor.trim().replaceFirst('#', '');
    if (cleaned.length != 6) {
      return Colors.grey;
    }
    final value = int.tryParse('FF$cleaned', radix: 16);
    if (value == null) {
      return Colors.grey;
    }
    return Color(value);
  }

  Widget _buildFolderTile(VaultDocFolderModel folder) {
    final folderColor = _parseColor(folder.colorHex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space6),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space12),
        onTap: () => context.push(RoutePaths.vaultDocFolder(folder.id)),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: folderColor.withAlpha(51),
              child: Icon(
                Icons.folder_outlined,
                color: folderColor,
                size: AppTokens.iconLg,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    folder.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    '${folder.itemCount} document${folder.itemCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    _latestItemLabel(folder.latestItemAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (action) async {
                if (action == 'rename') {
                  await _showRenameFolderDialog(folder);
                  return;
                }
                if (action == 'delete') {
                  await _deleteFolder(folder);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultDocAsync = ref.watch(vaultDocProvider);
    final state = vaultDocAsync.asData?.value ?? const VaultDocState();
    final folders = state.filteredFolders;
    final usage = state.storageUsage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Vault'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Storage info',
            onPressed: _showStorageModal,
            icon: const Icon(Icons.info_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(vaultDocProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(vaultDocProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space20,
          ),
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders',
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
            const SizedBox(height: AppTokens.space16),
            if (folders.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${folders.length} folder${folders.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (usage.totalBytes > 0)
                    Chip(
                      avatar: const Icon(Icons.storage_outlined, size: 18),
                      label: Text(_formatBytes(usage.totalBytes)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space12),
            ],
            if (state.errorMessage != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppTokens.space12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space12),
            ],
            if (vaultDocAsync.isLoading && state.folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        ),
                        child: Icon(
                          Icons.folder_open_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space16),
                      Text(
                        'No folders yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space6),
                      Text(
                        'Create your first folder to organize documents',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTokens.space16),
                      FilledButton.icon(
                        onPressed: _showCreateFolderDialog,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('Create Folder'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...folders.map(_buildFolderTile),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateFolderDialog,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add Folder'),
      ),
    );
  }
}

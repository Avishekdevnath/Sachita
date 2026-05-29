import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/groups/data/group_vault_doc_repository.dart';
import 'package:sanchita/features/groups/models/group_vault_doc_storage_usage_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class GroupVaultDocFoldersScreen extends ConsumerStatefulWidget {
  const GroupVaultDocFoldersScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupVaultDocFoldersScreen> createState() {
    return _GroupVaultDocFoldersScreenState();
  }
}

class _GroupVaultDocFoldersScreenState
    extends ConsumerState<GroupVaultDocFoldersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _errorMessage;
  List<VaultDocFolderModel> _folders = const <VaultDocFolderModel>[];
  GroupVaultDocStorageUsageModel _usage =
      const GroupVaultDocStorageUsageModel();

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
    _searchController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStorageModal() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStorageRow('Total Used', _formatBytes(_usage.totalBytes), true),
            const SizedBox(height: AppTokens.space12),
            _buildStorageRow('Metadata', _formatBytes(_usage.metadataBytes), false),
            const SizedBox(height: AppTokens.space8),
            _buildStorageRow('Images', _formatBytes(_usage.imagePayloadBytes), false),
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
                          '${_usage.folderCount} folder${_usage.folderCount == 1 ? '' : 's'}, ${_usage.itemCount} document${_usage.itemCount == 1 ? '' : 's'}',
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final repository = ref.read(groupVaultDocRepositoryProvider);
    final foldersResult = await repository.getFolders(widget.groupId);
    final usageResult = await repository.getStorageUsage(widget.groupId);
    if (!mounted) {
      return;
    }

    final folders = foldersResult.when(
      success: (items) => items,
      failure: (_) => const <VaultDocFolderModel>[],
    );
    final usage = usageResult.when(
      success: (model) => model,
      failure: (_) => const GroupVaultDocStorageUsageModel(),
    );
    final errorMessage =
        foldersResult.when(
          success: (_) => null,
          failure: (message) => message,
        ) ??
        usageResult.when(success: (_) => null, failure: (message) => message);

    setState(() {
      _folders = folders;
      _usage = usage;
      _errorMessage = errorMessage;
      _loading = false;
    });
  }

  List<VaultDocFolderModel> _visibleFolders() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _folders;
    }
    return _folders
        .where((folder) {
          return folder.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _showCreateFolderDialog() async {
    final nameController = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Group Folder'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'e.g. Family Docs, Shared IDs',
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

    final result = await ref
        .read(groupVaultDocRepositoryProvider)
        .createFolder(groupId: widget.groupId, name: folderName);
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Folder created.')));
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
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

    final result = await ref
        .read(groupVaultDocRepositoryProvider)
        .renameFolder(
          groupId: widget.groupId,
          folderId: folder.id,
          name: nextName,
        );
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Folder renamed.')));
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
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

    final result = await ref
        .read(groupVaultDocRepositoryProvider)
        .deleteFolder(groupId: widget.groupId, folderId: folder.id);
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Folder deleted.')));
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
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
      return const Color(0xFF4ECDC4);
    }
    final value = int.tryParse('FF$cleaned', radix: 16);
    if (value == null) {
      return const Color(0xFF4ECDC4);
    }
    return Color(value);
  }

  Widget _buildFolderTile(VaultDocFolderModel folder) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _parseColor(folder.colorHex).withAlpha(51),
        child: Icon(Icons.folder_outlined, color: _parseColor(folder.colorHex)),
      ),
      title: Text(folder.name),
      subtitle: Text(
        '${folder.itemCount} item(s) - ${_latestItemLabel(folder.latestItemAt)}',
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
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
      onTap: () {
        context.push(
          RoutePaths.groupsVaultDocsFolder(
            groupId: widget.groupId,
            folderId: folder.id,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = ref
        .watch(groupDetailProvider(widget.groupId))
        .asData
        ?.value
        .name;
    final visibleFolders = _visibleFolders();

    return Scaffold(
      appBar: AppNavigationBar(
        title: '${groupName ?? 'Group'} Docs',
        showBackButton: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Storage info',
            onPressed: _showStorageModal,
            icon: const Icon(Icons.info_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders',
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
            const SizedBox(height: 16),
            Text(
              '${visibleFolders.length} folder(s)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (_loading && _folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleFolders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No folders yet.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your first group folder to store shared documents.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showCreateFolderDialog,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Create First Folder'),
                    ),
                  ],
                ),
              )
            else
              ...visibleFolders.map(_buildFolderTile),
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/groups/data/group_vault_doc_repository.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/features/vault/models/vault_doc_item_model.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class GroupVaultDocFolderScreen extends ConsumerStatefulWidget {
  const GroupVaultDocFolderScreen({
    required this.groupId,
    required this.folderId,
    super.key,
  });

  final String groupId;
  final String folderId;

  @override
  ConsumerState<GroupVaultDocFolderScreen> createState() {
    return _GroupVaultDocFolderScreenState();
  }
}

class _GroupVaultDocFolderScreenState
    extends ConsumerState<GroupVaultDocFolderScreen> {
  static const List<String> _sortModes = <String>[
    'Newest',
    'Oldest',
    'Name A-Z',
    'Name Z-A',
  ];

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<Uint8List?>> _thumbnailFutures =
      <String, Future<Uint8List?>>{};
  String _sortMode = _sortModes.first;
  bool _loading = true;
  String? _errorMessage;
  VaultDocFolderModel? _folder;
  List<VaultDocItemModel> _items = const <VaultDocItemModel>[];

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
    _thumbnailFutures.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final repository = ref.read(groupVaultDocRepositoryProvider);
    final foldersResult = await repository.getFolders(widget.groupId);
    final itemsResult = await repository.getItemsForFolder(
      groupId: widget.groupId,
      folderId: widget.folderId,
    );
    if (!mounted) {
      return;
    }

    final folders = foldersResult.when(
      success: (items) => items,
      failure: (_) => const <VaultDocFolderModel>[],
    );
    final itemList = itemsResult.when(
      success: (items) => items,
      failure: (_) => const <VaultDocItemModel>[],
    );
    final errorMessage =
        itemsResult.when(success: (_) => null, failure: (message) => message) ??
        foldersResult.when(success: (_) => null, failure: (message) => message);

    VaultDocFolderModel? folder;
    for (final candidate in folders) {
      if (candidate.id == widget.folderId) {
        folder = candidate;
        break;
      }
    }

    setState(() {
      _folder = folder;
      _items = itemList;
      _errorMessage = errorMessage;
      _loading = false;
      _thumbnailFutures.clear();
    });
  }

  Future<Uint8List?> _loadThumbnailBytes(String imageKey) {
    final normalized = imageKey.trim();
    if (normalized.isEmpty) {
      return Future<Uint8List?>.value(null);
    }
    return _thumbnailFutures.putIfAbsent(
      normalized,
      () => ref.read(groupVaultDocRepositoryProvider).readImageBytes(normalized),
    );
  }

  List<VaultDocItemModel> _visibleItems() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items
        .where((item) {
          if (query.isEmpty) {
            return true;
          }
          final label = item.label.toLowerCase();
          final notes = item.notes.toLowerCase();
          final tags = item.tags.join(' ').toLowerCase();
          return label.contains(query) ||
              notes.contains(query) ||
              tags.contains(query);
        })
        .toList(growable: false);

    final sorted = <VaultDocItemModel>[...filtered];
    switch (_sortMode) {
      case 'Newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Name A-Z':
        sorted.sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
        break;
      case 'Name Z-A':
        sorted.sort(
          (a, b) => b.label.toLowerCase().compareTo(a.label.toLowerCase()),
        );
        break;
      default:
        break;
    }
    return sorted;
  }

  IconData _iconForMode(String saveMode) {
    switch (saveMode.toLowerCase()) {
      case 'document':
        return Icons.description_outlined;
      case 'enhanced':
        return Icons.auto_fix_high_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  String _modeLabel(String saveMode) {
    switch (saveMode.toLowerCase()) {
      case 'document':
        return 'Document';
      case 'enhanced':
        return 'Enhanced';
      default:
        return 'Original';
    }
  }

  Widget _buildThumbnailPlaceholder(
    BuildContext context,
    VaultDocItemModel item,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _iconForMode(item.saveMode),
          size: 28,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, VaultDocItemModel item) {
    final thumbKey = item.thumbnailKey.trim();
    final fullKey = item.imageKey.trim();
    final imageKey = thumbKey.isNotEmpty ? thumbKey : fullKey;

    if (imageKey.isEmpty) {
      return _buildThumbnailPlaceholder(context, item);
    }

    return FutureBuilder<Uint8List?>(
      future: _loadThumbnailBytes(imageKey),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _buildThumbnailPlaceholder(context, item);
        }

        final colorScheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                colorScheme.surfaceContainerHighest,
                colorScheme.surfaceContainer,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: colorScheme.surface,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) {
                    return _buildThumbnailPlaceholder(context, item);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard(BuildContext context, VaultDocItemModel item) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdOn = DateFormat('dd MMM yyyy').format(item.createdAt);
    final tags = item.tags.take(2).join(' | ');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final changed = await context.push<bool>(
            RoutePaths.groupsVaultDocsItem(
              groupId: widget.groupId,
              folderId: item.folderId,
              itemId: item.id,
            ),
          );
          if (changed == true && mounted) {
            await _load();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildThumbnail(context, item)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(_iconForMode(item.saveMode), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _modeLabel(item.saveMode),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          createdOn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      tags,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_folder == null) {
      return Scaffold(
        appBar: const AppNavigationBar(
          title: 'Group Folder',
          showBackButton: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Folder not found. Pull to refresh from Group Document Vault.',
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('Refresh Folders'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppNavigationBar(
        title: _folder!.name,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search labels, tags, notes',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _sortMode,
              decoration: const InputDecoration(labelText: 'Sort'),
              items: _sortModes
                  .map(
                    (mode) => DropdownMenuItem<String>(
                      value: mode,
                      child: Text(mode),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (selected) {
                if (selected == null) {
                  return;
                }
                setState(() {
                  _sortMode = selected;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              '${visibleItems.length} document(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (visibleItems.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'No documents in this folder yet.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use Add Document to start building this folder.',
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                itemCount: visibleItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  return _buildDocumentCard(context, item);
                },
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final changed = await context.push<bool>(
                  RoutePaths.groupsVaultDocsAdd(
                    groupId: widget.groupId,
                    folderId: widget.folderId,
                  ),
                );
                if (changed == true && mounted) {
                  await _load();
                }
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Document'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/vault/data/vault_doc_repository.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/features/vault/models/vault_doc_item_model.dart';
import 'package:sanchita/features/vault/providers/vault_doc_provider.dart';
import 'package:sanchita/features/vault/services/document_file_action_service.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class VaultDocViewerScreen extends ConsumerStatefulWidget {
  const VaultDocViewerScreen({
    required this.folderId,
    required this.itemId,
    super.key,
  });

  final String folderId;
  final String itemId;

  @override
  ConsumerState<VaultDocViewerScreen> createState() {
    return _VaultDocViewerScreenState();
  }
}

class _VaultDocViewerScreenState extends ConsumerState<VaultDocViewerScreen> {
  final Map<String, Future<Uint8List?>> _imageFutures =
      <String, Future<Uint8List?>>{};
  PageController? _pageController;

  bool _loading = true;
  String? _errorMessage;
  List<VaultDocItemModel> _items = const <VaultDocItemModel>[];
  List<VaultDocFolderModel> _folders = const <VaultDocFolderModel>[];
  int _currentIndex = 0;
  bool _prefetching = false;
  int _prefetchTotal = 0;
  int _prefetchDone = 0;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData(preferredItemId: widget.itemId);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadData({String? preferredItemId}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final repository = ref.read(vaultDocRepositoryProvider);
    final itemsResult = await repository.getItemsForFolder(widget.folderId);
    final foldersResult = await repository.getFolders();
    if (!mounted) {
      return;
    }

    final items = itemsResult.when(
      success: (data) => data,
      failure: (_) => const <VaultDocItemModel>[],
    );
    final folders = foldersResult.when(
      success: (data) => data,
      failure: (_) => const <VaultDocFolderModel>[],
    );

    final failureMessage =
        itemsResult.when(success: (_) => null, failure: (message) => message) ??
        foldersResult.when(success: (_) => null, failure: (message) => message);

    if (items.isEmpty) {
      _pageController?.dispose();
      setState(() {
        _items = const <VaultDocItemModel>[];
        _folders = folders;
        _loading = false;
        _errorMessage =
            failureMessage ?? 'No documents available in this folder.';
        _currentIndex = 0;
        _pageController = null;
        _prefetching = false;
        _prefetchTotal = 0;
        _prefetchDone = 0;
      });
      return;
    }

    var initialIndex = 0;
    final targetItemId = preferredItemId?.trim();
    if (targetItemId != null && targetItemId.isNotEmpty) {
      final found = items.indexWhere((item) => item.id == targetItemId);
      if (found >= 0) {
        initialIndex = found;
      }
    }

    final nextController = PageController(initialPage: initialIndex);
    _pageController?.dispose();
    setState(() {
      _items = items;
      _folders = folders;
      _loading = false;
      _errorMessage = failureMessage;
      _currentIndex = initialIndex;
      _pageController = nextController;
    });
    _prefetchAround(initialIndex);
  }

  Future<Uint8List?> _loadImageBytes(String imageKey) {
    final normalized = imageKey.trim();
    if (normalized.isEmpty) {
      return Future<Uint8List?>.value(null);
    }
    return _imageFutures.putIfAbsent(
      normalized,
      () => ref.read(vaultDocRepositoryProvider).readImageBytes(normalized),
    );
  }

  Future<void> _prefetchAround(int centerIndex) async {
    if (_items.isEmpty) {
      return;
    }

    final keys = <String>{};
    for (var delta = -1; delta <= 1; delta++) {
      final index = centerIndex + delta;
      if (index < 0 || index >= _items.length) {
        continue;
      }
      final key = _items[index].imageKey.trim();
      if (key.isNotEmpty) {
        keys.add(key);
      }
    }
    if (keys.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _prefetching = true;
        _prefetchDone = 0;
        _prefetchTotal = keys.length;
      });
    }

    var done = 0;
    final futures = keys.map((key) async {
      await _loadImageBytes(key);
      done += 1;
      if (mounted) {
        setState(() {
          _prefetchDone = done;
        });
      }
    }).toList(growable: false);

    await Future.wait(futures);
    if (mounted) {
      setState(() {
        _prefetching = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unit]}';
  }

  String _folderName(String folderId) {
    for (final folder in _folders) {
      if (folder.id == folderId) {
        return folder.name;
      }
    }
    return 'Document Folder';
  }

  VaultDocItemModel? _currentItem() {
    if (_items.isEmpty || _currentIndex < 0 || _currentIndex >= _items.length) {
    // Defensive null return - validation failed
      return null;
    }
    return _items[_currentIndex];
  }

  Future<void> _showEditDialog(VaultDocItemModel item) async {
    final labelController = TextEditingController(text: item.label);
    final tagsController = TextEditingController(text: item.tags.join(', '));
    final notesController = TextEditingController(text: item.notes);
    var selectedFolderId = item.folderId;
    if (_folders.isNotEmpty &&
        !_folders.any((folder) => folder.id == selectedFolderId)) {
      selectedFolderId = _folders.first.id;
    }

    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Edit Document'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    const SizedBox(height: 8),
                    if (_folders.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No folders available'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue:
                            _folders.any(
                              (folder) => folder.id == selectedFolderId,
                            )
                            ? selectedFolderId
                            : _folders.first.id,
                        decoration: const InputDecoration(labelText: 'Folder'),
                        items: _folders
                            .map(
                              (folder) => DropdownMenuItem<String>(
                                value: folder.id,
                                child: Text(folder.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setLocalState(() {
                            selectedFolderId = value;
                          });
                        },
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
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
                    Navigator.of(context).pop(<String, Object?>{
                      'label': labelController.text.trim(),
                      'folderId': selectedFolderId,
                      'tags': tagsController.text,
                      'notes': notesController.text.trim(),
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
    tagsController.dispose();
    notesController.dispose();

    if (!mounted || payload == null) {
      return;
    }

    final label = (payload['label'] as String? ?? '').trim();
    final folderId = (payload['folderId'] as String? ?? '').trim();
    final tagsRaw = (payload['tags'] as String? ?? '');
    final notes = (payload['notes'] as String? ?? '').trim();
    final tags = tagsRaw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    final result = await ref
        .read(vaultDocRepositoryProvider)
        .updateItemMetadata(
          itemId: item.id,
          folderId: folderId,
          label: label,
          tags: tags,
          notes: notes,
        );
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        if (!mounted) {
          return;
        }
        try {
          await ref.read(vaultDocProvider.notifier).refresh();
        } catch (_) {
          // Provider refresh failed, continue with local reload
        }
        if (!mounted) {
          return;
        }
        if (folderId != widget.folderId) {
          if (mounted) {
            context.go(RoutePaths.vaultDocFolder(folderId));
          }
          return;
        }
        await _loadData(preferredItemId: item.id);
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _deleteCurrentItem(VaultDocItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete document?'),
          content: Text('Delete "${item.label}" from this vault folder?'),
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
        .read(vaultDocRepositoryProvider)
        .softDeleteItem(item.id);
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        if (!mounted) {
          return;
        }
        try {
          await ref.read(vaultDocProvider.notifier).refresh();
        } catch (_) {
          // Provider refresh failed, continue with navigation
        }
        if (!mounted) {
          return;
        }
        if (_items.length <= 1) {
          if (mounted) {
            context.pop(true);
          }
          return;
        }
        final preferred = _currentIndex < _items.length - 1
            ? _items[_currentIndex + 1].id
            : _items[_items.length - 2].id;
        await _loadData(preferredItemId: preferred);
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
  }) async {
    if (_actionBusy) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<Uint8List?> _readCurrentItemBytes(VaultDocItemModel item) async {
    final key = item.imageKey.trim();
    if (key.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }
    return _loadImageBytes(key);
  }

  Future<void> _shareCurrentItem(VaultDocItemModel item) async {
    final bytes = await _readCurrentItemBytes(item);
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image data found for this document.')),
      );
      return;
    }

    final result = await ref
        .read(documentFileActionServiceProvider)
        .shareImage(
          imageBytes: bytes,
          label: item.label,
          namespace: 'vault_docs',
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {},
      failure: (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _printCurrentItem(VaultDocItemModel item) async {
    final bytes = await _readCurrentItemBytes(item);
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image data found for this document.')),
      );
      return;
    }

    final result = await ref
        .read(documentFileActionServiceProvider)
        .printImage(imageBytes: bytes, label: item.label);
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {},
      failure: (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _exportCurrentItem(VaultDocItemModel item) async {
    final bytes = await _readCurrentItemBytes(item);
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image data found for this document.')),
      );
      return;
    }

    final result = await ref
        .read(documentFileActionServiceProvider)
        .exportImage(
          imageBytes: bytes,
          label: item.label,
          folderName: _folderName(item.folderId),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (filePath) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $filePath')),
        );
      },
      failure: (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Widget _buildImagePage(VaultDocItemModel item) {
    if (item.imageKey.trim().isEmpty) {
      return const Center(child: Icon(Icons.description_outlined, size: 72));
    }

    return FutureBuilder<Uint8List?>(
      future: _loadImageBytes(item.imageKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Loading page...'),
              ],
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 72),
          );
        }

        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.broken_image_outlined, size: 72);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem();

    return Scaffold(
      appBar: AppNavigationBar(
        title: _items.isEmpty
            ? 'Document Viewer'
            : '${_currentIndex + 1}/${_items.length}',
        showBackButton: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Share',
            onPressed: item == null || _actionBusy
                ? null
                : () {
                    _runAction(action: () => _shareCurrentItem(item));
                  },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Print',
            onPressed: item == null || _actionBusy
                ? null
                : () {
                    _runAction(action: () => _printCurrentItem(item));
                  },
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Export',
            onPressed: item == null || _actionBusy
                ? null
                : () {
                    _runAction(action: () => _exportCurrentItem(item));
                  },
            icon: const Icon(Icons.file_download_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final selectedItem = _currentItem();
              if (selectedItem == null) {
                return;
              }
              if (value == 'edit') {
                await _showEditDialog(selectedItem);
                return;
              }
              if (value == 'delete') {
                await _deleteCurrentItem(selectedItem);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () {
                        _loadData(preferredItemId: widget.itemId);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: <Widget>[
                if (_prefetching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LinearProgressIndicator(
                          value: _prefetchTotal == 0
                              ? null
                              : _prefetchDone / _prefetchTotal,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Preparing nearby pages... $_prefetchDone/$_prefetchTotal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      _prefetchAround(index);
                    },
                    itemBuilder: (context, index) {
                      final pageItem = _items[index];
                      return _buildImagePage(pageItem);
                    },
                  ),
                ),
                if (item != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_folderName(item.folderId)} - ${DateFormat('dd MMM yyyy').format(item.createdAt)} - ${item.saveMode}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (item.outputWidth > 0 && item.outputHeight > 0)
                            Text(
                              '${item.outputWidth}x${item.outputHeight} - ${_formatBytes(item.estimatedBytes)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (item.tags.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: item.tags
                                  .map((tag) => Chip(label: Text(tag)))
                                  .toList(growable: false),
                            ),
                          ],
                          if (item.notes.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(item.notes),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

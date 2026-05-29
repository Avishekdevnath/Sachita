import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/groups/data/group_vault_info_repository.dart';
import 'package:sanchita/features/groups/models/group_vault_info_item_model.dart';
import 'package:sanchita/features/groups/providers/group_vault_info_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class GroupVaultInfoDetailScreen extends ConsumerStatefulWidget {
  const GroupVaultInfoDetailScreen({
    required this.groupId,
    required this.itemId,
    super.key,
  });

  final String groupId;
  final String itemId;

  @override
  ConsumerState<GroupVaultInfoDetailScreen> createState() =>
      _GroupVaultInfoDetailScreenState();
}

class _GroupVaultInfoDetailScreenState
    extends ConsumerState<GroupVaultInfoDetailScreen> {
  bool _loading = true;
  bool _revealed = false;
  String? _errorMessage;
  GroupVaultInfoItemModel? _item;
  Timer? _clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItem() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final itemResult = await ref
        .read(groupVaultInfoRepositoryProvider)
        .getItemById(groupId: widget.groupId, itemId: widget.itemId);

    if (!mounted) {
      return;
    }

    itemResult.when(
      success: (item) {
        setState(() {
          _item = item;
          _loading = false;
        });
      },
      failure: (message) {
        setState(() {
          _item = null;
          _errorMessage = message;
          _loading = false;
        });
      },
    );
  }

  Future<void> _toggleReveal() async {
    if (_item == null) {
      return;
    }

    if (_revealed) {
      setState(() {
        _revealed = false;
      });
      return;
    }

    final allowed = await _authenticateSensitiveAction();
    if (!mounted || !allowed) {
      return;
    }

    setState(() {
      _revealed = true;
    });
  }

  Future<void> _copyValue() async {
    if (_item == null) {
      return;
    }

    final allowed = await _authenticateSensitiveAction();
    if (!mounted || !allowed) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _item!.value));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Value copied. Clipboard clears in 30s.')),
    );

    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  Future<bool> _authenticateSensitiveAction() async {
    if (!mounted) {
      return false;
    }
    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _goToEdit() async {
    if (_item == null) {
      return;
    }

    final changed = await context.push<bool>(
      RoutePaths.groupsVaultInfoEdit(
        groupId: widget.groupId,
        itemId: _item!.id,
      ),
    );
    if (changed == true) {
      await _loadItem();
    }
  }

  Future<void> _delete() async {
    if (_item == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete info item?'),
          content: Text('Delete "${_item!.label}" from group vault?'),
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

    if (confirmed != true) {
      return;
    }

    final result = await ref
        .read(groupVaultInfoRepositoryProvider)
        .softDeleteItem(groupId: widget.groupId, itemId: _item!.id);
    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        ref.invalidate(groupVaultInfoItemsProvider(widget.groupId));
        if (!mounted) {
          return;
        }
        context.pop(true);
      },
      failure: (message) async {
        _setError(message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_item == null) {
      return Scaffold(
        appBar: const AppNavigationBar(
          title: 'Group Info Item',
          showBackButton: true,
        ),
        body: Center(
          child: Text(_errorMessage ?? 'Group info item not found.'),
        ),
      );
    }

    final item = _item!;
    final addedOn = DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt);
    final valueText = _revealed ? item.value : '********';

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Group Info Item Detail',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text(item.category)),
              Chip(
                label: Text('Belongs to: ${item.belongsToLabel}'),
                avatar: const Icon(Icons.person_outline, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Value'),
            subtitle: Text(valueText),
            trailing: TextButton.icon(
              onPressed: _toggleReveal,
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(_revealed ? 'Hide' : 'Reveal'),
            ),
          ),
          if (item.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(item.notes),
          ],
          const SizedBox(height: 12),
          Text('Added: $addedOn', style: Theme.of(context).textTheme.bodySmall),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _copyValue,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy Value'),
              ),
              FilledButton.tonalIcon(
                onPressed: _goToEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              FilledButton.tonalIcon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/providers/group_provider.dart';

class GroupEditScreen extends ConsumerStatefulWidget {
  const GroupEditScreen({this.groupId, super.key});

  final String? groupId;

  bool get isEdit => groupId != null;

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  static const List<String> _iconOptions = <String>[
    'group',
    'family',
    'home',
    'work',
    'travel',
    'event',
  ];

  static const List<String> _colorOptions = <String>[
    '#4ECDC4',
    '#FF6B6B',
    '#45B7D1',
    '#96CEB4',
    '#DDA0DD',
    '#F7DC6F',
    '#2ECC71',
    '#3498DB',
  ];

  final TextEditingController _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _selectedIcon = _iconOptions.first;
  String _selectedColor = _colorOptions.first;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIfEditing();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadIfEditing() async {
    if (!widget.isEdit) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final result = await ref
        .read(groupRepositoryProvider)
        .getGroupById(widget.groupId!);
    if (!mounted) {
      return;
    }

    result.when(
      success: (group) {
        setState(() {
          _nameController.text = group.name;
          _selectedIcon = _iconOptions.contains(group.icon)
              ? group.icon
              : _iconOptions.first;
          _selectedColor = _colorOptions.contains(group.colorHex)
              ? group.colorHex
              : _colorOptions.first;
          _loading = false;
        });
      },
      failure: (message) {
        setState(() {
          _loading = false;
          _errorMessage = message;
        });
      },
    );
  }

  IconData _iconData(String key) {
    switch (key) {
      case 'group':
        return Icons.group_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline;
      case 'travel':
        return Icons.luggage_outlined;
      case 'event':
        return Icons.event_outlined;
      default:
        return Icons.group_outlined;
    }
  }

  Color _parseColor(String hexColor) {
    final cleaned = hexColor.trim().replaceFirst('#', '');
    final parsed = int.tryParse('FF$cleaned', radix: 16);
    if (parsed == null) {
      return const Color(0xFF4ECDC4);
    }
    return Color(parsed);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Group name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final notifier = ref.read(groupProvider.notifier);
    final error = widget.isEdit
        ? await notifier.updateGroup(
            groupId: widget.groupId!,
            name: name,
            icon: _selectedIcon,
            colorHex: _selectedColor,
          )
        : await notifier.createGroup(
            name: name,
            icon: _selectedIcon,
            colorHex: _selectedColor,
          );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _saving = false;
        _errorMessage = error;
      });
      return;
    }

    context.pop(true);
  }

  Widget _buildIconOption(String iconKey) {
    final selected = _selectedIcon == iconKey;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_iconData(iconKey), size: 18),
          const SizedBox(width: 6),
          Text(iconKey),
        ],
      ),
      selected: selected,
      onSelected: _saving
          ? null
          : (_) {
              setState(() {
                _selectedIcon = iconKey;
              });
            },
    );
  }

  Widget _buildColorOption(String colorHex) {
    final selected = _selectedColor == colorHex;
    final color = _parseColor(colorHex);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _saving
          ? null
          : () {
              setState(() {
                _selectedColor = colorHex;
              });
            },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : const <BoxShadow>[],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Group' : 'Create Group'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _nameController,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g. Family, Friends, Flatmates',
            ),
          ),
          const SizedBox(height: 14),
          Text('Icon', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _iconOptions
                .map(_buildIconOption)
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorOptions
                .map(_buildColorOption)
                .toList(growable: false),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save Group'),
          ),
        ],
      ),
    );
  }
}

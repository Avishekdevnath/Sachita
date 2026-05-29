import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/features/groups/data/group_vault_info_repository.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/providers/group_members_provider.dart';
import 'package:sanchita/features/groups/providers/group_vault_info_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class GroupVaultInfoEditScreen extends ConsumerStatefulWidget {
  const GroupVaultInfoEditScreen({
    required this.groupId,
    this.itemId,
    super.key,
  });

  final String groupId;
  final String? itemId;

  bool get isEdit => itemId != null;

  @override
  ConsumerState<GroupVaultInfoEditScreen> createState() =>
      _GroupVaultInfoEditScreenState();
}

class _GroupVaultInfoEditScreenState
    extends ConsumerState<GroupVaultInfoEditScreen> {
  static const List<String> _standardCategories = <String>[
    'IDs',
    'Finance',
    'Medical',
    'General',
    'Custom',
  ];
  static const String _groupWideValue = '__group_wide__';

  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscureValue = true;
  String _category = 'IDs';
  String _selectedMemberValue = _groupWideValue;
  String? _errorMessage;

  bool get _isCustomCategory => _category == 'Custom';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!widget.isEdit) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final itemResult = await ref
        .read(groupVaultInfoRepositoryProvider)
        .getItemById(groupId: widget.groupId, itemId: widget.itemId!);

    if (!mounted) {
      return;
    }

    itemResult.when(
      success: (item) {
        final normalized = item.category.trim();
        final matchingStandard = _standardCategories.firstWhere(
          (candidate) => candidate.toLowerCase() == normalized.toLowerCase(),
          orElse: () => 'Custom',
        );

        setState(() {
          _category = matchingStandard;
          _selectedMemberValue = item.memberId ?? _groupWideValue;
          _labelController.text = item.label;
          _valueController.text = item.value;
          _notesController.text = item.notes;
          _customCategoryController.text = matchingStandard == 'Custom'
              ? normalized
              : '';
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

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final category = _isCustomCategory
        ? _customCategoryController.text.trim()
        : _category;
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    final notes = _notesController.text.trim();
    final memberId = _selectedMemberValue == _groupWideValue
        ? null
        : _selectedMemberValue;

    if (category.isEmpty) {
      setState(() {
        _errorMessage = 'Category is required.';
      });
      return;
    }
    if (label.isEmpty) {
      setState(() {
        _errorMessage = 'Label is required.';
      });
      return;
    }
    if (value.isEmpty) {
      setState(() {
        _errorMessage = 'Value is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final repository = ref.read(groupVaultInfoRepositoryProvider);
    final result = widget.isEdit
        ? await repository.updateItem(
            groupId: widget.groupId,
            itemId: widget.itemId!,
            memberId: memberId,
            category: category,
            label: label,
            value: value,
            notes: notes,
          )
        : await repository.createItem(
            groupId: widget.groupId,
            memberId: memberId,
            category: category,
            label: label,
            value: value,
            notes: notes,
          );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) async {
        ref.invalidate(groupVaultInfoItemsProvider(widget.groupId));
        if (!mounted) {
          return;
        }
        context.pop(true);
      },
      failure: (message) {
        setState(() {
          _saving = false;
          _errorMessage = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final members = membersAsync.asData?.value ?? const <GroupMemberModel>[];
    final memberIds = <String>{for (final member in members) member.id};
    final selectedMemberValue =
        _selectedMemberValue == _groupWideValue ||
            memberIds.contains(_selectedMemberValue)
        ? _selectedMemberValue
        : _groupWideValue;

    return Scaffold(
      appBar: AppNavigationBar(
        title: widget.isEdit ? 'Edit Group Info Item' : 'Add Group Info Item',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _standardCategories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (selected) {
                    if (selected == null) {
                      return;
                    }
                    setState(() {
                      _category = selected;
                    });
                  },
          ),
          if (_isCustomCategory) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _customCategoryController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Custom category name',
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'group-info-member-$selectedMemberValue-${members.length}',
            ),
            initialValue: selectedMemberValue,
            decoration: const InputDecoration(labelText: 'Belongs to'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: _groupWideValue,
                child: Text('Group-wide'),
              ),
              ...members.map((member) {
                return DropdownMenuItem<String>(
                  value: member.id,
                  child: Text(member.name),
                );
              }),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedMemberValue = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            enabled: !_saving,
            obscureText: _obscureValue,
            decoration: InputDecoration(
              labelText: 'Value',
              suffixIcon: IconButton(
                tooltip: _obscureValue ? 'Show' : 'Hide',
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _obscureValue = !_obscureValue;
                        });
                      },
                icon: Icon(
                  _obscureValue
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}

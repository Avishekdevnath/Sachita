import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/groups/providers/group_members_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupMembersScreen> createState() {
    return _GroupMembersScreenState();
  }
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  bool _submitting = false;

  Future<Map<String, String>?> _showMemberForm({
    GroupMemberModel? initialMember,
  }) async {
    final nameController = TextEditingController(
      text: initialMember?.name ?? '',
    );
    final photoKeyController = TextEditingController(
      text: initialMember?.photoKey ?? '',
    );
    final payload = await AppModalSheet.show<Map<String, String>>(
      context: context,
      title: initialMember == null ? 'Add Member' : 'Edit Member',
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Member name',
              hintText: 'e.g. Rahim',
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          TextField(
            controller: photoKeyController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Photo key (optional)',
              hintText: 'Optional secure-storage key',
            ),
          ),
          const SizedBox(height: AppTokens.space16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, String>{
                  'name': nameController.text.trim(),
                  'photoKey': photoKeyController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
    nameController.dispose();
    photoKeyController.dispose();
    return payload;
  }

  Future<void> _refreshMembers() async {
    ref.invalidate(groupMembersProvider(widget.groupId));
  }

  Future<void> _addMember() async {
    final payload = await _showMemberForm();
    if (!mounted || payload == null) {
      return;
    }

    final name = payload['name'] ?? '';
    final photoKey = payload['photoKey'];
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member name is required.')));
      return;
    }

    setState(() {
      _submitting = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .createGroupMember(
          groupId: widget.groupId,
          name: name,
          photoKey: photoKey,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });

    await result.when(
      success: (_) async {
        await _refreshMembers();
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _editMember(GroupMemberModel member) async {
    final payload = await _showMemberForm(initialMember: member);
    if (!mounted || payload == null) {
      return;
    }

    final name = payload['name'] ?? '';
    final photoKey = payload['photoKey'];
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member name is required.')));
      return;
    }

    setState(() {
      _submitting = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .updateGroupMember(
          memberId: member.id,
          groupId: widget.groupId,
          name: name,
          photoKey: photoKey,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });

    await result.when(
      success: (_) async {
        await _refreshMembers();
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _removeMember(GroupMemberModel member) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Choose how to remove "${member.name}".'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop('keep');
              },
              child: const Text('Keep Transactions'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop('delete');
              },
              child: const Text('Delete Transactions'),
            ),
          ],
        );
      },
    );

    if (!mounted || mode == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .removeGroupMember(
          memberId: member.id,
          groupId: widget.groupId,
          deleteRelatedTransactions: mode == 'delete',
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });

    await result.when(
      success: (_) async {
        await _refreshMembers();
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Widget _memberTile(GroupMemberModel member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(
          member.photoKey == null ? Icons.person_outline : Icons.photo_outlined,
        ),
      ),
      title: Text(member.name),
      subtitle: Text(
        member.photoKey == null
            ? 'No photo key'
            : 'Photo key: ${member.photoKey}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (_submitting) {
            return;
          }
          if (value == 'edit') {
            await _editMember(member);
            return;
          }
          if (value == 'remove') {
            await _removeMember(member);
          }
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
          PopupMenuItem<String>(value: 'remove', child: Text('Remove')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final groupName = groupAsync.asData?.value.name ?? 'Group';

    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName Members'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _submitting
                ? null
                : () async {
                    await _refreshMembers();
                  },
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMembers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space16,
          ),
          children: <Widget>[
            const Text(
              'Manage group members. Optional photo key can be attached for each member.',
            ),
            const SizedBox(height: AppTokens.space8),
            const Text(
              'Remove behavior: keep previous transactions or delete them together.',
            ),
            const SizedBox(height: AppTokens.space12),
            if (membersAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTokens.space24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (membersAsync.hasError)
              GlassCard(
                padding: const EdgeInsets.all(AppTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      membersAsync.error.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    FilledButton.tonal(
                      onPressed: _refreshMembers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if ((membersAsync.asData?.value ?? const <GroupMemberModel>[])
                .isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(AppTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No members yet.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.space6),
                    const Text(
                      'Add at least one member to start group breakdowns.',
                    ),
                    const SizedBox(height: AppTokens.space12),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _addMember,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add Member'),
                    ),
                  ],
                ),
              )
            else
              ...membersAsync.asData!.value.map(_memberTile),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitting ? null : _addMember,
        tooltip: 'Add member',
        child: const Icon(Icons.add),
      ),
    );
  }
}

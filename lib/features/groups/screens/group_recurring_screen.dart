import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/models/group_recurring_rule_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/groups/providers/group_members_provider.dart';
import 'package:sanchita/features/groups/providers/group_recurring_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';

class GroupRecurringScreen extends ConsumerStatefulWidget {
  const GroupRecurringScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupRecurringScreen> createState() =>
      _GroupRecurringScreenState();
}

class _GroupRecurringScreenState extends ConsumerState<GroupRecurringScreen> {
  static const List<String> _frequencies = <String>[
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  bool _submitting = false;

  String _formatAmountNumber(int paisa) => (paisa / 100).toStringAsFixed(2);

  String _formatAmountDisplay(int paisa, String currencySymbol) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  int? _parseToPaisa(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
    // Defensive null return - validation failed
      return null;
    }
    return (value * 100).round();
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  Future<List<CategoryModel>> _loadCategories(String type) async {
    final result = await ref
        .read(categoryRepositoryProvider)
        .getCategoriesByType(type);
    return result.when(
      success: (items) => items,
      failure: (_) => const <CategoryModel>[],
    );
  }

  Future<void> _refreshRules() async {
    ref.invalidate(groupRecurringProvider(widget.groupId));
  }

  Future<void> _showRuleSheet({
    required List<GroupMemberModel> members,
    GroupRecurringRuleModel? existingRule,
  }) async {
    final currencySymbol = ref.read(currencySymbolProvider);
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add members first before recurring rules.'),
        ),
      );
      return;
    }

    final amountController = TextEditingController(
      text: existingRule == null
          ? ''
          : _formatAmountNumber(existingRule.amountPaisa),
    );
    final noteController = TextEditingController(
      text: existingRule?.note ?? '',
    );

    var type = existingRule?.type ?? 'expense';
    var frequency = existingRule?.frequency ?? 'monthly';
    var startDate = existingRule?.startDate ?? DateTime.now();
    DateTime? endDate = existingRule?.endDate;
    var selectedMemberId = existingRule?.memberId ?? members.first.id;
    String? selectedCategoryId = existingRule?.categoryId;
    var categoriesFuture = _loadCategories(type);
    String? validationError;

    final sheetResult = await AppModalSheet.show<bool>(
      context: context,
      title: existingRule == null
          ? 'Create Group Recurring Rule'
          : 'Edit Group Recurring Rule',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'expense',
                    label: Text('Expense'),
                  ),
                  ButtonSegment<String>(
                    value: 'income',
                    label: Text('Income'),
                  ),
                ],
                selected: <String>{type},
                onSelectionChanged: (selection) {
                  setSheetState(() {
                    type = selection.first;
                    selectedCategoryId = null;
                    categoriesFuture = _loadCategories(type);
                  });
                },
              ),
              const SizedBox(height: AppTokens.space12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'group-recurring-member-$selectedMemberId-${members.length}',
                ),
                initialValue: selectedMemberId,
                items: members
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setSheetState(() {
                    selectedMemberId = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Member'),
              ),
              const SizedBox(height: AppTokens.space12),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                items: _frequencies
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_frequencyLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setSheetState(() {
                    frequency = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Frequency'),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount ($currencySymbol)',
                  hintText: 'e.g. 1200.00',
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              FutureBuilder<List<CategoryModel>>(
                future: categoriesFuture,
                builder: (context, snapshot) {
                  final categories =
                      snapshot.data ?? const <CategoryModel>[];
                  if (categories.isNotEmpty &&
                      selectedCategoryId == null) {
                    selectedCategoryId = categories.first.id;
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppTokens.space12),
                      child: LinearProgressIndicator(),
                    );
                  }

                  if (categories.isEmpty) {
                    return const Text(
                      'No categories available for this type.',
                    );
                  }

                  var hasSelected = false;
                  for (final category in categories) {
                    if (category.id == selectedCategoryId) {
                      hasSelected = true;
                      break;
                    }
                  }
                  if (!hasSelected) {
                    selectedCategoryId = categories.first.id;
                  }

                  return DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'group-recurring-category-$type-${selectedCategoryId ?? 'none'}-${categories.length}',
                    ),
                    initialValue: selectedCategoryId,
                    items: categories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setSheetState(() {
                        selectedCategoryId = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: noteController,
                maxLines: null,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Add details, shopping list, bazar items…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(
                        const Duration(days: 3650),
                      ),
                    );
                    if (picked == null) {
                      return;
                    }
                    setSheetState(() {
                      startDate = picked;
                      if (endDate != null &&
                          endDate!.isBefore(picked)) {
                        endDate = picked;
                      }
                    });
                  },
                  child: Text('Start: ${_formatDate(startDate)}'),
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate,
                          firstDate: startDate,
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked == null) {
                          return;
                        }
                        setSheetState(() {
                          endDate = picked;
                        });
                      },
                      child: Text(
                        endDate == null
                            ? 'No end date'
                            : 'End: ${_formatDate(endDate!)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  TextButton(
                    onPressed: endDate == null
                        ? null
                        : () {
                            setSheetState(() {
                              endDate = null;
                            });
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              if (validationError != null) ...<Widget>[
                const SizedBox(height: AppTokens.space8),
                Text(
                  validationError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.space16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final amountPaisa = _parseToPaisa(
                            amountController.text,
                          );
                          if (amountPaisa == null) {
                            setSheetState(() {
                              validationError =
                                  'Enter a valid amount above zero.';
                            });
                            return;
                          }
                          if (selectedCategoryId == null) {
                            setSheetState(() {
                              validationError = 'Select a category.';
                            });
                            return;
                          }

                          setState(() {
                            _submitting = true;
                          });

                          final repository = ref.read(groupRepositoryProvider);
                          final result = existingRule == null
                              ? await repository.createGroupRecurringRule(
                                  groupId: widget.groupId,
                                  memberId: selectedMemberId,
                                  type: type,
                                  amountPaisa: amountPaisa,
                                  categoryId: selectedCategoryId!,
                                  note: noteController.text,
                                  frequency: frequency,
                                  startDate: startDate,
                                  endDate: endDate,
                                )
                              : await repository.updateGroupRecurringRule(
                                  ruleId: existingRule.id,
                                  groupId: widget.groupId,
                                  memberId: selectedMemberId,
                                  type: type,
                                  amountPaisa: amountPaisa,
                                  categoryId: selectedCategoryId!,
                                  note: noteController.text,
                                  frequency: frequency,
                                  startDate: startDate,
                                  endDate: endDate,
                                );
                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _submitting = false;
                          });

                          await result.when(
                            success: (_) async {
                              navigator.pop(true);
                            },
                            failure: (message) async {
                              setSheetState(() {
                                validationError = message;
                              });
                            },
                          );
                        },
                  child: Text(existingRule == null ? 'Create' : 'Save'),
                ),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    noteController.dispose();

    if (sheetResult == true) {
      await _refreshRules();
    }
  }

  Future<void> _togglePaused(GroupRecurringRuleModel rule, bool paused) async {
    setState(() {
      _submitting = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .setGroupRecurringPaused(
          groupId: widget.groupId,
          ruleId: rule.id,
          paused: paused,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    await result.when(
      success: (_) async {
        await _refreshRules();
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _deleteRule(GroupRecurringRuleModel rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recurring rule?'),
          content: Text(
            'Delete ${rule.memberName} - ${rule.categoryName} recurring rule?',
          ),
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

    setState(() {
      _submitting = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .softDeleteGroupRecurringRule(groupId: widget.groupId, ruleId: rule.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    await result.when(
      success: (_) async {
        await _refreshRules();
      },
      failure: (message) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final recurringAsync = ref.watch(groupRecurringProvider(widget.groupId));
    final currencySymbol = ref.watch(currencySymbolProvider);

    final groupName = groupAsync.asData?.value.name ?? 'Group';
    final members = membersAsync.asData?.value ?? const <GroupMemberModel>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName Recurring'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _submitting ? null : _refreshRules,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRules,
        child: recurringAsync.when(
          data: (rules) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space12,
                AppTokens.space16,
                AppTokens.space16,
              ),
              children: <Widget>[
                const Text(
                  'Create and manage group recurring rules by member, category, and frequency.',
                ),
                const SizedBox(height: AppTokens.space12),
                if (members.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.space12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'No members found.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTokens.space6),
                          const Text(
                            'Add at least one member to create recurring rules.',
                          ),
                        ],
                      ),
                    ),
                  ),
                if (rules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTokens.space20),
                    child: Text('No recurring rules yet.'),
                  )
                else
                  ...rules.map((rule) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTokens.space12),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.space12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${rule.memberName} - ${rule.categoryName}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Switch(
                                  value: !rule.isPaused,
                                  onChanged: _submitting
                                      ? null
                                      : (value) async {
                                          await _togglePaused(rule, !value);
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.space4),
                            Text(
                              '${rule.type} - ${_frequencyLabel(rule.frequency)} - ${_formatAmountDisplay(rule.amountPaisa, currencySymbol)}',
                            ),
                            Text('Next due: ${_formatDate(rule.nextDueDate)}'),
                            if (rule.note.trim().isNotEmpty) Text(rule.note),
                            const SizedBox(height: AppTokens.space8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                          await _showRuleSheet(
                                            members: members,
                                            existingRule: rule,
                                          );
                                        },
                                  child: const Text('Edit'),
                                ),
                                const SizedBox(width: AppTokens.space8),
                                TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                          await _deleteRule(rule);
                                        },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            return ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Text(
                    error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitting
            ? null
            : () async {
                await _showRuleSheet(members: members);
              },
        tooltip: 'Add recurring rule',
        child: const Icon(Icons.add),
      ),
    );
  }
}

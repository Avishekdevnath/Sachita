import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_category_budget_model.dart';
import 'package:sanchita/features/groups/providers/group_budget_provider.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';

class GroupBudgetScreen extends ConsumerStatefulWidget {
  const GroupBudgetScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupBudgetScreen> createState() => _GroupBudgetScreenState();
}

class _GroupBudgetScreenState extends ConsumerState<GroupBudgetScreen> {
  late DateTime _activeMonth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activeMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  String _formatMoney(int paisa, String currencySymbol) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';
  }

  int? _parseToPaisa(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }
    final value = double.tryParse(normalized);
    if (value == null || value < 0) {
    // Defensive null return - validation failed
      return null;
    }
    return (value * 100).round();
  }

  Color _statusColor(GroupCategoryBudgetModel item) {
    if (item.exceeded) {
      return Colors.red;
    }
    if (item.reachedWarning80) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _statusText(GroupCategoryBudgetModel item) {
    if (item.monthlyLimitPaisa <= 0) {
      return 'No limit';
    }
    if (item.exceeded) {
      return 'Exceeded';
    }
    if (item.reachedWarning80) {
      return 'Warning 80%';
    }
    return 'Within budget';
  }

  Future<void> _editLimit(
    GroupCategoryBudgetModel item,
    String currencySymbol,
  ) async {
    final controller = TextEditingController(
      text: (item.monthlyLimitPaisa / 100).toStringAsFixed(2),
    );
    String? validationError;

    final newLimit = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set limit: ${item.categoryName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Monthly limit ($currencySymbol)',
                        hintText: 'e.g. 3000.00',
                      ),
                    ),
                    if (validationError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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
                    final parsed = _parseToPaisa(controller.text);
                    if (parsed == null) {
                      setDialogState(() {
                        validationError = 'Enter a valid non-negative amount.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newLimit == null) {
      return;
    }

    setState(() {
      _saving = true;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .upsertGroupBudget(
          groupId: widget.groupId,
          categoryId: item.categoryId,
          monthlyLimitPaisa: newLimit,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });

    await result.when(
      success: (_) async {
        ref.invalidate(
          groupBudgetProvider(
            GroupBudgetQuery(groupId: widget.groupId, month: _activeMonth),
          ),
        );
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
    final currencySymbol = ref.watch(currencySymbolProvider);
    final query = GroupBudgetQuery(
      groupId: widget.groupId,
      month: _activeMonth,
    );
    final budgetAsync = ref.watch(groupBudgetProvider(query));
    final monthLabel = DateFormat('MMMM yyyy').format(_activeMonth);
    final groupName = groupAsync.asData?.value.name ?? 'Group';

    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName Budgets'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Previous month',
            onPressed: () {
              setState(() {
                _activeMonth = DateTime(
                  _activeMonth.year,
                  _activeMonth.month - 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Center(child: Text(monthLabel)),
          IconButton(
            tooltip: 'Next month',
            onPressed: () {
              setState(() {
                _activeMonth = DateTime(
                  _activeMonth.year,
                  _activeMonth.month + 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupBudgetProvider(query));
        },
        child: budgetAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No expense categories found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final statusColor = _statusColor(item);
                final spentLabel = _formatMoney(
                  item.spentPaisa,
                  currencySymbol,
                );
                final limitLabel = item.monthlyLimitPaisa <= 0
                    ? 'Not set'
                    : _formatMoney(item.monthlyLimitPaisa, currencySymbol);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.categoryName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(38),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusText(item),
                                style: TextStyle(color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Spent: $spentLabel'),
                        Text('Limit: $limitLabel'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.usageRatio,
                          color: statusColor,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _editLimit(item, currencySymbol),
                            child: Text(
                              item.monthlyLimitPaisa <= 0
                                  ? 'Set Limit'
                                  : 'Edit Limit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            return ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
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
    );
  }
}

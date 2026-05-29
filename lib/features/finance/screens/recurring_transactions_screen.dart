import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/models/recurring_rule_model.dart';
import 'package:sanchita/features/finance/providers/recurring_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  ConsumerState<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends ConsumerState<RecurringTransactionsScreen> {
  static const List<String> _frequencies = <String>[
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  String _formatAmountNumber(int paisa) {
    return (paisa / 100).toStringAsFixed(2);
  }

  String _formatAmountDisplay(int paisa, String currencySymbol) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';
  }

  int? _parseToPaisa(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
    // Defensive null return - validation failed
      return null;
    }
    return (value * 100).round();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
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

  Future<void> _showCreateRuleDialog() async {
    await _showRuleSheet();
  }

  Future<void> _showEditRuleDialog(RecurringRuleModel rule) async {
    await _showRuleSheet(existingRule: rule);
  }

  Future<void> _showRuleSheet({RecurringRuleModel? existingRule}) async {
    final currencySymbol = ref.read(currencySymbolProvider);
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
    var categoriesFuture = _loadCategories(type);
    String? selectedCategoryId = existingRule?.categoryId;
    String? validationError;

    await AppModalSheet.show<void>(
      context: context,
      title: existingRule == null
          ? 'Create Recurring Rule'
          : 'Edit Recurring Rule',
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
                initialValue: frequency,
                items: _frequencies
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_frequencyLabel(value)),
                      ),
                    )
                    .toList(),
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
                  hintText: 'e.g. 1500.00',
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
                      'recurring-category-$type-${selectedCategoryId ?? 'none'}-${categories.length}',
                    ),
                    initialValue: selectedCategoryId,
                    items: categories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
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
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final amountPaisa = _parseToPaisa(amountController.text);
                    if (amountPaisa == null) {
                      setSheetState(() {
                        validationError = 'Enter a valid amount above zero.';
                      });
                      return;
                    }
                    if (selectedCategoryId == null) {
                      setSheetState(() {
                        validationError = 'Select a category.';
                      });
                      return;
                    }

                    final notifier = ref.read(recurringProvider.notifier);
                    final success = existingRule == null
                        ? await notifier.createRule(
                            type: type,
                            amountPaisa: amountPaisa,
                            categoryId: selectedCategoryId!,
                            note: noteController.text,
                            frequency: frequency,
                            startDate: startDate,
                            endDate: endDate,
                          )
                        : await notifier.updateRule(
                            ruleId: existingRule.id,
                            type: type,
                            amountPaisa: amountPaisa,
                            categoryId: selectedCategoryId!,
                            note: noteController.text,
                            frequency: frequency,
                            startDate: startDate,
                            endDate: endDate,
                          );

                    if (!context.mounted) {
                      return;
                    }

                    if (success) {
                      navigator.pop();
                    } else {
                      final message = ref
                          .read(recurringProvider)
                          .asData
                          ?.value
                          .errorMessage;
                      setSheetState(() {
                        validationError =
                            message ??
                            (existingRule == null
                                ? 'Could not create recurring rule.'
                                : 'Could not update recurring rule.');
                      });
                    }
                  },
                  child: Text(existingRule == null ? 'Create' : 'Save'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(RecurringRuleModel rule) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recurring rule?'),
          content: Text(
            'Delete ${rule.categoryName} ${_frequencyLabel(rule.frequency).toLowerCase()} rule?',
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

    return result == true;
  }

  Future<int?> _promptEditedAmount(RecurringRuleModel rule) async {
    final currencySymbol = ref.read(currencySymbolProvider);
    final controller = TextEditingController(
      text: _formatAmountNumber(rule.amountPaisa),
    );
    String? validationError;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Due Amount'),
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
                        labelText: 'Amount ($currencySymbol)',
                        hintText: 'e.g. 1500.00',
                      ),
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
                    final value = _parseToPaisa(controller.text);
                    if (value == null) {
                      setDialogState(() {
                        validationError = 'Enter a valid amount above zero.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final state = recurringAsync.asData?.value ?? const RecurringState();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(recurringProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRuleDialog,
        tooltip: 'New recurring rule',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(recurringProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: <Widget>[
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Text(
              'Due Approvals (${state.dueRules.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space8),
            if (recurringAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTokens.space12),
                child: LinearProgressIndicator(),
              )
            else if (state.dueRules.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: AppTokens.space12),
                child: Text('No due recurring approvals right now.'),
              )
            else
              ...state.dueRules.map((rule) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.space12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${rule.categoryName} - ${_formatAmountDisplay(rule.amountPaisa, currencySymbol)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppTokens.space4),
                        Text(
                          'Due ${_formatDate(rule.nextDueDate)} - ${_frequencyLabel(rule.frequency)}',
                        ),
                        if (rule.note.trim().isNotEmpty) Text(rule.note),
                        const SizedBox(height: AppTokens.space12),
                        Wrap(
                          spacing: AppTokens.space8,
                          runSpacing: AppTokens.space8,
                          children: <Widget>[
                            FilledButton(
                              onPressed: () {
                                ref
                                    .read(recurringProvider.notifier)
                                    .approveDueRule(rule: rule);
                              },
                              child: const Text('Approve'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                final editedAmount = await _promptEditedAmount(
                                  rule,
                                );
                                if (editedAmount == null) {
                                  return;
                                }
                                await ref
                                    .read(recurringProvider.notifier)
                                    .approveDueRule(
                                      rule: rule,
                                      editedAmountPaisa: editedAmount,
                                    );
                              },
                              child: const Text('Edit & Approve'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(recurringProvider.notifier)
                                    .skipDueRule(rule);
                              },
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppTokens.space8),
            Text('All Rules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTokens.space8),
            if (!recurringAsync.isLoading && state.rules.isEmpty)
              const Text('No recurring rules yet. Create your first rule.')
            else
              ...state.rules.map((rule) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.space12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${rule.categoryName} - ${_formatAmountDisplay(rule.amountPaisa, currencySymbol)}',
                      ),
                      subtitle: Text(
                        '${rule.isPaused ? 'Paused' : 'Active'} - ${_frequencyLabel(rule.frequency)} - Next due: ${_formatDate(rule.nextDueDate)}'
                        '${rule.note.trim().isEmpty ? '' : '\n${rule.note}'}',
                      ),
                      isThreeLine: rule.note.trim().isNotEmpty,
                      trailing: Wrap(
                        spacing: AppTokens.space6,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () {
                              _showEditRuleDialog(rule);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: rule.isPaused ? 'Resume' : 'Pause',
                            onPressed: () {
                              ref
                                  .read(recurringProvider.notifier)
                                  .togglePaused(rule);
                            },
                            icon: Icon(
                              rule.isPaused
                                  ? Icons.play_arrow_outlined
                                  : Icons.pause_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirmed = await _confirmDelete(rule);
                              if (!confirmed) {
                                return;
                              }
                              await ref
                                  .read(recurringProvider.notifier)
                                  .deleteRule(rule.id);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

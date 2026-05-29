import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/utils/finance_input_utils.dart';
import 'package:sanchita/features/finance/widgets/finance_balance_card.dart';
import 'package:sanchita/features/groups/data/group_repository.dart';
import 'package:sanchita/features/groups/models/group_finance_transaction_model.dart';
import 'package:sanchita/features/groups/models/group_member_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/groups/providers/group_members_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';
import 'package:sanchita/shared/widgets/empty_state_widget.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';
import 'package:sanchita/shared/widgets/money_amount_text.dart';
import 'package:sanchita/shared/widgets/month_switcher.dart';

enum _GroupFinanceView { individual, combined }

class GroupFinanceScreen extends ConsumerStatefulWidget {
  const GroupFinanceScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupFinanceScreen> createState() => _GroupFinanceScreenState();
}

class _GroupFinanceScreenState extends ConsumerState<GroupFinanceScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late final ProviderSubscription<AsyncValue<List<GroupMemberModel>>>
  _memberSubscription;

  _GroupFinanceView _viewMode = _GroupFinanceView.individual;
  DateTime _activeMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _activeType = 'expense';

  String? _selectedMemberId;
  String? _entryMemberId;
  String? _selectedCategoryId;

  List<CategoryModel> _categories = const <CategoryModel>[];
  List<GroupFinanceTransactionModel> _transactions =
      const <GroupFinanceTransactionModel>[];

  int _netBalancePaisa = 0;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _memberSubscription = ref.listenManual<AsyncValue<List<GroupMemberModel>>>(
      groupMembersProvider(widget.groupId),
      (previous, next) {
        final members = next.asData?.value;
        if (members == null) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }

          await _loadTransactions(members: members);
        });
      },
    );
    _reload();
  }

  @override
  void dispose() {
    _memberSubscription.close();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatAmount({required int paisa, required String currencySymbol}) {
    return FinanceInputUtils.formatFromPaisa(
      paisa: paisa,
      currencySymbol: currencySymbol,
    );
  }

  int? _parseToPaisa(String raw) {
    final localeCode = Localizations.localeOf(context).toLanguageTag();
    return FinanceInputUtils.parseAmountToPaisa(
      raw,
      localeCode: localeCode,
    );
  }

  bool _canAddTransaction({
    required bool hasMembers,
    required List<GroupMemberModel> members,
  }) {
    if (_saving || !hasMembers) {
      return false;
    }

    final amountPaisa = _parseToPaisa(_amountController.text);
    if (amountPaisa == null || amountPaisa <= 0) {
      return false;
    }

    final categoryId = _selectedCategoryId?.trim();
    if (categoryId == null || categoryId.isEmpty) {
      return false;
    }

    final memberId = _effectiveEntryMemberId(members)?.trim();
    return memberId != null && memberId.isNotEmpty;
  }

  String? _effectiveFilterMemberId(List<GroupMemberModel> members) {
    if (_viewMode == _GroupFinanceView.combined) {
    // Defensive null return - validation failed
      return null;
    }

    final selected = _selectedMemberId?.trim();
    if (selected != null && selected.isNotEmpty) {
      for (final member in members) {
        if (member.id == selected) {
          return selected;
        }
      }
    }

    if (members.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    return members.first.id;
  }

  String? _effectiveEntryMemberId(List<GroupMemberModel> members) {
    if (members.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    if (_viewMode == _GroupFinanceView.individual) {
      return _effectiveFilterMemberId(members);
    }

    final selected = _entryMemberId?.trim();
    if (selected != null && selected.isNotEmpty) {
      for (final member in members) {
        if (member.id == selected) {
          return selected;
        }
      }
    }

    return members.first.id;
  }

  Future<void> _reload() async {
    await _loadCategories();
    await _loadTransactions();
  }

  Future<void> _loadCategories() async {
    final result = await ref
        .read(categoryRepositoryProvider)
        .getCategoriesByType(_activeType);

    if (!mounted) {
      return;
    }

    result.when(
      success: (categories) {
        final preferred = _selectedCategoryId;
        final selected = categories.any((item) => item.id == preferred)
            ? preferred
            : (categories.isEmpty ? null : categories.first.id);
        setState(() {
          _categories = categories;
          _selectedCategoryId = selected;
        });
      },
      failure: (message) {
        setState(() {
          _categories = const <CategoryModel>[];
          _selectedCategoryId = null;
          _errorMessage = message;
        });
      },
    );
  }

  Future<void> _loadTransactions({List<GroupMemberModel>? members}) async {
    final resolvedMembers =
        members ??
        ref.read(groupMembersProvider(widget.groupId)).asData?.value ??
            const <GroupMemberModel>[];

    final filterMemberId = _effectiveFilterMemberId(resolvedMembers);

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final transactionResult = await ref
        .read(groupRepositoryProvider)
        .getGroupTransactionsForMonth(
          groupId: widget.groupId,
          month: _activeMonth,
          memberId: filterMemberId,
          type: _activeType,
        );
    final netResult = await ref
        .read(groupRepositoryProvider)
        .getGroupNetBalanceForMonth(
          groupId: widget.groupId,
          month: _activeMonth,
          memberId: filterMemberId,
        );

    if (!mounted) {
      return;
    }

    final transactions = transactionResult.when(
      success: (items) => items,
      failure: (_) => const <GroupFinanceTransactionModel>[],
    );
    final net = netResult.when(success: (value) => value, failure: (_) => 0);

    final transactionError = transactionResult.when<String?>(
      success: (_) => null,
      failure: (message) => message,
    );
    final netError = netResult.when<String?>(
      success: (_) => null,
      failure: (message) => message,
    );

    final entryMemberId = _effectiveEntryMemberId(resolvedMembers);

    setState(() {
      _transactions = transactions;
      _netBalancePaisa = net;
      _loading = false;
      _errorMessage = transactionError ?? netError;
      _selectedMemberId = filterMemberId;
      _entryMemberId = entryMemberId;
    });
  }

  Future<void> _changeViewMode(_GroupFinanceView viewMode) async {
    setState(() {
      _viewMode = viewMode;
    });
    await _loadTransactions();
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _activeMonth = DateTime(_activeMonth.year, _activeMonth.month + delta);
    });
    await _loadTransactions();
  }

  Future<void> _changeType(String type) async {
    if (_activeType == type) {
      return;
    }

    setState(() {
      _activeType = type;
    });
    await _loadCategories();
    await _loadTransactions();
  }

  Future<void> _addTransaction(List<GroupMemberModel> members) async {
    if (_saving) {
      return;
    }

    final amountPaisa = _parseToPaisa(_amountController.text);
    final categoryId = _selectedCategoryId;
    final memberId = _effectiveEntryMemberId(members);

    if (amountPaisa == null || amountPaisa <= 0) {
      setState(() {
        _errorMessage = 'Enter a valid amount greater than zero.';
      });
      return;
    }

    if (categoryId == null || categoryId.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Select a category before adding transaction.';
      });
      return;
    }

    if (memberId == null || memberId.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Select a member before adding transaction.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(groupRepositoryProvider)
        .addGroupTransaction(
          groupId: widget.groupId,
          memberId: memberId,
          type: _activeType,
          amountPaisa: amountPaisa,
          categoryId: categoryId,
          note: _noteController.text,
          date: DateTime.now(),
        );

    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        _amountController.clear();
        _noteController.clear();
        setState(() {
          _saving = false;
        });
        await _loadTransactions(members: members);
      },
      failure: (message) async {
        setState(() {
          _saving = false;
          _errorMessage = message;
        });
      },
    );
  }

  Future<bool> _confirmDelete(GroupFinanceTransactionModel item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: Text(
            item.note.isEmpty
                ? 'Delete this group transaction from active history?'
                : 'Delete "${item.note}" from active history?',
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

  Future<void> _deleteTransaction(GroupFinanceTransactionModel item) async {
    final result = await ref
        .read(groupRepositoryProvider)
        .softDeleteGroupTransaction(
          groupId: widget.groupId,
          transactionId: item.id,
        );

    if (!mounted) {
      return;
    }

    await result.when(
      success: (_) async {
        await _loadTransactions();
      },
      failure: (message) async {
        setState(() {
          _errorMessage = message;
        });
      },
    );
  }

  Map<String, List<GroupFinanceTransactionModel>> _groupByDate(
    List<GroupFinanceTransactionModel> transactions,
  ) {
    final grouped = <String, List<GroupFinanceTransactionModel>>{};
    for (final item in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(item.date);
      grouped.putIfAbsent(key, () => <GroupFinanceTransactionModel>[]).add(item);
    }
    return grouped;
  }

  void _showEntrySheet({
    required List<GroupMemberModel> members,
    required bool hasMembers,
  }) {
    final effectiveEntryMemberId = _effectiveEntryMemberId(members);

    AppModalSheet.show(
      context: context,
      title: 'Add ${_activeType == 'income' ? 'Income' : 'Expense'}',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final canAdd = _canAddTransaction(
            hasMembers: hasMembers,
            members: members,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'e.g. 1500.50',
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: _noteController,
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
              if (_categories.length <= 8)
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: _categories.map((item) {
                    return ChoiceChip(
                      label: Text(item.name),
                      selected: _selectedCategoryId == item.id,
                      onSelected: (selected) {
                        if (!selected) {
                          return;
                        }
                        setState(() {
                          _selectedCategoryId = item.id;
                        });
                        setSheetState(() {});
                      },
                    );
                  }).toList(growable: false),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'group_category_${_activeType}_${_selectedCategoryId ?? 'none'}',
                  ),
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                    setSheetState(() {});
                  },
                ),
              const SizedBox(height: AppTokens.space12),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('entry_member_$effectiveEntryMemberId'),
                initialValue: effectiveEntryMemberId,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: members
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: hasMembers
                    ? (value) {
                        setState(() {
                          _entryMemberId = value;
                        });
                        setSheetState(() {});
                      }
                    : null,
              ),
              const SizedBox(height: AppTokens.space16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canAdd
                      ? () async {
                          final nav = Navigator.of(context);
                          await _addTransaction(members);
                          if (mounted) {
                            nav.pop();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(_saving ? 'Adding...' : 'Add Transaction'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space12,
        ),
      ),
      icon: Icon(icon, size: AppTokens.iconSm),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTopPanel({
    required List<GroupMemberModel> members,
    required bool hasMembers,
    required String? effectiveFilterMemberId,
    required String? effectiveEntryMemberId,
    required String currencySymbol,
  }) {
    final monthLabel = DateFormat('MMMM yyyy').format(_activeMonth);
    final canAdd = _canAddTransaction(hasMembers: hasMembers, members: members);
    final netBalanceText = _formatAmount(
      paisa: _netBalancePaisa,
      currencySymbol: currencySymbol,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        0,
      ),
      child: Column(
        children: <Widget>[
          Card(
            child: MonthSwitcher(
              monthLabel: monthLabel,
              onPrevious: () {
                _changeMonth(-1);
              },
              onNext: () {
                _changeMonth(1);
              },
              onRefresh: _reload,
              compact: true,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          SegmentedButton<_GroupFinanceView>(
            segments: const <ButtonSegment<_GroupFinanceView>>[
              ButtonSegment<_GroupFinanceView>(
                value: _GroupFinanceView.individual,
                icon: Icon(Icons.person_outline),
                label: Text('Individual'),
              ),
              ButtonSegment<_GroupFinanceView>(
                value: _GroupFinanceView.combined,
                icon: Icon(Icons.groups_outlined),
                label: Text('Combined'),
              ),
            ],
            selected: <_GroupFinanceView>{_viewMode},
            onSelectionChanged: (selection) {
              _changeViewMode(selection.first);
            },
          ),
          if (_viewMode == _GroupFinanceView.individual) ...<Widget>[
            const SizedBox(height: AppTokens.space12),
            hasMembers
                ? DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'filter_member_$effectiveFilterMemberId',
                    ),
                    initialValue: effectiveFilterMemberId,
                    decoration: const InputDecoration(labelText: 'Viewing member'),
                    items: members
                        .map(
                          (member) => DropdownMenuItem<String>(
                            value: member.id,
                            child: Text(member.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) async {
                      setState(() {
                        _selectedMemberId = value;
                      });
                      await _loadTransactions(members: members);
                    },
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.space12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'No members found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTokens.space6),
                          const Text(
                            'Add members first to use individual group finance.',
                          ),
                          const SizedBox(height: AppTokens.space12),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              context.push(RoutePaths.groupsMembers(widget.groupId));
                            },
                            icon: const Icon(Icons.people_outline),
                            label: const Text('Manage Members'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
          const SizedBox(height: AppTokens.space12),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'income',
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment<String>(
                value: 'expense',
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward),
              ),
            ],
            selected: <String>{_activeType},
            onSelectionChanged: (selection) {
              _changeType(selection.first);
            },
          ),
          const SizedBox(height: AppTokens.space12),
          FinanceBalanceCard(
            balanceLabel: 'Group net balance',
            balanceText: netBalanceText,
          ),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Quick Entry',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.space12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'e.g. 1500.50',
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                if (_categories.length <= 8)
                  Wrap(
                    spacing: AppTokens.space8,
                    runSpacing: AppTokens.space8,
                    children: _categories.map((item) {
                      return ChoiceChip(
                        label: Text(item.name),
                        selected: _selectedCategoryId == item.id,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          setState(() {
                            _selectedCategoryId = item.id;
                          });
                        },
                      );
                    }).toList(growable: false),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'group_category_${_activeType}_${_selectedCategoryId ?? 'none'}',
                    ),
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                const SizedBox(height: AppTokens.space8),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>('entry_member_$effectiveEntryMemberId'),
                  initialValue: effectiveEntryMemberId,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: members
                      .map(
                        (member) => DropdownMenuItem<String>(
                          value: member.id,
                          child: Text(member.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: hasMembers
                      ? (value) {
                          setState(() {
                            _entryMemberId = value;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: AppTokens.space12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canAdd
                        ? () {
                            _addTransaction(members);
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(_saving ? 'Adding...' : 'Add Transaction'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final halfWidth = (constraints.maxWidth - AppTokens.space8) / 2;
                return Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: <Widget>[
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : halfWidth,
                      child: _buildQuickActionButton(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Budgets',
                        onPressed: () {
                          context.push(
                            RoutePaths.groupsFinanceBudgets(widget.groupId),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : halfWidth,
                      child: _buildQuickActionButton(
                        icon: Icons.autorenew_outlined,
                        label: 'Recurring',
                        onPressed: () {
                          context.push(
                            RoutePaths.groupsFinanceRecurring(widget.groupId),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: _buildQuickActionButton(
                        icon: Icons.pie_chart_outline,
                        label: 'Member Breakdown',
                        onPressed: () {
                          context.push(
                            RoutePaths.groupsFinanceBreakdown(widget.groupId),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: AppTokens.space8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const Divider(height: AppTokens.space16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final members = membersAsync.asData?.value ?? const <GroupMemberModel>[];
    final currencySymbol = ref.watch(currencySymbolProvider);

    final groupName = groupAsync.asData?.value.name ?? 'Group';
    final hasMembers = members.isNotEmpty;

    final effectiveFilterMemberId = _effectiveFilterMemberId(members);
    final effectiveEntryMemberId = _effectiveEntryMemberId(members);

    final groupedTransactions = _groupByDate(_transactions);
    final sections = groupedTransactions.entries.toList(growable: false)
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName Finance'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Manage members',
            onPressed: () {
              context.push(RoutePaths.groupsMembers(widget.groupId));
            },
            icon: const Icon(Icons.people_outline),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: hasMembers
            ? () => _showEntrySheet(members: members, hasMembers: hasMembers)
            : null,
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _buildTopPanel(
                  members: members,
                  hasMembers: hasMembers,
                  effectiveFilterMemberId: effectiveFilterMemberId,
                  effectiveEntryMemberId: effectiveEntryMemberId,
                  currencySymbol: currencySymbol,
                ),
              ),
              if (_loading && _transactions.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      0,
                      AppTokens.space16,
                      AppTokens.space8,
                    ),
                    child: LinearProgressIndicator(),
                  ),
                ),
              if (_loading && _transactions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No group transactions this month',
                    subtitle:
                        'Tap + to add the first group transaction.',
                    action: !hasMembers
                        ? FilledButton.tonal(
                            onPressed: () {
                              context.push(RoutePaths.groupsMembers(widget.groupId));
                            },
                            child: const Text('Add Members First'),
                          )
                        : null,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final section = sections[index];
                    final headerDate =
                        DateTime.tryParse(section.key) ?? DateTime.now();
                    final headerLabel = DateFormat(
                      'EEEE, dd MMM yyyy',
                    ).format(headerDate);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.space16,
                            AppTokens.space12,
                            AppTokens.space16,
                            AppTokens.space4,
                          ),
                          child: Text(
                            headerLabel,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        ...section.value.map((item) {
                          final amount = _formatAmount(
                            paisa: item.amountPaisa,
                            currencySymbol: currencySymbol,
                          );
                          final signedAmount = item.type == 'income'
                              ? '+$amount'
                              : '-$amount';
                          final subtitleParts = <String>[
                            item.categoryName,
                            DateFormat('dd MMM').format(item.date),
                          ];
                          if (_viewMode == _GroupFinanceView.combined) {
                            subtitleParts.insert(0, item.memberName);
                          }

                          return Dismissible(
                            key: ValueKey<String>('group_tx_${item.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) {
                              return _confirmDelete(item);
                            },
                            onDismissed: (_) {
                              _deleteTransaction(item);
                            },
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(
                                right: AppTokens.space20,
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.space16,
                                vertical: AppTokens.space2,
                              ),
                              title: Text(
                                item.note.isEmpty ? item.categoryName : item.note,
                              ),
                              subtitle: Text(subtitleParts.join(' - ')),
                              trailing: MoneyAmountText(
                                amountText: signedAmount,
                                semanticLabel:
                                    '${item.type == 'income' ? 'Income' : 'Expense'} amount $signedAmount',
                                color: item.type == 'income'
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }, childCount: sections.length),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTokens.space16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

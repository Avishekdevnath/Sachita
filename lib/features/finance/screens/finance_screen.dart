import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/dashboard/providers/dashboard_provider.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/finance/utils/finance_input_utils.dart';
import 'package:sanchita/features/finance/utils/finance_transaction_view_filter.dart';
import 'package:sanchita/features/finance/widgets/finance_balance_card.dart';
import 'package:sanchita/features/finance/widgets/finance_empty_states.dart';
import 'package:sanchita/features/finance/widgets/finance_filter_sheet_content.dart';
import 'package:sanchita/features/finance/widgets/finance_header_bar.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_deleted_snackbar.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_form_content.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_section_list.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_view_tabs.dart';
import 'package:sanchita/features/quotes/providers/finance_quote_provider.dart';
import 'package:sanchita/features/quotes/services/finance_quote_situation_detector.dart';
import 'package:sanchita/features/quotes/utils/finance_quote_situation.dart';
import 'package:sanchita/features/quotes/widgets/finance_quote_sheet.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';
import 'package:sanchita/shared/widgets/money_amount_text.dart';
import 'package:sanchita/shared/widgets/skeleton_loader.dart';

enum _FinanceMenuAction { summary, budget, recurring }

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final Map<String, String> _lastUsedNoteByType = <String, String>{};
  final Map<String, String> _lastUsedCategoryByType = <String, String>{};

  FinanceState? _lastKnownState;
  DateTime _composerDate = DateTime.now();
  String _transactionView = 'all';
  String _composerType = 'expense';

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Removed text controller listeners that caused full screen rebuilds.
    // Form state updates now only rebuild the modal (via setSheetState), not the main screen.
  }

  String _formatAmount({required int paisa, required String currencySymbol}) {
    return FinanceInputUtils.formatFromPaisa(
      paisa: paisa,
      currencySymbol: currencySymbol,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  int? _parseToPaisa(String raw) {
    final localeCode = Localizations.localeOf(context).toLanguageTag();
    return FinanceInputUtils.parseAmountToPaisa(raw, localeCode: localeCode);
  }

  Future<void> _submitEntry(FinanceState state) async {
    final selectedCategory = state.selectedCategory;
    final amountPaisa = _parseToPaisa(_amountController.text);
    if (amountPaisa == null || amountPaisa <= 0 || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid amount and select a category.'),
        ),
      );
      return;
    }

    final wasFirstTransaction = state.transactions.isEmpty;
    final transactionType = state.activeType;
    final categoryName = selectedCategory.name;

    await ref
        .read(financeProvider.notifier)
        .addTransaction(
          amountPaisa: amountPaisa,
          categoryId: selectedCategory.id,
          note: _noteController.text,
          date: _composerDate,
        );

    _lastUsedCategoryByType[state.activeType] = selectedCategory.id;
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      _lastUsedNoteByType[state.activeType] = note;
    }

    _amountController.clear();
    _noteController.clear();

    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop();
      final situation =
          FinanceQuoteSituationDetector.detectTransactionAddedSituation(
            wasFirstTransaction: wasFirstTransaction,
            transactionType: transactionType,
            categoryName: categoryName,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showFinanceQuote(situation);
        }
      });
    }
  }

  bool _canSubmitEntry(FinanceState state) {
    final amountPaisa = _parseToPaisa(_amountController.text);
    if (amountPaisa == null || amountPaisa <= 0) {
      return false;
    }
    return state.selectedCategory != null;
  }

  String? _amountValidationMessage() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) {
      // Defensive null return - validation failed
      return null;
    }

    final amountPaisa = _parseToPaisa(raw);
    if (amountPaisa == null) {
      return 'Invalid amount format.';
    }

    if (amountPaisa <= 0) {
      return 'Amount must be greater than zero.';
    }

    // Defensive null return - validation failed
    return null;
  }

  Future<void> _pickComposerDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _composerDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _composerDate = selected;
    });
  }

  void _setComposerToday() {
    setState(() {
      final now = DateTime.now();
      _composerDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _reuseLastNoteForType(String activeType) {
    final note = _lastUsedNoteByType[activeType];
    if (note == null || note.trim().isEmpty) {
      return;
    }

    _noteController.text = note;
    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
  }

  Future<void> _changeTypeWithSessionMemory(String type) async {
    await ref.read(financeProvider.notifier).changeType(type);
    if (!mounted) {
      return;
    }

    final stateAfterTypeChange = ref.read(financeProvider).asData?.value;
    if (stateAfterTypeChange == null) {
      return;
    }

    final rememberedCategoryId = _lastUsedCategoryByType[type];
    if (rememberedCategoryId != null) {
      for (final category in stateAfterTypeChange.categories) {
        if (category.id == rememberedCategoryId) {
          ref
              .read(financeProvider.notifier)
              .selectCategory(rememberedCategoryId);
          break;
        }
      }
    }

    if (_noteController.text.trim().isEmpty) {
      final rememberedNote = _lastUsedNoteByType[type];
      if (rememberedNote != null && rememberedNote.trim().isNotEmpty) {
        _noteController.text = rememberedNote;
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
      }
    }
  }

  Future<void> _changeTransactionView(String view) async {
    setState(() {
      _transactionView = view;
    });

    if (view == 'income' || view == 'expense') {
      await _changeTypeWithSessionMemory(view);
    }
  }

  void _showDeletedSnackBar(TransactionModel item) {
    showTransactionDeletedSnackBar(
      messenger: ScaffoldMessenger.of(context),
      onUndo: () async {
        await ref.read(financeProvider.notifier).restoreTransaction(item.id);
      },
    );
  }

  /// Shows a short finance insight after the add sheet has closed.
  Future<void> _showFinanceQuote(FinanceQuoteSituation situation) async {
    final quote = await ref
        .read(financeQuoteControllerProvider)
        .quoteForSituation(situation);
    if (!mounted || quote == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return FinanceQuoteSheet(
          quote: quote,
          onAction: () {
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  /// Build category ID to name map for efficient lookup.
  Map<String, String> _buildCategoryMap(FinanceState state) {
    final categories = state.allCategories.isEmpty
        ? state.categories
        : state.allCategories;
    return {for (final category in categories) category.id: category.name};
  }

  String _getCategoryName(String categoryId, Map<String, String> categoryMap) {
    return categoryMap[categoryId] ?? 'Unknown';
  }

  Widget _buildTransactionTile({
    required FinanceState state,
    required TransactionModel item,
    required String currencySymbol,
    required BuildContext context,
    required Map<String, String> categoryMap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _formatAmount(
      paisa: item.amountPaisa,
      currencySymbol: currencySymbol,
    );
    final dateLabel = DateFormat('dd MMM').format(item.date);
    final categoryName = _getCategoryName(item.categoryId, categoryMap);

    final isIncome = item.type == 'income';
    final iconColor = isIncome ? colorScheme.tertiary : colorScheme.error;
    final iconBg = isIncome
        ? colorScheme.tertiary.withValues(alpha: 0.12)
        : colorScheme.error.withValues(alpha: 0.10);

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await ref.read(financeProvider.notifier).deleteTransaction(item.id);
        if (mounted) {
          _showDeletedSnackBar(item);
        }
      },
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.space20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.financeTransaction(item.id)),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space4,
            vertical: AppTokens.space10,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(
                  isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  size: AppTokens.iconSm,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.note.isEmpty ? categoryName : item.note,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      '$categoryName • $dateLabel',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              MoneyAmountText(
                amountText: amount,
                semanticLabel:
                    '${isIncome ? 'Income' : 'Expense'} amount $amount',
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(FinanceState state, _FinanceMenuAction action) {
    switch (action) {
      case _FinanceMenuAction.summary:
        context.push(RoutePaths.financeSummary(state.activeMonth));
        return;
      case _FinanceMenuAction.budget:
        context.push(RoutePaths.financeBudget);
        return;
      case _FinanceMenuAction.recurring:
        context.push(RoutePaths.financeRecurring);
        return;
    }
  }

  Future<void> _showComposerSheet() async {
    if (_transactionView == 'income' || _transactionView == 'expense') {
      _composerType = _transactionView;
    }

    final currentState = ref.read(financeProvider).asData?.value;
    if (currentState != null && currentState.activeType != _composerType) {
      await _changeTypeWithSessionMemory(_composerType);
    }

    if (!mounted) {
      return;
    }

    final initialState =
        ref.read(financeProvider).asData?.value ?? _lastKnownState;
    if (initialState == null) {
      return;
    }

    final showTypeToggle = _transactionView == 'all';
    final initialTitleType = _composerType == 'income' ? 'Income' : 'Expense';

    AppModalSheet.show(
      context: context,
      title: showTypeToggle ? 'Add Transaction' : 'Add $initialTitleType',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final financeAsync = ref.read(financeProvider);
          final state =
              financeAsync.asData?.value ?? _lastKnownState ?? initialState;
          final canSubmit = _canSubmitEntry(state);
          final submitType = _composerType == 'income' ? 'Income' : 'Expense';

          return FinanceTransactionFormContent(
            amountController: _amountController,
            noteController: _noteController,
            amountFocusNode: _amountFocusNode,
            categories: state.categories,
            selectedCategoryId: state.selectedCategory?.id,
            activeType: _composerType,
            entryDate: _composerDate,
            isBusy: financeAsync.isLoading,
            canSubmit: canSubmit,
            submitLabel: 'Add $submitType',
            showTypeToggle: showTypeToggle,
            onTypeChanged: (type) async {
              _composerType = type;
              await _changeTypeWithSessionMemory(type);
              if (mounted) {
                setSheetState(() {});
              }
            },
            amountErrorText: _amountValidationMessage(),
            lastUsedNote: _lastUsedNoteByType[_composerType],
            onReuseLastNote: () {
              _reuseLastNoteForType(_composerType);
              setSheetState(() {});
            },
            onCategoryChanged: (value) {
              ref.read(financeProvider.notifier).selectCategory(value);
              setSheetState(() {});
            },
            onPickDate: () async {
              await _pickComposerDate();
              if (mounted) {
                setSheetState(() {});
              }
            },
            onSetToday: () {
              _setComposerToday();
              setSheetState(() {});
            },
            onFormChanged: () {
              setSheetState(() {});
            },
            onSubmit: () async {
              final submitState =
                  ref.read(financeProvider).asData?.value ?? state;
              await _submitEntry(submitState);
            },
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    AppModalSheet.show(
      context: context,
      title: 'Filter Transactions',
      child: const FinanceFilterSheetContent(),
      initialChildSize: 0.86,
      minChildSize: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeAsync = ref.watch(financeProvider);
    final liveState = financeAsync.asData?.value;
    if (liveState != null) {
      _lastKnownState = liveState;
    }

    final state =
        liveState ??
        _lastKnownState ??
        FinanceState(
          activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
        );

    final currencySymbol = ref.watch(currencySymbolProvider);
    final dashboardState = ref.watch(dashboardProvider).asData?.value;
    final monthLabel = DateFormat('MMMM yyyy').format(state.activeMonth);
    final netDisplay = _formatAmount(
      paisa: state.netBalancePaisa,
      currencySymbol: currencySymbol,
    );
    final incomeDisplay = _formatAmount(
      paisa: state.monthlyIncomePaisa,
      currencySymbol: currencySymbol,
    );
    final expenseDisplay = _formatAmount(
      paisa: state.monthlyExpensePaisa,
      currencySymbol: currencySymbol,
    );
    // All-time totals from dashboard (for Monthly/Total toggle)
    final totalNetPaisa = dashboardState?.netBalancePaisa;
    final totalIncomeDisplay = dashboardState != null
        ? _formatAmount(paisa: dashboardState.allTimeIncomePaisa, currencySymbol: currencySymbol)
        : null;
    final totalExpenseDisplay = dashboardState != null
        ? _formatAmount(paisa: dashboardState.allTimeExpensePaisa, currencySymbol: currencySymbol)
        : null;
    final activeFilterCount = state.filters.activeCount;
    final groupedTransactions = ref.watch(financeGroupedTransactionsProvider);
    final sections = groupedTransactions
        .map(
          (group) =>
              FinanceTransactionSection(date: group.date, items: group.items),
        )
        .toList(growable: false);
    final visibleSections = filterFinanceTransactionSections(
      sections: sections,
      view: _transactionView,
    );

    // OPTIMIZATION: Build category map once for O(1) lookups in list items
    final categoryMap = _buildCategoryMap(state);

    final showInitialLoader =
        financeAsync.isLoading &&
        _lastKnownState == null &&
        state.transactions.isEmpty;
    final showRefreshBar = financeAsync.isLoading && _lastKnownState != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: <Widget>[
          PopupMenuButton<_FinanceMenuAction>(
            tooltip: 'More',
            onSelected: (action) {
              _handleMenuAction(state, action);
            },
            itemBuilder: (context) =>
                const <PopupMenuEntry<_FinanceMenuAction>>[
                  PopupMenuItem<_FinanceMenuAction>(
                    value: _FinanceMenuAction.summary,
                    child: Text('Monthly Summary'),
                  ),
                  PopupMenuItem<_FinanceMenuAction>(
                    value: _FinanceMenuAction.budget,
                    child: Text('Budget Management'),
                  ),
                  PopupMenuItem<_FinanceMenuAction>(
                    value: _FinanceMenuAction.recurring,
                    child: Text('Recurring Rules'),
                  ),
                ],
          ),
          const SizedBox(width: AppTokens.space8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showComposerSheet();
        },
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(financeProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space12,
                  AppTokens.space16,
                  AppTokens.space8,
                ),
                child: Column(
                  children: <Widget>[
                    FinanceHeaderBar(
                      monthLabel: monthLabel,
                      activeFilterCount: activeFilterCount,
                      onPreviousMonth: () {
                        ref
                            .read(financeProvider.notifier)
                            .changeMonth(
                              DateTime(
                                state.activeMonth.year,
                                state.activeMonth.month - 1,
                              ),
                            );
                      },
                      onNextMonth: () {
                        ref
                            .read(financeProvider.notifier)
                            .changeMonth(
                              DateTime(
                                state.activeMonth.year,
                                state.activeMonth.month + 1,
                              ),
                            );
                      },
                      onFilterTap: () {
                        _showFilterSheet();
                      },
                    ),
                    const SizedBox(height: AppTokens.space12),
                    FinanceBalanceCard(
                      balanceLabel: 'This month net balance',
                      balancePaisa: state.netBalancePaisa,
                      currencySymbol: currencySymbol,
                      balanceText: netDisplay,
                      incomeText: incomeDisplay,
                      expenseText: expenseDisplay,
                      totalNetBalancePaisa: totalNetPaisa,
                      totalIncomeText: totalIncomeDisplay,
                      totalExpenseText: totalExpenseDisplay,
                    ),
                    const SizedBox(height: AppTokens.space12),
                    FinanceTransactionViewTabs(
                      selectedView: _transactionView,
                      onChanged: _changeTransactionView,
                    ),
                    if (state.filters.hasAny) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space12,
                            vertical: AppTokens.space8,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Active filters: ${state.filters.activeCount}',
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(financeProvider.notifier)
                                      .clearFilters();
                                },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (showRefreshBar) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            if (showInitialLoader)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space12,
                  ),
                  child: SkeletonList(itemCount: 5, itemHeight: 80),
                ),
              )
            else if (sections.isEmpty)
              state.filters.hasAny
                  ? FinanceNoFilterResultsEmptyState(
                      onClearFiltersTap: () {
                        ref.read(financeProvider.notifier).clearFilters();
                      },
                    )
                  : FinanceNoTransactionsEmptyState(
                      onAddFirstTap: () {
                        _showComposerSheet();
                      },
                    )
            else if (visibleSections.isEmpty)
              FinanceNoTransactionsForTypeEmptyState(
                typeLabel: _transactionView,
              )
            else
              FinanceTransactionSectionSliver(
                sections: visibleSections,
                itemBuilder: (context, item) {
                  return _buildTransactionTile(
                    state: state,
                    item: item,
                    currencySymbol: currencySymbol,
                    context: context,
                    categoryMap: categoryMap,
                  );
                },
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96 + MediaQuery.of(context).viewInsets.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

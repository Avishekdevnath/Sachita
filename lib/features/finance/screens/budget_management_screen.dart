import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/features/finance/models/category_budget_model.dart';
import 'package:sanchita/features/finance/providers/budget_management_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/skeleton_loader.dart';

enum _BudgetMenuAction { transactions, summary, recurring }

class BudgetManagementScreen extends ConsumerStatefulWidget {
  const BudgetManagementScreen({super.key});

  @override
  ConsumerState<BudgetManagementScreen> createState() =>
      _BudgetManagementScreenState();
}

class _BudgetManagementScreenState
    extends ConsumerState<BudgetManagementScreen> {

  int? _parseToPaisa(String raw) {
    final n = raw.replaceAll(',', '').trim();
    if (n.isEmpty) return null;
    final v = double.tryParse(n);
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }

  void _onMenuAction(_BudgetMenuAction action) {
    switch (action) {
      case _BudgetMenuAction.transactions:
        context.pop();
      case _BudgetMenuAction.summary:
        context.pop();
        final now = DateTime.now();
        context.push(RoutePaths.financeSummary(DateTime(now.year, now.month)));
      case _BudgetMenuAction.recurring:
        context.pop();
        context.push(RoutePaths.financeRecurring);
    }
  }

  Future<void> _editLimit(
      CategoryBudgetModel item, String currencySymbol) async {
    final controller = TextEditingController(
      text: item.monthlyLimitPaisa > 0
          ? (item.monthlyLimitPaisa / 100).toStringAsFixed(2)
          : '',
    );
    String? error;

    final newLimit = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('Set limit: ${item.categoryName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly limit ($currencySymbol)',
                  hintText: 'e.g. 5000.00',
                ),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: AppTokens.space8),
                Text(error!,
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 12)),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parseToPaisa(controller.text);
                if (parsed == null) {
                  setDs(() => error = 'Enter a valid non-negative amount.');
                  return;
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (newLimit == null) return;
    await ref.read(budgetManagementProvider.notifier).setMonthlyLimit(
          categoryId: item.categoryId,
          monthlyLimitPaisa: newLimit,
        );
  }

  @override
  Widget build(BuildContext context) {
    final budgetAsync = ref.watch(budgetManagementProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final state = budgetAsync.asData?.value ??
        BudgetManagementState(
          activeMonth: DateTime(DateTime.now().year, DateTime.now().month),
        );
    final monthLabel = DateFormat('MMM yyyy').format(state.activeMonth);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        actions: <Widget>[
          PopupMenuButton<_BudgetMenuAction>(
            tooltip: 'More',
            onSelected: _onMenuAction,
            itemBuilder: (_) => const <PopupMenuEntry<_BudgetMenuAction>>[
              PopupMenuItem(
                  value: _BudgetMenuAction.transactions,
                  child: Text('Transactions')),
              PopupMenuItem(
                  value: _BudgetMenuAction.summary,
                  child: Text('Monthly Summary')),
              PopupMenuItem(
                  value: _BudgetMenuAction.recurring,
                  child: Text('Recurring Rules')),
            ],
          ),
          const SizedBox(width: AppTokens.space4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(budgetManagementProvider.notifier).refresh(),
        child: budgetAsync.isLoading
            ? const _BudgetSkeleton()
            : state.items.isEmpty
                ? const Center(child: Text('No expense categories found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      AppTokens.space16,
                      AppTokens.space16,
                      AppTokens.space32,
                    ),
                    itemCount: state.items.length +
                        (state.errorMessage != null ? 1 : 0) +
                        1, // +1 for month nav header
                    itemBuilder: (ctx, i) {
                      // Row 0: month nav pill
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.space16),
                          child: _MonthNavPill(
                            monthLabel: monthLabel,
                            onPrevious: () => ref
                                .read(budgetManagementProvider.notifier)
                                .changeMonth(DateTime(state.activeMonth.year,
                                    state.activeMonth.month - 1)),
                            onNext: () => ref
                                .read(budgetManagementProvider.notifier)
                                .changeMonth(DateTime(state.activeMonth.year,
                                    state.activeMonth.month + 1)),
                          ),
                        );
                      }
                      final j = i - 1; // offset for month nav
                      if (state.errorMessage != null && j == 0) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppTokens.space12),
                          child: Text(state.errorMessage!,
                              style: TextStyle(color: colorScheme.error)),
                        );
                      }
                      final idx = state.errorMessage != null ? j - 1 : j;
                      final item = state.items[idx];
                      return _BudgetCard(
                        item: item,
                        currencySymbol: currencySymbol,
                        onEdit: () => _editLimit(item, currencySymbol),
                      );
                    },
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Budget card
// ---------------------------------------------------------------------------

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.item,
    required this.currencySymbol,
    required this.onEdit,
  });

  final CategoryBudgetModel item;
  final String currencySymbol;
  final VoidCallback onEdit;

  String get _status {
    if (item.monthlyLimitPaisa <= 0) return 'No limit';
    if (item.exceeded) return 'Exceeded';
    if (item.reachedWarning80) return 'Near limit';
    return 'Within budget';
  }

  String _fmt(int paisa) =>
      '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    final isExceeded = item.exceeded;
    final hasLimit = item.monthlyLimitPaisa > 0;
    final ratio = !hasLimit
        ? 0.0
        : (item.spentPaisa / item.monthlyLimitPaisa).clamp(0.0, 1.0);

    final statusColor = isExceeded
        ? colorScheme.error
        : item.reachedWarning80
            ? AppTokens.warningOrange
            : colorScheme.onSurfaceVariant;

    final barColor = isExceeded ? colorScheme.error : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space16),
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        color: glass.background,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(color: glass.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Name + status badge
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.categoryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space10,
                  vertical: AppTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),

          // Spent / Limit row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Spent',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    _fmt(item.spentPaisa),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Limit',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    hasLimit ? _fmt(item.monthlyLimitPaisa) : 'Not set',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: barColor,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // Edit / Set Limit button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space16,
                  vertical: AppTokens.space8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Text(
                hasLimit ? 'Edit Limit' : 'Set Limit',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space16),
      children: List.generate(
        3,
        (_) => const SkeletonLoader(
          width: double.infinity,
          height: 160,
          borderRadius: AppTokens.radiusXl,
          margin: EdgeInsets.only(bottom: AppTokens.space16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month nav pill
// ---------------------------------------------------------------------------

class _MonthNavPill extends StatelessWidget {
  const _MonthNavPill({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).glass;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: glass.background,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        border: Border.all(color: glass.border),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Center(
              child: Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

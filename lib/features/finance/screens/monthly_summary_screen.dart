import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/features/finance/models/monthly_summary_model.dart';
import 'package:sanchita/features/finance/providers/monthly_summary_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/skeleton_loader.dart';

enum _SummaryMenuAction { transactions, budget, recurring }

class MonthlySummaryScreen extends ConsumerStatefulWidget {
  const MonthlySummaryScreen({required this.initialMonth, super.key});

  final DateTime initialMonth;

  @override
  ConsumerState<MonthlySummaryScreen> createState() =>
      _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends ConsumerState<MonthlySummaryScreen> {
  late DateTime _activeMonth;

  @override
  void initState() {
    super.initState();
    _activeMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  String _fmt(int paisa, String sym) =>
      '$sym ${(paisa / 100).toStringAsFixed(2)}';

  void _changeMonth(int delta) => setState(() {
        _activeMonth = DateTime(_activeMonth.year, _activeMonth.month + delta);
      });

  void _onMenuAction(_SummaryMenuAction action) {
    switch (action) {
      case _SummaryMenuAction.transactions:
        context.pop();
      case _SummaryMenuAction.budget:
        context.pop();
        context.push(RoutePaths.financeBudget);
      case _SummaryMenuAction.recurring:
        context.pop();
        context.push(RoutePaths.financeRecurring);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(monthlySummaryProvider(_activeMonth));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final monthLabel = DateFormat('MMM yyyy').format(_activeMonth);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
        actions: <Widget>[
          PopupMenuButton<_SummaryMenuAction>(
            tooltip: 'More',
            onSelected: _onMenuAction,
            itemBuilder: (_) => const <PopupMenuEntry<_SummaryMenuAction>>[
              PopupMenuItem(
                value: _SummaryMenuAction.transactions,
                child: Text('Transactions'),
              ),
              PopupMenuItem(
                value: _SummaryMenuAction.budget,
                child: Text('Budget Management'),
              ),
              PopupMenuItem(
                value: _SummaryMenuAction.recurring,
                child: Text('Recurring Rules'),
              ),
            ],
          ),
          const SizedBox(width: AppTokens.space4),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const _SummarySkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space20),
            child: Text('Failed to load: $e',
                style: TextStyle(color: colorScheme.error)),
          ),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space16,
            AppTokens.space16,
            AppTokens.space32,
          ),
          children: <Widget>[
            _MonthNavPill(
              monthLabel: monthLabel,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            const SizedBox(height: AppTokens.space16),
            // 3 pill cards
            _SummaryTotalsRow(
              income: _fmt(summary.totalIncomePaisa, currencySymbol),
              expense: _fmt(summary.totalExpensePaisa, currencySymbol),
              net: _fmt(summary.netPaisa, currencySymbol),
              netPaisa: summary.netPaisa,
            ),
            const SizedBox(height: AppTokens.space24),

            // Category breakdown
            Text(
              'Expense Category Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            if (summary.categoryExpenses.isEmpty)
              const _EmptySection(message: 'No expense data for this month.')
            else
              _CategoryBreakdown(
                items: summary.categoryExpenses,
                totalExpensePaisa: summary.totalExpensePaisa,
                currencySymbol: currencySymbol,
              ),
            const SizedBox(height: AppTokens.space24),

            // Daily trend
            Text(
              'Daily Expense Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            if (summary.dailyExpenses.isEmpty)
              const _EmptySection(message: 'No daily data for this month.')
            else
              _DailyTrend(
                items: summary.dailyExpenses,
                fmt: (p) => _fmt(p, currencySymbol),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary totals row
// ---------------------------------------------------------------------------

class _SummaryTotalsRow extends StatelessWidget {
  const _SummaryTotalsRow({
    required this.income,
    required this.expense,
    required this.net,
    required this.netPaisa,
  });

  final String income;
  final String expense;
  final String net;
  final int netPaisa;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: _Pill(
            label: 'Income',
            value: income,
            valueColor: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: _Pill(
            label: 'Expense',
            value: expense,
            valueColor: colorScheme.error,
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: _Pill(
            label: 'Net',
            value: net,
            valueColor: netPaisa >= 0 ? colorScheme.tertiary : colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: glass.background,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: glass.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.5,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTokens.space6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category breakdown
// ---------------------------------------------------------------------------

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.items,
    required this.totalExpensePaisa,
    required this.currencySymbol,
  });

  final List<CategoryExpenseSummary> items;
  final int totalExpensePaisa;
  final String currencySymbol;

  Color _parseColor(String hex) {
    final n = hex.replaceAll('#', '').trim();
    if (n.length != 6) return Colors.grey;
    final p = int.tryParse(n, radix: 16);
    return p == null ? Colors.grey : Color(0xFF000000 | p);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: items.map((item) {
        final ratio = totalExpensePaisa == 0
            ? 0.0
            : (item.amountPaisa / totalExpensePaisa).clamp(0.0, 1.0);
        final catColor = _parseColor(item.colorHex);
        final amount = '$currencySymbol ${(item.amountPaisa / 100).toStringAsFixed(2)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.space20),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: catColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Expanded(
                    child: Text(
                      item.categoryName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: catColor,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily trend
// ---------------------------------------------------------------------------

class _DailyTrend extends StatelessWidget {
  const _DailyTrend({required this.items, required this.fmt});

  final List<DailyExpenseSummary> items;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final max = items.fold(0, (m, i) => i.amountPaisa > m ? i.amountPaisa : m);

    return Column(
      children: items.map((item) {
        final ratio = max == 0 ? 0.0 : (item.amountPaisa / max).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.space12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: AppTokens.space32,
                child: Text(
                  DateFormat('dd').format(item.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    color: colorScheme.primary,
                    backgroundColor:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              SizedBox(
                width: 88,
                child: Text(
                  fmt(item.amountPaisa),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space16),
      children: <Widget>[
        Row(
          children: List.generate(
            3,
            (_) => const Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: AppTokens.space8),
                child: SkeletonLoader(
                  width: double.infinity,
                  height: 64,
                  borderRadius: AppTokens.radiusMd,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space24),
        ...List.generate(
          4,
          (_) => const SkeletonLoader(
            width: double.infinity,
            height: 40,
            borderRadius: AppTokens.radiusSm,
            margin: EdgeInsets.only(bottom: AppTokens.space16),
          ),
        ),
      ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/utils/format_utils.dart';
import 'package:sanchita/features/dashboard/providers/dashboard_provider.dart';
import 'package:sanchita/features/finance/models/monthly_summary_model.dart';
import 'package:sanchita/features/finance/providers/category_range_provider.dart';
import 'package:sanchita/features/quotes/providers/finance_quote_provider.dart';
import 'package:sanchita/features/quotes/services/finance_quote_situation_detector.dart';
import 'package:sanchita/features/quotes/widgets/finance_quote_sheet.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/app_logo.dart';
import 'package:sanchita/shared/widgets/skeleton_loader.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _quoteCheckScheduled = false;
  int _rangeMonths = 1;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: <Widget>[
          _ThemeToggleButton(),
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go(RoutePaths.search),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(RoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardProvider.notifier).refresh();
        },
        child: dashboardAsync.when(
          loading: () => _buildLoadingState(),
          error: (error, stack) => _buildErrorState(error),
          data: (state) => _buildContentState(state),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space8,
        AppTokens.space16,
        AppTokens.space24,
      ),
      children: <Widget>[
        const SkeletonLoader(
          width: 200,
          height: 28,
          borderRadius: AppTokens.radiusMd,
          margin: EdgeInsets.only(bottom: AppTokens.space4),
        ),
        const SkeletonLoader(
          width: 150,
          height: 14,
          borderRadius: AppTokens.radiusSm,
          margin: EdgeInsets.only(bottom: AppTokens.space32),
        ),
        const SkeletonLoader(
          width: double.infinity,
          height: 48,
          borderRadius: AppTokens.radiusMd,
          margin: EdgeInsets.only(bottom: AppTokens.space24),
        ),
        const SkeletonCard(height: 220),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: AppTokens.space16),
          const Text('Failed to load dashboard'),
          const SizedBox(height: AppTokens.space8),
          ElevatedButton(
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeShowDashboardQuote(DashboardState state) async {
    final situation = FinanceQuoteSituationDetector.detectDashboardSituation(
      hasTransactions: state.recentTransactions.isNotEmpty,
      netBalancePaisa: state.netBalancePaisa,
      budgetNearLimitCount: state.budgetNearLimitCount,
      budgetExceededCount: state.budgetExceededCount,
    );
    final quote = await ref
        .read(financeQuoteControllerProvider)
        .automaticQuoteForSituation(situation);
    if (!mounted || quote == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl)),
      ),
      builder: (sheetContext) => FinanceQuoteSheet(
        quote: quote,
        onAction: () {
          Navigator.of(sheetContext).pop();
          context.go(RoutePaths.finance);
        },
      ),
    );
  }

  Widget _buildContentState(DashboardState state) {
    if (!_quoteCheckScheduled) {
      _quoteCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShowDashboardQuote(state);
      });
    }

    final now = state.now;
    final dateLabel = formatDate(now);
    final greetingBase = greetingFor(now);
    final userName = state.userName;
    final greeting = userName == null ? '$greetingBase,' : '$greetingBase, $userName';
    final currencySymbol = state.currencySymbol;
    final hideBalance = state.hideBalance;
    final netBalance = state.netBalancePaisa;
    final displayBalance = hideBalance
        ? '••••••'
        : formatAmount(paisa: netBalance, currencySymbol: currencySymbol);
    final colorScheme = Theme.of(context).colorScheme;
    final isNegative = netBalance < 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space8,
        AppTokens.space16,
        AppTokens.space24,
      ),
      children: <Widget>[
        // Greeting
        Text(greeting, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppTokens.space4),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.space24),

        // Net balance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Net Balance',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  'All records',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: hideBalance ? 'Show balance' : 'Hide balance',
              onPressed: () => ref.read(dashboardProvider.notifier).toggleHideBalance(),
              icon: Icon(
                hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: AppTokens.iconSm,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          displayBalance,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: hideBalance
                ? colorScheme.onSurface
                : isNegative
                    ? colorScheme.error
                    : colorScheme.tertiary,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: AppTokens.space32),

        // Category breakdown card
        _CategoryBreakdownCard(
          rangeMonths: _rangeMonths,
          currencySymbol: currencySymbol,
          onRangeChanged: (months) => setState(() => _rangeMonths = months),
          onDetailsTap: () => context.go(RoutePaths.finance),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category Breakdown Card
// ---------------------------------------------------------------------------

class _CategoryBreakdownCard extends ConsumerWidget {
  const _CategoryBreakdownCard({
    required this.rangeMonths,
    required this.currencySymbol,
    required this.onRangeChanged,
    required this.onDetailsTap,
  });

  final int rangeMonths;
  final String currencySymbol;
  final ValueChanged<int> onRangeChanged;
  final VoidCallback onDetailsTap;

  static const _ranges = <(int, String)>[
    (1, '1M'),
    (3, '3M'),
    (6, '6M'),
    (12, '12M'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryRangeProvider(rangeMonths));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Category Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: onDetailsTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Details'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Range tabs
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                padding: const EdgeInsets.all(AppTokens.space4),
                child: Row(
                  children: _ranges.map((entry) {
                    final (months, label) = entry;
                    final selected = months == rangeMonths;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onRangeChanged(months),
                        child: AnimatedContainer(
                          duration: AppTokens.durationFast,
                          padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
                          decoration: BoxDecoration(
                            color: selected ? colorScheme.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            border: selected
                                ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              categoryAsync.when(
                loading: () => const _CategoryBreakdownSkeleton(),
                error: (_, __) => const Text('Failed to load category data'),
                data: (categories) => categories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
                        child: Text(
                          'No expense data for this period',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _CategoryBreakdownBody(
                        categories: categories,
                        currencySymbol: currencySymbol,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdownBody extends StatelessWidget {
  const _CategoryBreakdownBody({
    required this.categories,
    required this.currencySymbol,
  });

  final List<CategoryExpenseSummary> categories;
  final String currencySymbol;

  Color _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '').trim();
    if (normalized.length != 6) return Colors.grey;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return Colors.grey;
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = categories.fold(0, (sum, c) => sum + c.amountPaisa);

    // Stacked horizontal bar
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: SizedBox(
        height: 10,
        child: Row(
          children: categories.map((cat) {
            final ratio = total == 0 ? 0.0 : cat.amountPaisa / total;
            return Expanded(
              flex: (ratio * 1000).round(),
              child: Container(color: _parseColor(cat.colorHex)),
            );
          }).toList(growable: false),
        ),
      ),
    );

    return Column(
      children: <Widget>[
        bar,
        const SizedBox(height: AppTokens.space16),
        ...categories.map((cat) {
          final ratio = total == 0 ? 0.0 : cat.amountPaisa / total;
          final pct = (ratio * 100).round();
          final amount = '$currencySymbol ${(cat.amountPaisa / 100).toStringAsFixed(2)}';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parseColor(cat.colorHex),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    cat.categoryName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryBreakdownSkeleton extends StatelessWidget {
  const _CategoryBreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SkeletonLoader(
          width: double.infinity,
          height: 10,
          borderRadius: AppTokens.radiusFull,
          margin: EdgeInsets.only(bottom: AppTokens.space16),
        ),
        ...List.generate(3, (_) => const SkeletonLoader(
          width: double.infinity,
          height: 14,
          borderRadius: AppTokens.radiusSm,
          margin: EdgeInsets.only(bottom: AppTokens.space12),
        )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Theme Toggle Button
// ---------------------------------------------------------------------------

class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(
      settingsProvider.select((s) => s.asData?.value.theme ?? 'system'),
    );
    final isDark = theme == 'dark' ||
        (theme == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () async {
        final next = isDark ? 'light' : 'dark';
        await ref.read(settingsProvider.notifier).setTheme(next);
      },
      icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined),
    );
  }
}

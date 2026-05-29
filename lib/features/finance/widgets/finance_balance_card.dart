import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/shared/widgets/animated_number_text.dart';

/// Finance balance card — matches brand_new_ui.js FinanceScreen summary card.
/// Monthly view: passed monthly totals.
/// Total view: passed all-time totals (from dashboardProvider).
class FinanceBalanceCard extends StatefulWidget {
  const FinanceBalanceCard({
    required this.balanceLabel,
    this.balancePaisa = 0,
    this.balanceText,
    this.incomeText,
    this.expenseText,
    this.currencySymbol = 'BDT',
    this.totalNetBalancePaisa,
    this.totalIncomeText,
    this.totalExpenseText,
    super.key,
  });

  final String balanceLabel;
  final int balancePaisa;
  final String? balanceText;
  final String? incomeText;
  final String? expenseText;
  final String currencySymbol;

  // All-time totals — when null, Total toggle mirrors Monthly values.
  final int? totalNetBalancePaisa;
  final String? totalIncomeText;
  final String? totalExpenseText;

  @override
  State<FinanceBalanceCard> createState() => _FinanceBalanceCardState();
}

class _FinanceBalanceCardState extends State<FinanceBalanceCard> {
  bool _showMonthly = true;

  int get _activePaisa =>
      _showMonthly ? widget.balancePaisa : (widget.totalNetBalancePaisa ?? widget.balancePaisa);

  String get _activeIncomeText =>
      _showMonthly ? (widget.incomeText ?? '${widget.currencySymbol} 0.00') : (widget.totalIncomeText ?? widget.incomeText ?? '${widget.currencySymbol} 0.00');

  String get _activeExpenseText =>
      _showMonthly ? (widget.expenseText ?? '${widget.currencySymbol} 0.00') : (widget.totalExpenseText ?? widget.expenseText ?? '${widget.currencySymbol} 0.00');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;
    final isNegative = _activePaisa < 0;
    final balanceColor = isNegative ? colorScheme.error : colorScheme.tertiary;

    final label = _showMonthly ? widget.balanceLabel : 'Total net balance';

    return Container(
      decoration: BoxDecoration(
        color: glass.background,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(color: glass.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Label + Monthly/Total toggle row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              _ViewToggle(
                showMonthly: _showMonthly,
                onChanged: (v) => setState(() => _showMonthly = v),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),

          // Net balance amount — FittedBox keeps it single-line
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _activePaisa != 0
                ? AnimatedNumberText(
                    _activePaisa,
                    prefix: '${widget.currencySymbol} ',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                    duration: AppTokens.durationNormal,
                  )
                : Text(
                    widget.balanceText ?? '${widget.currencySymbol} 0.00',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
          ),

          // Dashed divider
          const SizedBox(height: AppTokens.space16),
          const _DashedDivider(),
          const SizedBox(height: AppTokens.space16),

          // Income + Expense row
          Row(
            children: <Widget>[
              _SummaryTile(
                icon: Icons.arrow_downward_rounded,
                iconColor: colorScheme.tertiary,
                iconBg: colorScheme.tertiary.withValues(alpha: 0.12),
                label: 'Income',
                value: _activeIncomeText,
              ),
              const SizedBox(width: AppTokens.space16),
              _SummaryTile(
                icon: Icons.arrow_upward_rounded,
                iconColor: colorScheme.error,
                iconBg: colorScheme.error.withValues(alpha: 0.10),
                label: 'Expense',
                value: _activeExpenseText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.showMonthly, required this.onChanged});

  final bool showMonthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: glass.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ToggleChip(
            label: 'Monthly',
            selected: showMonthly,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: AppTokens.space2),
          _ToggleChip(
            label: 'Total',
            selected: !showMonthly,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.durationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space8,
          vertical: AppTokens.space6,
        ),
        decoration: BoxDecoration(
          color: selected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
          border: selected ? Border.all(color: glass.border) : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppTokens.space4),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: AppTokens.space6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(right: dashSpace),
              child: Container(
                width: dashWidth,
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

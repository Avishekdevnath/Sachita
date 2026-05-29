import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

class FinanceTransactionTypeToggle extends StatelessWidget {
  const FinanceTransactionTypeToggle({
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    return Container(
      key: const ValueKey<String>('finance-type-toggle'),
      height: 44,
      padding: const EdgeInsets.all(AppTokens.space4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: glass.border.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Row(
        children: <Widget>[
          _TypeButton(
            value: 'income',
            label: 'Income',
            icon: Icons.arrow_downward,
            selected: selectedType == 'income',
            enabled: enabled,
            onTap: onChanged,
          ),
          const SizedBox(width: AppTokens.space4),
          _TypeButton(
            value: 'expense',
            label: 'Expense',
            icon: Icons.arrow_upward,
            selected: selectedType == 'expense',
            enabled: enabled,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: selected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  if (!selected) {
                    onTap(value);
                  }
                }
              : null,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.space4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

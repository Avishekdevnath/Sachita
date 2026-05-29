import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

class FinanceTransactionViewTabs extends StatelessWidget {
  const FinanceTransactionViewTabs({
    required this.selectedView,
    required this.onChanged,
    super.key,
  });

  final String selectedView;
  final ValueChanged<String> onChanged;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(value: 'all', label: 'All'),
    _Tab(value: 'income', label: 'Income'),
    _Tab(value: 'expense', label: 'Expense'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey<String>('finance-view-tabs'),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final selected = selectedView == tab.value;
          return _TabButton(
            tab: tab,
            selected: selected,
            onTap: () {
              if (!selected) onChanged(tab.value);
            },
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          right: AppTokens.space24,
          bottom: AppTokens.space12,
          top: AppTokens.space4,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Text(
              tab.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (selected)
              Positioned(
                bottom: -AppTokens.space12,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.value, required this.label});

  final String value;
  final String label;
}

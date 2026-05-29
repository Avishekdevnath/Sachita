import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

class FinanceHeaderBar extends StatelessWidget {
  const FinanceHeaderBar({
    required this.monthLabel,
    required this.activeFilterCount,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onFilterTap,
    super.key,
  });

  final String monthLabel;
  final int activeFilterCount;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).glass;

    final pillDecoration = BoxDecoration(
      color: glass.background,
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      border: Border.all(color: glass.border),
    );

    return Row(
      children: <Widget>[
        // Month nav pill
        Expanded(
          child: Container(
            height: 48,
            decoration: pillDecoration,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onPreviousMonth,
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
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTokens.space12),

        // Filter button pill
        Container(
          width: 48,
          height: 48,
          decoration: pillDecoration,
          child: Semantics(
            label: activeFilterCount > 0
                ? 'Filter with $activeFilterCount active filters'
                : 'Filter transactions',
            child: InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(
                      Icons.filter_alt_outlined,
                      color: colorScheme.onSurface,
                      size: AppTokens.iconMd,
                    ),
                    if (activeFilterCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusFull),
                          ),
                          child: Text(
                            activeFilterCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

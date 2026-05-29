import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
    this.onRefresh,
    this.backgroundColor,
    this.compact = false,
    super.key,
  });

  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onRefresh;
  final Color? backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh month data',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_outlined),
          ),
      ],
    );

    if (compact) {
      return content;
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space8,
          vertical: AppTokens.space8,
        ),
        child: content,
      ),
    );
  }
}

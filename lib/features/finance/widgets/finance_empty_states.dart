import 'package:flutter/material.dart';
import 'package:sanchita/shared/widgets/empty_state_widget.dart';

class FinanceNoTransactionsEmptyState extends StatelessWidget {
  const FinanceNoTransactionsEmptyState({
    required this.onAddFirstTap,
    super.key,
  });

  final VoidCallback onAddFirstTap;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions for this month',
        subtitle: 'Tap + to add your first transaction.',
        action: FilledButton(
          onPressed: onAddFirstTap,
          child: const Text('Add First Transaction'),
        ),
      ),
    );
  }
}

class FinanceNoFilterResultsEmptyState extends StatelessWidget {
  const FinanceNoFilterResultsEmptyState({
    required this.onClearFiltersTap,
    super.key,
  });

  final VoidCallback onClearFiltersTap;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyStateWidget(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matching transactions',
        subtitle: 'Try adjusting or clearing filters to see more results.',
        action: FilledButton.tonal(
          onPressed: onClearFiltersTap,
          child: const Text('Clear Filters'),
        ),
      ),
    );
  }
}

class FinanceNoTransactionsForTypeEmptyState extends StatelessWidget {
  const FinanceNoTransactionsForTypeEmptyState({
    required this.typeLabel,
    super.key,
  });

  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: 'No $typeLabel transactions',
        subtitle: 'Switch tabs or add a new transaction.',
      ),
    );
  }
}

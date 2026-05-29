import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';

class FinanceTransactionSection {
  const FinanceTransactionSection({required this.date, required this.items});

  final DateTime date;
  final List<TransactionModel> items;
}

typedef FinanceTransactionItemBuilder =
    Widget Function(BuildContext context, TransactionModel item);

class FinanceTransactionSectionSliver extends StatelessWidget {
  const FinanceTransactionSectionSliver({
    required this.sections,
    required this.itemBuilder,
    super.key,
  });

  final List<FinanceTransactionSection> sections;
  final FinanceTransactionItemBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final section = sections[index];
        final headerLabel = DateFormat(
          'EEEE, dd MMM yyyy',
        ).format(section.date);
        final entryCount = section.items.length;
        final entryLabel = entryCount == 1 ? '1 entry' : '$entryCount entries';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space8,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      headerLabel.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    entryLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space4,
                  AppTokens.space16,
                  AppTokens.space4,
                ),
                child: itemBuilder(context, item),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
          ],
        );
      }, childCount: sections.length),
    );
  }
}

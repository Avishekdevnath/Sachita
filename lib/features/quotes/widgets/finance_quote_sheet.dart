import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/quotes/models/finance_quote_model.dart';

class FinanceQuoteSheet extends StatelessWidget {
  const FinanceQuoteSheet({
    required this.quote,
    required this.onAction,
    super.key,
  });

  final FinanceQuoteModel quote;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          AppTokens.space12,
          AppTokens.space20,
          AppTokens.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space20),
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTokens.goldGradient,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(Icons.format_quote, color: colorScheme.onPrimary),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    quote.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              '"${quote.quote}"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            Text(
              quote.source,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (quote.sourceReference.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.space4),
              Text(
                quote.sourceReference,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.space20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(quote.actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/groups/models/group_member_breakdown_model.dart';
import 'package:sanchita/features/groups/providers/group_detail_provider.dart';
import 'package:sanchita/features/groups/providers/group_member_breakdown_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';

class GroupMemberBreakdownScreen extends ConsumerWidget {
  const GroupMemberBreakdownScreen({required this.groupId, super.key});

  final String groupId;

  String _formatAmount(int paisa, String currencySymbol) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final breakdownAsync = ref.watch(groupMemberBreakdownProvider(groupId));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final groupName = groupAsync.asData?.value.name ?? 'Group';
    String formatAmount(int paisa) {
      return _formatAmount(paisa, currencySymbol);
    }

    return Scaffold(
      appBar: AppBar(title: Text('$groupName Breakdown')),
      body: breakdownAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No members found. Add members and group transactions first.',
              ),
            );
          }

          final maxVolume = items
              .map((item) => item.incomePaisa + item.expensePaisa)
              .fold<int>(0, (prev, next) => next > prev ? next : prev);

          final totalIncome = items
              .map((item) => item.incomePaisa)
              .fold<int>(0, (prev, next) => prev + next);
          final totalExpense = items
              .map((item) => item.expensePaisa)
              .fold<int>(0, (prev, next) => prev + next);
          final totalNet = totalIncome - totalExpense;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Combined Totals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Income: ${formatAmount(totalIncome)}'),
                      Text('Expense: ${formatAmount(totalExpense)}'),
                      Text('Net: ${formatAmount(totalNet)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => _MemberBreakdownTile(
                  item: item,
                  maxVolume: maxVolume,
                  formatAmount: formatAmount,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberBreakdownTile extends StatelessWidget {
  const _MemberBreakdownTile({
    required this.item,
    required this.maxVolume,
    required this.formatAmount,
  });

  final GroupMemberBreakdownModel item;
  final int maxVolume;
  final String Function(int) formatAmount;

  @override
  Widget build(BuildContext context) {
    final volume = item.incomePaisa + item.expensePaisa;
    final ratio = maxVolume == 0 ? 0.0 : (volume / maxVolume).clamp(0.0, 1.0);
    final netPositive = item.netPaisa >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.memberName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(minHeight: 8, value: ratio),
            ),
            const SizedBox(height: 8),
            Text('Income: ${formatAmount(item.incomePaisa)}'),
            Text('Expense: ${formatAmount(item.expensePaisa)}'),
            Text(
              'Net: ${formatAmount(item.netPaisa)}',
              style: TextStyle(
                color: netPositive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

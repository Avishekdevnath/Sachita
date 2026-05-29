import 'package:sanchita/features/finance/widgets/finance_transaction_section_list.dart';

List<FinanceTransactionSection> filterFinanceTransactionSections({
  required List<FinanceTransactionSection> sections,
  required String view,
}) {
  if (view == 'all') {
    return sections;
  }

  return sections
      .map((section) {
        final filteredItems = section.items
            .where((item) => item.type == view)
            .toList(growable: false);
        return FinanceTransactionSection(
          date: section.date,
          items: filteredItems,
        );
      })
      .where((section) => section.items.isNotEmpty)
      .toList(growable: false);
}

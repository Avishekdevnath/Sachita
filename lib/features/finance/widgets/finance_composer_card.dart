import 'package:flutter/material.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_form_content.dart';

/// Form content for adding a finance transaction.
/// Designed to be placed inside an [AppModalSheet].
class FinanceComposerContent extends StatelessWidget {
  const FinanceComposerContent({
    required this.amountController,
    required this.noteController,
    required this.amountFocusNode,
    required this.categories,
    required this.selectedCategoryId,
    required this.activeType,
    required this.entryDate,
    required this.isBusy,
    required this.canSubmit,
    required this.onCategoryChanged,
    required this.onPickDate,
    required this.onSetToday,
    required this.onSubmit,
    this.onReuseLastNote,
    this.lastUsedNote,
    this.amountErrorText,
    this.onFormChanged,
    super.key,
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  final FocusNode amountFocusNode;
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final String activeType;
  final DateTime entryDate;
  final bool isBusy;
  final bool canSubmit;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSetToday;
  final Future<void> Function() onSubmit;
  final VoidCallback? onReuseLastNote;
  final String? lastUsedNote;
  final String? amountErrorText;
  final VoidCallback? onFormChanged;

  @override
  Widget build(BuildContext context) {
    final actionLabel = activeType == 'income' ? 'Add Income' : 'Add Expense';
    return FinanceTransactionFormContent(
      amountController: amountController,
      noteController: noteController,
      amountFocusNode: amountFocusNode,
      categories: categories,
      selectedCategoryId: selectedCategoryId,
      activeType: activeType,
      entryDate: entryDate,
      isBusy: isBusy,
      canSubmit: canSubmit,
      submitLabel: actionLabel,
      onCategoryChanged: onCategoryChanged,
      onPickDate: onPickDate,
      onSetToday: onSetToday,
      onSubmit: onSubmit,
      onReuseLastNote: onReuseLastNote,
      lastUsedNote: lastUsedNote,
      amountErrorText: amountErrorText,
      onFormChanged: onFormChanged,
    );
  }
}

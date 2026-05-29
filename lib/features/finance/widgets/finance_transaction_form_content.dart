import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_type_toggle.dart';

class FinanceTransactionFormContent extends StatelessWidget {
  const FinanceTransactionFormContent({
    required this.amountController,
    required this.noteController,
    required this.amountFocusNode,
    required this.categories,
    required this.selectedCategoryId,
    required this.activeType,
    required this.entryDate,
    required this.isBusy,
    required this.canSubmit,
    required this.submitLabel,
    required this.onCategoryChanged,
    required this.onPickDate,
    required this.onSetToday,
    required this.onSubmit,
    this.showTypeToggle = false,
    this.onTypeChanged,
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
  final String submitLabel;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSetToday;
  final Future<void> Function() onSubmit;
  final bool showTypeToggle;
  final ValueChanged<String>? onTypeChanged;
  final VoidCallback? onReuseLastNote;
  final String? lastUsedNote;
  final String? amountErrorText;
  final VoidCallback? onFormChanged;

  bool get _useChipCategorySelector => categories.length <= 8;

  @override
  Widget build(BuildContext context) {
    final hasCategories = categories.isNotEmpty;
    final dateLabel = DateFormat('dd MMM yyyy').format(entryDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showTypeToggle) ...<Widget>[
          FinanceTransactionTypeToggle(
            selectedType: activeType,
            enabled: !isBusy,
            onChanged: onTypeChanged ?? (_) {},
          ),
          const SizedBox(height: AppTokens.space12),
        ],
        TextField(
          controller: amountController,
          focusNode: amountFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !isBusy,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: 'e.g. 1500.50',
            errorText: amountErrorText,
            prefixIcon: const Icon(Icons.calculate_outlined),
          ),
          onChanged: (_) {
            onFormChanged?.call();
          },
        ),
        const SizedBox(height: AppTokens.space12),
        TextField(
          controller: noteController,
          enabled: !isBusy,
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'Add details, shopping list, bazar items…',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: AppTokens.space32),
              child: Icon(Icons.notes_outlined),
            ),
            suffixIcon:
                (lastUsedNote != null &&
                    lastUsedNote!.trim().isNotEmpty &&
                    onReuseLastNote != null)
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.space32),
                    child: IconButton(
                      tooltip: 'Reuse last note',
                      onPressed: isBusy ? null : onReuseLastNote,
                      icon: const Icon(Icons.history_outlined),
                    ),
                  )
                : null,
            alignLabelWithHint: true,
          ),
          onChanged: (_) {
            onFormChanged?.call();
          },
        ),
        const SizedBox(height: AppTokens.space12),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: isBusy ? null : onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Date: $dateLabel'),
            ),
            TextButton.icon(
              onPressed: isBusy ? null : onSetToday,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Today'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        if (!hasCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space8),
            child: Text('No category available for $activeType.'),
          )
        else if (_useChipCategorySelector)
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: categories
                .map((item) {
                  final isSelected = selectedCategoryId == item.id;
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: isSelected,
                    onSelected: isBusy
                        ? null
                        : (selected) {
                            if (selected) {
                              onCategoryChanged(item.id);
                            }
                          },
                  );
                })
                .toList(growable: false),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'finance-form-category-$activeType-${selectedCategoryId ?? 'none'}-${categories.length}',
            ),
            initialValue: selectedCategoryId,
            items: categories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: isBusy
                ? null
                : (value) {
                    if (value != null) {
                      onCategoryChanged(value);
                    }
                  },
            decoration: const InputDecoration(labelText: 'Category'),
          ),
        const SizedBox(height: AppTokens.space16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy || !canSubmit
                ? null
                : () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await onSubmit();
                  },
            icon: Icon(
              activeType == 'income'
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
            ),
            label: Text(submitLabel),
          ),
        ),
      ],
    );
  }
}

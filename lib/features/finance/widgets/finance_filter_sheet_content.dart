import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/models/finance_filters_model.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/finance/utils/finance_input_utils.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';

class FinanceFilterSheetContent extends ConsumerStatefulWidget {
  const FinanceFilterSheetContent({this.showIntro = false, super.key});

  final bool showIntro;

  @override
  ConsumerState<FinanceFilterSheetContent> createState() =>
      _FinanceFilterSheetContentState();
}

class _FinanceFilterSheetContentState
    extends ConsumerState<FinanceFilterSheetContent> {
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  Set<String> _selectedCategoryIds = <String>{};
  String? _validationError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _minAmountController.addListener(_onInputChanged);
    _maxAmountController.addListener(_onInputChanged);
    final current = ref.read(financeProvider).asData?.value;
    final filters = current?.filters ?? const FinanceFilters();
    _fromDate = filters.fromDate;
    _toDate = filters.toDate;
    _selectedCategoryIds = <String>{...filters.categoryIds};
    if (filters.minAmountPaisa != null) {
      _minAmountController.text = (filters.minAmountPaisa! / 100)
          .toStringAsFixed(2);
    }
    if (filters.maxAmountPaisa != null) {
      _maxAmountController.text = (filters.maxAmountPaisa! / 100)
          .toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _minAmountController.removeListener(_onInputChanged);
    _maxAmountController.removeListener(_onInputChanged);
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int? _parseToPaisa(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }

    final localeCode = Localizations.localeOf(context).toLanguageTag();
    return FinanceInputUtils.parseAmountToPaisa(raw, localeCode: localeCode);
  }

  bool get _hasAnyInputFilter {
    return _fromDate != null ||
        _toDate != null ||
        _selectedCategoryIds.isNotEmpty ||
        _minAmountController.text.trim().isNotEmpty ||
        _maxAmountController.text.trim().isNotEmpty;
  }

  Future<void> _pickFromDate() async {
    final initialDate = _fromDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
    });
  }

  Future<void> _pickToDate() async {
    final initialDate = _toDate ?? _fromDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _toDate = picked;
      if (_fromDate != null && picked.isBefore(_fromDate!)) {
        _fromDate = picked;
      }
    });
  }

  Future<void> _apply() async {
    if (_submitting) {
      return;
    }

    final minPaisa = _parseToPaisa(_minAmountController.text);
    final maxPaisa = _parseToPaisa(_maxAmountController.text);
    if (minPaisa != null && maxPaisa != null && minPaisa > maxPaisa) {
      setState(() {
        _validationError = 'Min amount cannot be greater than max amount.';
      });
      return;
    }

    final filters = FinanceFilters(
      fromDate: _fromDate,
      toDate: _toDate,
      categoryIds: <String>{..._selectedCategoryIds},
      minAmountPaisa: minPaisa,
      maxAmountPaisa: maxPaisa,
    );

    setState(() {
      _validationError = null;
      _submitting = true;
    });

    await ref.read(financeProvider.notifier).applyFilters(filters);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    if (_submitting) {
      return;
    }

    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedCategoryIds = <String>{};
      _validationError = null;
      _submitting = true;
    });
    await ref.read(financeProvider.notifier).clearFilters();
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  Widget _buildSectionCard({
    required String title,
    Widget? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppTokens.space4),
              subtitle,
            ],
            const SizedBox(height: AppTokens.space12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider.select((s) => s.asData?.value));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final categories = finance?.categories ?? const <CategoryModel>[];
    final dateFormat = DateFormat('dd MMM yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.showIntro) ...<Widget>[
          Text(
            'Refine your transaction list',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
        ],
        _buildSectionCard(
          title: 'Date range',
          subtitle: Text(
            'Limit results to a custom time window.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickFromDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _fromDate == null ? 'From' : dateFormat.format(_fromDate!),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickToDate,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    _toDate == null ? 'To' : dateFormat.format(_toDate!),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        _buildSectionCard(
          title: 'Categories',
          subtitle: Text(
            'Choose one or more categories.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          child: categories.isEmpty
              ? Text(
                  'No categories available for this type.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: <Widget>[
                    for (final category in categories)
                      FilterChip(
                        label: Text(category.name),
                        selected: _selectedCategoryIds.contains(category.id),
                        onSelected: _submitting
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(category.id);
                                  } else {
                                    _selectedCategoryIds.remove(category.id);
                                  }
                                });
                              },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppTokens.space12),
        _buildSectionCard(
          title: 'Amount range',
          subtitle: Text(
            'Use $currencySymbol values with decimals if needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: 'Min amount ($currencySymbol)',
                    hintText: 'e.g. 100.00',
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: TextField(
                  controller: _maxAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: 'Max amount ($currencySymbol)',
                    hintText: 'e.g. 5000.00',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_validationError != null) ...<Widget>[
          const SizedBox(height: AppTokens.space8),
          Text(
            _validationError!,
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppTokens.space16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting || !_hasAnyInputFilter ? null : _clear,
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _apply,
                child: Text(_submitting ? 'Applying...' : 'Apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

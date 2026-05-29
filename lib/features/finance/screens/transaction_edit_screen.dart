import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/data/transaction_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/models/transaction_model.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/finance/utils/finance_input_utils.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_deleted_snackbar.dart';
import 'package:sanchita/features/finance/widgets/finance_transaction_form_content.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  String _type = 'expense';
  DateTime _date = DateTime.now();
  String? _selectedCategoryId;
  List<CategoryModel> _categories = const <CategoryModel>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onInputChanged);
    _noteController.addListener(_onInputChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onInputChanged);
    _noteController.removeListener(_onInputChanged);
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final transactionResult = await ref
        .read(transactionRepositoryProvider)
        .getTransactionById(widget.transactionId);

    if (!mounted) {
      return;
    }

    await transactionResult.when(
      success: (transaction) async {
        await _hydrateFromTransaction(transaction);
      },
      failure: (message) async {
        setState(() {
          _loading = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _hydrateFromTransaction(TransactionModel transaction) async {
    _type = transaction.type;
    _date = transaction.date;
    _amountController.text = (transaction.amountPaisa / 100).toStringAsFixed(2);
    _noteController.text = transaction.note;

    final categoriesResult = await ref
        .read(categoryRepositoryProvider)
        .getCategoriesByType(transaction.type);

    if (!mounted) {
      return;
    }

    categoriesResult.when(
      success: (items) {
        final selected = _resolveCategorySelection(
          transaction.categoryId,
          items,
        );
        setState(() {
          _categories = items;
          _selectedCategoryId = selected;
          _loading = false;
          _error = null;
        });
      },
      failure: (message) {
        setState(() {
          _categories = const <CategoryModel>[];
          _selectedCategoryId = null;
          _loading = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _onTypeChanged(String type) async {
    if (_saving || _deleting || _type == type) {
      return;
    }

    setState(() {
      _type = type;
      _selectedCategoryId = null;
      _error = null;
    });

    final categoriesResult = await ref
        .read(categoryRepositoryProvider)
        .getCategoriesByType(type);

    if (!mounted) {
      return;
    }

    categoriesResult.when(
      success: (items) {
        setState(() {
          _categories = items;
          _selectedCategoryId = items.isEmpty ? null : items.first.id;
        });
      },
      failure: (message) {
        setState(() {
          _categories = const <CategoryModel>[];
          _selectedCategoryId = null;
          _error = message;
        });
      },
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _date = selected;
    });
  }

  Future<void> _save() async {
    final amountPaisa = _parseToPaisa(_amountController.text);
    final selectedCategoryId = _selectedCategoryId;

    if (amountPaisa == null || amountPaisa <= 0) {
      setState(() {
        _error = 'Enter a valid amount greater than zero.';
      });
      return;
    }

    if (selectedCategoryId == null) {
      setState(() {
        _error = 'Select a category before saving.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await ref
        .read(financeProvider.notifier)
        .updateTransaction(
          id: widget.transactionId,
          type: _type,
          amountPaisa: amountPaisa,
          categoryId: selectedCategoryId,
          note: _noteController.text,
          date: _date,
        );

    if (!mounted) {
      return;
    }

    final financeState = ref.read(financeProvider).asData?.value;
    if (financeState?.errorMessage != null) {
      setState(() {
        _saving = false;
        _error = financeState!.errorMessage;
      });
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      context.pop();
    }
  }

  Future<void> _delete() async {
    if (_saving || _deleting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This will remove the transaction from active history.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final deletedTransactionId = widget.transactionId;
    await ref
        .read(financeProvider.notifier)
        .deleteTransaction(deletedTransactionId);

    if (!mounted) {
      return;
    }

    final financeState = ref.read(financeProvider).asData?.value;
    if (financeState?.errorMessage != null) {
      setState(() {
        _deleting = false;
        _error = financeState!.errorMessage;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    context.pop();
    showTransactionDeletedSnackBar(
      messenger: messenger,
      onUndo: () async {
        await container
            .read(financeProvider.notifier)
            .restoreTransaction(deletedTransactionId);
      },
    );
  }

  Widget _buildFormCard({required bool busy}) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Transaction details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space12),
          FinanceTransactionFormContent(
            amountController: _amountController,
            noteController: _noteController,
            amountFocusNode: _amountFocusNode,
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            activeType: _type,
            entryDate: _date,
            isBusy: busy,
            canSubmit: _canSave,
            submitLabel: _saving ? 'Updating...' : 'Update Transaction',
            showTypeToggle: true,
            onTypeChanged: _onTypeChanged,
            onCategoryChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
            onPickDate: _pickDate,
            onSetToday: () {
              setState(() {
                final now = DateTime.now();
                _date = DateTime(now.year, now.month, now.day);
              });
            },
            onSubmit: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteCard({required bool busy}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Danger zone',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            'Remove this transaction from active history.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(_deleting ? 'Deleting...' : 'Delete Transaction'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSave {
    final amountPaisa = _parseToPaisa(_amountController.text);
    return amountPaisa != null &&
        amountPaisa > 0 &&
        _selectedCategoryId != null &&
        !_loading &&
        !_saving &&
        !_deleting;
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _saving || _deleting;

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Edit Transaction',
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space16,
                        AppTokens.space12,
                        AppTokens.space16,
                        AppTokens.space12,
                      ),
                      children: <Widget>[
                        Text(
                          'Update amount, type, category, date, and note.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppTokens.space12),
                        _buildFormCard(busy: busy),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AppTokens.space8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTokens.space12),
                        _buildDeleteCard(busy: busy),
                        const SizedBox(height: AppTokens.space24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String? _resolveCategorySelection(
    String currentCategoryId,
    List<CategoryModel> categories,
  ) {
    for (final item in categories) {
      if (item.id == currentCategoryId) {
        return currentCategoryId;
      }
    }

    if (categories.isEmpty) {
      // Defensive null return - validation failed
      return null;
    }

    return categories.first.id;
  }

  int? _parseToPaisa(String text) {
    return FinanceInputUtils.parseAmountToPaisa(
      text,
      localeCode: Localizations.localeOf(context).toLanguageTag(),
    );
  }
}

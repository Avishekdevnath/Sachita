import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/settings/providers/category_management_provider.dart';
import 'package:sanchita/shared/widgets/app_modal_sheet.dart';

class SettingsCategoriesScreen extends ConsumerStatefulWidget {
  const SettingsCategoriesScreen({super.key});

  @override
  ConsumerState<SettingsCategoriesScreen> createState() =>
      _SettingsCategoriesScreenState();
}

class _SettingsCategoriesScreenState
    extends ConsumerState<SettingsCategoriesScreen> {
  final RegExp _hexColorRegExp = RegExp(r'^#[0-9A-Fa-f]{6}$');

  Color _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '').trim();
    if (normalized.length != 6) {
      return Colors.grey;
    }

    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return Colors.grey;
    }

    return Color(0xFF000000 | parsed);
  }

  Future<_CategoryDialogResult?> _showCategorySheet({
    required String title,
    String initialName = '',
    String initialIcon = 'other',
    String initialColor = '#999999',
  }) async {
    final nameController = TextEditingController(text: initialName);
    final iconController = TextEditingController(text: initialIcon);
    final colorController = TextEditingController(text: initialColor);
    var validationError = '';

    final result = await AppModalSheet.show<_CategoryDialogResult>(
      context: context,
      title: title,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.8,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. Groceries',
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon key',
                  hintText: 'e.g. food',
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                        hintText: '#FF6B6B',
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _parseColor(colorController.text),
                  ),
                ],
              ),
              if (validationError.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppTokens.space8),
                Text(
                  validationError,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.space16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final icon = iconController.text.trim().isEmpty
                        ? 'other'
                        : iconController.text.trim();
                    final color = colorController.text.trim().isEmpty
                        ? '#999999'
                        : colorController.text.trim();

                    if (name.isEmpty) {
                      setSheetState(() {
                        validationError = 'Category name is required.';
                      });
                      return;
                    }

                    if (!_hexColorRegExp.hasMatch(color)) {
                      setSheetState(() {
                        validationError = 'Color must be in #RRGGBB format.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      _CategoryDialogResult(
                        name: name,
                        icon: icon,
                        colorHex: color.toUpperCase(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Future<void> _addCategory() async {
    final input = await _showCategorySheet(title: 'Add Category');
    if (input == null) {
      return;
    }

    await ref
        .read(categoryManagementProvider.notifier)
        .createCategory(
          name: input.name,
          icon: input.icon,
          colorHex: input.colorHex,
        );
  }

  Future<void> _editCategory(CategoryModel category) async {
    final input = await _showCategorySheet(
      title: 'Edit Category',
      initialName: category.name,
      initialIcon: category.icon,
      initialColor: category.colorHex,
    );
    if (input == null) {
      return;
    }

    await ref
        .read(categoryManagementProvider.notifier)
        .updateCategory(
          id: category.id,
          name: input.name,
          icon: input.icon,
          colorHex: input.colorHex,
        );
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete category?'),
          content: Text('Delete "${category.name}" from active categories?'),
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

    await ref
        .read(categoryManagementProvider.notifier)
        .deleteCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryManagementProvider);
    final state =
        categoryAsync.asData?.value ?? const CategoryManagementState();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: categoryAsync.isLoading ? null : _addCategory,
        tooltip: 'Add category',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space12,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'expense',
                        label: Text('Expense'),
                      ),
                      ButtonSegment<String>(
                        value: 'income',
                        label: Text('Income'),
                      ),
                    ],
                    selected: <String>{state.activeType},
                    onSelectionChanged: categoryAsync.isLoading
                        ? null
                        : (selection) {
                            ref
                                .read(categoryManagementProvider.notifier)
                                .changeType(selection.first);
                          },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Default categories are protected. You can add/edit/delete custom categories.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space8,
                AppTokens.space16,
                0,
              ),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: AppTokens.space8),
          Expanded(
            child: categoryAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.categories.isEmpty
                ? const Center(child: Text('No categories found.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      0,
                      AppTokens.space16,
                      AppTokens.space16,
                    ),
                    itemCount: state.categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = state.categories[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _parseColor(category.colorHex),
                        ),
                        title: Text(category.name),
                        subtitle: Text(
                          category.isDefault
                              ? 'Default category'
                              : 'Custom category',
                        ),
                        trailing: category.isDefault
                            ? const Icon(Icons.lock_outline, size: 18)
                            : Wrap(
                                spacing: AppTokens.space4,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () {
                                      _editCategory(category);
                                    },
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () {
                                      _deleteCategory(category);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialogResult {
  const _CategoryDialogResult({
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  final String name;
  final String icon;
  final String colorHex;
}

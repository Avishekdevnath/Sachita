import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/finance/data/category_repository.dart';
import 'package:sanchita/features/finance/models/category_model.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';

class CategoryManagementState {
  const CategoryManagementState({
    this.activeType = 'expense',
    this.categories = const <CategoryModel>[],
    this.errorMessage,
  });

  final String activeType;
  final List<CategoryModel> categories;
  final String? errorMessage;

  CategoryManagementState copyWith({
    String? activeType,
    List<CategoryModel>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CategoryManagementState(
      activeType: activeType ?? this.activeType,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final categoryManagementProvider =
    AsyncNotifierProvider<CategoryManagementNotifier, CategoryManagementState>(
      CategoryManagementNotifier.new,
    );

class CategoryManagementNotifier
    extends AsyncNotifier<CategoryManagementState> {
  CategoryRepository get _categoryRepository =>
      ref.read(categoryRepositoryProvider);

  @override
  Future<CategoryManagementState> build() async {
    return _loadForType(const CategoryManagementState(activeType: 'expense'));
  }

  Future<void> changeType(String type) async {
    final current = state.asData?.value ?? const CategoryManagementState();
    state = const AsyncLoading();
    state = AsyncData(
      await _loadForType(current.copyWith(activeType: type, clearError: true)),
    );
  }

  Future<void> createCategory({
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final current = state.asData?.value ?? const CategoryManagementState();
    final result = await _categoryRepository.createCategory(
      type: current.activeType,
      name: name,
      icon: icon,
      colorHex: colorHex,
    );

    await result.when(
      success: (_) async {
        ref.invalidate(financeProvider);
        state = const AsyncLoading();
        state = AsyncData(
          await _loadForType(current.copyWith(clearError: true)),
        );
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final current = state.asData?.value ?? const CategoryManagementState();
    final result = await _categoryRepository.updateCategory(
      id: id,
      name: name,
      icon: icon,
      colorHex: colorHex,
    );

    await result.when(
      success: (_) async {
        ref.invalidate(financeProvider);
        state = const AsyncLoading();
        state = AsyncData(
          await _loadForType(current.copyWith(clearError: true)),
        );
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final current = state.asData?.value ?? const CategoryManagementState();
    final result = await _categoryRepository.softDeleteCategory(categoryId);

    await result.when(
      success: (_) async {
        ref.invalidate(financeProvider);
        state = const AsyncLoading();
        state = AsyncData(
          await _loadForType(current.copyWith(clearError: true)),
        );
      },
      failure: (message) async {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value ?? const CategoryManagementState();
    state = const AsyncLoading();
    state = AsyncData(await _loadForType(current.copyWith(clearError: true)));
  }

  Future<CategoryManagementState> _loadForType(
    CategoryManagementState source,
  ) async {
    final result = await _categoryRepository.getCategoriesByType(
      source.activeType,
    );

    return result.when(
      success: (categories) {
        return source.copyWith(categories: categories, clearError: true);
      },
      failure: (message) {
        return source.copyWith(
          categories: const <CategoryModel>[],
          errorMessage: message,
        );
      },
    );
  }
}

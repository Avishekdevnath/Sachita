class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorHex,
    required this.isDefault,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String colorHex;
  final bool isDefault;
  final int sortOrder;

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'expense',
      icon: map['icon'] as String? ?? 'other',
      colorHex: map['color'] as String? ?? '#999999',
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

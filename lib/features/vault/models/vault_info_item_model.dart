class VaultInfoItemModel {
  const VaultInfoItemModel({
    required this.id,
    required this.category,
    required this.label,
    required this.value,
    required this.notes,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String category;
  final String label;
  final String value;
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isCustomCategory {
    final lower = category.trim().toLowerCase();
    return lower != 'ids' &&
        lower != 'finance' &&
        lower != 'medical' &&
        lower != 'general';
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'category': category,
      'label': label,
      'value': value,
      'notes': notes,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VaultInfoItemModel.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final deletedAtRaw = map['deleted_at'] as String?;
    final isDeletedRaw = map['is_deleted'];
    return VaultInfoItemModel(
      id: map['id'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      label: map['label'] as String? ?? '',
      value: map['value'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isDeleted: isDeletedRaw is bool
          ? isDeletedRaw
          : (isDeletedRaw is num ? isDeletedRaw.toInt() == 1 : false),
      deletedAt: deletedAtRaw == null ? null : DateTime.tryParse(deletedAtRaw),
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtRaw) ?? DateTime.now(),
    );
  }

  VaultInfoItemModel copyWith({
    String? category,
    String? label,
    String? value,
    String? notes,
    bool? isDeleted,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return VaultInfoItemModel(
      id: id,
      category: category ?? this.category,
      label: label ?? this.label,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

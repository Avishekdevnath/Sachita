class VaultDocFolderModel {
  const VaultDocFolderModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.sortOrder,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.deletedAt,
    this.itemCount = 0,
    this.latestItemAt,
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final int sortOrder;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final DateTime? deletedAt;
  final int itemCount;
  final DateTime? latestItemAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'icon': icon,
      'color': colorHex,
      'sort_order': sortOrder,
      'is_deleted': isDeleted,
      'group_id': groupId,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VaultDocFolderModel.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final deletedAtRaw = map['deleted_at'] as String?;
    final isDeletedRaw = map['is_deleted'];
    return VaultDocFolderModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String? ?? 'folder',
      colorHex: map['color'] as String? ?? '#4ECDC4',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isDeleted: isDeletedRaw is bool
          ? isDeletedRaw
          : (isDeletedRaw is num ? isDeletedRaw.toInt() == 1 : false),
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtRaw) ?? DateTime.now(),
      groupId: map['group_id'] as String?,
      deletedAt: deletedAtRaw == null ? null : DateTime.tryParse(deletedAtRaw),
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      latestItemAt: DateTime.tryParse(map['latest_item_at'] as String? ?? ''),
    );
  }

  VaultDocFolderModel copyWith({
    String? name,
    String? icon,
    String? colorHex,
    int? sortOrder,
    bool? isDeleted,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? itemCount,
    DateTime? latestItemAt,
    bool clearLatestItemAt = false,
  }) {
    return VaultDocFolderModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      groupId: groupId,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      itemCount: itemCount ?? this.itemCount,
      latestItemAt: clearLatestItemAt
          ? null
          : (latestItemAt ?? this.latestItemAt),
    );
  }
}

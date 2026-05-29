class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.memberCount,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final int memberCount;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActivityAt;

  factory GroupModel.fromMap(Map<String, Object?> map) {
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final lastActivityRaw = map['last_activity_at'] as String?;
    return GroupModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String? ?? 'group',
      colorHex: map['color'] as String? ?? '#4ECDC4',
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtRaw) ?? DateTime.now(),
      lastActivityAt: lastActivityRaw == null
          ? null
          : DateTime.tryParse(lastActivityRaw),
    );
  }
}

class GroupMemberModel {
  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.photoKey,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String groupId;
  final String name;
  final String? photoKey;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupMemberModel.fromMap(Map<String, Object?> map) {
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final photoKeyRaw = (map['photo_key'] as String? ?? '').trim();

    return GroupMemberModel(
      id: map['id'] as String? ?? '',
      groupId: map['group_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      photoKey: photoKeyRaw.isEmpty ? null : photoKeyRaw,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtRaw) ?? DateTime.now(),
    );
  }
}

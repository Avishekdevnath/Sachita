class GroupVaultInfoItemModel {
  const GroupVaultInfoItemModel({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.memberName,
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
  final String groupId;
  final String? memberId;
  final String? memberName;
  final String category;
  final String label;
  final String value;
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isGroupWide => memberId == null || memberId!.trim().isEmpty;

  String get belongsToLabel {
    if (isGroupWide) {
      return 'Group-wide';
    }
    final name = memberName?.trim() ?? '';
    if (name.isEmpty) {
      return 'Member';
    }
    return name;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
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

  factory GroupVaultInfoItemModel.fromMap(
    Map<String, dynamic> map, {
    String? memberName,
  }) {
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final deletedAtRaw = map['deleted_at'] as String?;
    final isDeletedRaw = map['is_deleted'];
    final memberIdRaw = (map['member_id'] as String? ?? '').trim();
    return GroupVaultInfoItemModel(
      id: map['id'] as String? ?? '',
      groupId: map['group_id'] as String? ?? '',
      memberId: memberIdRaw.isEmpty ? null : memberIdRaw,
      memberName: memberName,
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

  GroupVaultInfoItemModel copyWith({
    String? memberId,
    String? memberName,
    String? category,
    String? label,
    String? value,
    String? notes,
    bool? isDeleted,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return GroupVaultInfoItemModel(
      id: id,
      groupId: groupId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
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

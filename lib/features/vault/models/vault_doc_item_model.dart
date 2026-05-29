class VaultDocItemModel {
  const VaultDocItemModel({
    required this.id,
    required this.folderId,
    required this.label,
    required this.imageKey,
    required this.thumbnailKey,
    required this.saveMode,
    required this.outputWidth,
    required this.outputHeight,
    required this.estimatedBytes,
    required this.tags,
    required this.notes,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.deletedAt,
  });

  final String id;
  final String folderId;
  final String label;
  final String imageKey;
  final String thumbnailKey;
  final String saveMode;
  final int outputWidth;
  final int outputHeight;
  final int estimatedBytes;
  final List<String> tags;
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'folder_id': folderId,
      'label': label,
      'image_key': imageKey,
      'thumbnail_key': thumbnailKey,
      'save_mode': saveMode,
      'output_width': outputWidth,
      'output_height': outputHeight,
      'estimated_bytes': estimatedBytes,
      'tags': tags,
      'notes': notes,
      'is_deleted': isDeleted,
      'group_id': groupId,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VaultDocItemModel.fromMap(Map<String, dynamic> map) {
    final isDeletedRaw = map['is_deleted'];
    final tagsRaw = map['tags'];
    final createdAtRaw = map['created_at'] as String? ?? '';
    final updatedAtRaw = map['updated_at'] as String? ?? '';
    final deletedAtRaw = map['deleted_at'] as String?;

    return VaultDocItemModel(
      id: map['id'] as String? ?? '',
      folderId: map['folder_id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      imageKey: map['image_key'] as String? ?? '',
      thumbnailKey: map['thumbnail_key'] as String? ?? '',
      saveMode: map['save_mode'] as String? ?? 'original',
      outputWidth: (map['output_width'] as num?)?.toInt() ?? 0,
      outputHeight: (map['output_height'] as num?)?.toInt() ?? 0,
      estimatedBytes: (map['estimated_bytes'] as num?)?.toInt() ?? 0,
      tags: tagsRaw is List
          ? tagsRaw.whereType<String>().toList(growable: false)
          : const <String>[],
      notes: map['notes'] as String? ?? '',
      isDeleted: isDeletedRaw is bool
          ? isDeletedRaw
          : (isDeletedRaw is num ? isDeletedRaw.toInt() == 1 : false),
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtRaw) ?? DateTime.now(),
      groupId: map['group_id'] as String?,
      deletedAt: deletedAtRaw == null ? null : DateTime.tryParse(deletedAtRaw),
    );
  }
}

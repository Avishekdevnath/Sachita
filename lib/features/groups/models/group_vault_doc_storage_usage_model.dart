class GroupVaultDocStorageUsageModel {
  const GroupVaultDocStorageUsageModel({
    this.folderCount = 0,
    this.itemCount = 0,
    this.metadataBytes = 0,
    this.imagePayloadBytes = 0,
  });

  final int folderCount;
  final int itemCount;
  final int metadataBytes;
  final int imagePayloadBytes;

  int get totalBytes => metadataBytes + imagePayloadBytes;

  GroupVaultDocStorageUsageModel copyWith({
    int? folderCount,
    int? itemCount,
    int? metadataBytes,
    int? imagePayloadBytes,
  }) {
    return GroupVaultDocStorageUsageModel(
      folderCount: folderCount ?? this.folderCount,
      itemCount: itemCount ?? this.itemCount,
      metadataBytes: metadataBytes ?? this.metadataBytes,
      imagePayloadBytes: imagePayloadBytes ?? this.imagePayloadBytes,
    );
  }
}

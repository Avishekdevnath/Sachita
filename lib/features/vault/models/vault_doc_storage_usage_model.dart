class VaultDocStorageUsageModel {
  const VaultDocStorageUsageModel({
    this.folderCount = 0,
    this.itemCount = 0,
    this.metadataBytes = 0,
    this.imagePayloadBytes = 0,
  });

  final int folderCount;
  final int itemCount;
  final int metadataBytes;
  final int imagePayloadBytes;

  int get totalBytes {
    return metadataBytes + imagePayloadBytes;
  }
}

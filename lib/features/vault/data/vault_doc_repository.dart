import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/services/file_image_storage_service.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/features/vault/models/vault_doc_folder_model.dart';
import 'package:sanchita/features/vault/models/vault_doc_item_model.dart';
import 'package:sanchita/features/vault/models/vault_doc_storage_usage_model.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:uuid/uuid.dart';

final vaultDocRepositoryProvider = Provider<VaultDocRepository>((ref) {
  return VaultDocRepository(
    SecureStorageService.instance,
    FileImageStorageService.instance,
  );
});

class VaultDocRepository {
  VaultDocRepository(
    this._secureStorageService,
    this._fileImageStorageService,
  );

  static const Uuid _uuid = Uuid();
  static const String _folderIndexKey = 'vault_doc_index';
  static const String _folderPrefix = 'vault_doc_folder_';
  static const String _itemIndexKey = 'vault_doc_item_index';
  static const String _itemPrefix = 'vault_doc_item_';
  static const String _imagePrefix = 'vault_doc_image_';

  final SecureStorageService _secureStorageService;
  final FileImageStorageService _fileImageStorageService;

  Future<Result<List<VaultDocFolderModel>>> getFolders() async {
    try {
      final folderIds = await _loadOrRebuildFolderIndex();
      final folderStats = await _loadFolderStats();
      final folders = <VaultDocFolderModel>[];

      for (final id in folderIds) {
        final raw = await _secureStorageService.read(_folderKey(id));
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final base = VaultDocFolderModel.fromMap(decoded);
        if (base.isDeleted) {
          continue;
        }

        final stats = folderStats[id];
        folders.add(
          base.copyWith(
            itemCount: stats?.count ?? 0,
            latestItemAt: stats?.latestItemAt,
            clearLatestItemAt: stats?.latestItemAt == null,
          ),
        );
      }

      folders.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) {
          return byOrder;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return Result<List<VaultDocFolderModel>>.success(folders);
    } catch (error) {
      return Result<List<VaultDocFolderModel>>.failure(
        'Failed to load document folders: $error',
      );
    }
  }

  Future<Result<void>> createFolder({
    required String name,
    String icon = 'folder',
    String colorHex = '#4ECDC4',
  }) async {
    try {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        return const Result<void>.failure('Folder name is required.');
      }

      final foldersResult = await getFolders();
      final existingFolders = foldersResult.when(
        success: (items) => items,
        failure: (_) => const <VaultDocFolderModel>[],
      );
      final exists = existingFolders.any(
        (folder) => folder.name.toLowerCase() == normalizedName.toLowerCase(),
      );
      if (exists) {
        return const Result<void>.failure(
          'A folder with this name already exists.',
        );
      }

      final folderIds = await _loadOrRebuildFolderIndex();
      var maxSortOrder = -1;
      for (final id in folderIds) {
        final raw = await _secureStorageService.read(_folderKey(id));
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final folder = VaultDocFolderModel.fromMap(decoded);
        if (!folder.isDeleted && folder.sortOrder > maxSortOrder) {
          maxSortOrder = folder.sortOrder;
        }
      }

      final now = DateTime.now();
      final id = _uuid.v4();
      final folder = VaultDocFolderModel(
        id: id,
        name: normalizedName,
        icon: icon.trim().isEmpty ? 'folder' : icon.trim(),
        colorHex: colorHex.trim().isEmpty ? '#4ECDC4' : colorHex.trim(),
        sortOrder: maxSortOrder + 1,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );

      await _secureStorageService.write(
        key: _folderKey(id),
        value: jsonEncode(folder.toMap()),
      );
      await _appendFolderToIndex(id);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to create folder: $error');
    }
  }

  Future<Result<void>> renameFolder({
    required String id,
    required String name,
  }) async {
    try {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        return const Result<void>.failure('Folder name is required.');
      }

      final raw = await _secureStorageService.read(_folderKey(id));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Folder not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Folder data is invalid.');
      }

      final existing = VaultDocFolderModel.fromMap(decoded);
      if (existing.isDeleted) {
        return const Result<void>.failure('Folder not found.');
      }

      final foldersResult = await getFolders();
      final existingFolders = foldersResult.when(
        success: (items) => items,
        failure: (_) => const <VaultDocFolderModel>[],
      );
      final nameTaken = existingFolders.any(
        (folder) =>
            folder.id != id &&
            folder.name.toLowerCase() == normalizedName.toLowerCase(),
      );
      if (nameTaken) {
        return const Result<void>.failure(
          'A folder with this name already exists.',
        );
      }

      final updated = existing.copyWith(
        name: normalizedName,
        updatedAt: DateTime.now(),
      );
      await _secureStorageService.write(
        key: _folderKey(id),
        value: jsonEncode(updated.toMap()),
      );
      await _ensureFolderInIndex(id);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to rename folder: $error');
    }
  }

  Future<Result<void>> deleteFolder(String id) async {
    try {
      final raw = await _secureStorageService.read(_folderKey(id));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Folder not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Folder data is invalid.');
      }

      final folder = VaultDocFolderModel.fromMap(decoded);
      if (folder.isDeleted) {
        return const Result<void>.success(null);
      }

      final now = DateTime.now();
      final deletedFolder = folder.copyWith(
        isDeleted: true,
        deletedAt: now,
        updatedAt: now,
      );
      await _secureStorageService.write(
        key: _folderKey(id),
        value: jsonEncode(deletedFolder.toMap()),
      );
      await _removeFolderFromIndex(id);
      await _softDeleteItemsForFolder(folderId: id, deletedAt: now);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete folder: $error');
    }
  }

  Future<Result<List<VaultDocItemModel>>> getItemsForFolder(
    String folderId,
  ) async {
    try {
      final normalizedFolderId = folderId.trim();
      if (normalizedFolderId.isEmpty) {
        return const Result<List<VaultDocItemModel>>.success(
          <VaultDocItemModel>[],
        );
      }

      final itemIds = await _loadOrRebuildItemIndex();
      final items = <VaultDocItemModel>[];
      for (final id in itemIds) {
        final raw = await _secureStorageService.read(_itemKey(id));
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final item = VaultDocItemModel.fromMap(decoded);
        if (item.isDeleted || item.folderId != normalizedFolderId) {
          continue;
        }

        items.add(item);
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result<List<VaultDocItemModel>>.success(items);
    } catch (error) {
      return Result<List<VaultDocItemModel>>.failure(
        'Failed to load document items: $error',
      );
    }
  }

  Future<Result<void>> createItem({
    required String folderId,
    required String label,
    required String saveMode,
    required List<String> tags,
    required String notes,
    Uint8List? imageBytes,
  }) async {
    try {
      final normalizedFolderId = folderId.trim();
      final normalizedLabel = label.trim();
      final normalizedMode = saveMode.trim().toLowerCase();
      final normalizedNotes = notes.trim();
      final normalizedTags = tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (normalizedFolderId.isEmpty) {
        return const Result<void>.failure('Folder is required.');
      }
      if (normalizedLabel.isEmpty) {
        return const Result<void>.failure('Document label is required.');
      }
      if (normalizedMode != 'original' &&
          normalizedMode != 'enhanced' &&
          normalizedMode != 'document') {
        return const Result<void>.failure('Invalid save mode.');
      }

      final folderRaw = await _secureStorageService.read(
        _folderKey(normalizedFolderId),
      );
      if (folderRaw == null || folderRaw.isEmpty) {
        return const Result<void>.failure('Folder not found.');
      }

      final now = DateTime.now();
      final itemId = _uuid.v4();
      var imageKey = '';
      var thumbnailKey = '';
      var outputWidth = 0;
      var outputHeight = 0;
      var estimatedBytes = 0;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        _ImagePayload payload;
        try {
          payload = await _buildImagePayload(
            imageBytes: imageBytes,
            saveMode: normalizedMode,
          );
        } catch (error) {
          return Result<void>.failure(
            'Image enhancement failed. Please retry. '
            'If it keeps failing, switch to Original mode. ($error)',
          );
        }

        final outputDecodable = await _isDecodableImage(payload.outputBytes);
        final thumbnailDecodable = await _isDecodableImage(
          payload.thumbnailBytes,
        );
        if (!outputDecodable || !thumbnailDecodable) {
          return const Result<void>.failure(
            'Processed image is not readable. Please retry with another mode.',
          );
        }

        imageKey = '$_imagePrefix${itemId}_full';
        thumbnailKey = '$_imagePrefix${itemId}_thumb';
        outputWidth = payload.outputWidth;
        outputHeight = payload.outputHeight;
        estimatedBytes = payload.estimatedBytes;

        // Write images to file storage (much faster than secure storage)
        await _writeImagePayload(
          imageKey: imageKey,
          imageBytes: payload.outputBytes,
        );
        await _writeImagePayload(
          imageKey: thumbnailKey,
          imageBytes: payload.thumbnailBytes,
        );

        // Verify write was successful
        final fullExists = await _fileImageStorageService.imageExists(imageKey);
        final thumbExists = await _fileImageStorageService.imageExists(thumbnailKey);
        if (!fullExists || !thumbExists) {
          return const Result<void>.failure(
            'Failed to save processed image. Please retry.',
          );
        }
      }

      final item = VaultDocItemModel(
        id: itemId,
        folderId: normalizedFolderId,
        label: normalizedLabel,
        imageKey: imageKey,
        thumbnailKey: thumbnailKey,
        saveMode: normalizedMode,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        estimatedBytes: estimatedBytes,
        tags: normalizedTags,
        notes: normalizedNotes,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );

      await _secureStorageService.write(
        key: _itemKey(itemId),
        value: jsonEncode(item.toMap()),
      );
      await _appendItemToIndex(itemId);

      return const Result<void>.success(null);
    } catch (error) {
      return const Result<void>.failure(
        'Failed to create document item. Please try again.',
      );
    }
  }

  Future<Result<void>> updateItemMetadata({
    required String itemId,
    required String folderId,
    required String label,
    required List<String> tags,
    required String notes,
  }) async {
    try {
      final normalizedItemId = itemId.trim();
      final normalizedFolderId = folderId.trim();
      final normalizedLabel = label.trim();
      final normalizedNotes = notes.trim();
      final normalizedTags = tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (normalizedItemId.isEmpty) {
        return const Result<void>.failure('Document item is required.');
      }
      if (normalizedFolderId.isEmpty) {
        return const Result<void>.failure('Folder is required.');
      }
      if (normalizedLabel.isEmpty) {
        return const Result<void>.failure('Document label is required.');
      }

      final itemRaw = await _secureStorageService.read(
        _itemKey(normalizedItemId),
      );
      if (itemRaw == null || itemRaw.isEmpty) {
        return const Result<void>.failure('Document not found.');
      }

      final itemDecoded = jsonDecode(itemRaw);
      if (itemDecoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Document data is invalid.');
      }

      final existing = VaultDocItemModel.fromMap(itemDecoded);
      if (existing.isDeleted) {
        return const Result<void>.failure('Document not found.');
      }

      final folderRaw = await _secureStorageService.read(
        _folderKey(normalizedFolderId),
      );
      if (folderRaw == null || folderRaw.isEmpty) {
        return const Result<void>.failure('Target folder not found.');
      }
      final folderDecoded = jsonDecode(folderRaw);
      if (folderDecoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Target folder data is invalid.');
      }
      final targetFolder = VaultDocFolderModel.fromMap(folderDecoded);
      if (targetFolder.isDeleted) {
        return const Result<void>.failure('Target folder not found.');
      }

      final updated = existing.toMap()
        ..['folder_id'] = normalizedFolderId
        ..['label'] = normalizedLabel
        ..['tags'] = normalizedTags
        ..['notes'] = normalizedNotes
        ..['updated_at'] = DateTime.now().toIso8601String();

      await _secureStorageService.write(
        key: _itemKey(normalizedItemId),
        value: jsonEncode(updated),
      );
      await _ensureItemInIndex(normalizedItemId);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update document item: $error');
    }
  }

  Future<Result<void>> softDeleteItem(String itemId) async {
    try {
      final normalizedId = itemId.trim();
      if (normalizedId.isEmpty) {
        return const Result<void>.failure('Document item is required.');
      }

      final raw = await _secureStorageService.read(_itemKey(normalizedId));
      if (raw == null || raw.isEmpty) {
        return const Result<void>.failure('Document not found.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Result<void>.failure('Document data is invalid.');
      }

      final existing = VaultDocItemModel.fromMap(decoded);
      if (existing.isDeleted) {
        return const Result<void>.success(null);
      }

      final nowIso = DateTime.now().toIso8601String();
      decoded['is_deleted'] = true;
      decoded['deleted_at'] = nowIso;
      decoded['updated_at'] = nowIso;

      await _secureStorageService.write(
        key: _itemKey(normalizedId),
        value: jsonEncode(decoded),
      );
      await _removeItemFromIndex(normalizedId);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to delete document item: $error');
    }
  }

  Future<Result<VaultDocStorageUsageModel>> getStorageUsage() async {
    try {
      final all = await _secureStorageService.readAll();

      final folderIds = _extractIndexIds(
        indexRaw: all[_folderIndexKey],
        keyPrefix: _folderPrefix,
        allKeys: all.keys,
      );
      final itemIds = _extractIndexIds(
        indexRaw: all[_itemIndexKey],
        keyPrefix: _itemPrefix,
        allKeys: all.keys,
      );

      int activeFolderCount = 0; // ignore: prefer_final_locals
      int activeItemCount = 0; // ignore: prefer_final_locals
      int metadataBytes = 0; // ignore: prefer_final_locals
      int imagePayloadBytes = 0; // ignore: prefer_const_declarations, prefer_final_locals

      for (final id in folderIds) {
        final raw = all[_folderKey(id)];
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final folder = VaultDocFolderModel.fromMap(decoded);
        if (folder.isDeleted) {
          continue;
        }
        activeFolderCount += 1;
        metadataBytes += raw.length;
      }

      for (final id in itemIds) {
        final raw = all[_itemKey(id)];
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final item = VaultDocItemModel.fromMap(decoded);
        if (item.isDeleted) {
          continue;
        }
        activeItemCount += 1;
        metadataBytes += raw.length;

        // Images are now stored in FileImageStorageService, not in secure storage chunks
        // Skip size calculation for legacy chunked image format
        // Future: Calculate sizes from file storage if needed
      }

      return Result<VaultDocStorageUsageModel>.success(
        VaultDocStorageUsageModel(
          folderCount: activeFolderCount,
          itemCount: activeItemCount,
          metadataBytes: metadataBytes,
          imagePayloadBytes: imagePayloadBytes,
        ),
      );
    } catch (error) {
      return Result<VaultDocStorageUsageModel>.failure(
        'Failed to estimate vault storage usage: $error',
      );
    }
  }

  Future<Uint8List?> readImageBytes(String imageKey) async {
    final normalizedKey = imageKey.trim();
    if (normalizedKey.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    return _readImagePayload(normalizedKey);
  }

  Future<_ImagePayload> _buildImagePayload({
    required Uint8List imageBytes,
    required String saveMode,
  }) async {
    final decoded = await _decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Invalid image payload.');
    }

    ui.Image workingImage = decoded;
    try {
      final normalized = await _normalizeOrientationFromExif(
        sourceBytes: imageBytes,
        decodedImage: decoded,
      );
      if (normalized != null) {
        workingImage = normalized;
        decoded.dispose();
      }

      if (saveMode == 'document') {
        try {
          final perspectiveCorrected =
              await _applyPerspectiveCorrectionIfPossible(workingImage);
          if (perspectiveCorrected != null) {
            workingImage.dispose();
            workingImage = perspectiveCorrected;
          }
        } catch (_) {
          // Perspective correction failed - continue with uncorrected image
        }
      }

      final outputBytes = await _buildOutputVariant(
        image: workingImage,
        saveMode: saveMode,
      );
      final outputImage = await _decodeImage(outputBytes);
      if (outputImage == null ||
          outputImage.width <= 0 ||
          outputImage.height <= 0) {
        outputImage?.dispose();
        throw StateError('Invalid processed image dimensions.');
      }
      try {
        final thumbnailBytes = await _buildThumbnailVariant(outputImage);
        final thumbnailImage = await _decodeImage(thumbnailBytes);
        if (thumbnailImage == null ||
            thumbnailImage.width <= 0 ||
            thumbnailImage.height <= 0) {
          throw StateError('Invalid thumbnail output.');
        }
        thumbnailImage.dispose();
        return _ImagePayload(
          outputBytes: outputBytes,
          thumbnailBytes: thumbnailBytes,
          outputWidth: outputImage.width,
          outputHeight: outputImage.height,
          estimatedBytes: outputBytes.length,
        );
      } finally {
        outputImage.dispose();
      }
    } finally {
      workingImage.dispose();
    }
  }

  Future<Uint8List> _buildOutputVariant({
    required ui.Image image,
    required String saveMode,
  }) async {
    if (saveMode == 'original') {
      final bytes = await _encodePng(image);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Original image encoding failed.');
      }
      return bytes;
    }

    if (saveMode == 'enhanced') {
      return _renderVariant(
        image: image,
        targetLongEdge: 2000,
        colorMatrix: _enhancedColorMatrix,
      );
    }

    return _renderVariant(
      image: image,
      targetLongEdge: 1800,
      colorMatrix: _documentColorMatrix,
    );
  }

  Future<Uint8List> _buildThumbnailVariant(ui.Image image) async {
    return _renderVariant(
      image: image,
      targetLongEdge: 360,
      colorMatrix: null,
    );
  }

  Future<Uint8List> _renderVariant({
    required ui.Image image,
    required int targetLongEdge,
    required List<double>? colorMatrix,
  }) async {
    final size = _fitSize(
      width: image.width,
      height: image.height,
      targetLongEdge: targetLongEdge,
    );
    final outputWidth = size.$1;
    final outputHeight = size.$2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    if (colorMatrix != null) {
      paint.colorFilter = ui.ColorFilter.matrix(colorMatrix);
    }

    final sourceRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destinationRect = ui.Rect.fromLTWH(
      0,
      0,
      outputWidth.toDouble(),
      outputHeight.toDouble(),
    );

    canvas.drawRect(
      destinationRect,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.drawImageRect(image, sourceRect, destinationRect, paint);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(outputWidth, outputHeight);
    try {
      final bytes = await _encodePng(rendered);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Processed image encoding failed.');
      }
      return bytes;
    } finally {
      rendered.dispose();
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
    // Defensive null return - validation failed
      return null;
    }
  }

  Future<ui.Image?> _applyPerspectiveCorrectionIfPossible(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
    // Defensive null return - validation failed
      return null;
    }

    final quad = _detectDocumentQuad(
      rgbaBytes: byteData.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
    if (quad == null) {
    // Defensive null return - validation failed
      return null;
    }

    return _warpDocumentQuadToRect(image: image, quad: quad);
  }

  _DocumentQuad? _detectDocumentQuad({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) {
    if (width < 80 || height < 80) {
    // Defensive null return - validation failed
      return null;
    }

    final background = _estimateBackgroundColor(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
    );
    final minSpanWidth = width * _documentForegroundMinWidthRatio;

    int? topY;
    int? bottomY;
    int? topLeftX;
    int? topRightX;
    int? bottomLeftX;
    int? bottomRightX;

    for (var y = 0; y < height; y++) {
      final span = _foregroundSpanForRow(
        y: y,
        rgbaBytes: rgbaBytes,
        width: width,
        background: background,
      );
      if (span == null) {
        continue;
      }
      final spanWidth = span.$2 - span.$1 + 1;
      if (spanWidth >= minSpanWidth) {
        topY = y;
        topLeftX = span.$1;
        topRightX = span.$2;
        break;
      }
    }

    for (var y = height - 1; y >= 0; y--) {
      final span = _foregroundSpanForRow(
        y: y,
        rgbaBytes: rgbaBytes,
        width: width,
        background: background,
      );
      if (span == null) {
        continue;
      }
      final spanWidth = span.$2 - span.$1 + 1;
      if (spanWidth >= minSpanWidth) {
        bottomY = y;
        bottomLeftX = span.$1;
        bottomRightX = span.$2;
        break;
      }
    }

    if (topY == null ||
        bottomY == null ||
        topLeftX == null ||
        topRightX == null ||
        bottomLeftX == null ||
        bottomRightX == null) {
    // Defensive null return - validation failed
      return null;
    }

    final verticalSpan = bottomY - topY;
    if (verticalSpan < height * 0.25) {
    // Defensive null return - validation failed
      return null;
    }

    final topWidth = topRightX - topLeftX;
    final bottomWidth = bottomRightX - bottomLeftX;
    if (topWidth < width * 0.25 || bottomWidth < width * 0.25) {
    // Defensive null return - validation failed
      return null;
    }

    return _DocumentQuad(
      topLeft: ui.Offset(topLeftX.toDouble(), topY.toDouble()),
      topRight: ui.Offset(topRightX.toDouble(), topY.toDouble()),
      bottomRight: ui.Offset(bottomRightX.toDouble(), bottomY.toDouble()),
      bottomLeft: ui.Offset(bottomLeftX.toDouble(), bottomY.toDouble()),
    );
  }

  ({int r, int g, int b}) _estimateBackgroundColor({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) {
    const sampleSize = 10;
    final points = <(int, int)>[
      (0, 0),
      (width - 1, 0),
      (0, height - 1),
      (width - 1, height - 1),
    ];

    var totalR = 0;
    var totalG = 0;
    var totalB = 0;
    var count = 0;

    for (final point in points) {
      final startX = point.$1 == 0 ? 0 : width - sampleSize;
      final startY = point.$2 == 0 ? 0 : height - sampleSize;
      for (var y = startY; y < startY + sampleSize; y++) {
        for (var x = startX; x < startX + sampleSize; x++) {
          final pixelOffset = ((y * width) + x) * 4;
          totalR += rgbaBytes[pixelOffset];
          totalG += rgbaBytes[pixelOffset + 1];
          totalB += rgbaBytes[pixelOffset + 2];
          count++;
        }
      }
    }

    if (count == 0) {
      return (r: 255, g: 255, b: 255);
    }
    return (
      r: (totalR / count).round(),
      g: (totalG / count).round(),
      b: (totalB / count).round(),
    );
  }

  (int, int)? _foregroundSpanForRow({
    required int y,
    required Uint8List rgbaBytes,
    required int width,
    required ({int r, int g, int b}) background,
  }) {
    int? left;
    int? right;
    for (var x = 0; x < width; x++) {
      final pixelOffset = ((y * width) + x) * 4;
      final r = rgbaBytes[pixelOffset];
      final g = rgbaBytes[pixelOffset + 1];
      final b = rgbaBytes[pixelOffset + 2];
      final distance = (r - background.r).abs() +
          (g - background.g).abs() +
          (b - background.b).abs();
      if (distance < _documentForegroundColorDistanceThreshold) {
        continue;
      }

      left ??= x;
      right = x;
    }

    if (left == null || right == null) {
    // Defensive null return - validation failed
      return null;
    }
    return (left, right);
  }

  Future<ui.Image?> _warpDocumentQuadToRect({
    required ui.Image image,
    required _DocumentQuad quad,
  }) async {
    final topWidth = (quad.topRight - quad.topLeft).distance;
    final bottomWidth = (quad.bottomRight - quad.bottomLeft).distance;
    final leftHeight = (quad.bottomLeft - quad.topLeft).distance;
    final rightHeight = (quad.bottomRight - quad.topRight).distance;

    final outputWidth = ((topWidth + bottomWidth) / 2)
        .round()
        .clamp(1, image.width)
        .toInt();
    final outputHeight = ((leftHeight + rightHeight) / 2)
        .round()
        .clamp(1, image.height)
        .toInt();

    if (outputWidth < 16 || outputHeight < 16) {
    // Defensive null return - validation failed
      return null;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList(<double>[
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
    );

    final paint = ui.Paint()
      ..shader = shader
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      <ui.Offset>[
        const ui.Offset(0, 0),
        ui.Offset(outputWidth.toDouble(), 0),
        ui.Offset(outputWidth.toDouble(), outputHeight.toDouble()),
        const ui.Offset(0, 0),
        ui.Offset(outputWidth.toDouble(), outputHeight.toDouble()),
        ui.Offset(0, outputHeight.toDouble()),
      ],
      textureCoordinates: <ui.Offset>[
        quad.topLeft,
        quad.topRight,
        quad.bottomRight,
        quad.topLeft,
        quad.bottomRight,
        quad.bottomLeft,
      ],
    );

    canvas.drawVertices(vertices, ui.BlendMode.srcOver, paint);

    final picture = recorder.endRecording();
    final transformed = await picture.toImage(outputWidth, outputHeight);
    return transformed;
  }

  Future<ui.Image?> _normalizeOrientationFromExif({
    required Uint8List sourceBytes,
    required ui.Image decodedImage,
  }) async {
    final orientation = _readExifOrientation(sourceBytes);
    if (orientation == null || orientation == 1) {
    // Defensive null return - validation failed
      return null;
    }

    return _transformExifOrientation(
      decodedImage: decodedImage,
      orientation: orientation,
    );
  }

  Future<ui.Image?> _transformExifOrientation({
    required ui.Image decodedImage,
    required int orientation,
  }) async {
    if (orientation != 2 &&
        orientation != 3 &&
        orientation != 4 &&
        orientation != 5 &&
        orientation != 6 &&
        orientation != 7 &&
        orientation != 8) {
    // Defensive null return - validation failed
      return null;
    }

    final swapAxes =
        orientation == 5 || orientation == 6 || orientation == 7 || orientation == 8;
    final outputWidth = swapAxes ? decodedImage.height : decodedImage.width;
    final outputHeight = swapAxes ? decodedImage.width : decodedImage.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    switch (orientation) {
      case 2:
        canvas.translate(outputWidth.toDouble(), 0);
        canvas.scale(-1, 1);
        break;
      case 3:
        canvas.translate(outputWidth.toDouble(), outputHeight.toDouble());
        canvas.rotate(math.pi);
        break;
      case 4:
        canvas.translate(0, outputHeight.toDouble());
        canvas.scale(1, -1);
        break;
      case 5:
        canvas.translate(outputWidth.toDouble(), 0);
        canvas.rotate(math.pi / 2);
        canvas.scale(-1, 1);
        break;
      case 6:
        canvas.translate(outputWidth.toDouble(), 0);
        canvas.rotate(math.pi / 2);
        break;
      case 7:
        canvas.translate(0, outputHeight.toDouble());
        canvas.rotate(-math.pi / 2);
        canvas.scale(-1, 1);
        break;
      case 8:
        canvas.translate(0, outputHeight.toDouble());
        canvas.rotate(-math.pi / 2);
        break;
      default:
        break;
    }

    canvas.drawImage(decodedImage, ui.Offset.zero, paint);
    final picture = recorder.endRecording();
    final transformed = await picture.toImage(outputWidth, outputHeight);
    return transformed;
  }

  int? _readExifOrientation(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    // Defensive null return - validation failed
      return null;
    }

    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final marker = bytes[offset + 1];
      offset += 2;
      if (marker == 0xDA || marker == 0xD9) {
        break;
      }
      if (offset + 2 > bytes.length) {
        break;
      }

      final segmentLength = _readUint16BigEndian(bytes, offset);
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        break;
      }

      if (marker == 0xE1) {
        final exifStart = offset + 2;
        final exifEnd = offset + segmentLength;
        final orientation = _readOrientationFromExifSegment(
          bytes: bytes,
          start: exifStart,
          end: exifEnd,
        );
        if (orientation != null) {
          return orientation;
        }
      }

      offset += segmentLength;
    }
    // Defensive null return - validation failed
    return null;
  }

  int? _readOrientationFromExifSegment({
    required Uint8List bytes,
    required int start,
    required int end,
  }) {
    if (start + 14 > end) {
    // Defensive null return - validation failed
      return null;
    }

    final hasExifHeader =
        bytes[start] == 0x45 &&
        bytes[start + 1] == 0x78 &&
        bytes[start + 2] == 0x69 &&
        bytes[start + 3] == 0x66 &&
        bytes[start + 4] == 0x00 &&
        bytes[start + 5] == 0x00;
    if (!hasExifHeader) {
    // Defensive null return - validation failed
      return null;
    }

    final tiffStart = start + 6;
    if (tiffStart + 8 > end) {
    // Defensive null return - validation failed
      return null;
    }

    final littleEndian = bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49;
    final bigEndian = bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D;
    if (!littleEndian && !bigEndian) {
    // Defensive null return - validation failed
      return null;
    }

    final fixed42 = _readUint16(
      bytes: bytes,
      offset: tiffStart + 2,
      littleEndian: littleEndian,
    );
    if (fixed42 != 42) {
    // Defensive null return - validation failed
      return null;
    }

    final ifd0Offset = _readUint32(
      bytes: bytes,
      offset: tiffStart + 4,
      littleEndian: littleEndian,
    );
    final ifd0Start = tiffStart + ifd0Offset;
    if (ifd0Start + 2 > end) {
    // Defensive null return - validation failed
      return null;
    }

    final entryCount = _readUint16(
      bytes: bytes,
      offset: ifd0Start,
      littleEndian: littleEndian,
    );
    for (var i = 0; i < entryCount; i++) {
      final entryOffset = ifd0Start + 2 + i * 12;
      if (entryOffset + 12 > end) {
        break;
      }

      final tag = _readUint16(
        bytes: bytes,
        offset: entryOffset,
        littleEndian: littleEndian,
      );
      if (tag != 0x0112) {
        continue;
      }

      final type = _readUint16(
        bytes: bytes,
        offset: entryOffset + 2,
        littleEndian: littleEndian,
      );
      final count = _readUint32(
        bytes: bytes,
        offset: entryOffset + 4,
        littleEndian: littleEndian,
      );
      if (type != 3 || count < 1) {
    // Defensive null return - validation failed
        return null;
      }

      if (count == 1) {
        final value = _readUint16(
          bytes: bytes,
          offset: entryOffset + 8,
          littleEndian: littleEndian,
        );
        return value;
      }

      final valueOffset = _readUint32(
        bytes: bytes,
        offset: entryOffset + 8,
        littleEndian: littleEndian,
      );
      final actualOffset = tiffStart + valueOffset;
      if (actualOffset + 2 > end) {
    // Defensive null return - validation failed
        return null;
      }

      return _readUint16(
        bytes: bytes,
        offset: actualOffset,
        littleEndian: littleEndian,
      );
    }

    // Defensive null return - validation failed
    return null;
  }

  int _readUint16BigEndian(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int _readUint16({
    required Uint8List bytes,
    required int offset,
    required bool littleEndian,
  }) {
    if (littleEndian) {
      return bytes[offset] | (bytes[offset + 1] << 8);
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int _readUint32({
    required Uint8List bytes,
    required int offset,
    required bool littleEndian,
  }) {
    if (littleEndian) {
      return bytes[offset] |
          (bytes[offset + 1] << 8) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 24);
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  Future<Uint8List?> _encodePng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
    // Defensive null return - validation failed
      return null;
    }
    return byteData.buffer.asUint8List();
  }

  (int, int) _fitSize({
    required int width,
    required int height,
    required int targetLongEdge,
  }) {
    if (width <= 0 || height <= 0) {
      return (1, 1);
    }
    final longEdge = width > height ? width : height;
    if (longEdge <= targetLongEdge) {
      return (width, height);
    }

    final ratio = targetLongEdge / longEdge;
    var nextWidth = (width * ratio).round();
    var nextHeight = (height * ratio).round();
    if (nextWidth < 1) {
      nextWidth = 1;
    } else if (nextWidth > width) {
      nextWidth = width;
    }
    if (nextHeight < 1) {
      nextHeight = 1;
    } else if (nextHeight > height) {
      nextHeight = height;
    }
    return (nextWidth, nextHeight);
  }

  /// Write image bytes directly to file storage (no chunking needed)
  Future<void> _writeImagePayload({
    required String imageKey,
    required Uint8List imageBytes,
  }) async {
    try {
      await _fileImageStorageService.saveImage(
        imageKey: imageKey,
        bytes: imageBytes,
      );
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  /// Read image bytes from file storage, with fallback to legacy secure storage.
  /// Normalizes EXIF orientation for consistency across saved and legacy images.
  Future<Uint8List?> _readImagePayload(String imageKey) async {
    // Try file storage first (current format)
    try {
      final fileBytes = await _fileImageStorageService.loadImage(imageKey);
      if (fileBytes != null && fileBytes.isNotEmpty) {
        // Normalize orientation for consistent display
        return await _normalizeOrientationForDisplay(fileBytes);
      }
    } catch (_) {
      // Fall through to legacy lookup
    }

    // Fallback: try legacy secure storage (plain or chunked base64)
    try {
      final base64Value = await _readLegacyChunkedPayload(imageKey);
      if (base64Value == null || base64Value.isEmpty) {
        return null;
      }

      final bytes = base64Decode(base64Value);
      if (bytes.isEmpty) {
        return null;
      }

      // Normalize orientation before display or migration
      final normalizedBytes = await _normalizeOrientationForDisplay(bytes);
      if (normalizedBytes == null) {
        return bytes;
      }

      // Migrate normalized bytes to file storage for future reads
      try {
        await _fileImageStorageService.saveImage(
          imageKey: imageKey,
          bytes: normalizedBytes,
        );
      } catch (_) {
        // Migration failed but we still have the normalized bytes - return them
      }

      return normalizedBytes;
    } catch (_) {
      return null;
    }
  }

  /// Normalize EXIF orientation for consistent display across all images.
  Future<Uint8List?> _normalizeOrientationForDisplay(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return bytes;
    }
    try {
      final decoded = await _decodeImage(bytes);
      if (decoded == null) {
        return bytes; // Not decodable, return as-is
      }

      final orientation = _readExifOrientation(bytes);
      if (orientation == null || orientation == 1) {
        decoded.dispose();
        return bytes; // No rotation needed
      }

      final normalized = await _transformExifOrientation(
        decodedImage: decoded,
        orientation: orientation,
      );
      decoded.dispose();
      if (normalized == null) {
        return bytes;
      }

      final normalizedBytes = await _encodePng(normalized);
      normalized.dispose();
      return normalizedBytes ?? bytes;
    } catch (_) {
      return bytes; // Fallback to original if normalization fails
    }
  }

  /// Read legacy chunked payload from secure storage.
  /// Old images were stored as base64 strings, either directly or split into
  /// chunks when they exceeded 3000 characters.
  Future<String?> _readLegacyChunkedPayload(String baseKey) async {
    final base = await _secureStorageService.read(baseKey);
    if (base == null || base.isEmpty) {
      return null;
    }

    // Small image stored as single base64 string
    if (base != '__chunked__') {
      return base;
    }

    // Large image stored in chunks
    final rawCount = await _secureStorageService.read(
      '${baseKey}__chunk_count',
    );
    final count = int.tryParse(rawCount ?? '');
    if (count == null || count <= 0) {
      return null;
    }

    final buffer = StringBuffer();
    for (var index = 0; index < count; index++) {
      final chunk = await _secureStorageService.read(
        '${baseKey}__chunk_$index',
      );
      if (chunk == null) {
        return null;
      }
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<bool> _isDecodableImage(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return false;
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, _FolderStats>> _loadFolderStats() async {
    final itemIds = await _loadOrRebuildItemIndex();
    final stats = <String, _FolderStats>{};
    for (final id in itemIds) {
      final raw = await _secureStorageService.read(_itemKey(id));
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final isDeletedRaw = decoded['is_deleted'];
      final isDeleted = isDeletedRaw is bool
          ? isDeletedRaw
          : (isDeletedRaw is num ? isDeletedRaw.toInt() == 1 : false);
      if (isDeleted) {
        continue;
      }

      final folderId = (decoded['folder_id'] as String? ?? '').trim();
      if (folderId.isEmpty) {
        continue;
      }

      final createdAt = DateTime.tryParse(
        decoded['created_at'] as String? ?? '',
      );
      final existing = stats[folderId];
      if (existing == null) {
        stats[folderId] = _FolderStats(count: 1, latestItemAt: createdAt);
      } else {
        final nextLatest = _later(existing.latestItemAt, createdAt);
        stats[folderId] = _FolderStats(
          count: existing.count + 1,
          latestItemAt: nextLatest,
        );
      }
    }

    return stats;
  }

  Future<void> _softDeleteItemsForFolder({
    required String folderId,
    required DateTime deletedAt,
  }) async {
    final itemIds = await _loadOrRebuildItemIndex();
    final remainingIds = <String>[];
    for (final id in itemIds) {
      final raw = await _secureStorageService.read(_itemKey(id));
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final itemFolderId = decoded['folder_id'] as String? ?? '';
      if (itemFolderId != folderId) {
        remainingIds.add(id);
        continue;
      }

      decoded['is_deleted'] = true;
      decoded['deleted_at'] = deletedAt.toIso8601String();
      decoded['updated_at'] = deletedAt.toIso8601String();
      await _secureStorageService.write(
        key: _itemKey(id),
        value: jsonEncode(decoded),
      );
    }

    await _writeItemIndex(remainingIds);
  }

  Future<List<String>> _loadOrRebuildFolderIndex() async {
    final raw = await _secureStorageService.read(_folderIndexKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
      }
    }

    final all = await _secureStorageService.readAll();
    final ids = all.keys
        .where((key) => key.startsWith(_folderPrefix) && key != _folderIndexKey)
        .map((key) => key.substring(_folderPrefix.length))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    await _writeFolderIndex(ids);
    return ids;
  }

  Future<List<String>> _loadOrRebuildItemIndex() async {
    final raw = await _secureStorageService.read(_itemIndexKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
      }
    }

    final all = await _secureStorageService.readAll();
    final ids = all.keys
        .where((key) => key.startsWith(_itemPrefix) && key != _itemIndexKey)
        .map((key) => key.substring(_itemPrefix.length))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    await _writeItemIndex(ids);
    return ids;
  }

  Future<void> _appendFolderToIndex(String id) async {
    final ids = await _loadOrRebuildFolderIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeFolderIndex(<String>[...ids, id]);
  }

  Future<void> _ensureFolderInIndex(String id) async {
    final ids = await _loadOrRebuildFolderIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeFolderIndex(<String>[...ids, id]);
  }

  Future<void> _removeFolderFromIndex(String id) async {
    final ids = await _loadOrRebuildFolderIndex();
    final next = ids.where((current) => current != id).toList(growable: false);
    await _writeFolderIndex(next);
  }

  Future<void> _appendItemToIndex(String id) async {
    final ids = await _loadOrRebuildItemIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeItemIndex(<String>[...ids, id]);
  }

  Future<void> _ensureItemInIndex(String id) async {
    final ids = await _loadOrRebuildItemIndex();
    if (ids.contains(id)) {
      return;
    }
    await _writeItemIndex(<String>[...ids, id]);
  }

  Future<void> _removeItemFromIndex(String id) async {
    final ids = await _loadOrRebuildItemIndex();
    final next = ids.where((current) => current != id).toList(growable: false);
    await _writeItemIndex(next);
  }

  Future<void> _writeFolderIndex(List<String> ids) async {
    await _secureStorageService.write(
      key: _folderIndexKey,
      value: jsonEncode(ids),
    );
  }

  Future<void> _writeItemIndex(List<String> ids) async {
    await _secureStorageService.write(
      key: _itemIndexKey,
      value: jsonEncode(ids),
    );
  }

  static DateTime? _later(DateTime? first, DateTime? second) {
    if (first == null) {
      return second;
    }
    if (second == null) {
      return first;
    }
    return first.isAfter(second) ? first : second;
  }

  static String _folderKey(String id) => '$_folderPrefix$id';
  static String _itemKey(String id) => '$_itemPrefix$id';

  static const List<double> _enhancedColorMatrix = <double>[
    1.08, 0, 0, 0, 0,
    0, 1.08, 0, 0, 0,
    0, 0, 1.08, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _documentColorMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];
  static const double _documentForegroundMinWidthRatio = 0.30;
  static const int _documentForegroundColorDistanceThreshold = 34;

  static List<String> _extractIndexIds({
    required String? indexRaw,
    required String keyPrefix,
    required Iterable<String> allKeys,
  }) {
    if (indexRaw != null && indexRaw.isNotEmpty) {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty && id != 'index')
            .toList(growable: false);
      }
    }

    return allKeys
        .where((key) => key.startsWith(keyPrefix))
        .map((key) => key.substring(keyPrefix.length))
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != 'index')
        .toList(growable: false);
  }
}

class _ImagePayload {
  const _ImagePayload({
    required this.outputBytes,
    required this.thumbnailBytes,
    required this.outputWidth,
    required this.outputHeight,
    required this.estimatedBytes,
  });

  final Uint8List outputBytes;
  final Uint8List thumbnailBytes;
  final int outputWidth;
  final int outputHeight;
  final int estimatedBytes;
}

class _DocumentQuad {
  const _DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ui.Offset topLeft;
  final ui.Offset topRight;
  final ui.Offset bottomRight;
  final ui.Offset bottomLeft;
}

class _FolderStats {
  const _FolderStats({required this.count, required this.latestItemAt});

  final int count;
  final DateTime? latestItemAt;
}

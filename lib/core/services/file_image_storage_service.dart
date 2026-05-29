import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// High-performance file-based image storage service optimized for vault documents.
/// Stores images directly to app private storage instead of secure storage,
/// avoiding the overhead of base64 encoding and chunking.
class FileImageStorageService {
  FileImageStorageService._();

  static final FileImageStorageService instance = FileImageStorageService._();

  late Directory _imageDir;
  bool _initialized = false;

  /// Initialize the image storage directory
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _imageDir = Directory('${appDir.path}/vault_images');

      if (!await _imageDir.exists()) {
        await _imageDir.create(recursive: true);
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize image storage: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Save image bytes to file storage
  /// Returns the file path for reference in metadata
  Future<String> saveImage({
    required String imageKey,
    required Uint8List bytes,
  }) async {
    await _ensureInitialized();

    try {
      final file = File('${_imageDir.path}/$imageKey');

      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Write image file
      await file.writeAsBytes(bytes, flush: true);

      return imageKey;
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  /// Load image bytes from file storage
  Future<Uint8List?> loadImage(String imageKey) async {
    await _ensureInitialized();

    try {
      final file = File('${_imageDir.path}/$imageKey');

      if (!await file.exists()) {
    // Defensive null return - validation failed
        return null;
      }

      return file.readAsBytes();
    } catch (e) {
      if (kDebugMode) print('Error loading image: $e');
    // Defensive null return - validation failed
      return null;
    }
  }

  /// Load image as File object (useful for direct streaming)
  Future<File?> getImageFile(String imageKey) async {
    await _ensureInitialized();

    try {
      final file = File('${_imageDir.path}/$imageKey');

      if (!await file.exists()) {
    // Defensive null return - validation failed
        return null;
      }

      return file;
    } catch (e) {
      if (kDebugMode) print('Error getting image file: $e');
    // Defensive null return - validation failed
      return null;
    }
  }

  /// Delete a single image file
  Future<void> deleteImage(String imageKey) async {
    await _ensureInitialized();

    try {
      final file = File('${_imageDir.path}/$imageKey');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log but don't throw - deletion failures shouldn't crash the app
    }
  }

  /// Delete multiple images
  Future<void> deleteImages(List<String> imageKeys) async {
    await _ensureInitialized();

    for (final key in imageKeys) {
      await deleteImage(key);
    }
  }

  /// Get storage usage statistics
  Future<int> getStorageUsageBytes() async {
    await _ensureInitialized();

    try {
      int total = 0;
      final files = _imageDir.listSync(recursive: true);

      for (final entity in files) {
        if (entity is File) {
          total += await entity.length();
        }
      }

      return total;
    } catch (e) {
      if (kDebugMode) print('Error calculating storage usage: $e');
      return 0;
    }
  }

  /// Clear all images (useful for cleanup/reset)
  Future<void> clearAllImages() async {
    await _ensureInitialized();

    try {
      if (await _imageDir.exists()) {
        await _imageDir.delete(recursive: true);
        await _imageDir.create(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to clear images: $e');
    }
  }

  /// Check if an image exists
  Future<bool> imageExists(String imageKey) async {
    await _ensureInitialized();

    try {
      final file = File('${_imageDir.path}/$imageKey');
      return await file.exists();
    } catch (e) {
      if (kDebugMode) print('Error checking image existence: $e');
      return false;
    }
  }
}

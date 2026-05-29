import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Isolate-based image processing service to prevent main thread jank.
/// Heavy image transformations run in a background isolate.
class ImageProcessingIsolateService {
  ImageProcessingIsolateService._();

  static final ImageProcessingIsolateService instance =
      ImageProcessingIsolateService._();

  static const int _targetThumbnailSize = 200;
  static const int _maxEnhancedDimension = 1200;

  /// Process image in background isolate
  /// Returns processed (output) and thumbnail bytes
  Future<({Uint8List outputBytes, Uint8List thumbnailBytes, int width, int height})>
      processImage({
    required Uint8List inputBytes,
    required String mode, // 'original', 'enhanced', 'document'
  }) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _imageProcessingEntryPoint,
      (
        sendPort: receivePort.sendPort,
        inputBytes: inputBytes,
        mode: mode,
      ),
    );

    final result = await receivePort.first as Map<String, dynamic>;

    if (result['error'] != null) {
      throw Exception(result['error']);
    }

    return (
      outputBytes: result['outputBytes'] as Uint8List,
      thumbnailBytes: result['thumbnailBytes'] as Uint8List,
      width: result['width'] as int,
      height: result['height'] as int,
    );
  }

  static void _imageProcessingEntryPoint(
    ({
      SendPort sendPort,
      Uint8List inputBytes,
      String mode,
    }) params,
  ) {
    try {
      final inputImage = img.decodeImage(params.inputBytes);
      if (inputImage == null) {
        params.sendPort.send({'error': 'Failed to decode input image'});
        return;
      }

      late img.Image processedImage;
      switch (params.mode) {
        case 'enhanced':
          processedImage = _enhanceImage(inputImage);
        case 'document':
          processedImage = _prepareDocumentMode(inputImage);
        default: // 'original'
          processedImage = inputImage;
      }

      // Generate thumbnail
      final thumbnail = img.copyResize(
        processedImage,
        width: _targetThumbnailSize,
        height: _targetThumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      final outputBytes = Uint8List.fromList(img.encodeJpg(processedImage));
      final thumbnailBytes = Uint8List.fromList(img.encodeJpg(thumbnail));

      params.sendPort.send({
        'outputBytes': outputBytes,
        'thumbnailBytes': thumbnailBytes,
        'width': processedImage.width,
        'height': processedImage.height,
        'error': null,
      });
    } catch (e) {
      params.sendPort.send({'error': 'Image processing failed: $e'});
    }
  }

  static img.Image _enhanceImage(img.Image source) {
    var result = source;

    // Auto-level (histogram equalization equivalent)
    result = img.adjustColor(
      result,
      saturation: 1.15,
      contrast: 1.1,
    );

    // Constrain dimensions to prevent excessive processing
    if (result.width > _maxEnhancedDimension ||
        result.height > _maxEnhancedDimension) {
      final maxDim = math.max(result.width, result.height);
      final scale = _maxEnhancedDimension / maxDim;
      result = img.copyResize(
        result,
        width: (result.width * scale).toInt(),
        height: (result.height * scale).toInt(),
        interpolation: img.Interpolation.linear,
      );
    }

    return result;
  }

  static img.Image _prepareDocumentMode(img.Image source) {
    var result = source;

    // Increase contrast for document scans
    result = img.adjustColor(
      result,
      contrast: 1.3,
      saturation: 0.5, // Reduce color saturation for cleaner documents
    );

    // Constrain dimensions
    if (result.width > _maxEnhancedDimension ||
        result.height > _maxEnhancedDimension) {
      final maxDim = math.max(result.width, result.height);
      final scale = _maxEnhancedDimension / maxDim;
      result = img.copyResize(
        result,
        width: (result.width * scale).toInt(),
        height: (result.height * scale).toInt(),
        interpolation: img.Interpolation.linear,
      );
    }

    return result;
  }
}

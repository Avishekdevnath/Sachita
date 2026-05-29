import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:share_plus/share_plus.dart';

final documentFileActionServiceProvider = Provider<DocumentFileActionService>((
  ref,
) {
  return const DocumentFileActionService();
});

class DocumentFileActionService {
  const DocumentFileActionService();
  static const MethodChannel _downloadsChannel = MethodChannel(
    'sanchita/downloads_export',
  );
  static const Duration _tempExportMaxAge = Duration(hours: 12);
  static const int _tempExportMaxFiles = 20;

  Future<Result<String>> exportImage({
    required Uint8List imageBytes,
    required String label,
    required String folderName,
  }) async {
    if (imageBytes.isEmpty) {
      return const Result<String>.failure('Document image is empty.');
    }

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeLabel = _sanitizeSegment(label);
      final fileName = '${safeLabel}_$timestamp.png';
      final safeFolder = _sanitizeFolderSegment(folderName);

      if (Platform.isAndroid) {
        final androidExportResult = await _exportToAndroidDownloads(
          imageBytes: imageBytes,
          fileName: fileName,
          folderPath: 'sanchita/vault/$safeFolder',
        );
        if (androidExportResult is Success<String>) {
          return androidExportResult;
        }
        return Result<String>.failure(
          (androidExportResult as Failure<String>).message,
        );
      }

      final directory = await _resolveDownloadsRoot();
      final exportDirectory = Directory(
        join(directory.path, 'sanchita', 'vault', safeFolder),
      );
      if (!await exportDirectory.exists()) {
        await exportDirectory.create(recursive: true);
      }
      final file = File(join(exportDirectory.path, fileName));
      await file.writeAsBytes(imageBytes, flush: true);
      return Result<String>.success(file.path);
    } catch (error) {
      return Result<String>.failure('Failed to export image: $error');
    }
  }

  Future<Result<String>> _exportToAndroidDownloads({
    required Uint8List imageBytes,
    required String fileName,
    required String folderPath,
  }) async {
    try {
      final savedLocation = await _downloadsChannel.invokeMethod<String>(
        'saveImageToDownloads',
        <String, Object>{
          'fileName': fileName,
          'folderPath': folderPath,
          'bytes': imageBytes,
        },
      );
      if (savedLocation == null || savedLocation.trim().isEmpty) {
        return const Result<String>.failure(
          'Export succeeded but no file location was returned.',
        );
      }
      return Result<String>.success(savedLocation);
    } on PlatformException catch (error) {
      return Result<String>.failure(
        'Failed to export to Downloads: ${error.message ?? error.code}',
      );
    } catch (error) {
      return Result<String>.failure('Failed to export to Downloads: $error');
    }
  }

  Future<Result<void>> shareImage({
    required Uint8List imageBytes,
    required String label,
    required String namespace,
  }) async {
    if (imageBytes.isEmpty) {
      return const Result<void>.failure('Document image is empty.');
    }

    try {
      final tempPath = await _writeTempImage(
        imageBytes: imageBytes,
        label: label,
        namespace: namespace,
      );

      await Share.shareXFiles(
        <XFile>[XFile(tempPath)],
        text: 'Shared from Sanchita: $label',
      );
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to share image: $error');
    }
  }

  Future<Result<void>> printImage({
    required Uint8List imageBytes,
    required String label,
  }) async {
    if (imageBytes.isEmpty) {
      return const Result<void>.failure('Document image is empty.');
    }

    try {
      final document = pw.Document();
      final memoryImage = pw.MemoryImage(imageBytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name: '${_sanitizeSegment(label)}.pdf',
        onLayout: (format) async => document.save(),
      );
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to print image: $error');
    }
  }

  Future<String> _writeTempImage({
    required Uint8List imageBytes,
    required String label,
    required String namespace,
  }) async {
    final temporaryRoot = await getTemporaryDirectory();
    final segment = _sanitizeSegment(namespace);
    final fileName =
        '${_sanitizeSegment(label)}_${DateTime.now().millisecondsSinceEpoch}.png';
    final namespaceDirectory = Directory(join(temporaryRoot.path, segment));
    await namespaceDirectory.create(recursive: true);
    await _cleanupOldTempExports(namespaceDirectory);
    final file = File(join(namespaceDirectory.path, fileName));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return file.path;
  }

  Future<void> _cleanupOldTempExports(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return;
      }
      final entities = await directory.list().toList();
      final files = entities.whereType<File>().toList(growable: false);
      if (files.isEmpty) {
        return;
      }

      final now = DateTime.now();
      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });

      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final modified = (await file.stat()).modified;
        final tooOld = now.difference(modified) > _tempExportMaxAge;
        final overLimit = index >= _tempExportMaxFiles;
        if (!tooOld && !overLimit) {
          continue;
        }
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    } catch (_) {
      // Ignore cleanup failure to avoid blocking share/export flow.
    }
  }

  Future<Directory> _resolveDownloadsRoot() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }

    if (Platform.isAndroid) {
      const candidates = <String>[
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ];
      for (final candidate in candidates) {
        final dir = Directory(candidate);
        if (await dir.exists()) {
          return dir;
        }
      }
      return Directory(candidates.first);
    }

    return getApplicationDocumentsDirectory();
  }

  String _sanitizeSegment(String raw) {
    final trimmed = raw.trim().toLowerCase();
    final replaced = trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    if (collapsed.isEmpty) {
      return 'document';
    }
    return collapsed;
  }

  String _sanitizeFolderSegment(String raw) {
    final trimmed = raw.trim();
    final cleaned = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final collapsed = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) {
      return 'uncategorized';
    }
    return collapsed;
  }
}

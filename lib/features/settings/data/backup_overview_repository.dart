import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sanchita/core/constants/app_constants.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sqflite/sqflite.dart';

class StorageOverviewModel {
  const StorageOverviewModel({
    required this.databaseBytes,
    required this.secureStorageBytes,
    required this.vaultDocBytes,
    required this.vaultInfoBytes,
    required this.backupEstimateBytes,
  });

  final int databaseBytes;
  final int secureStorageBytes;
  final int vaultDocBytes;
  final int vaultInfoBytes;
  final int backupEstimateBytes;
}

class BackupHistoryModel {
  const BackupHistoryModel({
    required this.backupDate,
    required this.destination,
    required this.fileSizeBytes,
    required this.status,
    required this.errorMessage,
  });

  final DateTime backupDate;
  final String destination;
  final int fileSizeBytes;
  final String status;
  final String? errorMessage;
}

final backupOverviewRepositoryProvider = Provider<BackupOverviewRepository>((
  ref,
) {
  return BackupOverviewRepository(
    DatabaseHelper.instance,
    SecureStorageService.instance,
  );
});

class BackupOverviewRepository {
  BackupOverviewRepository(this._databaseHelper, this._secureStorageService);

  final DatabaseHelper _databaseHelper;
  final SecureStorageService _secureStorageService;

  Future<Result<StorageOverviewModel>> getStorageOverview() async {
    try {
      final dbBytes = await _readDatabaseSizeBytes();
      final secureValues = await _secureStorageService.readAll();

      var secureBytes = 0;
      var vaultDocBytes = 0;
      var vaultInfoBytes = 0;

      for (final entry in secureValues.entries) {
        final valueBytes = utf8.encode(entry.value).length;
        secureBytes += valueBytes;

        if (entry.key.startsWith('vault_doc_')) {
          vaultDocBytes += valueBytes;
        } else if (entry.key.startsWith('vault_info_')) {
          vaultInfoBytes += valueBytes;
        }
      }

      final estimate = dbBytes + secureBytes;
      return Result<StorageOverviewModel>.success(
        StorageOverviewModel(
          databaseBytes: dbBytes,
          secureStorageBytes: secureBytes,
          vaultDocBytes: vaultDocBytes,
          vaultInfoBytes: vaultInfoBytes,
          backupEstimateBytes: estimate,
        ),
      );
    } catch (error) {
      return Result<StorageOverviewModel>.failure(
        'Failed to load storage overview: $error',
      );
    }
  }

  Future<Result<List<BackupHistoryModel>>> getBackupHistory() async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query(
        'backup_log',
        orderBy: 'backup_date DESC, created_at DESC',
        limit: 20,
      );

      final items = rows
          .map((row) {
            final backupDate = DateTime.tryParse(
              row['backup_date'] as String? ?? '',
            );
            return BackupHistoryModel(
              backupDate: backupDate ?? DateTime.now(),
              destination: row['destination'] as String? ?? 'unknown',
              fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt() ?? 0,
              status: row['status'] as String? ?? 'unknown',
              errorMessage: row['error_message'] as String?,
            );
          })
          .toList(growable: false);

      return Result<List<BackupHistoryModel>>.success(items);
    } catch (error) {
      return Result<List<BackupHistoryModel>>.failure(
        'Failed to load backup history: $error',
      );
    }
  }

  Future<int> _readDatabaseSizeBytes() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, AppConstants.databaseName);
    final file = File(dbPath);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }
}

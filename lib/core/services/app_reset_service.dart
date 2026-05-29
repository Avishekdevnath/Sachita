import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/secure_storage_service.dart';
import 'package:sanchita/shared/models/result.dart';

final appResetServiceProvider = Provider<AppResetService>((ref) {
  return AppResetService(
    databaseHelper: DatabaseHelper.instance,
    secureStorageService: SecureStorageService.instance,
  );
});

class AppResetService {
  const AppResetService({
    required this.databaseHelper,
    required this.secureStorageService,
  });

  final DatabaseHelper databaseHelper;
  final SecureStorageService secureStorageService;

  Future<Result<void>> wipeAllData() async {
    try {
      await secureStorageService.deleteAll();
      await databaseHelper.resetDatabase();
      await databaseHelper.database;
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to wipe app data: $error');
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/shared/models/result.dart';

class AppSettingsModel {
  const AppSettingsModel({
    required this.currencyCode,
    required this.currencySymbol,
    required this.theme,
    required this.language,
    required this.autoLockSeconds,
    required this.biometricEnabled,
    this.userName,
  });

  final String currencyCode;
  final String currencySymbol;
  final String theme;
  final String language;
  final int autoLockSeconds;
  final bool biometricEnabled;
  final String? userName;
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(DatabaseHelper.instance);
});

class SettingsRepository {
  SettingsRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<Result<AppSettingsModel>> getSettings() async {
    try {
      final row = await _databaseHelper.getAppSettings();
      if (row == null) {
        return const Result<AppSettingsModel>.failure(
          'Settings row not found.',
        );
      }

      final userNameRaw = (row['user_name'] as String?)?.trim();
      return Result<AppSettingsModel>.success(
        AppSettingsModel(
          currencyCode: row['currency_code'] as String? ?? 'BDT',
          currencySymbol: row['currency_symbol'] as String? ?? 'BDT',
          theme: row['theme'] as String? ?? 'system',
          language: row['language'] as String? ?? 'en',
          autoLockSeconds: row['auto_lock_mins'] as int? ?? 300,
          biometricEnabled: (row['biometric_enabled'] as int? ?? 0) == 1,
          userName: (userNameRaw == null || userNameRaw.isEmpty)
              ? null
              : userNameRaw,
        ),
      );
    } catch (error) {
      return Result<AppSettingsModel>.failure(
        'Failed to load settings: $error',
      );
    }
  }

  Future<Result<void>> updateTheme(String theme) async {
    try {
      await _databaseHelper.updateAppSettings(<String, Object>{'theme': theme});
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update theme: $error');
    }
  }

  Future<Result<void>> updateLanguage(String language) async {
    try {
      await _databaseHelper.updateAppSettings(<String, Object>{
        'language': language,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update language: $error');
    }
  }

  Future<Result<void>> updateCurrency({
    required String currencyCode,
    required String currencySymbol,
  }) async {
    try {
      await _databaseHelper.updateAppSettings(<String, Object>{
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update currency: $error');
    }
  }

  Future<Result<void>> updateAutoLockSeconds(int autoLockSeconds) async {
    try {
      await _databaseHelper.updateAppSettings(<String, Object>{
        'auto_lock_mins': autoLockSeconds,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update auto-lock timer: $error');
    }
  }

  Future<Result<void>> updateBiometricEnabled(bool enabled) async {
    try {
      await _databaseHelper.updateAppSettings(<String, Object>{
        'biometric_enabled': enabled ? 1 : 0,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update biometric flag: $error');
    }
  }

  Future<Result<void>> updateUserName(String? userName) async {
    try {
      final trimmed = userName?.trim();
      await _databaseHelper.updateAppSettings(<String, Object?>{
        'user_name': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      });
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to update name: $error');
    }
  }
}

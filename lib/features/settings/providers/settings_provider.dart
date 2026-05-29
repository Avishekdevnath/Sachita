import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/settings/data/settings_repository.dart';

class SettingsState {
  const SettingsState({
    this.currencyCode = 'BDT',
    this.currencySymbol = 'BDT',
    this.theme = 'system',
    this.language = 'en',
    this.autoLockSeconds = 300,
    this.biometricEnabled = false,
    this.userName,
    this.errorMessage,
  });

  final String currencyCode;
  final String currencySymbol;
  final String theme;
  final String language;
  final int autoLockSeconds;
  final bool biometricEnabled;
  final String? userName;
  final String? errorMessage;

  SettingsState copyWith({
    String? currencyCode,
    String? currencySymbol,
    String? theme,
    String? language,
    int? autoLockSeconds,
    bool? biometricEnabled,
    String? userName,
    String? errorMessage,
    bool clearError = false,
    bool clearUserName = false,
  }) {
    return SettingsState(
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      userName: clearUserName ? null : (userName ?? this.userName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).asData?.value.currencySymbol ?? 'BDT';
});

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<SettingsState> build() async {
    final result = await _repository.getSettings();
    return result.when(
      success: (settings) {
        return SettingsState(
          currencyCode: settings.currencyCode,
          currencySymbol: settings.currencySymbol,
          theme: settings.theme,
          language: settings.language,
          autoLockSeconds: settings.autoLockSeconds,
          biometricEnabled: settings.biometricEnabled,
          userName: settings.userName,
        );
      },
      failure: (_) => const SettingsState(),
    );
  }

  Future<void> setUserName(String? userName) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateUserName(userName);
    result.when(
      success: (_) {
        final trimmed = userName?.trim();
        final cleared = trimmed == null || trimmed.isEmpty;
        state = AsyncData(
          current.copyWith(
            userName: cleared ? null : trimmed,
            clearUserName: cleared,
            clearError: true,
          ),
        );
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setTheme(String theme) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateTheme(theme);
    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(theme: theme, clearError: true));
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setLanguage(String language) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateLanguage(language);
    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(language: language, clearError: true));
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setCurrency({
    required String currencyCode,
    required String currencySymbol,
  }) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateCurrency(
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );

    result.when(
      success: (_) {
        state = AsyncData(
          current.copyWith(
            currencyCode: currencyCode,
            currencySymbol: currencySymbol,
            clearError: true,
          ),
        );
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateBiometricEnabled(enabled);
    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(biometricEnabled: enabled, clearError: true));
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }

  Future<void> setAutoLockSeconds(int autoLockSeconds) async {
    final current = state.asData?.value ?? const SettingsState();
    final result = await _repository.updateAutoLockSeconds(autoLockSeconds);
    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(autoLockSeconds: autoLockSeconds, clearError: true));
      },
      failure: (message) {
        state = AsyncData(current.copyWith(errorMessage: message));
      },
    );
  }
}

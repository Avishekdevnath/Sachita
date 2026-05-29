import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/services/biometric_auth_service.dart';
import 'package:sanchita/features/auth/data/auth_repository.dart';
import 'package:sanchita/shared/models/result.dart';

class SessionState {
  const SessionState({
    this.onboardingDone = false,
    this.biometricEnabled = false,
    this.authenticated = false,
    this.lockedUntil,
    this.pinFallbackEnabled = false,
    this.securityAnswerVerified = false,
    this.biometricFailCount = 0,
  });

  final bool onboardingDone;
  final bool biometricEnabled;
  final bool authenticated;
  final DateTime? lockedUntil;
  final bool pinFallbackEnabled;
  final bool securityAnswerVerified;
  final int biometricFailCount;

  static const int maxBiometricAttempts = 3;

  bool get biometricAvailable =>
      biometricEnabled && biometricFailCount < maxBiometricAttempts;

  bool get isLockedOut {
    if (lockedUntil == null) {
      return false;
    }
    return lockedUntil!.isAfter(DateTime.now());
  }

  SessionState copyWith({
    bool? onboardingDone,
    bool? biometricEnabled,
    bool? authenticated,
    DateTime? lockedUntil,
    bool? pinFallbackEnabled,
    bool? securityAnswerVerified,
    int? biometricFailCount,
    bool clearLockedUntil = false,
  }) {
    return SessionState(
      onboardingDone: onboardingDone ?? this.onboardingDone,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      authenticated: authenticated ?? this.authenticated,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      pinFallbackEnabled: pinFallbackEnabled ?? this.pinFallbackEnabled,
      securityAnswerVerified:
          securityAnswerVerified ?? this.securityAnswerVerified,
      biometricFailCount: biometricFailCount ?? this.biometricFailCount,
    );
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<SessionState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  BiometricAuthService get _biometricAuthService =>
      ref.read(biometricAuthServiceProvider);

  @override
  Future<SessionState> build() async {
    final snapshotResult = await _authRepository.loadSessionSnapshot();
    if (snapshotResult is Failure<SessionSnapshot>) {
      return const SessionState();
    }

    final snapshot = (snapshotResult as Success<SessionSnapshot>).value;
    final currentLockedUntil = snapshot.lockedUntil;
    final isExpired =
        currentLockedUntil != null &&
        !currentLockedUntil.isAfter(DateTime.now());

    if (isExpired) {
      await _authRepository.clearLockoutIfExpired();
    }

    return SessionState(
      onboardingDone: snapshot.onboardingDone,
      biometricEnabled: snapshot.biometricEnabled,
      // Require PIN/biometric on every fresh app start.
      authenticated: false,
      lockedUntil: isExpired ? null : currentLockedUntil,
    );
  }

  Future<Result<void>> completeOnboarding({
    required bool biometricEnabled,
    required String pin,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final result = await _authRepository.completeOnboarding(
      biometricEnabled: biometricEnabled,
      pin: pin,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );

    return result.when(
      success: (_) {
        final current = state.asData?.value ?? const SessionState();
        state = AsyncData(
          current.copyWith(
            onboardingDone: true,
            biometricEnabled: biometricEnabled,
            authenticated: true,
            pinFallbackEnabled: false,
            securityAnswerVerified: false,
          ),
        );
        return const Result<void>.success(null);
      },
      failure: (message) {
        return Result<void>.failure(message);
      },
    );
  }

  Future<void> authenticate() async {
    final current = state.asData?.value ?? const SessionState();
    if (current.isLockedOut) {
      return;
    }

    await _authRepository.clearPinFailures();

    state = AsyncData(
      current.copyWith(
        authenticated: true,
        clearLockedUntil: true,
        pinFallbackEnabled: false,
        securityAnswerVerified: false,
      ),
    );
  }

  Future<Result<void>> verifyAndAuthenticatePin(String pin) async {
    final current = state.asData?.value ?? const SessionState();
    final result = await _authRepository.verifyPin(pin);

    return result.when(
      success: (verification) {
        if (verification.authenticated) {
          state = AsyncData(
            current.copyWith(
              authenticated: true,
              clearLockedUntil: true,
              pinFallbackEnabled: false,
              securityAnswerVerified: false,
            ),
          );
          return const Result<void>.success(null);
        }

        state = AsyncData(
          current.copyWith(lockedUntil: verification.lockedUntil),
        );
        return Result<void>.failure(verification.message ?? 'Incorrect PIN.');
      },
      failure: (message) => Result<void>.failure(message),
    );
  }

  void lockForReauth({bool forcePinFallback = false}) {
    final current = state.asData?.value ?? const SessionState();
    state = AsyncData(
      current.copyWith(
        authenticated: false,
        pinFallbackEnabled: forcePinFallback,
        securityAnswerVerified: false,
      ),
    );
  }

  void signOut() {
    lockForReauth(forcePinFallback: true);
  }

  Future<void> registerFailedPinAttempt() async {
    final current = state.asData?.value ?? const SessionState();
    final result = await _authRepository.registerFailedPinAttempt();

    result.when(
      success: (outcome) {
        state = AsyncData(current.copyWith(lockedUntil: outcome.lockedUntil));
      },
      failure: (_) {
        state = AsyncData(current);
      },
    );
  }

  Future<void> clearLockoutIfExpired() async {
    final current = state.asData?.value ?? const SessionState();
    final result = await _authRepository.clearLockoutIfExpired();

    result.when(
      success: (lockedUntil) {
        state = AsyncData(
          current.copyWith(
            lockedUntil: lockedUntil,
            clearLockedUntil: lockedUntil == null,
          ),
        );
      },
      failure: (_) {},
    );
  }

  Future<Result<String>> loadSecurityQuestion() async {
    return _authRepository.getSecurityQuestion();
  }

  Future<Result<void>> verifySecurityAnswer(String answer) async {
    final current = state.asData?.value ?? const SessionState();
    final result = await _authRepository.verifySecurityAnswer(answer);

    result.when(
      success: (_) {
        state = AsyncData(current.copyWith(securityAnswerVerified: true));
      },
      failure: (_) {
        state = AsyncData(current.copyWith(securityAnswerVerified: false));
      },
    );

    return result;
  }

  Future<Result<void>> setNewPinAfterRecovery(String newPin) async {
    final current = state.asData?.value ?? const SessionState();
    if (!current.securityAnswerVerified) {
      return const Result<void>.failure(
        'Security answer verification is required before setting a new PIN.',
      );
    }

    final result = await _authRepository.setNewPin(newPin);
    result.when(
      success: (_) {
        state = AsyncData(
          current.copyWith(
            authenticated: true,
            clearLockedUntil: true,
            securityAnswerVerified: false,
          ),
        );
      },
      failure: (_) {},
    );

    return result;
  }

  Future<Result<void>> verifyCurrentPinForSettings(String pin) async {
    final current = state.asData?.value ?? const SessionState();
    final result = await _authRepository.verifyPin(pin);

    return result.when(
      success: (verification) {
        state = AsyncData(
          current.copyWith(
            lockedUntil: verification.lockedUntil,
            clearLockedUntil: verification.lockedUntil == null,
          ),
        );

        if (verification.authenticated) {
          return const Result<void>.success(null);
        }

        return Result<void>.failure(
          verification.message ?? 'Incorrect current PIN.',
        );
      },
      failure: (message) => Result<void>.failure(message),
    );
  }

  Future<Result<void>> changePinFromSettings({
    required String currentPin,
    required String newPin,
  }) async {
    final current = state.asData?.value ?? const SessionState();
    if (current.isLockedOut) {
      return Result<void>.failure(
        'Too many failed attempts. Try again after ${current.lockedUntil?.toLocal()}.',
      );
    }

    final result = await _authRepository.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );

    return result.when(
      success: (_) {
        state = AsyncData(current.copyWith(clearLockedUntil: true));
        return const Result<void>.success(null);
      },
      failure: (message) => Result<void>.failure(message),
    );
  }

  Future<Result<void>> updateSecurityQuestionFromSettings({
    required String currentPin,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final current = state.asData?.value ?? const SessionState();
    if (current.isLockedOut) {
      return Result<void>.failure(
        'Too many failed attempts. Try again after ${current.lockedUntil?.toLocal()}.',
      );
    }

    final result = await _authRepository.updateSecurityQuestion(
      currentPin: currentPin,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );

    return result.when(
      success: (_) {
        state = AsyncData(current.copyWith(clearLockedUntil: true));
        return const Result<void>.success(null);
      },
      failure: (message) => Result<void>.failure(message),
    );
  }

  Future<Result<void>> authenticateWithBiometric() async {
    final current = state.asData?.value ?? const SessionState();
    if (current.isLockedOut) {
      return Result<void>.failure(
        'Too many failed attempts. Try again after ${current.lockedUntil?.toLocal()}.',
      );
    }

    if (!current.biometricAvailable) {
      return const Result<void>.failure(
        'Biometric login disabled after too many failures. Use PIN instead.',
      );
    }

    final result = await _biometricAuthService.authenticateForUnlock();
    if (result is Failure<void>) {
      final newCount = current.biometricFailCount + 1;
      state = AsyncData(
        current.copyWith(biometricFailCount: newCount),
      );
      if (newCount >= SessionState.maxBiometricAttempts) {
        return const Result<void>.failure(
          'Biometric failed 3 times. Use PIN to unlock.',
        );
      }
      return Result<void>.failure(result.message);
    }

    await authenticate();
    return const Result<void>.success(null);
  }

  void enablePinFallback() {
    final current = state.asData?.value ?? const SessionState();
    state = AsyncData(current.copyWith(pinFallbackEnabled: true));
  }

  void disablePinFallback() {
    final current = state.asData?.value ?? const SessionState();
    state = AsyncData(current.copyWith(pinFallbackEnabled: false));
  }

  void setBiometricPreference(bool enabled) {
    final current = state.asData?.value ?? const SessionState();
    state = AsyncData(
      current.copyWith(biometricEnabled: enabled, pinFallbackEnabled: false),
    );
  }

  Future<Result<void>> resetAppData() async {
    final result = await _authRepository.resetAppData();
    if (result is Failure<void>) {
      return Result<void>.failure(result.message);
    }

    state = const AsyncData(SessionState());
    return const Result<void>.success(null);
  }
}

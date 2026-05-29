import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/constants/app_constants.dart';
import 'package:sanchita/core/database/database_helper.dart';
import 'package:sanchita/core/services/app_reset_service.dart';
import 'package:sanchita/core/services/security_hasher.dart';
import 'package:sanchita/shared/models/result.dart';

class SessionSnapshot {
  const SessionSnapshot({
    required this.onboardingDone,
    required this.biometricEnabled,
    required this.lockedUntil,
  });

  final bool onboardingDone;
  final bool biometricEnabled;
  final DateTime? lockedUntil;
}

class PinAttemptOutcome {
  const PinAttemptOutcome({
    required this.failedAttempts,
    required this.lockedUntil,
  });

  final int failedAttempts;
  final DateTime? lockedUntil;
}

class PinVerificationResult {
  const PinVerificationResult({
    required this.authenticated,
    required this.lockedUntil,
    required this.message,
  });

  final bool authenticated;
  final DateTime? lockedUntil;
  final String? message;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    DatabaseHelper.instance,
    const SecurityHasher(),
    ref.read(appResetServiceProvider),
  );
});

class AuthRepository {
  AuthRepository(this._databaseHelper, this._hasher, this._appResetService);

  final DatabaseHelper _databaseHelper;
  final SecurityHasher _hasher;
  final AppResetService _appResetService;

  Future<Result<SessionSnapshot>> loadSessionSnapshot() async {
    try {
      final onboardingDone = await _databaseHelper.getOnboardingDone();
      final biometricEnabled = await _databaseHelper.getBiometricEnabled();
      final lockedUntil = await _databaseHelper.getLockedUntil();

      return Result<SessionSnapshot>.success(
        SessionSnapshot(
          onboardingDone: onboardingDone,
          biometricEnabled: biometricEnabled,
          lockedUntil: lockedUntil,
        ),
      );
    } catch (error) {
      return Result<SessionSnapshot>.failure(
        'Failed to load session snapshot: $error',
      );
    }
  }

  Future<Result<void>> completeOnboarding({
    required bool biometricEnabled,
    required String pin,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    try {
      final pinHash = _hasher.createStoredHash(pin);
      final answerHash = _hasher.createStoredHash(
        _normalizeAnswer(securityAnswer),
      );

      await _databaseHelper.setSecurityCredentials(
        pinHash: pinHash,
        securityQuestion: securityQuestion,
        securityAnswerHash: answerHash,
      );
      await _databaseHelper.setOnboardingDone(true);
      await _databaseHelper.setBiometricEnabled(biometricEnabled);
      await _databaseHelper.setFailedAttempts(0);
      await _databaseHelper.setLockedUntil(null);

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to complete onboarding: $error');
    }
  }

  Future<Result<void>> clearPinFailures() async {
    try {
      await _databaseHelper.setFailedAttempts(0);
      await _databaseHelper.setLockedUntil(null);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to clear PIN failures: $error');
    }
  }

  Future<Result<PinAttemptOutcome>> registerFailedPinAttempt() async {
    try {
      final attempts = await _databaseHelper.getFailedAttempts() + 1;
      await _databaseHelper.setFailedAttempts(attempts);

      if (attempts < AppConstants.maxPinAttempts) {
        return Result<PinAttemptOutcome>.success(
          PinAttemptOutcome(failedAttempts: attempts, lockedUntil: null),
        );
      }

      final lockoutTime = DateTime.now().add(
        const Duration(minutes: AppConstants.lockoutMinutes),
      );
      await _databaseHelper.setLockedUntil(lockoutTime);

      return Result<PinAttemptOutcome>.success(
        PinAttemptOutcome(failedAttempts: attempts, lockedUntil: lockoutTime),
      );
    } catch (error) {
      return Result<PinAttemptOutcome>.failure(
        'Failed to register failed PIN attempt: $error',
      );
    }
  }

  Future<Result<DateTime?>> clearLockoutIfExpired() async {
    try {
      final lockedUntil = await _databaseHelper.getLockedUntil();
      if (lockedUntil == null || lockedUntil.isAfter(DateTime.now())) {
        return Result<DateTime?>.success(lockedUntil);
      }

      await _databaseHelper.setLockedUntil(null);
      await _databaseHelper.setFailedAttempts(0);
      return const Result<DateTime?>.success(null);
    } catch (error) {
      return Result<DateTime?>.failure('Failed to clear lockout state: $error');
    }
  }

  Future<Result<PinVerificationResult>> verifyPin(String pin) async {
    try {
      final lockoutResult = await clearLockoutIfExpired();
      DateTime? lockedUntil = lockoutResult.when(
        success: (value) => value,
        failure: (_) => null,
      );

      if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
        return Result<PinVerificationResult>.success(
          PinVerificationResult(
            authenticated: false,
            lockedUntil: lockedUntil,
            message: 'Too many failed attempts. Try again later.',
          ),
        );
      }

      final storedHash = await _databaseHelper.getPinHash();
      if (storedHash == 'UNSET') {
        return const Result<PinVerificationResult>.failure(
          'PIN is not set yet.',
        );
      }

      final isValid = await _hasher.verifyAsync(pin, storedHash);
      if (isValid) {
        if (_hasher.isLegacyHash(storedHash)) {
          await _databaseHelper.updatePinHash(_hasher.createStoredHash(pin));
        }
        await clearPinFailures();
        return const Result<PinVerificationResult>.success(
          PinVerificationResult(
            authenticated: true,
            lockedUntil: null,
            message: null,
          ),
        );
      }

      final failedResult = await registerFailedPinAttempt();
      lockedUntil = failedResult.when(
        success: (value) => value.lockedUntil,
        failure: (_) => null,
      );

      return Result<PinVerificationResult>.success(
        PinVerificationResult(
          authenticated: false,
          lockedUntil: lockedUntil,
          message: lockedUntil == null
              ? 'Incorrect PIN.'
              : 'Too many failed attempts. Try again later.',
        ),
      );
    } catch (error) {
      return Result<PinVerificationResult>.failure(
        'Failed to verify PIN: $error',
      );
    }
  }

  Future<Result<String>> getSecurityQuestion() async {
    try {
      final question = await _databaseHelper.getSecurityQuestion();
      if (question == null || question.isEmpty) {
        return const Result<String>.failure('Security question is not set.');
      }

      return Result<String>.success(question);
    } catch (error) {
      return Result<String>.failure('Failed to load security question: $error');
    }
  }

  Future<Result<void>> resetPinWithSecurityAnswer({
    required String answer,
    required String newPin,
  }) async {
    try {
      final verifyResult = await verifySecurityAnswer(answer);
      return verifyResult.when(
        success: (_) => setNewPin(newPin),
        failure: (message) => Result<void>.failure(message),
      );
    } catch (error) {
      return Result<void>.failure('Failed to reset PIN: $error');
    }
  }

  Future<Result<void>> verifySecurityAnswer(String answer) async {
    try {
      final storedAnswerHash = await _databaseHelper.getSecurityAnswerHash();
      if (storedAnswerHash == 'UNSET') {
        return const Result<void>.failure('Security answer is not set.');
      }

      final isValid = await _hasher.verifyAsync(
        _normalizeAnswer(answer),
        storedAnswerHash,
      );
      if (!isValid) {
        return const Result<void>.failure('Incorrect security answer.');
      }

      if (_hasher.isLegacyHash(storedAnswerHash)) {
        final upgradedHash = _hasher.createStoredHash(_normalizeAnswer(answer));
        await _databaseHelper.updateSecurityAnswerHash(upgradedHash);
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to verify security answer: $error');
    }
  }

  Future<Result<void>> setNewPin(String newPin) async {
    try {
      final newPinHash = _hasher.createStoredHash(newPin);
      await _databaseHelper.updatePinHash(newPinHash);
      await clearPinFailures();
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure('Failed to set new PIN: $error');
    }
  }

  Future<Result<void>> verifyCurrentPin(String currentPin) async {
    final verifyResult = await verifyPin(currentPin);
    return verifyResult.when(
      success: (verification) {
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

  Future<Result<void>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final verifyResult = await verifyCurrentPin(currentPin);
    return verifyResult.when(
      success: (_) => setNewPin(newPin),
      failure: (message) => Result<void>.failure(message),
    );
  }

  Future<Result<void>> updateSecurityQuestion({
    required String currentPin,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final verifyResult = await verifyCurrentPin(currentPin);
    return verifyResult.when(
      success: (_) async {
        try {
          final answerHash = _hasher.createStoredHash(
            _normalizeAnswer(securityAnswer),
          );
          await _databaseHelper.updateSecurityQuestionAndAnswer(
            securityQuestion: securityQuestion,
            securityAnswerHash: answerHash,
          );
          await clearPinFailures();
          return const Result<void>.success(null);
        } catch (error) {
          return Result<void>.failure(
            'Failed to update security question: $error',
          );
        }
      },
      failure: (message) => Result<void>.failure(message),
    );
  }

  Future<Result<void>> resetAppData() async {
    return _appResetService.wipeAllData();
  }

  static String _normalizeAnswer(String answer) {
    return answer.trim().toLowerCase();
  }
}

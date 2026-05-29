import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sanchita/shared/models/result.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(LocalAuthentication());
});

class BiometricAuthService {
  BiometricAuthService(this._localAuth);

  final LocalAuthentication _localAuth;

  Future<Result<bool>> canAuthenticate() async {
    try {
      final canAuthenticateWithBiometric = await _localAuth.canCheckBiometrics;
      final canAuthenticateWithDevice = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      final hasEnrolledBiometric = availableBiometrics.isNotEmpty;

      return Result<bool>.success(
        canAuthenticateWithBiometric &&
            canAuthenticateWithDevice &&
            hasEnrolledBiometric,
      );
    } catch (error) {
      return const Result<bool>.failure(
        'Unable to check biometric availability on this device.',
      );
    }
  }

  Future<Result<void>> authenticateForUnlock() async {
    try {
      final canAuthenticateResult = await canAuthenticate();
      final canUseBiometrics = canAuthenticateResult.when(
        success: (value) => value,
        failure: (_) => false,
      );

      if (!canUseBiometrics) {
        return const Result<void>.failure(
          'Biometric authentication is not available on this device.',
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock Sanchita',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );

      if (!authenticated) {
        return const Result<void>.failure(
          'Biometric authentication was not successful.',
        );
      }

      return const Result<void>.success(null);
    } catch (error) {
      return const Result<void>.failure(
        'Biometric authentication failed. Use PIN instead.',
      );
    }
  }
}

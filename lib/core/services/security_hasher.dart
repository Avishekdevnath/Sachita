import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Top-level function for background isolate bcrypt verification
/// Must be a top-level function to work with compute()
bool _verifyBcryptInBackground(
  ({String input, String hash}) params,
) {
  return BCrypt.checkpw(params.input, params.hash);
}

class SecurityHasher {
  const SecurityHasher();

  String createStoredHash(String input) {
    return BCrypt.hashpw(input, BCrypt.gensalt());
  }

  bool verify(String input, String storedHash) {
    if (_isBcryptHash(storedHash)) {
      return BCrypt.checkpw(input, storedHash);
    }
    return _verifyLegacySha256(input, storedHash);
  }

  /// Async version using background isolate for heavy bcrypt operations
  Future<bool> verifyAsync(String input, String storedHash) async {
    if (_isBcryptHash(storedHash)) {
      // Run bcrypt verification in background isolate
      return await compute(
        _verifyBcryptInBackground,
        (input: input, hash: storedHash),
      );
    }
    // Legacy SHA256 is fast enough for main thread
    return _verifyLegacySha256(input, storedHash);
  }

  bool isLegacyHash(String storedHash) {
    return !_isBcryptHash(storedHash) && storedHash.split(':').length == 2;
  }

  bool _isBcryptHash(String storedHash) {
    return storedHash.startsWith(r'$2a$') ||
        storedHash.startsWith(r'$2b$') ||
        storedHash.startsWith(r'$2y$');
  }

  bool _verifyLegacySha256(String input, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) {
      return false;
    }

    final salt = parts.first;
    final expectedDigest = parts.last;
    final actualDigest = _legacySha256(input: input, salt: salt);
    return expectedDigest == actualDigest;
  }

  String _legacySha256({required String input, required String salt}) {
    final bytes = utf8.encode('$salt::$input');
    return sha256.convert(bytes).toString();
  }
}

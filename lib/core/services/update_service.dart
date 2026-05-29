import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sanchita/core/constants/app_constants.dart';
import 'package:sanchita/core/models/update_check_result.dart';

class UpdateService {
  const UpdateService();

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(AppConstants.updateCheckUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const NoUpdate();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = json['latest_version'] as String? ?? '';
      final minRequiredVersion = json['min_required_version'] as String? ?? '';
      final apkUrl = json['apk_url'] as String? ?? '';
      final releaseNotes = json['release_notes'] as String? ?? '';

      if (latestVersion.isEmpty || apkUrl.isEmpty) {
        return const NoUpdate();
      }

      if (minRequiredVersion.isNotEmpty &&
          isLowerVersion(currentVersion, minRequiredVersion)) {
        return ForceUpdate(
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes,
        );
      }

      if (isLowerVersion(currentVersion, latestVersion)) {
        return SoftUpdate(
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes,
        );
      }

      return const NoUpdate();
    } catch (error) {
      debugPrint('[UpdateService] check failed: $error');
      return const NoUpdate();
    }
  }

  /// Returns true if [current] is strictly lower than [target].
  /// Compares major, then minor, then patch. Returns false on parse error.
  @visibleForTesting
  static bool isLowerVersion(String current, String target) {
    final c = _parse(current);
    final t = _parse(target);
    if (c == null || t == null) return false;

    if (c[0] != t[0]) return c[0] < t[0];
    if (c[1] != t[1]) return c[1] < t[1];
    return c[2] < t[2];
  }

  static List<int>? _parse(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return null;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    return nums.cast<int>();
  }
}

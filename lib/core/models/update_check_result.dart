sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

final class NoUpdate extends UpdateCheckResult {
  const NoUpdate();
}

final class SoftUpdate extends UpdateCheckResult {
  const SoftUpdate({
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;
}

final class ForceUpdate extends UpdateCheckResult {
  const ForceUpdate({
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;
}

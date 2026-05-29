import 'package:flutter/material.dart';

import 'package:sanchita/core/models/update_check_result.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showSoftUpdateDialog(BuildContext context, SoftUpdate update) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _UpdateDialog(update: update, force: false),
  );
}

Future<void> showForceUpdateDialog(BuildContext context, ForceUpdate update) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _UpdateDialog(update: update, force: true),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update, required this.force});

  final UpdateCheckResult update;
  final bool force;

  String get _latestVersion => switch (update) {
        SoftUpdate(:final latestVersion) => latestVersion,
        ForceUpdate(:final latestVersion) => latestVersion,
        _ => '',
      };

  String get _apkUrl => switch (update) {
        SoftUpdate(:final apkUrl) => apkUrl,
        ForceUpdate(:final apkUrl) => apkUrl,
        _ => '',
      };

  String get _releaseNotes => switch (update) {
        SoftUpdate(:final releaseNotes) => releaseNotes,
        ForceUpdate(:final releaseNotes) => releaseNotes,
        _ => '',
      };

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(_apkUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(force ? 'Update Required' : 'Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Version $_latestVersion is available.'),
          if (_releaseNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(_releaseNotes),
          ],
        ],
      ),
      actions: <Widget>[
        if (!force)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: () => _openUrl(context),
          child: Text(force ? 'Update Now' : 'Update'),
        ),
      ],
    );
  }
}

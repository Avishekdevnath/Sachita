import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/auth/data/auth_repository.dart';
import 'package:sanchita/features/settings/data/backup_engine_repository.dart';
import 'package:sanchita/features/settings/providers/backup_overview_provider.dart';
import 'package:sanchita/features/settings/providers/backup_reminder_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class SettingsBackupCreateScreen extends ConsumerStatefulWidget {
  const SettingsBackupCreateScreen({super.key});

  @override
  ConsumerState<SettingsBackupCreateScreen> createState() {
    return _SettingsBackupCreateScreenState();
  }
}

class _SettingsBackupCreateScreenState
    extends ConsumerState<SettingsBackupCreateScreen> {
  String _encryptionMode = 'pin';
  String _destination = '';
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _customPasswordController =
      TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _pinController.dispose();
    _customPasswordController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[index]}';
  }

  Widget _buildChoiceTile({
    required String value,
    required String selectedValue,
    required bool enabled,
    required ValueChanged<String> onSelected,
    required String title,
    required IconData icon,
    String? subtitle,
  }) {
    final isSelected = value == selectedValue;
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(
          isSelected ? Icons.check_circle_outline : Icons.circle_outlined,
        ),
        onTap: enabled ? () => onSelected(value) : null,
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_creating) {
      return;
    }
    if (_destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a backup destination first.')),
      );
      return;
    }

    if (_encryptionMode == 'password' &&
        _customPasswordController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup password must be at least 4 chars.'),
        ),
      );
      return;
    }

    String secret;
    if (_encryptionMode == 'pin') {
      final pin = _pinController.text.trim();
      if (pin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter current PIN to encrypt backup.')),
        );
        return;
      }

      final verifyResult = await ref
          .read(authRepositoryProvider)
          .verifyCurrentPin(pin);
      if (!mounted) {
        return;
      }

      var pinVerified = false;
      verifyResult.when(
        success: (_) {
          pinVerified = true;
        },
        failure: (message) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      );
      if (!pinVerified) {
        return;
      }
      secret = pin;
    } else {
      secret = _customPasswordController.text.trim();
    }

    setState(() {
      _creating = true;
    });

    final result = await ref
        .read(backupEngineRepositoryProvider)
        .createEncryptedBackup(
          destination: _destination,
          secret: secret,
          oauthScopes: _destination == 'drive'
              ? <String>[BackupEngineRepository.googleDriveFileScope]
              : const <String>[],
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _creating = false;
    });

    await result.when(
      success: (value) async {
        final successMessage = value.destination == 'drive'
            ? '✓ Backup uploaded to Google Drive (${_formatBytes(value.fileSizeBytes)})'
            : value.destination == 'share'
                ? 'Backup saved locally (${_formatBytes(value.fileSizeBytes)}) - ready to share'
                : 'Backup saved locally (${_formatBytes(value.fileSizeBytes)})';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        await ref.read(backupReminderProvider.notifier).markBackupCompleted();
        await ref.read(backupOverviewProvider.notifier).refresh();

        if (mounted) {
          Navigator.pop(context);
        }
      },
      failure: (message) async {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(backupOverviewProvider).asData?.value.storage;
    final estimate = storage?.backupEstimateBytes ?? 0;

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Create Backup',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Estimated backup size'),
            trailing: Text(_formatBytes(estimate)),
          ),
          if (estimate > 10 * 1024 * 1024)
            const Card(
              child: ListTile(
                leading: Icon(Icons.wifi_tethering_error_outlined),
                title: Text('Large backup'),
                subtitle: Text('Prefer Wi-Fi before uploading large backups.'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Encryption Key',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _buildChoiceTile(
            value: 'pin',
            selectedValue: _encryptionMode,
            enabled: !_creating,
            onSelected: (value) {
              setState(() {
                _encryptionMode = value;
              });
            },
            title: 'Use current PIN',
            icon: Icons.pin_outlined,
          ),
          if (_encryptionMode == 'pin')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                enabled: !_creating,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
            ),
          _buildChoiceTile(
            value: 'password',
            selectedValue: _encryptionMode,
            enabled: !_creating,
            onSelected: (value) {
              setState(() {
                _encryptionMode = value;
              });
            },
            title: 'Use custom backup password',
            icon: Icons.password_outlined,
          ),
          if (_encryptionMode == 'password')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _customPasswordController,
                obscureText: true,
                enabled: !_creating,
                decoration: const InputDecoration(labelText: 'Backup password'),
              ),
            ),
          const SizedBox(height: 6),
          Text('Destination', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildChoiceTile(
            value: 'drive',
            selectedValue: _destination,
            enabled: !_creating,
            onSelected: (value) {
              setState(() {
                _destination = value;
              });
            },
            title: 'Google Drive',
            subtitle:
                'Recommended for cloud backup (scope: drive.file only)',
            icon: Icons.cloud_outlined,
          ),
          _buildChoiceTile(
            value: 'local',
            selectedValue: _destination,
            enabled: !_creating,
            onSelected: (value) {
              setState(() {
                _destination = value;
              });
            },
            title: 'Phone Storage',
            subtitle: 'Save to local file',
            icon: Icons.folder_outlined,
          ),
          _buildChoiceTile(
            value: 'share',
            selectedValue: _destination,
            enabled: !_creating,
            onSelected: (value) {
              setState(() {
                _destination = value;
              });
            },
            title: 'Share Anywhere',
            subtitle: 'Share to another app',
            icon: Icons.share_outlined,
          ),
          const SizedBox(height: 10),
          if (_creating)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(),
                SizedBox(height: 8),
                Text('Encrypting and writing backup...'),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _creating ? null : _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: Text(_creating ? 'Creating...' : 'Create Backup'),
          ),
        ],
      ),
    );
  }
}

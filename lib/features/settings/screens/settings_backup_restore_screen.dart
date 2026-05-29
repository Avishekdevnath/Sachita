import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/dashboard/providers/dashboard_provider.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/settings/data/backup_engine_repository.dart';
import 'package:sanchita/features/settings/providers/backup_overview_provider.dart';
import 'package:sanchita/features/settings/providers/backup_reminder_provider.dart';
import 'package:sanchita/features/vault/providers/vault_doc_provider.dart';
import 'package:sanchita/features/vault/providers/vault_info_provider.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class SettingsBackupRestoreScreen extends ConsumerStatefulWidget {
  const SettingsBackupRestoreScreen({super.key});

  @override
  ConsumerState<SettingsBackupRestoreScreen> createState() {
    return _SettingsBackupRestoreScreenState();
  }
}

class _SettingsBackupRestoreScreenState
    extends ConsumerState<SettingsBackupRestoreScreen> {
  String _source = '';
  final TextEditingController _passwordController = TextEditingController();
  bool _restoring = false;

  Widget _buildSourceTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _source == value;
    return Card(
      child: ListTile(
        enabled: !_restoring,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle_outline : Icons.circle_outlined,
        ),
        onTap: _restoring
            ? null
            : () {
                setState(() {
                  _source = value;
                });
              },
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreNow() async {
    if (_restoring) {
      return;
    }
    if (_source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a restore source first.')),
      );
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter PIN/password to decrypt backup.')),
      );
      return;
    }

    setState(() {
      _restoring = true;
    });

    final result = await ref
        .read(backupEngineRepositoryProvider)
        .restoreLatestBackup(
          source: _source,
          secret: _passwordController.text.trim(),
          oauthScopes: _source == 'drive'
              ? <String>[BackupEngineRepository.googleDriveFileScope]
              : const <String>[],
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _restoring = false;
    });

    await result.when(
      success: (value) async {
        // Invalidate all major providers to reload fresh data after restore
        ref.invalidate(dashboardProvider);
        ref.invalidate(financeProvider);
        ref.invalidate(vaultInfoProvider);
        ref.invalidate(vaultDocProvider);
        ref.invalidate(backupOverviewProvider);
        ref.invalidate(backupReminderProvider);

        if (mounted) {
          // Show completion dialog
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Restore Complete'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your app data has been successfully restored.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tables: ${value.tableCount}, Rows: ${value.totalRows}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          // Refresh overview after restore
          await ref.read(backupOverviewProvider.notifier).refresh();

          if (mounted) {
            // Navigate to dashboard
            context.go(RoutePaths.dashboard);
          }
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
    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Restore Backup',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded),
              title: Text('Restore Warning'),
              subtitle: Text(
                'Restore will replace current app data after successful decryption.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Source', style: Theme.of(context).textTheme.titleMedium),
          _buildSourceTile(
            value: 'drive',
            title: 'Google Drive',
            subtitle: 'Select .sanchita backup from Drive (drive.file scope)',
            icon: Icons.cloud_outlined,
          ),
          _buildSourceTile(
            value: 'file',
            title: 'Local File',
            subtitle: 'Select .sanchita backup from storage',
            icon: Icons.folder_open_outlined,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_restoring,
            decoration: const InputDecoration(
              labelText: 'PIN / Backup password',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _restoring ? null : _restoreNow,
            icon: const Icon(Icons.restore_outlined),
            label: Text(_restoring ? 'Restoring...' : 'Restore Now'),
          ),
        ],
      ),
    );
  }
}

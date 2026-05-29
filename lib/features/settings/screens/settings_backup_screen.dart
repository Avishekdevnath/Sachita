import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/settings/data/backup_overview_repository.dart';
import 'package:sanchita/features/settings/providers/backup_overview_provider.dart';
import 'package:sanchita/features/settings/providers/backup_reminder_provider.dart';

class SettingsBackupScreen extends ConsumerWidget {
  const SettingsBackupScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }

  Widget _metricTile({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _historyTile(BuildContext context, BackupHistoryModel item) {
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(item.backupDate);
    final statusColor = item.status.toLowerCase() == 'success'
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${item.destination} - ${_formatBytes(item.fileSizeBytes)}'),
      subtitle: Text(date),
      trailing: Text(item.status, style: TextStyle(color: statusColor)),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }

  Widget _sectionTitle(BuildContext context, String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _summaryChip({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    final buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 8),
        Text(label),
      ],
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        child: buttonChild,
      );
    }

    return FilledButton(
      onPressed: onTap,
      child: buttonChild,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupAsync = ref.watch(backupOverviewProvider);
    final state = backupAsync.asData?.value ?? const BackupOverviewState();
    final storage = state.storage;
    final reminderAsync = ref.watch(backupReminderProvider);
    final reminder =
        reminderAsync.asData?.value ?? const BackupReminderState();
    final reminderBusy = reminderAsync.isLoading;
    final reminderInterval =
        const <int>[3, 7, 14, 30].contains(reminder.intervalDays)
        ? reminder.intervalDays
        : 7;
    final historyCount = state.history.length;
    final failedHistoryCount = state.history
        .where((entry) => entry.status.toLowerCase() != 'success')
        .length;
    final nextReminderLabel = reminder.enabled
        ? _formatDateTime(reminder.nextReminderAt)
        : 'Disabled';

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Backup')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(backupOverviewProvider.notifier).refresh();
          await ref.read(backupReminderProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _sectionTitle(
                      context,
                      'Backup Snapshot',
                      subtitle: 'Quick status of storage and backup health',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _summaryChip(
                          context: context,
                          icon: Icons.data_usage_outlined,
                          label:
                              'Estimate: ${_formatBytes(storage?.backupEstimateBytes ?? 0)}',
                        ),
                        _summaryChip(
                          context: context,
                          icon: Icons.history_outlined,
                          label: 'History: $historyCount',
                        ),
                        _summaryChip(
                          context: context,
                          icon: Icons.warning_amber_outlined,
                          label: 'Failed: $failedHistoryCount',
                        ),
                        _summaryChip(
                          context: context,
                          icon: Icons.schedule_outlined,
                          label: 'Reminder: $nextReminderLabel',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle(
              context,
              'Storage Overview',
              subtitle: 'Current local usage and estimated backup payload',
            ),
            const SizedBox(height: 8),
            if (backupAsync.isLoading && storage == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: <Widget>[
                      _metricTile(
                        context: context,
                        label: 'Estimated backup size',
                        value: _formatBytes(storage?.backupEstimateBytes ?? 0),
                      ),
                      const Divider(height: 1),
                      _metricTile(
                        context: context,
                        label: 'SQLite database',
                        value: _formatBytes(storage?.databaseBytes ?? 0),
                      ),
                      const Divider(height: 1),
                      _metricTile(
                        context: context,
                        label: 'Secure storage total',
                        value: _formatBytes(storage?.secureStorageBytes ?? 0),
                      ),
                      const Divider(height: 1),
                      _metricTile(
                        context: context,
                        label: 'Document vault payload',
                        value: _formatBytes(storage?.vaultDocBytes ?? 0),
                      ),
                      const Divider(height: 1),
                      _metricTile(
                        context: context,
                        label: 'Info vault payload',
                        value: _formatBytes(storage?.vaultInfoBytes ?? 0),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reminder.enabled,
                      onChanged: reminderBusy
                          ? null
                          : (enabled) async {
                              await ref
                                  .read(backupReminderProvider.notifier)
                                  .setEnabled(enabled);
                            },
                      title: const Text('Auto backup reminder'),
                      subtitle: Text(
                        reminder.enabled
                            ? 'Next reminder: ${_formatDateTime(reminder.nextReminderAt)}'
                            : 'Disabled',
                      ),
                    ),
                    if (reminder.enabled) ...<Widget>[
                      DropdownButtonFormField<int>(
                        initialValue: reminderInterval,
                        decoration: const InputDecoration(
                          labelText: 'Reminder interval',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(value: 3, child: Text('Every 3 days')),
                          DropdownMenuItem<int>(value: 7, child: Text('Every 7 days')),
                          DropdownMenuItem<int>(value: 14, child: Text('Every 14 days')),
                          DropdownMenuItem<int>(value: 30, child: Text('Every 30 days')),
                        ],
                        onChanged: reminderBusy
                            ? null
                            : (value) async {
                                if (value == null) {
                                  return;
                                }
                                await ref
                                    .read(backupReminderProvider.notifier)
                                    .setIntervalDays(value);
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder.isDue
                            ? 'Reminder status: Backup is due now.'
                            : 'Reminder status: On schedule.',
                        style: TextStyle(
                          color: reminder.isDue
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Last successful backup: ${_formatDateTime(reminder.lastSuccessfulBackupAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (reminder.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        reminder.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle(
              context,
              'Backup Actions',
              subtitle: 'Create secure backups or restore from existing files',
            ),
            const SizedBox(height: 8),
            _quickActionButton(
              icon: Icons.backup_outlined,
              label: 'Create Backup',
              onTap: () {
                context.push(RoutePaths.settingsBackupCreate);
              },
            ),
            const SizedBox(height: 8),
            _quickActionButton(
              icon: Icons.restore_outlined,
              label: 'Restore Backup',
              outlined: true,
              onTap: () {
                context.push(RoutePaths.settingsBackupRestore);
              },
            ),
            const SizedBox(height: 8),
            _quickActionButton(
              icon: Icons.cloud_outlined,
              label: 'Google Drive Backup',
              outlined: true,
              onTap: () {
                context.push(RoutePaths.settingsDriveBackup);
              },
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Image compression entry is ready. Processing is post-V1.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.photo_size_select_small_outlined),
              label: const Text('Compress Older Images'),
            ),
            const SizedBox(height: 16),
            _sectionTitle(
              context,
              'Backup History',
              subtitle: 'Latest operations and destination status',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: state.history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No backup history yet.'),
                      )
                    : Column(
                        children: state.history
                            .map((item) => _historyTile(context, item))
                            .toList(growable: false),
                      ),
              ),
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

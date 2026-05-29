import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/auth/data/auth_repository.dart';
import 'package:sanchita/features/settings/data/backup_engine_repository.dart';
import 'package:sanchita/features/settings/providers/backup_overview_provider.dart';
import 'package:sanchita/features/settings/providers/backup_reminder_provider.dart';
import 'package:sanchita/providers/drive_backup_provider.dart';
import 'package:sanchita/services/drive_backup_service.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';

class SettingsDriveBackupScreen extends ConsumerWidget {
  const SettingsDriveBackupScreen({super.key});

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

  Widget _buildSignInView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.cloud_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 24),
          Text(
            'Google Drive Backup',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to your Google account to backup and restore your data to Google Drive.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              ref.read(driveBackupProvider.notifier).signIn();
            },
            icon: const Icon(Icons.login_outlined),
            label: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String? error) {
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupTile(
    BuildContext context,
    WidgetRef ref,
    BackupFile backup,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.backup_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(backup.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(backup.formattedDate),
            Text(backup.formattedSize),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'download') {
              await _showDownloadDialog(context, ref, backup);
            } else if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Backup?'),
                  content: Text('Are you sure you want to delete "${backup.name}"?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref
                    .read(driveBackupProvider.notifier)
                    .deleteBackup(backup.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup deleted')),
                  );
                }
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'download',
              child: Row(
                children: <Widget>[
                  Icon(Icons.download_outlined),
                  SizedBox(width: 12),
                  Text('Download'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: <Widget>[
                  Icon(Icons.delete_outline),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateBackupDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    String encryptionMode = 'pin';
    final pinController = TextEditingController();
    final customPasswordController = TextEditingController();
    bool isCreating = false;

    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Encryption Key',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                // PIN option
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use current PIN'),
                  value: 'pin',
                  // ignore: deprecated_member_use
                  groupValue: encryptionMode,
                  enabled: !isCreating,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null && !isCreating) {
                      setState(() => encryptionMode = value);
                    }
                  },
                ),
                if (encryptionMode == 'pin')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                    child: TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      enabled: !isCreating,
                      decoration: const InputDecoration(
                        labelText: 'Current PIN',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                // Password option
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use custom backup password'),
                  value: 'password',
                  // ignore: deprecated_member_use
                  groupValue: encryptionMode,
                  enabled: !isCreating,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null && !isCreating) {
                      setState(() => encryptionMode = value);
                    }
                  },
                ),
                if (encryptionMode == 'password')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                    child: TextField(
                      controller: customPasswordController,
                      obscureText: true,
                      enabled: !isCreating,
                      decoration: const InputDecoration(
                        labelText: 'Backup password (min 4 chars)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                if (isCreating) ...<Widget>[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Encrypting and uploading backup...'),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      // Validate input
                      String secret;
                      if (encryptionMode == 'pin') {
                        final pin = pinController.text.trim();
                        if (pin.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter current PIN'),
                              ),
                            );
                          }
                          return;
                        }
                        // Verify PIN
                        final verifyResult = await ref
                            .read(authRepositoryProvider)
                            .verifyCurrentPin(pin);
                        var pinVerified = false;
                        verifyResult.when(
                          success: (_) {
                            pinVerified = true;
                          },
                          failure: (message) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          },
                        );
                        if (!pinVerified) {
                          return;
                        }
                        secret = pin;
                      } else {
                        final pwd = customPasswordController.text.trim();
                        if (pwd.length < 4) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password must be at least 4 chars'),
                              ),
                            );
                          }
                          return;
                        }
                        secret = pwd;
                      }

                      setState(() => isCreating = true);

                      // Create backup
                      final result = await ref
                          .read(backupEngineRepositoryProvider)
                          .createEncryptedBackup(
                            destination: 'local',
                            secret: secret,
                          );

                      if (!context.mounted) {
                        return;
                      }

                      await result.when(
                        success: (backupResult) async {
                          // Read backup file and upload to Drive
                          final backupFile = File(backupResult.filePath);
                          if (!await backupFile.exists()) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error: Backup file not found'),
                                ),
                              );
                              setState(() => isCreating = false);
                            }
                            return;
                          }

                          final fileBytes = await backupFile.readAsBytes();
                          final fileName =
                              'Sanchita_Backup_${DateTime.now().toString().split('.')[0].replaceAll(':', '-')}.enc';

                          // Upload to Drive
                          final uploadSuccess = await ref
                              .read(driveBackupProvider.notifier)
                              .uploadBackup(fileBytes, fileName);

                          if (!context.mounted) {
                            return;
                          }

                          if (uploadSuccess) {
                            // Mark backup as completed in reminder system
                            await ref
                                .read(backupReminderProvider.notifier)
                                .markBackupCompleted();
                            // Refresh backup overview
                            await ref
                                .read(backupOverviewProvider.notifier)
                                .refresh();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup uploaded: ${_formatBytes(fileBytes.length)}',
                                  ),
                                ),
                              );
                            }
                          } else {
                            setState(() => isCreating = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload failed'),
                              ),
                            );
                          }
                        },
                        failure: (message) async {
                          if (context.mounted) {
                            setState(() => isCreating = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Backup failed: $message')),
                            );
                          }
                        },
                      );
                    },
              child: const Text('Create & Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDownloadDialog(
    BuildContext context,
    WidgetRef ref,
    BackupFile backup,
  ) async {
    bool isDownloading = false;

    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Download Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.cloud_download_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                backup.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${backup.formattedSize} • ${backup.formattedDate}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'This backup will be downloaded to your device. You can then restore it from the Restore Backup screen.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: isDownloading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isDownloading
                  ? null
                  : () async {
                      setState(() => isDownloading = true);

                      try {
                        final bytes = await ref
                            .read(driveBackupProvider.notifier)
                            .downloadBackup(backup.id);

                        if (context.mounted) {
                          Navigator.pop(context);

                          if (bytes != null && bytes.isNotEmpty) {
                            // Save downloaded bytes to disk
                            try {
                              final backupsDir = Directory('${(await getApplicationDocumentsDirectory()).path}/backups');
                              if (!await backupsDir.exists()) {
                                await backupsDir.create(recursive: true);
                              }
                              final timestamp = DateTime.now().toString().split('.')[0].replaceAll(':', '-');
                              final fileName = 'drive_backup_$timestamp.sanchita';
                              final filePath = '${backupsDir.path}/$fileName';
                              await File(filePath).writeAsBytes(bytes);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Downloaded: ${backup.name}',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Restore',
                                      onPressed: () {
                                        if (context.mounted) {
                                          context.push(RoutePaths.settingsBackupRestore);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error saving backup: $e'),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Download completed'),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isDownloading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Download failed: $e'),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Download'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedInView(
    BuildContext context,
    WidgetRef ref,
    DriveBackupState state,
  ) {
    final isLoading = state.isLoading;

    return Column(
      children: <Widget>[
        // User Info Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundImage: state.currentUser?.photoUrl != null
                          ? NetworkImage(state.currentUser!.photoUrl!)
                          : null,
                      child: state.currentUser?.photoUrl == null
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            state.currentUser?.displayName ?? 'User',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            state.currentUser?.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: isLoading
                          ? null
                          : () {
                              ref
                                  .read(driveBackupProvider.notifier)
                                  .signOut();
                            },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Stats
        Row(
          children: <Widget>[
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total Backups',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.backups.length}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total Size',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(
                          state.backups.fold<int>(
                            0,
                            (sum, backup) => sum + backup.size,
                          ),
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Create Backup Button
        FilledButton.icon(
          onPressed: isLoading
              ? null
              : () {
                  _showCreateBackupDialog(context, ref);
                },
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Create & Upload Backup'),
        ),
        const SizedBox(height: 12),

        // Backup List
        Card(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Backups',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (state.backups.isNotEmpty)
                      FilledButton.tonal(
                        onPressed: isLoading
                            ? null
                            : () {
                                ref
                                    .read(driveBackupProvider.notifier)
                                    .refreshBackups();
                              },
                        child: const Text('Refresh'),
                      ),
                  ],
                ),
              ),
              if (isLoading && state.backups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else if (state.backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No backups yet. Create one to get started.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.backups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: _buildBackupTile(
                        context,
                        ref,
                        state.backups[index],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driveBackupProvider);

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Google Drive Backup',
        showBackButton: true,
      ),
      body: RefreshIndicator(
              onRefresh: () async {
                if (state.isSignedIn) {
                  await ref
                      .read(driveBackupProvider.notifier)
                      .refreshBackups();
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _buildErrorBanner(context, state.error),
                  if (state.isSignedIn)
                    _buildSignedInView(context, ref, state)
                  else
                    _buildSignInView(context, ref),
                ],
              ),
            ),
    );
  }
}

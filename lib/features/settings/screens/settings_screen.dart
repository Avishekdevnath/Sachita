import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/services/biometric_auth_service.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/features/settings/widgets/settings_user_name_dialog.dart';
import 'package:sanchita/shared/widgets/app_navigation_bar.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';
import 'package:sanchita/shared/widgets/section_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _verifyingBiometric = false;

  Future<void> _editUserName(String? current) async {
    final result = await showSettingsUserNameDialog(
      context: context,
      currentName: current,
    );

    if (result == null) {
      return;
    }
    await ref.read(settingsProvider.notifier).setUserName(result);
  }

  Future<void> _onBiometricToggle(bool enabled) async {
    if (_verifyingBiometric) {
      return;
    }

    if (!enabled) {
      await ref.read(settingsProvider.notifier).setBiometricEnabled(false);
      ref.read(sessionProvider.notifier).setBiometricPreference(false);
      return;
    }

    setState(() {
      _verifyingBiometric = true;
    });

    final verifyResult = await ref
        .read(biometricAuthServiceProvider)
        .authenticateForUnlock();

    if (!mounted) {
      return;
    }

    final verified = verifyResult.when(
      success: (_) => true,
      failure: (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return false;
      },
    );

    await ref.read(settingsProvider.notifier).setBiometricEnabled(verified);
    ref.read(sessionProvider.notifier).setBiometricPreference(verified);

    if (mounted) {
      setState(() {
        _verifyingBiometric = false;
      });
    }
  }

  String _themeLabel(String theme) {
    switch (theme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).asData?.value ?? const SettingsState();
    final session = ref.watch(sessionProvider).asData?.value;
    final colorScheme = Theme.of(context).colorScheme;
    final autoLockLabel = switch (settings.autoLockSeconds) {
      0 => 'Never',
      30 => '30 seconds',
      60 => '1 minute',
      300 => '5 minutes',
      900 => '15 minutes',
      1800 => '30 minutes',
      final s => '$s seconds',
    };
    final biometricSummary = settings.biometricEnabled ? 'Enabled' : 'Off';
    final securitySummary = session?.isLockedOut == true
        ? 'Temporarily locked'
        : 'PIN required on app open';

    return Scaffold(
      appBar: const AppNavigationBar(
        title: 'Settings',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space8,
          horizontal: AppTokens.space16,
        ),
        children: <Widget>[
          _SettingsOverviewCard(
            securitySummary: securitySummary,
            biometricSummary: biometricSummary,
            autoLockSummary: autoLockLabel,
            themeSummary: _themeLabel(settings.theme),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- Profile -----
          const SectionHeader(title: 'Profile'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Your Name'),
              subtitle: Text(
                settings.userName?.isNotEmpty == true
                    ? settings.userName!
                    : 'Tap to set name shown on dashboard',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await _editUserName(settings.userName);
              },
            ),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- Security -----
          const SectionHeader(title: 'Security'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: Column(
              children: <Widget>[
                _SettingsNavigationTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: 'Change PIN',
                  subtitle: 'Verify current PIN and set a new PIN',
                  onTap: () {
                    context.push(RoutePaths.settingsChangePin);
                  },
                ),
                const Divider(indent: 56, endIndent: 0, height: 1),
                _SettingsNavigationTile(
                  leading: const Icon(Icons.help_outline),
                  title: 'Change Security Question',
                  subtitle: 'PIN verification required',
                  onTap: () {
                    context.push(RoutePaths.settingsSecurityQuestion);
                  },
                ),
                const Divider(indent: 56, endIndent: 0, height: 1),
                const ListTile(
                  leading: Icon(Icons.pin_outlined),
                  title: Text('PIN behavior'),
                  subtitle: Text(
                    'App asks for PIN when reopened, not during active flows.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- Finance -----
          const SectionHeader(title: 'Finance'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: _SettingsNavigationTile(
              leading: const Icon(Icons.category_outlined),
              title: 'Manage Categories',
              subtitle:
                  'Add, edit, and delete custom income or expense categories',
              onTap: () {
                context.push(RoutePaths.settingsCategories);
              },
            ),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- Data -----
          const SectionHeader(title: 'Data'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: _SettingsNavigationTile(
              leading: const Icon(Icons.storage_outlined),
              title: 'Storage & Backup',
              subtitle: 'Storage usage, backup, and restore history',
              onTap: () {
                context.push(RoutePaths.settingsBackup);
              },
            ),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- Preferences -----
          const SectionHeader(title: 'Preferences'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: Column(
              children: <Widget>[
                _SettingsNavigationTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: 'Appearance',
                  subtitle: '${_themeLabel(settings.theme)} theme',
                  onTap: () {
                    context.push(RoutePaths.settingsAppearance);
                  },
                ),
                const Divider(indent: 56, endIndent: 0, height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Auto-lock timer'),
                  subtitle: const Text('Lock session when app is idle'),
                  trailing: Text(
                    autoLockLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () async {
                    final options = <(int, String)>[
                      (30, '30 seconds'),
                      (60, '1 minute'),
                      (300, '5 minutes'),
                      (900, '15 minutes'),
                      (1800, '30 minutes'),
                      (0, 'Never'),
                    ];
                    final selected = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Auto-lock timer'),
                        children: options.map((option) {
                          return SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, option.$1),
                            child: Text(option.$2),
                          );
                        }).toList(),
                      ),
                    );
                    if (selected != null) {
                      await ref
                          .read(settingsProvider.notifier)
                          .setAutoLockSeconds(selected);
                    }
                  },
                ),
                const Divider(indent: 56, endIndent: 0, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_outlined),
                  value: settings.biometricEnabled,
                  title: const Text('Biometric Enabled'),
                  subtitle: _verifyingBiometric
                      ? const Text('Verifying biometric...')
                      : const Text('Use fingerprint for quick unlock'),
                  onChanged: _verifyingBiometric ? null : _onBiometricToggle,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),

          // ----- About -----
          const SectionHeader(title: 'About'),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: _SettingsNavigationTile(
              leading: const Icon(Icons.info_outline),
              title: 'About & Privacy',
              subtitle: 'Transparency, on-device data policy, and licenses',
              onTap: () {
                context.push(RoutePaths.settingsAbout);
              },
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // ----- Danger Zone -----
          SectionHeader(title: 'Danger Zone', color: colorScheme.error),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: colorScheme.error,
              ),
              title: Text(
                'Delete All Data',
                style: TextStyle(color: colorScheme.error),
              ),
              subtitle: const Text('Delete all app data permanently'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push(RoutePaths.settingsDanger);
              },
            ),
          ),
          const SizedBox(height: AppTokens.space24),
        ],
      ),
    );
  }
}

class _SettingsOverviewCard extends StatelessWidget {
  const _SettingsOverviewCard({
    required this.securitySummary,
    required this.biometricSummary,
    required this.autoLockSummary,
    required this.themeSummary,
  });

  final String securitySummary;
  final String biometricSummary;
  final String autoLockSummary;
  final String themeSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quick Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            'Security and preferences snapshot',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: <Widget>[
              _StatusPill(icon: Icons.lock_outline, label: securitySummary),
              _StatusPill(
                icon: Icons.fingerprint_outlined,
                label: 'Bio: $biometricSummary',
              ),
              _StatusPill(
                icon: Icons.timer_outlined,
                label: 'Auto-lock: $autoLockSummary',
              ),
              _StatusPill(
                icon: Icons.palette_outlined,
                label: themeSummary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppTokens.iconSm),
          const SizedBox(width: AppTokens.space6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

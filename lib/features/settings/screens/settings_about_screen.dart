import 'package:flutter/material.dart';
import 'package:sanchita/shared/widgets/app_logo.dart';

class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  Widget _bulletRow({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  const AppLogo(size: 72),
                  const SizedBox(height: 10),
                  Text(
                    'Sanchita',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Everything important, in one place.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version 1.0.0+1',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Privacy',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _bulletRow(
                    context: context,
                    icon: Icons.lock_outline,
                    text: 'Your data stays on this device.',
                  ),
                  _bulletRow(
                    context: context,
                    icon: Icons.cloud_off_outlined,
                    text: 'No server sync. No analytics tracking.',
                  ),
                  _bulletRow(
                    context: context,
                    icon: Icons.security_outlined,
                    text: 'Vault data is kept in secure storage.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Stored On Device',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _bulletRow(
                    context: context,
                    icon: Icons.payments_outlined,
                    text: 'Finance transactions and budgets',
                  ),
                  _bulletRow(
                    context: context,
                    icon: Icons.folder_special_outlined,
                    text: 'Vault info and document metadata',
                  ),
                  _bulletRow(
                    context: context,
                    icon: Icons.tune_outlined,
                    text: 'App preferences and security settings',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              showLicensePage(context: context, applicationName: 'Sanchita');
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open Source Licenses'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).asData?.value ?? const SettingsState();
    final colorScheme = Theme.of(context).colorScheme;
    final themeLabel = switch (settings.theme) {
      'light' => 'Light',
      'dark' => 'Dark',
      _ => 'System',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: <Widget>[
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Current style',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  '$themeLabel theme',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.space12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTokens.space12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Preview',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppTokens.space6),
                      Text(
                        'Theme applies immediately.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.space8),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'system', label: Text('System')),
              ButtonSegment<String>(value: 'light', label: Text('Light')),
              ButtonSegment<String>(value: 'dark', label: Text('Dark')),
            ],
            selected: <String>{settings.theme},
            onSelectionChanged: (selection) {
              ref.read(settingsProvider.notifier).setTheme(selection.first);
            },
          ),
          const SizedBox(height: AppTokens.space16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(settingsProvider.notifier).setTheme('system');
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appearance reset to defaults')),
              );
            },
            icon: const Icon(Icons.restart_alt_outlined),
            label: const Text('Reset to Default'),
          ),
        ],
      ),
    );
  }
}

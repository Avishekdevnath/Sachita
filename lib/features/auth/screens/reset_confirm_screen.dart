import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/features/finance/providers/finance_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/features/vault/providers/vault_session_provider.dart';
import 'package:sanchita/shared/widgets/glass_app_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';

class ResetConfirmScreen extends ConsumerStatefulWidget {
  const ResetConfirmScreen({super.key});

  @override
  ConsumerState<ResetConfirmScreen> createState() => _ResetConfirmScreenState();
}

class _ResetConfirmScreenState extends ConsumerState<ResetConfirmScreen> {
  final TextEditingController _confirmController = TextEditingController();

  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canDelete => _confirmController.text == 'DELETE';

  Future<void> _onDeleteEverything() async {
    if (!_canDelete || _deleting) {
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    final result = await ref.read(sessionProvider.notifier).resetAppData();
    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.read(vaultSessionProvider.notifier).lock();
        ref.invalidate(financeProvider);
        ref.invalidate(settingsProvider);
        ref.invalidate(sessionProvider);
        context.go(RoutePaths.onboarding);
      },
      failure: (message) {
        setState(() {
          _deleting = false;
          _error = message;
        });
      },
    );
  }

  void _onCancel() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    final session = ref.read(sessionProvider).asData?.value;
    if (session?.authenticated == true) {
      context.go(RoutePaths.settings);
      return;
    }

    context.go(RoutePaths.forgotPin);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Delete All Data'),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: <Widget>[
          Text(
            'This will permanently delete all app data: transactions, groups, vault items, and settings. This action cannot be undone.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTokens.space16),
          TextField(
            controller: _confirmController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppTokens.space12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppTokens.space20),
          FilledButton.tonal(
            onPressed: _deleting ? null : _onCancel,
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppTokens.space8),
          FilledButton(
            onPressed: _canDelete && !_deleting ? _onDeleteEverything : null,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(_deleting ? 'Deleting...' : 'Delete Everything'),
          ),
        ],
      ),
    );
  }
}

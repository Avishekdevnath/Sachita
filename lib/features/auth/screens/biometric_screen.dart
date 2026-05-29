import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/glass_app_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) {
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .authenticateWithBiometric();

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _authenticating = false;
        });
      },
      failure: (message) {
        setState(() {
          _authenticating = false;
          _error = message;
        });
        _usePinFallback();
      },
    );
  }

  void _usePinFallback() {
    ref.read(sessionProvider.notifier).enablePinFallback();
    context.go(RoutePaths.pin);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GlassScaffold(
        appBar: const GlassAppBar(
          title: 'Biometric Unlock',
          showBackButton: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTokens.goldPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTokens.goldPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: AppTokens.iconXl,
                    color: Theme.of(context).glass.goldOnSurface,
                  ),
                ),
                const SizedBox(height: AppTokens.space16),
                const Text(
                  'Unlock Sanchita with biometrics',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppTokens.space20),
                FilledButton(
                  onPressed: _authenticating ? null : _authenticate,
                  child: Text(_authenticating ? 'Authenticating...' : 'Retry'),
                ),
                const SizedBox(height: AppTokens.space8),
                TextButton(
                  onPressed: _usePinFallback,
                  child: const Text('Use PIN instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

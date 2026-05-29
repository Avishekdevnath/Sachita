import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/services/biometric_auth_service.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/auth/data/auth_repository.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/features/vault/providers/vault_session_provider.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({super.key});

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  final TextEditingController _pinController = TextEditingController();

  bool _authenticatingBiometric = false;
  bool _authenticatingPin = false;
  bool _biometricTriggered = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on screen load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoTriggerBiometric();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _autoTriggerBiometric() async {
    if (_biometricTriggered) {
      return;
    }
    _biometricTriggered = true;

    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.biometricEnabled) {
      return;
    }

    await _unlockWithBiometric();
  }


  Future<void> _unlockWithBiometric() async {
    if (_authenticatingBiometric || _authenticatingPin) {
      return;
    }

    setState(() {
      _authenticatingBiometric = true;
      _error = null;
    });

    final result = await ref
        .read(biometricAuthServiceProvider)
        .authenticateForUnlock();

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.read(vaultSessionProvider.notifier).unlock();
      },
      failure: (message) {
        setState(() {
          _authenticatingBiometric = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _unlockWithPin() async {
    if (_authenticatingBiometric || _authenticatingPin) {
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() {
        _error = 'PIN must be 6 digits.';
      });
      return;
    }

    setState(() {
      _authenticatingPin = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).verifyPin(pin);

    if (!mounted) {
      return;
    }

    result.when(
      success: (verification) {
        if (verification.authenticated) {
          ref.read(vaultSessionProvider.notifier).unlock();
          return;
        }

        setState(() {
          _authenticatingPin = false;
          _error = verification.message ?? 'Incorrect PIN.';
        });
      },
      failure: (message) {
        setState(() {
          _authenticatingPin = false;
          _error = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _authenticatingBiometric || _authenticatingPin;
    final settings = ref.watch(settingsProvider).asData?.value;
    final biometricEnabled = settings?.biometricEnabled ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Vault Security'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTokens.goldGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space32,
            ),
            children: <Widget>[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTokens.space20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.onPrimary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 80,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space32),
              Text(
                'Vault Security',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                'Re-authenticate to access your private data',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space40),
              if (biometricEnabled) ...<Widget>[
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space12,
                  ),
                  onTap: isBusy ? null : _unlockWithBiometric,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.fingerprint,
                        color: colorScheme.onPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: AppTokens.space12),
                      Text(
                        _authenticatingBiometric
                            ? 'Authenticating...'
                            : 'Unlock with Biometric',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
              ],
              GlassCard(
                padding: const EdgeInsets.all(AppTokens.space20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Enter PIN',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: false,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        counterText: '',
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.onPrimary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.onPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isBusy ? null : _unlockWithPin,
                        child: Text(
                          _authenticatingPin ? 'Verifying...' : 'Unlock Vault',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppTokens.space16),
                Container(
                  padding: const EdgeInsets.all(AppTokens.space12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colorScheme.onError,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

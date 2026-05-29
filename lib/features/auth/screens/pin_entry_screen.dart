import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/animated_button.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';
import 'package:sanchita/shared/widgets/pin_dots_indicator.dart';
import 'package:sanchita/shared/widgets/pin_pad.dart';

/// REFACTORED PIN Entry Screen - Professional, Efficient, Reactive
///
/// Key Improvements:
/// - Removed manual Timer that rebuilt entire screen every second
/// - Separated PIN form state from clock display
/// - Reactive to lockout state changes only
/// - Uses RepaintBoundary for performance optimization
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  static const int _pinLength = 6;

  String _pin = '';
  String? _error;
  bool _submitting = false;
  bool _biometricBusy = false;

  Future<void> _authenticateBiometric() async {
    if (_biometricBusy || _submitting) {
      return;
    }

    setState(() {
      _biometricBusy = true;
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
          _biometricBusy = false;
        });
      },
      failure: (message) {
        setState(() {
          _biometricBusy = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _submitPin(String pin) async {
    if (pin.length != _pinLength) {
      _setError('PIN must be 6 digits.');
      return;
    }

    _setSubmitting(true);

    final result = await ref
        .read(sessionProvider.notifier)
        .verifyAndAuthenticatePin(pin);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        _clearForm();
      },
      failure: (message) {
        _setError(message);
      },
    );
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _submitting = false;
      });
    }
  }

  void _setSubmitting(bool value) {
    if (mounted) {
      setState(() {
        _submitting = value;
      });
    }
  }

  void _clearForm() {
    if (mounted) {
      setState(() {
        _submitting = false;
        _pin = '';
        _error = null;
      });
    }
  }

  void _onDigitPressed(String digit, {required bool isLockedOut}) {
    if (_submitting || isLockedOut || _pin.length >= _pinLength) {
      return;
    }

    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length == _pinLength) {
      _submitPin(_pin);
    }
  }

  void _onBackspacePressed({required bool isLockedOut}) {
    if (_submitting || isLockedOut || _pin.isEmpty) {
      return;
    }

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GlassScaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Clock display - isolated, only updates when needed
              const RepaintBoundary(
                child: _ClockDisplay(),
              ),
              // PIN form - only rebuilds when form state changes
              Expanded(
                child: RepaintBoundary(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space24,
                          vertical: AppTokens.space16,
                        ),
                        child: _PinForm(
                          pin: _pin,
                          error: _error,
                          isSubmitting: _submitting,
                          isBiometricBusy: _biometricBusy,
                          onDigitPressed: _onDigitPressed,
                          onBackspacePressed: _onBackspacePressed,
                          onBiometricPressed: _authenticateBiometric,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isolated clock display that only updates on minute change or lockout status change
class _ClockDisplay extends ConsumerWidget {
  const _ClockDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final lockedUntil = session?.lockedUntil;
    final now = DateTime.now();
    final isLocked = lockedUntil != null && lockedUntil.isAfter(now);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.space12,
        horizontal: AppTokens.space24,
      ),
      color: isLocked
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.2)
          : Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current time
          Text(
            DateFormat('hh:mm a').format(now),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1,
            ),
          ),
          // Lockout countdown (only shown when locked)
          if (isLocked)
            Text(
              'Locked out (${lockedUntil.difference(now).inSeconds}s)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// PIN form - contains PIN entry UI and handles user interactions
class _PinForm extends ConsumerWidget {
  const _PinForm({
    required this.pin,
    required this.error,
    required this.isSubmitting,
    required this.isBiometricBusy,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    required this.onBiometricPressed,
  });

  final String pin;
  final String? error;
  final bool isSubmitting;
  final bool isBiometricBusy;
  final void Function(String digit, {required bool isLockedOut}) onDigitPressed;
  final void Function({required bool isLockedOut}) onBackspacePressed;
  final VoidCallback onBiometricPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final lockedUntil = session?.lockedUntil;
    final isLockedOut =
        lockedUntil != null && lockedUntil.isAfter(DateTime.now());
    final biometricAvailable = session?.biometricAvailable ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lock icon
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
            Icons.lock_outline,
            size: AppTokens.iconXl,
            color: Theme.of(context).glass.goldOnSurface,
          ),
        ),
        const SizedBox(height: AppTokens.space20),

        // Title
        Text(
          'Enter your 6-digit PIN',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.space16),

        // PIN dots indicator
        PinDotsIndicator(length: pin.length, maxLength: 6),
        const SizedBox(height: AppTokens.space20),

        // Lockout message
        if (isLockedOut) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Text(
              'Too many wrong attempts. Try again later.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTokens.space16),
        ],

        // Error message
        if (error != null) ...[
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.space12),
        ],

        // Submitting indicator
        if (isSubmitting) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: AppTokens.space12),
          const Text('Verifying PIN...'),
          const SizedBox(height: AppTokens.space20),
        ] else ...[
          const SizedBox(height: AppTokens.space12),
        ],

        // PIN Pad
        PinPad(
          enabled: !isSubmitting && !isLockedOut && !isBiometricBusy,
          onDigitPressed: (digit) {
            onDigitPressed(digit, isLockedOut: isLockedOut);
          },
          onBackspacePressed: () {
            onBackspacePressed(isLockedOut: isLockedOut);
          },
        ),

        const SizedBox(height: AppTokens.space16),

        // Biometric button (shown when enabled and not exhausted)
        if (biometricAvailable) ...[
          FilledButton.icon(
            onPressed: (isBiometricBusy || isSubmitting || isLockedOut)
                ? null
                : onBiometricPressed,
            icon: isBiometricBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.fingerprint),
            label: Text(
              isBiometricBusy ? 'Authenticating...' : 'Use Biometric',
            ),
          ),
          const SizedBox(height: AppTokens.space8),
        ],

        // Forgot PIN link
        AnimatedTextButton(
          label: 'Forgot PIN?',
          onPressed: () {
            context.go(RoutePaths.forgotPin);
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/pin_dots_indicator.dart';
import 'package:sanchita/shared/widgets/pin_pad.dart';

class SettingsChangePinScreen extends ConsumerStatefulWidget {
  const SettingsChangePinScreen({super.key});

  @override
  ConsumerState<SettingsChangePinScreen> createState() =>
      _SettingsChangePinScreenState();
}

class _SettingsChangePinScreenState
    extends ConsumerState<SettingsChangePinScreen> {
  static const int _pinLength = 6;

  String _entryPin = '';
  String? _currentPin;
  String? _newPinFirstPass;
  String? _error;
  bool _submitting = false;

  bool get _isVerifyingCurrentPin => _currentPin == null;
  bool get _isEnteringFirstNewPin =>
      _currentPin != null && _newPinFirstPass == null;

  String get _title {
    if (_isVerifyingCurrentPin) {
      return 'Enter current PIN';
    }
    if (_isEnteringFirstNewPin) {
      return 'Enter new PIN';
    }
    return 'Confirm new PIN';
  }

  String get _subtitle {
    if (_isVerifyingCurrentPin) {
      return 'Step 1 of 3';
    }
    if (_isEnteringFirstNewPin) {
      return 'Step 2 of 3';
    }
    return 'Step 3 of 3';
  }

  void _onDigitPressed(String digit, {required bool isLockedOut}) {
    if (_submitting || isLockedOut || _entryPin.length >= _pinLength) {
      return;
    }

    setState(() {
      _entryPin += digit;
      _error = null;
    });

    if (_entryPin.length == _pinLength) {
      _onPinComplete(_entryPin);
    }
  }

  void _onBackspacePressed({required bool isLockedOut}) {
    if (_submitting || isLockedOut || _entryPin.isEmpty) {
      return;
    }

    setState(() {
      _entryPin = _entryPin.substring(0, _entryPin.length - 1);
      _error = null;
    });
  }

  Future<void> _onPinComplete(String pin) async {
    if (_isVerifyingCurrentPin) {
      await _verifyCurrentPin(pin);
      return;
    }

    if (_isEnteringFirstNewPin) {
      setState(() {
        _newPinFirstPass = pin;
        _entryPin = '';
      });
      return;
    }

    final firstPass = _newPinFirstPass;
    final currentPin = _currentPin;
    if (firstPass == null || currentPin == null) {
      return;
    }

    if (pin != firstPass) {
      setState(() {
        _newPinFirstPass = null;
        _entryPin = '';
        _error = 'PINs do not match. Re-enter new PIN.';
      });
      return;
    }

    await _changePin(currentPin: currentPin, newPin: pin);
  }

  Future<void> _verifyCurrentPin(String pin) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .verifyCurrentPinForSettings(pin);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _submitting = false;
          _currentPin = pin;
          _entryPin = '';
        });
      },
      failure: (message) {
        setState(() {
          _submitting = false;
          _entryPin = '';
          _error = message;
        });
      },
    );
  }

  Future<void> _changePin({
    required String currentPin,
    required String newPin,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .changePinFromSettings(currentPin: currentPin, newPin: newPin);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated successfully')),
        );
        context.go(RoutePaths.settings);
      },
      failure: (message) {
        setState(() {
          _submitting = false;
          _entryPin = '';
          _newPinFirstPass = null;
          _error = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(sessionProvider).asData?.value ?? const SessionState();
    final lockedUntil = session.lockedUntil;
    final isLockedOut =
        lockedUntil != null && lockedUntil.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(_title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_subtitle),
              const SizedBox(height: 16),
              PinDotsIndicator(length: _entryPin.length, maxLength: _pinLength),
              if (isLockedOut) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Too many failed attempts. Try again later.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_submitting) ...<Widget>[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              const SizedBox(height: 16),
              PinPad(
                enabled: !_submitting && !isLockedOut,
                onDigitPressed: (digit) {
                  _onDigitPressed(digit, isLockedOut: isLockedOut);
                },
                onBackspacePressed: () {
                  _onBackspacePressed(isLockedOut: isLockedOut);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

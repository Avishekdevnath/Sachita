import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/glass_app_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';
import 'package:sanchita/shared/widgets/pin_dots_indicator.dart';
import 'package:sanchita/shared/widgets/pin_pad.dart';

class SetNewPinScreen extends ConsumerStatefulWidget {
  const SetNewPinScreen({super.key});

  @override
  ConsumerState<SetNewPinScreen> createState() => _SetNewPinScreenState();
}

class _SetNewPinScreenState extends ConsumerState<SetNewPinScreen> {
  static const int _pinLength = 6;

  String? _firstPin;
  String _entryPin = '';
  String? _error;
  bool _submitting = false;

  bool get _isConfirmStep => _firstPin != null;

  void _onDigitPressed(String digit) {
    if (_submitting || _entryPin.length >= _pinLength) {
      return;
    }

    setState(() {
      _entryPin += digit;
      _error = null;
    });

    if (_entryPin.length == _pinLength) {
      _handleCompletedEntry();
    }
  }

  void _onBackspacePressed() {
    if (_submitting || _entryPin.isEmpty) {
      return;
    }

    setState(() {
      _entryPin = _entryPin.substring(0, _entryPin.length - 1);
      _error = null;
    });
  }

  Future<void> _handleCompletedEntry() async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = _entryPin;
        _entryPin = '';
        _error = null;
      });
      return;
    }

    if (_entryPin != _firstPin) {
      setState(() {
        _firstPin = null;
        _entryPin = '';
        _error = 'PINs do not match. Please try again.';
      });
      return;
    }

    await _saveNewPin(_entryPin);
  }

  Future<void> _saveNewPin(String pin) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .setNewPinAfterRecovery(pin);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        context.go(RoutePaths.dashboard);
      },
      failure: (message) {
        setState(() {
          _submitting = false;
          _firstPin = null;
          _entryPin = '';
          _error = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = _isConfirmStep ? 'Confirm new PIN' : 'Set new PIN';
    final step = _isConfirmStep ? 'Step 2 of 2' : 'Step 1 of 2';

    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Reset PIN'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(heading, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTokens.space8),
              Text(step),
              const SizedBox(height: AppTokens.space20),
              PinDotsIndicator(length: _entryPin.length, maxLength: _pinLength),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppTokens.space12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_submitting) ...<Widget>[
                const SizedBox(height: AppTokens.space16),
                const CircularProgressIndicator(),
                const SizedBox(height: AppTokens.space12),
                const Text('Saving new PIN...'),
              ],
              const SizedBox(height: AppTokens.space16),
              PinPad(
                enabled: !_submitting,
                onDigitPressed: _onDigitPressed,
                onBackspacePressed: _onBackspacePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

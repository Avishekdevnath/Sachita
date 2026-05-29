import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/pin_dots_indicator.dart';
import 'package:sanchita/shared/widgets/pin_pad.dart';

class SettingsSecurityQuestionScreen extends ConsumerStatefulWidget {
  const SettingsSecurityQuestionScreen({super.key});

  @override
  ConsumerState<SettingsSecurityQuestionScreen> createState() =>
      _SettingsSecurityQuestionScreenState();
}

class _SettingsSecurityQuestionScreenState
    extends ConsumerState<SettingsSecurityQuestionScreen> {
  static const int _pinLength = 6;
  static const List<String> _securityQuestions = <String>[
    'What was the name of your first pet?',
    'What city were you born in?',
    'What was the name of your primary school?',
    'What is your mother\'s maiden name?',
    'What is your oldest sibling\'s middle name?',
  ];

  final TextEditingController _answerController = TextEditingController();

  String _pinEntry = '';
  String? _verifiedPin;
  String _selectedQuestion = _securityQuestions.first;
  String? _error;
  bool _submitting = false;

  bool get _isPinStep => _verifiedPin == null;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit, {required bool isLockedOut}) {
    if (_submitting || isLockedOut || _pinEntry.length >= _pinLength) {
      return;
    }

    setState(() {
      _pinEntry += digit;
      _error = null;
    });

    if (_pinEntry.length == _pinLength) {
      _verifyCurrentPin(_pinEntry);
    }
  }

  void _onBackspacePressed({required bool isLockedOut}) {
    if (_submitting || isLockedOut || _pinEntry.isEmpty) {
      return;
    }

    setState(() {
      _pinEntry = _pinEntry.substring(0, _pinEntry.length - 1);
      _error = null;
    });
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
          _verifiedPin = pin;
          _pinEntry = '';
        });
      },
      failure: (message) {
        setState(() {
          _submitting = false;
          _pinEntry = '';
          _error = message;
        });
      },
    );
  }

  Future<void> _saveSecurityQuestion() async {
    final currentPin = _verifiedPin;
    final answer = _answerController.text.trim();

    if (currentPin == null) {
      setState(() {
        _error = 'PIN verification is required.';
      });
      return;
    }

    if (answer.isEmpty) {
      setState(() {
        _error = 'Enter your security answer.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .updateSecurityQuestionFromSettings(
          currentPin: currentPin,
          securityQuestion: _selectedQuestion,
          securityAnswer: answer,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security question updated')),
        );
        context.go(RoutePaths.settings);
      },
      failure: (message) {
        setState(() {
          _submitting = false;
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
      appBar: AppBar(title: const Text('Change Security Question')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            _isPinStep
                ? 'Verify current PIN to continue'
                : 'Update recovery question',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_isPinStep) ...<Widget>[
            PinDotsIndicator(length: _pinEntry.length, maxLength: _pinLength),
            const SizedBox(height: 16),
            if (_submitting) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            PinPad(
              enabled: !_submitting && !isLockedOut,
              onDigitPressed: (digit) {
                _onDigitPressed(digit, isLockedOut: isLockedOut);
              },
              onBackspacePressed: () {
                _onBackspacePressed(isLockedOut: isLockedOut);
              },
            ),
          ] else ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: _selectedQuestion,
              items: _securityQuestions
                  .map(
                    (question) => DropdownMenuItem<String>(
                      value: question,
                      child: Text(question, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedQuestion = value;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              onChanged: (_) {
                setState(() {
                  _error = null;
                });
              },
              decoration: const InputDecoration(labelText: 'Security answer'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _saveSecurityQuestion,
              child: Text(_submitting ? 'Saving...' : 'Save Changes'),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (isLockedOut) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Too many failed attempts. Try again later.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

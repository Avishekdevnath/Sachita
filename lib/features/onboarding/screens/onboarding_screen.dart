import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/services/biometric_auth_service.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/shared/models/result.dart';
import 'package:sanchita/shared/widgets/glass_app_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';
import 'package:sanchita/shared/widgets/pin_dots_indicator.dart';
import 'package:sanchita/shared/widgets/pin_pad.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _totalSteps = 8;
  static const int _pinLength = 6;
  static const List<String> _securityQuestions = <String>[
    'What was the name of your first pet?',
    'What city were you born in?',
    'What was the name of your primary school?',
    'What is your mother\'s maiden name?',
    'What is your oldest sibling\'s middle name?',
  ];

  final PageController _pageController = PageController();
  final TextEditingController _securityAnswerController =
      TextEditingController();

  int _currentStep = 0;

  bool _biometricEnabled = false;
  bool _finishing = false;

  String _currencyCode = 'BDT';
  String _currencySymbol = 'BDT';

  String _pinDraft = '';
  String? _pinFirstPass;
  String? _confirmedPin;

  String? _selectedSecurityQuestion = _securityQuestions.first;
  bool _answerHadText = false;
  String? _stepError;

  @override
  void dispose() {
    _pageController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  bool get _isValuePropStep => _currentStep <= 2;
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  String _stepTitleFor(int index) {
    switch (index) {
      case 0:
        return 'Everything important, in one place';
      case 1:
        return 'Know where your money goes';
      case 2:
        return 'Never lose an important document';
      case 3:
        return 'Confirm your currency';
      case 4:
        return 'Privacy statement';
      case 5:
        return 'Create your PIN';
      case 6:
        return 'Set security question';
      case 7:
        return 'Enable biometric unlock';
      default:
        return 'Onboarding';
    }
  }

  String _stepDescriptionFor(int index) {
    switch (index) {
      case 0:
        return 'Track finance, store documents, and keep private info secured on-device.';
      case 1:
        return 'Add income and expense quickly with monthly summaries and budgets.';
      case 2:
        return 'Capture and keep important files encrypted and organized.';
      case 3:
        return 'Choose your display currency now. You can change it later in settings.';
      case 4:
        return 'Your data stays on your device. No account is required for core usage.';
      case 5:
        return 'Set a 6-digit PIN. You must enter it twice to confirm.';
      case 6:
        return 'Pick a recovery question and answer. This is your only PIN recovery option.';
      case 7:
        return 'Choose whether biometric should be enabled after onboarding.';
      default:
        return '';
    }
  }

  Future<void> _goToStep(int step) async {
    setState(() {
      _currentStep = step;
      _stepError = null;
    });

    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  bool _canProceedCurrentStep() {
    if (_currentStep == 5) {
      return _confirmedPin != null;
    }

    if (_currentStep == 6) {
      return _selectedSecurityQuestion != null &&
          _securityAnswerController.text.trim().isNotEmpty;
    }

    if (_currentStep == 7) {
      return !_finishing;
    }

    return true;
  }

  Future<void> _onNextPressed() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _stepError = null;
    });

    if (_currentStep == 5 && _confirmedPin == null) {
      setState(() {
        _stepError = 'Set and confirm your 6-digit PIN to continue.';
      });
      return;
    }

    if (_currentStep == 6) {
      if (_selectedSecurityQuestion == null ||
          _securityAnswerController.text.trim().isEmpty) {
        setState(() {
          _stepError = 'Choose a security question and enter its answer.';
        });
        return;
      }
    }

    if (_isLastStep) {
      await _completeOnboarding();
      return;
    }

    await _goToStep(_currentStep + 1);
  }

  Future<void> _completeOnboarding() async {
    final confirmedPin = _confirmedPin;
    final selectedQuestion = _selectedSecurityQuestion;
    final securityAnswer = _securityAnswerController.text.trim();

    if (confirmedPin == null ||
        selectedQuestion == null ||
        securityAnswer.isEmpty) {
      setState(() {
        _stepError = 'Please complete PIN and security question setup.';
      });
      return;
    }

    setState(() {
      _finishing = true;
      _stepError = null;
    });

    if (_biometricEnabled) {
      final biometricSetupResult = await ref
          .read(biometricAuthServiceProvider)
          .authenticateForUnlock();
      if (biometricSetupResult is Failure<void>) {
        setState(() {
          _finishing = false;
          _stepError = biometricSetupResult.message;
        });
        return;
      }
    }

    await ref
        .read(settingsProvider.notifier)
        .setCurrency(
          currencyCode: _currencyCode,
          currencySymbol: _currencySymbol,
        );

    final result = await ref
        .read(sessionProvider.notifier)
        .completeOnboarding(
          biometricEnabled: _biometricEnabled,
          pin: confirmedPin,
          securityQuestion: selectedQuestion,
          securityAnswer: securityAnswer,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref
            .read(settingsProvider.notifier)
            .setBiometricEnabled(_biometricEnabled);
        setState(() {
          _finishing = false;
        });
      },
      failure: (message) {
        setState(() {
          _finishing = false;
          _stepError = message;
        });
      },
    );
  }

  void _onPinDigitPressed(String digit) {
    if (_confirmedPin != null || _pinDraft.length >= _pinLength) {
      return;
    }

    setState(() {
      _pinDraft += digit;
      _stepError = null;
    });

    if (_pinDraft.length == _pinLength) {
      _commitPinDraft();
    }
  }

  void _onPinBackspacePressed() {
    if (_confirmedPin != null || _pinDraft.isEmpty) {
      return;
    }

    setState(() {
      _pinDraft = _pinDraft.substring(0, _pinDraft.length - 1);
      _stepError = null;
    });
  }

  void _commitPinDraft() {
    final enteredPin = _pinDraft;

    if (_pinFirstPass == null) {
      setState(() {
        _pinFirstPass = enteredPin;
        _pinDraft = '';
      });
      return;
    }

    if (_pinFirstPass != enteredPin) {
      setState(() {
        _pinFirstPass = null;
        _confirmedPin = null;
        _pinDraft = '';
        _stepError = 'PINs do not match. Enter your PIN again.';
      });
      return;
    }

    setState(() {
      _confirmedPin = enteredPin;
      _pinDraft = '';
    });
  }

  void _resetPinSetup() {
    setState(() {
      _pinFirstPass = null;
      _confirmedPin = null;
      _pinDraft = '';
      _stepError = null;
    });
  }

  static IconData _iconForStep(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard_customize_outlined;
      case 1:
        return Icons.account_balance_wallet_outlined;
      case 2:
        return Icons.folder_special_outlined;
      case 3:
        return Icons.currency_exchange_outlined;
      case 4:
        return Icons.security_outlined;
      case 5:
        return Icons.pin_outlined;
      case 6:
        return Icons.help_outline;
      case 7:
        return Icons.fingerprint_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Setup',
        showBackButton: false,
        actions: <Widget>[
          if (_isValuePropStep)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _goToStep(3);
              },
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!_isValuePropStep)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space8,
                AppTokens.space16,
                0,
              ),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          const SizedBox(height: AppTokens.space12),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalSteps,
              itemBuilder: (context, index) {
                return _OnboardingStepView(
                  title: _stepTitleFor(index),
                  description: _stepDescriptionFor(index),
                  step: index + 1,
                  totalSteps: _totalSteps,
                  icon: _iconForStep(index),
                  extraChild: _buildStepExtra(index),
                );
              },
            ),
          ),
          if (_stepError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                0,
                AppTokens.space16,
                AppTokens.space8,
              ),
              child: Text(
                _stepError!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Row(
              children: <Widget>[
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _finishing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _goToStep(_currentStep - 1);
                            },
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: FilledButton(
                    onPressed: _finishing || !_canProceedCurrentStep()
                        ? null
                        : _onNextPressed,
                    child: Text(
                      _isLastStep
                          ? (_finishing ? 'Completing...' : 'Complete')
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildStepExtra(int index) {
    if (index == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppTokens.space12),
          DropdownButtonFormField<String>(
            initialValue: _currencyCode,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'BDT', child: Text('BDT (BDT)')),
              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR (EUR)')),
              DropdownMenuItem(value: 'INR', child: Text('INR (INR)')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _currencyCode = value;
                _currencySymbol = switch (value) {
                  'USD' => r'$',
                  'EUR' => 'EUR',
                  'INR' => 'INR',
                  _ => 'BDT',
                };
              });
            },
          ),
        ],
      );
    }

    if (index == 5) {
      final pinStepLabel = _confirmedPin != null
          ? 'PIN confirmed'
          : (_pinFirstPass == null ? 'Step 1 of 2' : 'Step 2 of 2');

      return Column(
        children: <Widget>[
          const SizedBox(height: AppTokens.space8),
          Text(
            pinStepLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          PinDotsIndicator(length: _pinDraft.length, maxLength: _pinLength),
          const SizedBox(height: AppTokens.space12),
          if (_confirmedPin != null)
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _resetPinSetup();
              },
              child: const Text('Re-enter PIN'),
            )
          else
            PinPad(
              onDigitPressed: _onPinDigitPressed,
              onBackspacePressed: _onPinBackspacePressed,
            ),
        ],
      );
    }

    if (index == 6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppTokens.space12),
          DropdownButtonFormField<String>(
            initialValue: _selectedSecurityQuestion,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Security question'),
            items: _securityQuestions
                .map(
                  (question) => DropdownMenuItem<String>(
                    value: question,
                    child: Text(question, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedSecurityQuestion = value;
                _stepError = null;
              });
            },
          ),
          const SizedBox(height: AppTokens.space8),
          TextField(
            controller: _securityAnswerController,
            onChanged: (value) {
              final hasText = value.trim().isNotEmpty;
              if (_stepError != null || hasText != _answerHadText) {
                _answerHadText = hasText;
                setState(() {
                  _stepError = null;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Your answer'),
          ),
        ],
      );
    }

    if (index == 7) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable biometric unlock'),
        value: _biometricEnabled,
        onChanged: (value) {
          HapticFeedback.lightImpact();
          setState(() {
            _biometricEnabled = value;
          });
        },
      );
    }

    // Defensive null return - validation failed
    return null;
  }
}

class _OnboardingStepView extends StatelessWidget {
  const _OnboardingStepView({
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.icon,
    this.extraChild,
  });

  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final IconData icon;
  final Widget? extraChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: AppTokens.onboardingIconSize,
                    height: AppTokens.onboardingIconSize,
                    decoration: BoxDecoration(
                      color: AppTokens.goldPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTokens.goldPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: AppTokens.iconXl,
                      color: Theme.of(context).glass.goldOnSurface,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space20),
                  Text(
                    'Step $step of $totalSteps',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (extraChild != null) ...<Widget>[
                    const SizedBox(height: AppTokens.space16),
                    extraChild!,
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

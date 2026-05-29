import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/constants/route_paths.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/shared/widgets/glass_app_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final TextEditingController _answerController = TextEditingController();

  bool _loadingQuestion = true;
  bool _submitting = false;
  String? _error;
  String? _securityQuestion;

  @override
  void initState() {
    super.initState();
    _loadSecurityQuestion();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityQuestion() async {
    setState(() {
      _loadingQuestion = true;
      _error = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .loadSecurityQuestion();
    if (!mounted) {
      return;
    }

    result.when(
      success: (question) {
        setState(() {
          _securityQuestion = question;
          _loadingQuestion = false;
        });
      },
      failure: (message) {
        setState(() {
          _error = message;
          _loadingQuestion = false;
        });
      },
    );
  }

  Future<void> _verifyAnswer() async {
    final answer = _answerController.text.trim();
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
        .verifySecurityAnswer(answer);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        context.go(RoutePaths.setNewPin);
      },
      failure: (message) {
        setState(() {
          _error = message;
          _submitting = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Forgot PIN'),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: <Widget>[
          Text(
            'Security verification',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTokens.space12),
          if (_loadingQuestion)
            const LinearProgressIndicator()
          else
            Text(
              _securityQuestion ?? 'Security question unavailable.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: AppTokens.space12),
          TextField(
            controller: _answerController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Security answer'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppTokens.space8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppTokens.space20),
          FilledButton(
            onPressed: _submitting || _loadingQuestion ? null : _verifyAnswer,
            child: Text(_submitting ? 'Verifying...' : 'Verify Answer'),
          ),
          const SizedBox(height: AppTokens.space12),
          TextButton(
            onPressed: () {
              context.push(RoutePaths.resetConfirm);
            },
            child: const Text('Reset all app data'),
          ),
        ],
      ),
    );
  }
}

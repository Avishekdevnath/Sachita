import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.enabled = true,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final bool enabled;

  static const List<String> _digits = <String>[
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '',  '0', 'backspace',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final digitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _digits.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppTokens.pinPadSpacing,
        crossAxisSpacing: AppTokens.pinPadSpacing,
        childAspectRatio: AppTokens.pinPadButtonAspectRatio,
      ),
      itemBuilder: (context, index) {
        final value = _digits[index];
        if (value.isEmpty) {
          return const SizedBox.shrink();
        }

        final isBackspace = value == 'backspace';

        return Material(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    if (isBackspace) {
                      onBackspacePressed();
                    } else {
                      onDigitPressed(value);
                    }
                  }
                : null,
            child: Center(
              child: isBackspace
                  ? Icon(
                      Icons.backspace_outlined,
                      color: enabled
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                    )
                  : Text(
                      value,
                      style: digitStyle?.copyWith(
                        color: enabled
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

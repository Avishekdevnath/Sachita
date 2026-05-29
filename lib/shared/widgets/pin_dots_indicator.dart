import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({super.key, required this.length, this.maxLength = 6});

  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(maxLength, (index) {
        final isFilled = index < length;
        final size = isFilled
            ? AppTokens.pinDotSize
            : AppTokens.pinDotSize * 0.65;
        return AnimatedContainer(
          duration: AppTokens.durationFast,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isFilled ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: AppTokens.pinDotBorderWidth,
            ),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

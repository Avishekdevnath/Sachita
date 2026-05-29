import 'package:flutter/material.dart';

class MoneyAmountText extends StatelessWidget {
  const MoneyAmountText({
    required this.amountText,
    this.color,
    this.style,
    this.semanticLabel,
    super.key,
  });

  final String amountText;
  final Color? color;
  final TextStyle? style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
      fontWeight: FontWeight.w700,
      color: color,
    );

    return Semantics(
      label: semanticLabel,
      child: Text(
        amountText,
        style: effectiveStyle,
      ),
    );
  }
}

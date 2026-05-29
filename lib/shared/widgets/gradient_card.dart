import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.gradient = AppTokens.goldGradient,
    this.padding = const EdgeInsets.all(AppTokens.space20),
    this.borderRadius = AppTokens.cardRadius,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppTokens.goldPrimary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

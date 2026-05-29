import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

/// Glass morphism card with solid semi-transparent surface.
///
/// Uses theme-aware surface tint instead of BackdropFilter to ensure reliable
/// rendering inside scrollable slivers and CustomScrollView contexts where
/// BackdropFilter can fail to composite correctly. Provides:
/// - Theme-aware semi-transparent surface (dark / light)
/// - Subtle top highlight border for depth
/// - Tap feedback via InkWell ripple
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.borderRadius = AppTokens.cardRadius,
    this.onTap,
    this.blurSigma = 16.0,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).glass;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solid semi-transparent surface — reliable in any rendering context.
    // Dark: lifted surface tint; Light: frosted white tint.
    final surfaceColor = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.75);

    final decoratedChild = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: glass.border.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: decoratedChild,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: decoratedChild,
      ),
    );
  }
}

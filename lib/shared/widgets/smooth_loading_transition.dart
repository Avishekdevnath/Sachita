import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Smoothly transitions between loading and content states with optional skeleton.
/// Provides a polished loading experience with fade animations.
class SmoothLoadingTransition<T> extends StatelessWidget {
  const SmoothLoadingTransition({
    super.key,
    required this.isLoading,
    required this.child,
    this.skeleton,
    this.duration = AppTokens.durationNormal,
    this.curve = Curves.easeInOut,
  });

  final bool isLoading;
  final Widget child;
  final Widget? skeleton;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: skeleton ?? _defaultSkeleton(context),
      secondChild: child,
      crossFadeState: isLoading ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: duration,
      firstCurve: curve,
      secondCurve: curve,
    );
  }

  Widget _defaultSkeleton(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

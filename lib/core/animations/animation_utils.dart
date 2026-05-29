import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Utility class for common animation patterns used throughout the app.
abstract final class AnimationUtils {
  /// Page transition animation (slide + fade)
  static PageRouteBuilder slidePageRoute({
    required Widget page,
    Duration duration = AppTokens.durationNormal,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const offset = Offset(1.0, 0.0);
        final tween = Tween(begin: offset, end: Offset.zero).chain(
          CurveTween(curve: Curves.easeInOut),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Fade transition animation
  static PageRouteBuilder fadePageRoute({
    required Widget page,
    Duration duration = AppTokens.durationNormal,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Scale + fade transition animation
  static PageRouteBuilder scalePageRoute({
    required Widget page,
    Duration duration = AppTokens.durationNormal,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        );

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Bounce animation curve
  static const bounceInOut = Curves.elasticInOut;
  static const easeInOutSmooth = Curves.easeInOutCubic;
  static const smoothAccelerate = Curves.easeInExpo;
  static const smoothDecelerate = Curves.easeOutExpo;

  /// List item stagger animation
  static Animation<double> getStaggerAnimation({
    required int index,
    required int itemCount,
    required Animation<double> parentAnimation,
    Duration staggerDuration = const Duration(milliseconds: 50),
    Duration totalDuration = AppTokens.durationNormal,
  }) {
    final interval = 1.0 / itemCount * index;
    final staggerInterval = staggerDuration.inMilliseconds /
        totalDuration.inMilliseconds;

    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: parentAnimation,
        curve: Interval(
          interval,
          (interval + staggerInterval).clamp(0.0, 1.0),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}

/// Widget for animated list items with stagger effect
class StaggeredListAnimation extends StatelessWidget {
  const StaggeredListAnimation({
    super.key,
    required this.itemIndex,
    required this.child,
    required this.animation,
    this.itemCount = 10,
  });

  final int itemIndex;
  final Widget child;
  final Animation<double> animation;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final itemAnimation = AnimationUtils.getStaggerAnimation(
      index: itemIndex,
      itemCount: itemCount,
      parentAnimation: animation,
    );

    return FadeTransition(
      opacity: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(itemAnimation),
        child: child,
      ),
    );
  }
}

/// Animated slide widget
class AnimatedSlideWidget extends StatelessWidget {
  const AnimatedSlideWidget({
    super.key,
    required this.child,
    required this.isVisible,
    this.duration = AppTokens.durationNormal,
    this.direction = AxisDirection.down,
  });

  final Widget child;
  final bool isVisible;
  final Duration duration;
  final AxisDirection direction;

  Offset _getOffsetFromDirection() {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0, -0.1);
      case AxisDirection.down:
        return const Offset(0, 0.1);
      case AxisDirection.left:
        return const Offset(-0.1, 0);
      case AxisDirection.right:
        return const Offset(0.1, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: isVisible ? Offset.zero : _getOffsetFromDirection(),
      duration: duration,
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: duration,
        child: child,
      ),
    );
  }
}

/// Pulse animation widget
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minOpacity = 0.5,
  });

  final Widget child;
  final Duration duration;
  final double minOpacity;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: widget.minOpacity).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Shake animation for error states
class ShakeAnimation extends StatefulWidget {
  const ShakeAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.distance = 5.0,
  });

  final Widget child;
  final Duration duration;
  final double distance;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final shakeValue = math.sin(value * math.pi * 4) * widget.distance;

        return Transform.translate(
          offset: Offset(shakeValue, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

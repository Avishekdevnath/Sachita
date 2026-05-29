import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

/// Enhanced card with smooth animations and interactive feedback.
/// Provides hover effects and better visual hierarchy.
class EnhancedCard extends StatefulWidget {
  const EnhancedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.borderRadius = AppTokens.cardRadius,
    this.elevation = AppTokens.elevationCard,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.enableHoverEffect = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double elevation;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final Border? border;
  final bool enableHoverEffect;

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTokens.durationFast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown() {
    if (widget.enableHoverEffect) {
      _controller.forward();
    }
  }

  void _onPointerUp() {
    if (widget.enableHoverEffect) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        onEnter: (_) => widget.enableHoverEffect ? _onPointerDown() : null,
        onExit: (_) => widget.enableHoverEffect ? _onPointerUp() : null,
        child: GestureDetector(
          onTapDown: (_) => _onPointerDown(),
          onTapUp: (_) {
            _onPointerUp();
            widget.onTap?.call();
          },
          onTapCancel: _onPointerUp,
          onLongPress: widget.onLongPress,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Card(
              elevation: widget.elevation,
              shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
              color: widget.backgroundColor ?? Theme.of(context).glass.background,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: widget.gradient,
                  border: widget.border,
                ),
                child: Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card specifically designed for displaying financial information
class FinanceCard extends EnhancedCard {
  const FinanceCard({
    super.key,
    required super.child,
    super.onTap,
    super.margin = const EdgeInsets.symmetric(
      vertical: AppTokens.space8,
      horizontal: AppTokens.space16,
    ),
    super.padding = const EdgeInsets.all(AppTokens.space16),
    super.gradient,
  });
}

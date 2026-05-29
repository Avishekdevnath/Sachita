import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Animated number text that smoothly transitions between values.
/// Useful for displaying changing amounts, balances, and counts.
class AnimatedNumberText extends StatefulWidget {
  const AnimatedNumberText(
    this.value, {
    super.key,
    this.style,
    this.duration = AppTokens.durationNormal,
    this.curve = Curves.easeInOut,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 2,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final int decimals;

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = _buildAnimation(widget.value, widget.value);
    _controller.forward();
  }

  Animation<double> _buildAnimation(int from, int to) {
    return Tween<double>(
      begin: from.toDouble(),
      end: to.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didUpdateWidget(AnimatedNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = _buildAnimation(_previousValue, widget.value);
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    final formatted = (value / 100).toStringAsFixed(widget.decimals);
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_formatNumber(_animation.value)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

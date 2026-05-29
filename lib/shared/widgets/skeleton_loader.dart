import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Generic skeleton loader with shimmer effect.
/// Used to show placeholder content while data is loading.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppTokens.radiusMd,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
  });

  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: widget.margin,
      child: Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.circular(widget.borderRadius),
          ),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
            transform: _ShimmerTransform(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _ShimmerTransform extends GradientTransform {
  const _ShimmerTransform(this.shimmerPhase);

  final double shimmerPhase;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * shimmerPhase * 2 - bounds.width,
      0.0,
      0.0,
    );
  }
}

/// Skeleton for a card/tile layout
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: AppTokens.space8),
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.height = 120,
  });

  final EdgeInsets margin;
  final EdgeInsets padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Card(
        child: Padding(
          padding: padding,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(
                width: double.infinity,
                height: 16,
                borderRadius: AppTokens.radiusSm,
                margin: EdgeInsets.only(bottom: AppTokens.space8),
              ),
              SkeletonLoader(
                width: 200,
                height: 14,
                borderRadius: AppTokens.radiusSm,
                margin: EdgeInsets.only(bottom: AppTokens.space16),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(
                    width: 80,
                    height: 12,
                    borderRadius: AppTokens.radiusSm,
                  ),
                  SkeletonLoader(
                    width: 80,
                    height: 12,
                    borderRadius: AppTokens.radiusSm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a list of items
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 120,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonCard(height: itemHeight),
    );
  }
}

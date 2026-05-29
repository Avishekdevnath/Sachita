import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Empty state widget with improved visual hierarchy and semantic colors.
///
/// Displays when content is unavailable with clear messaging and optional actions.
/// Now supports semantic icon colors for better visual feedback.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.receipt_long_outlined,
///   title: 'No transactions yet',
///   subtitle: 'Start by adding a transaction',
///   iconColor: AppTokens.infoBlue,
///   action: FilledButton(...),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
    this.iconSize = 80.0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: effectiveIconColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: iconSize * 0.5,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(height: AppTokens.space24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space12),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppTokens.space24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: action!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Semantic action bar for displaying quick access options with clear affordances.
///
/// Provides:
/// - Clear visual hierarchy for quick actions
/// - Icon + label + count pattern
/// - Better touch targets than chips
/// - Consistent spacing
///
/// Usage:
/// ```dart
/// ActionBar(
///   actions: [
///     ActionBarItem(
///       label: 'Groups',
///       count: 5,
///       icon: Icons.groups_outlined,
///       onTap: () => ...,
///     ),
///   ],
/// )
/// ```
class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.actions,
    this.spacing = AppTokens.space8,
    super.key,
  });

  final List<ActionBarItem> actions;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: actions
          .map((action) => _ActionBarButton(action: action))
          .toList(),
    );
  }
}

class ActionBarItem {
  const ActionBarItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
    this.badge,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final String? badge; // "5", "NEW", "!", etc.
  final bool enabled;
}

class _ActionBarButton extends StatefulWidget {
  const _ActionBarButton({required this.action});

  final ActionBarItem action;

  @override
  State<_ActionBarButton> createState() => _ActionBarButtonState();
}

class _ActionBarButtonState extends State<_ActionBarButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = widget.action.enabled;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.action.onTap();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: Transform.scale(
        scale: _isPressed ? 0.96 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space8,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.surfaceContainer
                : colorScheme.surfaceContainer.withValues(
                    alpha: AppTokens.opacityDisabled,
                  ),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: colorScheme.outline.withValues(
                alpha: isEnabled ? 0.2 : 0.1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.action.icon,
                size: AppTokens.iconSm,
                color: isEnabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(
                        alpha: AppTokens.opacityDisabled,
                      ),
              ),
              const SizedBox(width: AppTokens.space6),
              Text(
                widget.action.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(
                              alpha: AppTokens.opacityDisabled,
                            ),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (widget.action.count != null ||
                  widget.action.badge != null) ...[
                const SizedBox(width: AppTokens.space6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space6,
                    vertical: AppTokens.space2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Text(
                    widget.action.badge ?? '${widget.action.count}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/shared/widgets/glass_card.dart';

/// Semantic section container for organizing related content.
///
/// Provides:
/// - Optional header with title and action button
/// - Clear visual separation from other sections
/// - Consistent spacing and padding
/// - Support for different visual hierarchies (header, content, footer)
///
/// Usage:
/// ```dart
/// SectionCard(
///   title: 'Transactions',
///   action: IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
///   children: [
///     TransactionTile(...),
///     TransactionTile(...),
///   ],
/// )
/// ```
class SectionCard extends StatelessWidget {
  const SectionCard({
    this.title,
    this.subtitle,
    this.action,
    this.children = const <Widget>[],
    this.footer,
    this.isGlass = true,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.spacing = AppTokens.space12,
    super.key,
  });

  /// Section title displayed at the top
  final String? title;

  /// Optional subtitle under the title
  final String? subtitle;

  /// Optional action widget (usually IconButton) in the header
  final Widget? action;

  /// Content widgets displayed in a column
  final List<Widget> children;

  /// Optional footer widget displayed at the bottom
  final Widget? footer;

  /// Whether to use glass card styling (true) or standard card (false)
  final bool isGlass;

  /// Padding around the content
  final EdgeInsets padding;

  /// Vertical spacing between children
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          if (children.isNotEmpty)
            const SizedBox(height: AppTokens.space16),
        ],
        if (children.isNotEmpty)
          Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          ),
        if (footer != null) ...[
          const SizedBox(height: AppTokens.space12),
          footer!,
        ],
      ],
    );

    if (isGlass) {
      return GlassCard(
        padding: padding,
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: padding,
        child: content,
      ),
    );
  }
}

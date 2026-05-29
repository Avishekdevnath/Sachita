import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Reusable modal bottom sheet wrapper for heavy input forms.
///
/// Use [AppModalSheet.show] to present a draggable bottom sheet with a
/// consistent drag handle, title bar, and close button.
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    required this.title,
    required this.child,
    required this.scrollController,
    super.key,
  });

  final String title;
  final Widget child;
  final ScrollController scrollController;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    double initialChildSize = 0.7,
    double minChildSize = 0.4,
    double maxChildSize = 0.92,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusXl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) => AppModalSheet(
          title: title,
          scrollController: scrollController,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppTokens.space12),
        // Drag handle
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withAlpha(100),
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        // Title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: AppTokens.space8),
        // Scrollable content
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space8,
              AppTokens.space16,
              AppTokens.space24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: <Widget>[child],
          ),
        ),
      ],
    );
  }
}

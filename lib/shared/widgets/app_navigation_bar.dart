import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Reusable AppBar with consistent navigation patterns
/// Supports back button, home button, and custom actions
class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavigationBar({
    required this.title,
    this.showBackButton = true,
    this.showHomeButton = false,
    this.actions = const <Widget>[],
    this.onBackPressed,
    this.onHomePressed,
    super.key,
  });

  /// The title to display in the app bar
  final String title;

  /// Whether to show the back button (pop to previous screen)
  final bool showBackButton;

  /// Whether to show the home button (navigate to dashboard)
  final bool showHomeButton;

  /// Additional action buttons (refresh, info, etc.)
  final List<Widget> actions;

  /// Custom callback when back button is pressed
  /// If null, uses context.pop()
  final VoidCallback? onBackPressed;

  /// Custom callback when home button is pressed
  /// If null, uses context.go('/dashboard')
  final VoidCallback? onHomePressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onBackPressed != null) {
                  onBackPressed!();
                } else {
                  // Try to pop the current route
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    // If can't pop (e.g., due to context.go() usage), go to dashboard
                    context.go('/dashboard');
                  }
                }
              },
            )
          : null,
      actions: <Widget>[
        ...actions,
        if (showHomeButton)
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              if (onHomePressed != null) {
                onHomePressed!();
              } else {
                context.go('/dashboard');
              }
            },
          ),
      ],
    );
  }
}

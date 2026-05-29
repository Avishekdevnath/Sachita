import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

/// Glass-styled app bar — drop-in replacement for [AppNavigationBar].
///
/// Same constructor API: [showBackButton], [showHomeButton], [actions],
/// [onBackPressed], [onHomePressed]. Screens can swap without call-site changes.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    required this.title,
    this.showBackButton = true,
    this.showHomeButton = false,
    this.actions = const <Widget>[],
    this.onBackPressed,
    this.onHomePressed,
    super.key,
  });

  final String title;
  final bool showBackButton;
  final bool showHomeButton;
  final List<Widget> actions;
  final VoidCallback? onBackPressed;
  final VoidCallback? onHomePressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).glass;

    return AppBar(
      backgroundColor: glass.scaffoldStart,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onBackPressed != null) {
                  onBackPressed!();
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
            )
          : null,
      automaticallyImplyLeading: showBackButton,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: glass.border,
        ),
      ),
    );
  }
}

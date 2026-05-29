import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

/// Scaffold wrapper that applies a vertical gradient background.
///
/// Does NOT use [extendBodyBehindAppBar] or [extendBody] — body renders
/// in the normal region between app bar and bottom nav.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).glass;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[glass.scaffoldStart, glass.scaffoldEnd],
          ),
        ),
        child: body,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchita/core/models/update_check_result.dart';
import 'package:sanchita/core/providers/update_check_provider.dart';
import 'package:sanchita/shared/widgets/app_bottom_navigation_bar.dart';
import 'package:sanchita/shared/widgets/glass_scaffold.dart';
import 'package:sanchita/shared/widgets/update_dialog.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  bool _updateDialogShown = false;

  // Maps router branch index → visible nav index (hidden branches fall back to 0).
  int _branchToNav(int branch) => switch (branch) {
        1 => 1,
        3 => 2,
        _ => 0,
      };

  // Maps visible nav index → router branch index.
  int _navToBranch(int nav) => switch (nav) {
        1 => 1,
        2 => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    ref.listen(updateCheckProvider, (_, next) {
      if (_updateDialogShown) return;
      next.whenData((result) {
        if (result is NoUpdate) return;
        _updateDialogShown = true;
        switch (result) {
          case SoftUpdate():
            showSoftUpdateDialog(context, result);
          case ForceUpdate():
            showForceUpdateDialog(context, result);
          case NoUpdate():
            break;
        }
      });
    });

    // Branch indices: 0=Dashboard, 1=Finance, 2=Groups(hidden), 3=Search, 4=Vault(hidden)
    // Nav indices:    0=Dashboard, 1=Finance,                   2=Search
    final branchIndex = widget.navigationShell.currentIndex;
    final navIndex = _branchToNav(branchIndex);

    return GlassScaffold(
      body: widget.navigationShell,
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          final branch = _navToBranch(index);
          widget.navigationShell.goBranch(
            branch,
            initialLocation: branch == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

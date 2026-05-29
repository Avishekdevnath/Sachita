import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

/// Single source of truth for the app's primary bottom navigation destinations.
///
/// Use [AppBottomNavigationBar] inside [Scaffold.bottomNavigationBar] / shell
/// scaffolds to render a consistent five-tab nav across the app. The
/// destination list is exposed via [AppBottomNavigationDestinations.values] so
/// indexes stay in sync with shell branches.
class AppBottomNavigationDestinations {
  const AppBottomNavigationDestinations._();

  static const List<NavigationDestination> values = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Finance',
    ),
    // Groups tab hidden — feature not yet active (branch index 2 still exists in router)
    // NavigationDestination(
    //   icon: Icon(Icons.groups_outlined),
    //   selectedIcon: Icon(Icons.groups),
    //   label: 'Groups',
    // ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: 'Search',
    ),
    // Vault tab hidden — feature not yet active (branch index 4 still exists in router)
    // NavigationDestination(
    //   icon: Icon(Icons.lock_outline),
    //   selectedIcon: Icon(Icons.lock),
    //   label: 'Vault',
    // ),
  ];
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).glass;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: glass.border, width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: AppBottomNavigationDestinations.values,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import 'app_nav_bar.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0, initialLocation: true);
      },
      child: Scaffold(
      backgroundColor: AppTheme.surface,
      // Use a Column so the nav bar is a sibling of the content,
      // not a Scaffold bottomNavigationBar — this avoids SafeArea
      // double-padding issues with nested Scaffolds.
      body: Column(
        children: [
          Expanded(
            // Remove bottom system inset from MediaQuery so inner
            // screens' SafeArea widgets don't double-pad the bottom.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: navigationShell,
            ),
          ),
          AppNavBar(
            currentIndex: navigationShell.currentIndex,
            onTabSelected: (index) => navigationShell.goBranch(
              index,
              // Tapping the active tab scrolls back to top (initialLocation).
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

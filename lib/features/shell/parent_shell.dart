import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';

import '../parent/pages/parent_dashboard.dart';
import '../parent/pages/parent_assignments_screen.dart';
import '../parent/pages/parent_progress_screen.dart';
import '../parent/pages/parent_announcements_screen.dart';
import '../parent/pages/parent_results_screen.dart';
import '../parent/pages/parent_attendance_screen.dart';

// ─── Parent Navigation Shell ──────────────────────────────────────────────────

class ParentShell extends ConsumerStatefulWidget {
  final Widget child;

  const ParentShell({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/parent',
    ),
    _NavDestination(
      label: 'Progress',
      icon: Icons.trending_up_outlined,
      selectedIcon: Icons.trending_up_rounded,
      route: '/parent/progress',
    ),
    _NavDestination(
      label: 'Results',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      route: '/parent/results',
    ),
    _NavDestination(
      label: 'Attendance',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      route: '/parent/attendance',
    ),
    _NavDestination(
      label: 'More',
      icon: Icons.more_horiz_outlined,
      selectedIcon: Icons.more_horiz_rounded,
      route: '/parent/announcements',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIndexWithRoute();
  }

  void _syncIndexWithRoute() {
    final location = GoRouterState.of(context).matchedLocation;
    // Match the longest prefix
    int bestMatch = -1;
    int bestLength = 0;
    for (int i = 0; i < _destinations.length; i++) {
      final route = _destinations[i].route;
      if (location.startsWith(route) && route.length > bestLength) {
        bestMatch = i;
        bestLength = route.length;
      }
    }
    // Special case: /parent/assignments also maps to "More" tab
    if (location == '/parent/assignments' && bestMatch < 4) {
      bestMatch = 4;
    }
    if (bestMatch != -1 && bestMatch != _currentIndex) {
      setState(() => _currentIndex = bestMatch);
    }
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTap,
        backgroundColor: isDark
            ? KlasivoColors.darkSurface
            : KlasivoColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: KlasivoColors.secondarySurface,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KlasivoTypography.labelSmall.copyWith(
              color: KlasivoColors.secondary,
            );
          }
          return KlasivoTypography.labelSmall.copyWith(
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          );
        }),

        destinations: _destinations
            .map((dest) => NavigationDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: dest.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}


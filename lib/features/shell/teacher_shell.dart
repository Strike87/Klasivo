import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';

// ─── Teacher/Owner Navigation Shell ──────────────────────────────────────────

class TeacherShell extends ConsumerStatefulWidget {
  final Widget child;

  const TeacherShell({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      route: '/dashboard',
    ),
    _NavDestination(
      label: 'Academic',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      route: '/academic',
    ),
    _NavDestination(
      label: 'People',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      route: '/people',
    ),
    _NavDestination(
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      route: '/inbox',
    ),
    _NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: '/settings',
    ),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final userName = ref.watch(userNameProvider) ?? 'User';

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTap,
        destinations: _destinations.asMap().entries.map((entry) {
          final index = entry.key;
          final dest = entry.value;
          final isInbox = dest.label == 'Inbox';

          return NavigationDestination(
            icon: Badge(
              isLabelVisible: isInbox && unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: Icon(dest.icon),
            ),
            selectedIcon: Badge(
              isLabelVisible: isInbox && unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: Icon(dest.selectedIcon),
            ),
            label: dest.label,
          );
        }).toList(),
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

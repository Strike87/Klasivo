import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../providers/notification_provider.dart';

// ─── Student Navigation Shell ────────────────────────────────────────────────

class StudentShell extends ConsumerStatefulWidget {
  final Widget child;

  const StudentShell({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'Exams',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz_rounded,
    ),
    _NavDestination(
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
    ),
    _NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTap,
        destinations: _destinations.asMap().entries.map((entry) {
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

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

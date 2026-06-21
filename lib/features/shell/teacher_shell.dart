import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_badge.dart';

// ─── Teacher/Owner Navigation Shell ──────────────────────────────────────────

class TeacherShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const TeacherShell({super.key, required this.shell});

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    _NavDestination(
      label: 'Academic',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
    ),
    _NavDestination(
      label: 'People',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final userName = ref.watch(userNameProvider) ?? 'User';

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: _destinations.map((dest) {
          final isInbox = dest.label == 'Inbox';

          return NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(dest.icon),
                if (isInbox && unreadNotifs > 0)
                  Positioned(
                    top: -4,
                    right: -12,
                    child: KlasivoBadge(
                      label: '$unreadNotifs',
                      variant: KlasivoBadgeVariant.danger,
                      size: KlasivoBadgeSize.sm,
                    ),
                  ),
              ],
            ),
            selectedIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(dest.selectedIcon),
                if (isInbox && unreadNotifs > 0)
                  Positioned(
                    top: -4,
                    right: -12,
                    child: KlasivoBadge(
                      label: '$unreadNotifs',
                      variant: KlasivoBadgeVariant.danger,
                      size: KlasivoBadgeSize.sm,
                    ),
                  ),
              ],
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

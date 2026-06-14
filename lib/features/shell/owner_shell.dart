import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_badge.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OWNER SHELL — Owner-specific bottom navigation with admin tabs
// Provides Dashboard, Academic, People, Inbox, and Settings tabs.
// Owners see additional admin features (Audit Log, Org Settings, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

class OwnerShell extends ConsumerStatefulWidget {
  final Widget child;

  const OwnerShell({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  int _currentIndex = 0;

  static const List<_OwnerNavDestination> _destinations = [
    _OwnerNavDestination(
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      route: '/dashboard',
    ),
    _OwnerNavDestination(
      label: 'Academic',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      route: '/academic',
    ),
    _OwnerNavDestination(
      label: 'People',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      route: '/people',
    ),
    _OwnerNavDestination(
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      route: '/inbox',
    ),
    _OwnerNavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: '/settings',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIndexWithRoute();
  }

  void _syncIndexWithRoute() {
    final location = GoRouterState.of(context).matchedLocation;
    final newIndex = _destinations.indexWhere((d) => location.startsWith(d.route));
    if (newIndex != -1 && newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final userName = ref.watch(userNameProvider) ?? 'Owner';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTap,
        backgroundColor: isDark
            ? KlasivoColors.darkSurface
            : KlasivoColors.lightSurface,
        indicatorColor: KlasivoColors.primary.withValues(alpha: 0.12),
        destinations: _destinations.asMap().entries.map((entry) {
          final index = entry.key;
          final dest = entry.value;
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

class _OwnerNavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _OwnerNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

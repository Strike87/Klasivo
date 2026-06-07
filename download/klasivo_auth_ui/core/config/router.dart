import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/splash_screen.dart';
import '../../features/auth/pages/login_screen.dart';
import '../../features/auth/pages/register_screen.dart';
import '../../features/auth/pages/org_naming_screen.dart';
import '../../features/auth/pages/student_login_screen.dart';
import '../config/app_constants.dart';
import '../providers/auth_provider.dart';

/// Global navigator keys for shell routes
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final needsSetupAsync = ref.watch(needsSetupProvider);

  // Determine redirect based on auth state
  String? redirectLogic(GoRouterState state) {
    final isAuthRoute = [
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.studentLogin,
      AppRoutes.splash,
    ].contains(state.matchedLocation);

    final isOrgNaming = state.matchedLocation == AppRoutes.orgNaming;

    return authState.when(
      data: (user) {
        // Not logged in
        if (user == null) {
          // Allow access to auth routes
          if (isAuthRoute) return null;
          return AppRoutes.login;
        }

        // Logged in
        if (isAuthRoute && !isOrgNaming) {
          // Check if user needs org setup
          return needsSetupAsync.when(
            data: (needsSetup) {
              if (needsSetup) return AppRoutes.orgNaming;
              return AppRoutes.dashboard;
            },
            loading: () => AppRoutes.splash,
            error: (_, __) => AppRoutes.orgNaming,
          );
        }

        // Logged in and on org naming — check if they still need setup
        if (isOrgNaming) {
          return needsSetupAsync.when(
            data: (needsSetup) {
              if (!needsSetup) return AppRoutes.dashboard;
              return null; // Allow access to org naming
            },
            loading: () => null, // Stay on org naming while loading
            error: (_, __) => null, // Stay on org naming on error
          );
        }

        // Logged in and on a protected route — check setup
        return needsSetupAsync.when(
          data: (needsSetup) {
            if (needsSetup) return AppRoutes.orgNaming;
            return null; // Allow access
          },
          loading: () => null,
          error: (_, __) => null,
        );
      },
      loading: () {
        // Still loading auth state — go to splash
        if (state.matchedLocation == AppRoutes.splash) return null;
        return AppRoutes.splash;
      },
      error: (_, __) {
        if (isAuthRoute) return null;
        return AppRoutes.login;
      },
    );
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: redirectLogic,
    routes: [
      // ── Auth Routes (no shell) ──
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.orgNaming,
        builder: (context, state) => const OrgNamingScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentLogin,
        builder: (context, state) => const StudentLoginScreen(),
      ),

      // ── Protected Routes (require auth) ──
      // These will be expanded as more screens are implemented.
      // For now, placeholder routes that will be replaced
      // with ShellRoute for bottom navigation.

      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const _PlaceholderScreen(title: 'Dashboard'),
      ),
      GoRoute(
        path: AppRoutes.studentDashboard,
        builder: (context, state) => const _PlaceholderScreen(title: 'Student Dashboard'),
      ),
    ],
  );
});

/// Temporary placeholder for routes not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '$title — Coming Soon',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

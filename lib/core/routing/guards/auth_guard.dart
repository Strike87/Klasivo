/// Klasivo v2.0 - Authentication route guard
/// 
/// Redirects unauthenticated users to the login screen.
/// Used in GoRouter redirect callbacks.
library;

import "package:go_router/go_router.dart";

/// Authentication guard for route protection.
/// 
/// Checks if the user is authenticated before allowing
/// access to protected routes. Redirects to login if not.
/// 
/// Usage in GoRouter:
/// ```dart
/// redirect: authGuard,
/// ```
String? authGuard(GoRouterState state) {
  // TODO: Implement auth state check
  // final isAuthenticated = /* check auth provider */;
  // final isAuthRoute = state.matchedLocation == AppRoutes.login ||
  //     state.matchedLocation == AppRoutes.welcome;
  // if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;
  // if (isAuthenticated && isAuthRoute) return AppRoutes.teacherHome;
  return null;
}


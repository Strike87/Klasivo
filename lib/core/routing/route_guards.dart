import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/permission_service.dart';

/// Guard that redirects unauthenticated users to login.
String? authGuard(Ref ref, GoRouterState state) {
  final isLoggedIn = ref.read(isLoggedInProvider);
  if (!isLoggedIn) return '/auth';
  return null;
}

/// Guard that checks a specific permission before allowing access.
String? permissionGuard(Ref ref, GoRouterState state, String permission) {
  final role = ref.read(userRoleProvider);
  final userId = ref.read(userIdProvider);
  if (role.isEmpty || userId == null) return '/auth';
  final hasPermission = PermissionService.instance.hasPermission(
    userId: userId,
    role: role,
    permission: permission,
  );
  return hasPermission ? null : '/dashboard';
}

/// Guard that restricts access to specific roles.
String? roleGuard(Ref ref, GoRouterState state, List<String> allowedRoles) {
  final role = ref.read(userRoleProvider);
  if (!allowedRoles.contains(role)) return '/dashboard';
  return null;
}

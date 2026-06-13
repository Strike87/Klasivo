import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/tokens/tokens.dart';
import '../core/rbac/rbac.dart';
import '../providers/permission_provider.dart'; // Backward compat — old providers
import '../providers/rbac_provider.dart'; // New RBAC v2.0 providers
import '../providers/feature_flag_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PERMISSION GATE v2.0 — Declarative RBAC UI control
//
// Supports both the old API (backward compatible) and the new RBAC v2.0 API.
// The new API adds scope-aware permission checks.
// ═══════════════════════════════════════════════════════════════════════════════

/// Shows [child] only if the current user has the specified permission.
/// Optionally shows [fallback] when permission is denied.
///
/// **v2.0 API (recommended):**
/// ```dart
/// KlasivoPermissionGate(
///   permission: Permission.examCreate,
///   scopeType: 'class',     // Optional scope validation
///   scopeId: 'class_5A',    // Optional scope validation
///   child: KlasivoButton(label: 'New Exam', onPressed: ...),
///   fallback: Text('No permission'),
/// )
/// ```
///
/// **v1 backward compatible API:**
/// ```dart
/// KlasivoPermissionGate(
///   permission: Permission.examCreate,
///   resourceId: 'class_5A',    // Legacy field
///   resourceType: 'class',     // Legacy field
///   child: ...,
/// )
/// ```
class KlasivoPermissionGate extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  // v2.0 scope fields (preferred)
  final String? scopeType;
  final String? scopeId;

  // v1 legacy fields (backward compatible)
  final String? resourceId;
  final String? resourceType;

  /// When true, uses the new RBAC v2.0 providers.
  /// When false (default), uses the old permission_provider.dart.
  /// Toggle this during migration; remove after full migration.
  final bool useV2;

  const KlasivoPermissionGate({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
    this.scopeType,
    this.scopeId,
    this.resourceId,
    this.resourceType,
    this.useV2 = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool hasPermission;

    if (useV2) {
      // v2.0: Use new RBAC providers with scope support
      if (scopeType != null && scopeId != null) {
        hasPermission = ref.watch(rbacCanScopedProvider(
          RbacScopedCheck(
            permission: permission,
            scopeType: scopeType!,
            scopeId: scopeId!,
          ),
        ));
      } else {
        hasPermission = ref.watch(rbacCanProvider(permission));
      }
    } else {
      // v1: Use old permission providers (backward compatible)
      hasPermission = ref.watch(hasPermissionProvider(
        PermissionCheck(
          permission: permission,
          resourceId: resourceId,
          resourceType: resourceType,
        ),
      ));
    }

    if (hasPermission) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows [child] only if the current user has one of the specified roles.
/// Optionally shows [fallback] when role check fails.
///
/// **v2.0** uses hierarchy-aware role checking via [hasRole].
class KlasivoRoleGate extends ConsumerWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  /// When true, uses hierarchy-aware hasRole() instead of exact match.
  final bool useHierarchy;

  /// When true, uses the new RBAC v2.0 providers.
  final bool useV2;

  const KlasivoRoleGate({
    Key? key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.useHierarchy = true,
    this.useV2 = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool hasRole;

    if (useV2) {
      final service = ref.watch(rbacPermissionServiceProvider);
      if (useHierarchy) {
        // Hierarchy-aware: owner is considered to "have" admin role, etc.
        hasRole = allowedRoles.any((role) => service.hasRole(role));
      } else {
        // Exact match only
        hasRole = allowedRoles.any((role) => service.hasExactRole(role));
      }
    } else {
      // v1: exact string match
      final userRole = ref.watch(currentUserRoleProvider);
      hasRole = allowedRoles.contains(userRole);
    }

    if (hasRole) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows [child] only if the current user's scope includes the specified resource.
/// Optionally shows [fallback] when scope validation fails.
///
/// ```dart
/// KlasivoScopeGate(
///   scopeType: 'class',
///   scopeId: 'class_5A',
///   child: ClassDetailScreen(classId: 'class_5A'),
///   fallback: Text('No access to this class'),
/// )
/// ```
class KlasivoScopeGate extends ConsumerWidget {
  final String scopeType;
  final String scopeId;
  final Widget child;
  final Widget? fallback;

  const KlasivoScopeGate({
    Key? key,
    required this.scopeType,
    required this.scopeId,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasScope = ref.watch(rbacScopeValidatorProvider(
      RbacScopeCheck(scopeType: scopeType, scopeId: scopeId),
    ));

    if (hasScope) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Combined permission + scope gate.
/// Checks both permission AND scope in one widget.
///
/// ```dart
/// KlasivoPermissionScopeGate(
///   permission: Permission.examCreate,
///   scopeType: 'class',
///   scopeId: 'class_5A',
///   child: ExamFormScreen(classId: 'class_5A'),
/// )
/// ```
class KlasivoPermissionScopeGate extends ConsumerWidget {
  final String permission;
  final String scopeType;
  final String scopeId;
  final Widget child;
  final Widget? fallback;

  const KlasivoPermissionScopeGate({
    Key? key,
    required this.permission,
    required this.scopeType,
    required this.scopeId,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(rbacCanScopedProvider(
      RbacScopedCheck(
        permission: permission,
        scopeType: scopeType,
        scopeId: scopeId,
      ),
    ));

    if (hasPermission) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows a feature-flag gated UI. Used for features that are still in
/// development or rolling out gradually.
class KlasivoFeatureGate extends ConsumerWidget {
  final String featureFlag;
  final Widget child;
  final Widget? fallback;

  const KlasivoFeatureGate({
    Key? key,
    required this.featureFlag,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(featureFlagEnabledProvider(featureFlag));

    if (isEnabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows a locked/preview version of [child] when the feature is not enabled.
/// Displays a lock overlay with the feature name, useful for showing
/// upcoming features in the UI.
class KlasivoFeaturePreview extends ConsumerWidget {
  final String featureFlag;
  final String featureName;
  final Widget child;

  const KlasivoFeaturePreview({
    Key? key,
    required this.featureFlag,
    required this.featureName,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(featureFlagEnabledProvider(featureFlag));

    if (isEnabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Opacity(opacity: 0.4, child: child),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.lg,
              vertical: KlasivoSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
              borderRadius: BorderRadius.circular(KlasivoRadius.md),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: KlasivoSpacing.iconSizeMd,
                  color: KlasivoColors.lightTextTertiary,
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                Text(
                  '$featureName — Coming Soon',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

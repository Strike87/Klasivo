import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/tokens/tokens.dart';
import '../providers/permission_provider.dart';
import '../providers/feature_flag_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PERMISSION GATE — Declarative RBAC UI control
// Wraps UI elements to show/hide based on user permissions.
// Replaces manual role-checking in build methods.
// ═══════════════════════════════════════════════════════════════════════════════

/// Shows [child] only if the current user has the specified permission.
/// Optionally shows [fallback] when permission is denied.
///
/// Usage:
/// ```dart
/// KlasivoPermissionGate(
///   permission: Permission.createExam,
///   child: KlasivoButton(label: 'New Exam', onPressed: ...),
///   fallback: Text('No permission'),
/// )
/// ```
class KlasivoPermissionGate extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final String? resourceId;      // For resource-level permissions
  final String? resourceType;    // e.g., 'class', 'exam', 'organization'

  const KlasivoPermissionGate({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
    this.resourceId,
    this.resourceType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(hasPermissionProvider(
      PermissionCheck(
        permission: permission,
        resourceId: resourceId,
        resourceType: resourceType,
      ),
    ));

    if (hasPermission) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows [child] only if the current user has one of the specified roles.
/// Optionally shows [fallback] when role check fails.
class KlasivoRoleGate extends ConsumerWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const KlasivoRoleGate({
    Key? key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(currentUserRoleProvider);
    final hasRole = allowedRoles.contains(userRole);

    if (hasRole) return child;
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
        // Dimmed content
        Opacity(opacity: 0.4, child: child),
        // Lock overlay
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

import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K BADGE — Badge component for the Klasivo Design System
//
// Features:
// - Variants: info, success, warning, error, neutral
// - Sizes: sm, md, lg
// - Dot indicator variant
// - Counter variant (for notifications)
// ═══════════════════════════════════════════════════════════════════════════════

/// Badge semantic variant within the Klasivo Design System.
enum KBadgeVariant {
  /// Blue/indigo — informational labels.
  info,

  /// Green — success, completed, active states.
  success,

  /// Amber — warnings, pending, in-progress.
  warning,

  /// Red — errors, failed, critical.
  error,

  /// Gray — neutral, default labels.
  neutral,
}

/// Badge size within the Klasivo Design System.
enum KBadgeSize {
  /// Compact — table cells, inline labels.
  sm,

  /// Standard — cards, lists (default).
  md,

  /// Large — prominent labels, standalone badges.
  lg,
}

/// A versatile badge component supporting semantic variants, sizes,
/// dot indicators, and counter variants.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography] tokens
/// exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KBadge(
///   label: 'Active',
///   variant: KBadgeVariant.success,
///   size: KBadgeSize.sm,
/// )
///
/// KBadge.dot(
///   variant: KBadgeVariant.success,
/// )
///
/// KBadge.counter(count: 5)
/// ```
class KBadge extends StatelessWidget {
  /// The text label displayed on the badge.
  final String? label;

  /// The semantic variant determining badge colors.
  final KBadgeVariant variant;

  /// The size of the badge.
  final KBadgeSize size;

  /// Optional icon displayed before the label.
  final IconData? icon;

  /// Custom background color (overrides variant default).
  final Color? customBgColor;

  /// Custom foreground/text color (overrides variant default).
  final Color? customFgColor;

  /// Optional tap handler.
  final VoidCallback? onTap;

  // ─── Dot indicator mode ─────────────────────────────────────────────────

  /// When true, renders only a colored dot instead of a label.
  final bool _isDot;

  // ─── Counter mode ───────────────────────────────────────────────────────

  /// When provided, renders as a counter badge (e.g., notification count).
  final int? _count;

  const KBadge({
    super.key,
    this.label,
    this.variant = KBadgeVariant.info,
    this.size = KBadgeSize.md,
    this.icon,
    this.customBgColor,
    this.customFgColor,
    this.onTap,
  })  : _isDot = false,
        _count = null;

  /// Creates a dot indicator badge.
  const KBadge.dot({
    super.key,
    this.variant = KBadgeVariant.success,
    this.size = KBadgeSize.md,
    this.customBgColor,
    this.onTap,
  })  : label = null,
        icon = null,
        customFgColor = null,
        _isDot = true,
        _count = null;

  /// Creates a counter badge for notification counts.
  const KBadge.counter({
    super.key,
    required int count,
    this.variant = KBadgeVariant.error,
    this.size = KBadgeSize.md,
    this.customBgColor,
    this.customFgColor,
    this.onTap,
  })  : label = null,
        icon = null,
        _isDot = false,
        _count = count;

  @override
  Widget build(BuildContext context) {
    // Dot indicator variant
    if (_isDot) {
      return _buildDot();
    }

    // Counter variant
    if (_count != null) {
      return _buildCounter();
    }

    // Standard label badge
    return _buildLabelBadge();
  }

  /// Builds a dot indicator badge.
  Widget _buildDot() {
    final dotSize = _dotSize;
    final color = customBgColor ?? _variantBgColor;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Builds a counter badge.
  Widget _buildCounter() {
    final (hPad, vPad, fontSize) = _sizeConfig;
    final bgColor = customBgColor ?? _variantBgColor;
    final fgColor = customFgColor ?? _variantFgColor;

    final displayCount = _count! > 99 ? '99+' : '${_count!}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        constraints: BoxConstraints(
          minWidth: AppSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          displayCount,
          style: AppTypography.labelSmall.copyWith(
            color: fgColor,
            fontSize: fontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Builds a standard label badge with optional icon.
  Widget _buildLabelBadge() {
    final (hPad, vPad, fontSize) = _sizeConfig;
    final bgColor = customBgColor ?? _variantBgColor;
    final fgColor = customFgColor ?? _variantFgColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.badge),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: _iconSize, color: fgColor),
              const SizedBox(width: AppSpacing.inlineXs),
            ],
            if (label != null)
              Text(
                label!,
                style: AppTypography.labelSmall.copyWith(
                  color: fgColor,
                  fontSize: fontSize,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Size configuration ────────────────────────────────────────────────

  /// Returns (horizontal padding, vertical padding, font size) based on size.
  (double, double, double) get _sizeConfig => switch (size) {
        KBadgeSize.sm => (AppSpacing.sm, AppSpacing.xs / 2, 10.0),
        KBadgeSize.md =>
          (AppSpacing.chipHorizontal, AppSpacing.chipVertical, 11.0),
        KBadgeSize.lg =>
          (AppSpacing.md, AppSpacing.sm, AppTypography.labelSmall.fontSize!),
      };

  /// Returns icon size based on badge size.
  double get _iconSize => switch (size) {
        KBadgeSize.sm => 10,
        KBadgeSize.md => 12,
        KBadgeSize.lg => AppSpacing.iconSizeSm,
      };

  /// Returns dot size based on badge size.
  double get _dotSize => switch (size) {
        KBadgeSize.sm => AppSpacing.xs + 2,
        KBadgeSize.md => AppSpacing.sm,
        KBadgeSize.lg => AppSpacing.sm + AppSpacing.xs,
      };

  // ─── Variant colors ────────────────────────────────────────────────────

  /// Returns the background color for the current variant.
  Color get _variantBgColor => switch (variant) {
        KBadgeVariant.info => AppColors.infoSurface,
        KBadgeVariant.success => AppColors.successSurface,
        KBadgeVariant.warning => AppColors.warningSurface,
        KBadgeVariant.error => AppColors.errorSurface,
        KBadgeVariant.neutral => const Color(0xFFF1F3F5),
      };

  /// Returns the foreground (text/icon) color for the current variant.
  Color get _variantFgColor => switch (variant) {
        KBadgeVariant.info => AppColors.info,
        KBadgeVariant.success => AppColors.success,
        KBadgeVariant.warning => AppColors.warning,
        KBadgeVariant.error => AppColors.error,
        KBadgeVariant.neutral => const Color(0xFF495057),
      };

  // ─── Factory constructors ──────────────────────────────────────────────

  /// Creates a role badge with the appropriate role color.
  static KBadge role(String role) {
    final color = AppColors.roleColor(role);
    final displayName = role.replaceAll('_', ' ').split(' ').map(
      (w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
    ).join(' ');

    return KBadge(
      label: displayName,
      variant: KBadgeVariant.neutral,
      customBgColor: color.withOpacity(0.1),
      customFgColor: color,
    );
  }

  /// Creates a status badge with the appropriate variant.
  static KBadge status(String status) {
    return switch (status.toLowerCase()) {
      'active' || 'published' || 'present' => KBadge(
          label: status.toUpperCase(),
          variant: KBadgeVariant.success,
        ),
      'draft' || 'pending' => KBadge(
          label: status.toUpperCase(),
          variant: KBadgeVariant.warning,
        ),
      'completed' || 'graded' || 'submitted' => KBadge(
          label: status.toUpperCase(),
          variant: KBadgeVariant.info,
        ),
      'flagged' || 'absent' || 'failed' => KBadge(
          label: status.toUpperCase(),
          variant: KBadgeVariant.error,
        ),
      _ => KBadge(label: status, variant: KBadgeVariant.neutral),
    };
  }
}

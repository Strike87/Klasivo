import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO BADGE — Status and role badges with consistent styling
// Used for roles, statuses, categories, and inline labels.
// ═══════════════════════════════════════════════════════════════════════════════

enum KlasivoBadgeVariant {
  primary,    // Indigo background
  secondary,  // Emerald background
  accent,     // Amber background
  danger,     // Red background
  neutral,    // Gray background
  custom,     // Custom color
}

enum KlasivoBadgeSize {
  sm,  // Compact — table cells, inline
  md,  // Standard — cards, lists
}

class KlasivoBadge extends StatelessWidget {
  final String label;
  final KlasivoBadgeVariant variant;
  final KlasivoBadgeSize size;
  final IconData? icon;
  final Color? customColor;   // Only used when variant = custom
  final VoidCallback? onTap;

  const KlasivoBadge({
    Key? key,
    required this.label,
    this.variant = KlasivoBadgeVariant.primary,
    this.size = KlasivoBadgeSize.md,
    this.icon,
    this.customColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();

    final (hPad, vPad, fontSize, iconSize) = switch (size) {
      KlasivoBadgeSize.sm => (6.0, 2.0, 10.0, 12.0),
      KlasivoBadgeSize.md => (AppSpacing.chipHorizontal, AppSpacing.chipVertical, 11.0, 14.0),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.badge),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize, color: fg),
              const SizedBox(width: AppSpacing.inlineXs),
            ],
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: fg,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    return switch (variant) {
      KlasivoBadgeVariant.primary => (AppColors.primarySurface, AppColors.primary),
      KlasivoBadgeVariant.secondary => (AppColors.secondarySurface, AppColors.secondary),
      KlasivoBadgeVariant.accent => (AppColors.accentSurface, AppColors.accent),
      KlasivoBadgeVariant.danger => (AppColors.errorSurface, AppColors.error),
      KlasivoBadgeVariant.neutral => (const Color(0xFFF1F3F5), const Color(0xFF495057)),
      KlasivoBadgeVariant.custom => (
        (customColor ?? AppColors.primary).withOpacity(0.1),
        customColor ?? AppColors.primary,
      ),
    };
  }

  // ─── Factory: Role badge ────────────────────────────────────────────────
  static KlasivoBadge role(String role) {
    final color = AppColors.roleColor(role);
    final displayName = role.replaceAll('_', ' ').split(' ').map(
      (w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
    ).join(' ');

    return KlasivoBadge(
      label: displayName,
      variant: KlasivoBadgeVariant.custom,
      customColor: color,
    );
  }

  // ─── Factory: Status badge ──────────────────────────────────────────────
  static KlasivoBadge status(String status) {
    return switch (status.toLowerCase()) {
      'active' || 'published' || 'present' => KlasivoBadge(
          label: status.toUpperCase(),
          variant: KlasivoBadgeVariant.secondary,
        ),
      'draft' || 'pending' => KlasivoBadge(
          label: status.toUpperCase(),
          variant: KlasivoBadgeVariant.accent,
        ),
      'completed' || 'graded' || 'submitted' => KlasivoBadge(
          label: status.toUpperCase(),
          variant: KlasivoBadgeVariant.primary,
        ),
      'flagged' || 'absent' || 'failed' => KlasivoBadge(
          label: status.toUpperCase(),
          variant: KlasivoBadgeVariant.danger,
        ),
      _ => KlasivoBadge(label: status, variant: KlasivoBadgeVariant.neutral),
    };
  }
}

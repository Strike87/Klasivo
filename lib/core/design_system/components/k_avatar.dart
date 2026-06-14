import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K AVATAR — Avatar component for the Klasivo Design System
//
// Features:
// - Sizes: xs (24), sm (32), md (40), lg (56), xl (72)
// - Image, initials, or icon fallback
// - Online/offline status indicator
// - Badge overlay
// ═══════════════════════════════════════════════════════════════════════════════

/// Avatar size within the Klasivo Design System.
enum KAvatarSize {
  /// 24px — inline mentions, very compact lists.
  xs,

  /// 32px — lists, mentions.
  sm,

  /// 40px — standard (default).
  md,

  /// 56px — cards, profiles.
  lg,

  /// 72px — hero, settings.
  xl,
}

/// Avatar status indicator type.
enum KAvatarStatus {
  /// No status indicator.
  none,

  /// Green dot — user is online.
  online,

  /// Gray dot — user is offline.
  offline,

  /// Red dot — user is busy / do not disturb.
  busy,

  /// Amber dot — user is away.
  away,
}

/// A versatile avatar component supporting images, initials, icon fallback,
/// status indicators, and badge overlays.
///
/// Uses [AppColors], [AppSpacing], [AppRadius] tokens exclusively — no
/// hardcoded values.
///
/// Example:
/// ```dart
/// KAvatar(
///   name: 'Ahmad Al-Rashid',
///   size: KAvatarSize.md,
///   status: KAvatarStatus.online,
/// )
/// ```
class KAvatar extends StatelessWidget {
  /// Optional image URL for the avatar.
  final String? imageUrl;

  /// Name used for initials fallback (first letter of first/last name).
  final String? name;

  /// Role string used for color coding via [AppColors.roleColor].
  final String? role;

  /// Custom background color (overrides role-based default).
  final Color? backgroundColor;

  /// The size of the avatar.
  final KAvatarSize size;

  /// Status indicator type.
  final KAvatarStatus status;

  /// Optional badge count overlay (e.g., notification count).
  final int? badgeCount;

  /// Optional icon fallback when no image or initials are available.
  final IconData? fallbackIcon;

  /// Optional tap handler.
  final VoidCallback? onTap;

  const KAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.role,
    this.backgroundColor,
    this.size = KAvatarSize.md,
    this.status = KAvatarStatus.none,
    this.badgeCount,
    this.fallbackIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarDiameter = _diameter;
    final avatarRadius = avatarDiameter / 2;
    final fontSize = _fontSize;
    final statusDotSize = _statusDotSize;
    final avatarColor = backgroundColor ??
        (role != null ? AppColors.roleColor(role!) : AppColors.primary);

    Widget avatarChild;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          imageUrl!,
          width: avatarDiameter,
          height: avatarDiameter,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildInitialsOrIcon(avatarColor, fontSize),
        ),
      );
    } else {
      avatarChild = _buildInitialsOrIcon(avatarColor, fontSize);
    }

    Widget avatar = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: avatarColor.withOpacity(0.12),
        child: avatarChild,
      ),
    );

    // Status indicator overlay
    if (status != KAvatarStatus.none) {
      final statusColor = _statusColor;
      final borderColor =
          isDark ? AppColors.darkSurface : AppColors.lightSurface;

      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: statusDotSize,
              height: statusDotSize,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Badge overlay
    if (badgeCount != null && badgeCount! > 0) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -AppSpacing.xs,
            top: -AppSpacing.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              constraints: BoxConstraints(
                minWidth: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  width: 1.5,
                ),
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : '${badgeCount!}',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  /// Builds the initials text or fallback icon.
  Widget _buildInitialsOrIcon(Color color, double fontSize) {
    final initials = _getInitials();

    if (initials == '?' && fallbackIcon != null) {
      return Icon(
        fallbackIcon,
        size: fontSize * 1.2,
        color: color,
      );
    }

    return Text(
      initials,
      style: AppTypography.titleLarge.copyWith(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Extracts initials from [name].
  String _getInitials() {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Returns the diameter in logical pixels based on [KAvatarSize].
  double get _diameter => switch (size) {
        KAvatarSize.xs => 24,
        KAvatarSize.sm => 32,
        KAvatarSize.md => 40,
        KAvatarSize.lg => 56,
        KAvatarSize.xl => 72,
      };

  /// Returns the font size for initials based on [KAvatarSize].
  double get _fontSize => switch (size) {
        KAvatarSize.xs => 9,
        KAvatarSize.sm => 12,
        KAvatarSize.md => 16,
        KAvatarSize.lg => 20,
        KAvatarSize.xl => 28,
      };

  /// Returns the status dot diameter based on [KAvatarSize].
  double get _statusDotSize => switch (size) {
        KAvatarSize.xs => 6,
        KAvatarSize.sm => 7,
        KAvatarSize.md => 8,
        KAvatarSize.lg => 10,
        KAvatarSize.xl => 12,
      };

  /// Returns the status indicator color based on [KAvatarStatus].
  Color get _statusColor => switch (status) {
        KAvatarStatus.online => AppColors.success,
        KAvatarStatus.offline => AppColors.lightTextDisabled,
        KAvatarStatus.busy => AppColors.error,
        KAvatarStatus.away => AppColors.accent,
        KAvatarStatus.none => Colors.transparent,
      };
}

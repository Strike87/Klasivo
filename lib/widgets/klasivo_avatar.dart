import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO AVATAR — Consistent avatar component with fallback initials
// Supports images, initials, role colors, and online indicators.
// ═══════════════════════════════════════════════════════════════════════════════

enum KlasivoAvatarSize {
  sm,   // 32px — lists, mentions
  md,   // 40px — standard (default)
  lg,   // 56px — cards, profiles
  xl,   // 72px — hero, settings
}

enum KlasivoAvatarStatus {
  none,
  online,     // Green dot
  offline,    // Gray dot
  busy,       // Red dot
  away,       // Amber dot
}

class KlasivoAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;          // Used for initials fallback
  final String? role;          // Used for color coding
  final Color? backgroundColor;
  final KlasivoAvatarSize size;
  final KlasivoAvatarStatus status;
  final VoidCallback? onTap;

  const KlasivoAvatar({
    Key? key,
    this.imageUrl,
    this.name,
    this.role,
    this.backgroundColor,
    this.size = KlasivoAvatarSize.md,
    this.status = KlasivoAvatarStatus.none,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = switch (size) {
      KlasivoAvatarSize.sm => AppSpacing.avatarRadiusSm,
      KlasivoAvatarSize.md => AppSpacing.avatarRadius,
      KlasivoAvatarSize.lg => AppSpacing.avatarRadiusLg,
      KlasivoAvatarSize.xl => 36.0,
    };

    final fontSize = switch (size) {
      KlasivoAvatarSize.sm => 12.0,
      KlasivoAvatarSize.md => 16.0,
      KlasivoAvatarSize.lg => 20.0,
      KlasivoAvatarSize.xl => 28.0,
    };

    final statusDotSize = switch (size) {
      KlasivoAvatarSize.sm => 6.0,
      KlasivoAvatarSize.md => 8.0,
      KlasivoAvatarSize.lg => 10.0,
      KlasivoAvatarSize.xl => 12.0,
    };

    final avatarColor = backgroundColor ??
        (role != null ? AppColors.roleColor(role!) : AppColors.primary);
    final initials = _getInitials();

    Widget avatarChild;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitials(initials, avatarColor, fontSize),
        ),
      );
    } else {
      avatarChild = _buildInitials(initials, avatarColor, fontSize);
    }

    Widget avatar = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: avatarColor.withOpacity(0.12),
        child: avatarChild,
      ),
    );

    // Status indicator overlay
    if (status != KlasivoAvatarStatus.none) {
      final statusColor = switch (status) {
        KlasivoAvatarStatus.online => AppColors.success,
        KlasivoAvatarStatus.offline => AppColors.lightTextDisabled,
        KlasivoAvatarStatus.busy => AppColors.error,
        KlasivoAvatarStatus.away => AppColors.accent,
        KlasivoAvatarStatus.none => Colors.transparent,
      };

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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _buildInitials(String initials, Color color, double fontSize) {
    return Text(
      initials,
      style: AppTypography.titleLarge.copyWith(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

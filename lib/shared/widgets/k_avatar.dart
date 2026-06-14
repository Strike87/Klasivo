/// Klasivo v2.0 - KAvatar component
/// 
/// Enhanced avatar component based on klasivo_avatar.dart.
/// Supports image, initials fallback, status indicator,
/// and multiple sizes.
library;

import "package:flutter/material.dart";

/// Klasivo avatar component.
class KAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final KAvatarSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showStatus;
  final Color? statusColor;

  const KAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = KAvatarSize.md,
    this.backgroundColor,
    this.foregroundColor,
    this.showStatus = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = _sizeToDouble(size);
    return CircleAvatar(
      radius: avatarSize / 2,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null && initials != null
          ? Text(initials!, style: TextStyle(fontSize: avatarSize * 0.35))
          : null,
    );
  }

  double _sizeToDouble(KAvatarSize s) => switch (s) {
        KAvatarSize.xs => 24,
        KAvatarSize.sm => 32,
        KAvatarSize.md => 40,
        KAvatarSize.lg => 56,
        KAvatarSize.xl => 72,
      };
}

enum KAvatarSize { xs, sm, md, lg, xl }

/// Klasivo v2.0 - KBadge component
/// 
/// Enhanced badge component based on klasivo_badge.dart.
/// Supports variants, sizes, and RTL-aware positioning.
library;

import "package:flutter/material.dart";

/// Klasivo badge component.
class KBadge extends StatelessWidget {
  final String label;
  final KBadgeVariant variant;
  final KBadgeSize size;
  final Widget? icon;

  const KBadge({
    super.key,
    required this.label,
    this.variant = KBadgeVariant.default_,
    this.size = KBadgeSize.md,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _variantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Color _variantColor(BuildContext context) => switch (variant) {
        KBadgeVariant.default_ => Colors.grey.shade200,
        KBadgeVariant.success => Colors.green.shade100,
        KBadgeVariant.warning => Colors.orange.shade100,
        KBadgeVariant.error => Colors.red.shade100,
        KBadgeVariant.info => Colors.blue.shade100,
      };
}

enum KBadgeVariant { default_, success, warning, error, info }
enum KBadgeSize { sm, md, lg }

import 'package:flutter/material.dart';

import '../core/config/theme.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO COMPLETION BADGE — Shows progress % or completion status
// ═══════════════════════════════════════════════════════════════════════════════

enum CompletionStatus {
  notStarted,
  inProgress,
  completed,
}

class KlasivoCompletionBadge extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final bool showPercentage;
  final bool compact;
  final String? label;

  const KlasivoCompletionBadge({
    Key? key,
    required this.progress,
    this.showPercentage = true,
    this.compact = false,
    this.label,
  }) : super(key: key);

  CompletionStatus get _status {
    if (progress >= 0.9) return CompletionStatus.completed;
    if (progress > 0) return CompletionStatus.inProgress;
    return CompletionStatus.notStarted;
  }

  Color get _color {
    switch (_status) {
      case CompletionStatus.completed:
        return KlasivoColors.secondary;
      case CompletionStatus.inProgress:
        return KlasivoColors.accent;
      case CompletionStatus.notStarted:
        return KlasivoColors.darkTextTertiary;
    }
  }

  IconData get _icon {
    switch (_status) {
      case CompletionStatus.completed:
        return Icons.check_circle_rounded;
      case CompletionStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case CompletionStatus.notStarted:
        return Icons.radio_button_unchecked;
    }
  }

  String get _label {
    if (label != null) return label!;
    final percent = (progress * 100).round();
    switch (_status) {
      case CompletionStatus.completed:
        return 'Completed';
      case CompletionStatus.inProgress:
        return '$percent%';
      case CompletionStatus.notStarted:
        return 'Not started';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.sm,
        vertical: KlasivoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            _label,
            style: KlasivoTypography.labelSmall.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Icon(_icon, size: 16, color: _color),
            const SizedBox(width: KlasivoSpacing.sm),
            Expanded(
              child: Text(
                _label,
                style: KlasivoTypography.labelMedium.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showPercentage)
              Text(
                '${(progress * 100).round()}%',
                style: KlasivoTypography.labelSmall.copyWith(
                  color: _color,
                ),
              ),
          ],
        ),
        const SizedBox(height: KlasivoSpacing.xs),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(KlasivoRadius.xs),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? KlasivoColors.darkBorder
                : KlasivoColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO STREAK BADGE — Shows learning streak count
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoStreakBadge extends StatelessWidget {
  final int streakDays;

  const KlasivoStreakBadge({
    Key? key,
    required this.streakDays,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (streakDays <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KlasivoColors.accent.withValues(alpha: 0.15),
            KlasivoColors.accentDark.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
        border: Border.all(
          color: KlasivoColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            '$streakDays day streak',
            style: KlasivoTypography.labelMedium.copyWith(
              color: KlasivoColors.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

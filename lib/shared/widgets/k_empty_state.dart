import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO EMPTY STATE — Design-system empty state widget
// Displays an icon, title, subtitle, and optional action button
// when there is no content to show.
// ═══════════════════════════════════════════════════════════════════════════════

enum KEmptyStateType {
  generic,
  noResults,
  noData,
  noMessages,
  noNotifications,
  noExams,
  noStudents,
  noClasses,
  error,
  offline,
}

class KEmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final KEmptyStateType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIllustration;

  const KEmptyState({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.type = KEmptyStateType.generic,
    this.actionLabel,
    this.onAction,
    this.customIllustration,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.hero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Icon or Illustration ──────────────────────────────────
            if (customIllustration != null)
              customIllustration!
            else
              Container(
                width: AppSpacing.iconSizeHero * 2,
                height: AppSpacing.iconSizeHero * 2,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                    brightness: brightness,
                    light: AppColors.lightBackground,
                    dark: AppColors.darkSurface,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? _defaultIcon,
                  size: AppSpacing.iconSizeHero,
                  color: AppColors.textTertiary(brightness),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // ─── Title ─────────────────────────────────────────────────
            Text(
              title ?? _defaultTitle,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.center,
            ),

            // ─── Subtitle ──────────────────────────────────────────────
            if (subtitle != null || _hasDefaultSubtitle) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle ?? _defaultSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // ─── Action Button ─────────────────────────────────────────
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.buttonHorizontal,
                    vertical: AppSpacing.buttonVertical,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Default Values by Type ──────────────────────────────────────────

  IconData get _defaultIcon {
    switch (type) {
      case KEmptyStateType.generic:
        return Icons.inbox_outlined;
      case KEmptyStateType.noResults:
        return Icons.search_off_rounded;
      case KEmptyStateType.noData:
        return Icons.folder_open_outlined;
      case KEmptyStateType.noMessages:
        return Icons.chat_bubble_outline_rounded;
      case KEmptyStateType.noNotifications:
        return Icons.notifications_none_rounded;
      case KEmptyStateType.noExams:
        return Icons.quiz_outlined;
      case KEmptyStateType.noStudents:
        return Icons.people_outline_rounded;
      case KEmptyStateType.noClasses:
        return Icons.class_outlined;
      case KEmptyStateType.error:
        return Icons.error_outline_rounded;
      case KEmptyStateType.offline:
        return Icons.cloud_off_rounded;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case KEmptyStateType.generic:
        return 'Nothing here yet';
      case KEmptyStateType.noResults:
        return 'No results found';
      case KEmptyStateType.noData:
        return 'No data available';
      case KEmptyStateType.noMessages:
        return 'No messages';
      case KEmptyStateType.noNotifications:
        return 'No notifications';
      case KEmptyStateType.noExams:
        return 'No exams';
      case KEmptyStateType.noStudents:
        return 'No students';
      case KEmptyStateType.noClasses:
        return 'No classes';
      case KEmptyStateType.error:
        return 'Something went wrong';
      case KEmptyStateType.offline:
        return 'You\'re offline';
    }
  }

  bool get _hasDefaultSubtitle {
    switch (type) {
      case KEmptyStateType.noResults:
      case KEmptyStateType.noMessages:
      case KEmptyStateType.noNotifications:
      case KEmptyStateType.error:
      case KEmptyStateType.offline:
        return true;
      default:
        return false;
    }
  }

  String get _defaultSubtitle {
    switch (type) {
      case KEmptyStateType.noResults:
        return 'Try adjusting your search or filters';
      case KEmptyStateType.noMessages:
        return 'Start a conversation to see messages here';
      case KEmptyStateType.noNotifications:
        return 'You\'re all caught up!';
      case KEmptyStateType.error:
        return 'Please try again later';
      case KEmptyStateType.offline:
        return 'Check your internet connection and try again';
      default:
        return '';
    }
  }
}

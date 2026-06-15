import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';
import 'k_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K MODAL — Modal/bottom sheet component for the Klasivo Design System
//
// Features:
// - Drag handle
// - Animated slide-up
// - Title bar with close button
// - Content scroll area
// - Action buttons (RTL-aware layout)
// ═══════════════════════════════════════════════════════════════════════════════

/// A modal/bottom sheet component with drag handle, animated slide-up,
/// title bar, scrollable content, and RTL-aware action buttons.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography], and
/// [AppAnimation] tokens exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KModal.show(
///   context: context,
///   title: 'Add Student',
///   child: StudentForm(),
///   actions: [
///     KButton(label: 'Cancel', variant: KButtonVariant.text, onPressed: () => Navigator.pop(context)),
///     KButton(label: 'Save', variant: KButtonVariant.elevated, onPressed: handleSave),
///   ],
/// )
/// ```
class KModal {
  KModal._();

  /// Shows a bottom sheet modal with a drag handle, title bar, and
  /// scrollable content area.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    String? subtitle,
    bool isScrollControlled = true,
    bool showCloseButton = true,
    bool dismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      isDismissible: dismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _KModalContent(
        title: title,
        subtitle: subtitle,
        child: child,
        actions: actions,
        showCloseButton: showCloseButton,
      ),
    );
  }

  /// Shows a compact form bottom sheet (auto-adjusts for keyboard).
  static Future<T?> showForm<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      child: child,
      actions: actions,
      isScrollControlled: true,
    );
  }
}

/// Private widget that renders the modal's content.
class _KModalContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool showCloseButton;

  const _KModalContent({
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = context.isRTL;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xs,
              margin: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),

          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    iconSize: AppSpacing.iconSizeMd,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: AppSpacing.xs,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),

          // Content scroll area
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),

          // Action buttons
          if (actions != null && actions!.isNotEmpty) ...[
            Divider(
              height: AppSpacing.xs,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .map((action) => Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: AppSpacing.sm,
                          ),
                          child: action,
                        ))
                    .toList(),
              ),
            ),
          ],

          // Bottom safe area for keyboard
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
        ],
      ),
    );
  }
}

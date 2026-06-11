import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO MODAL — Bottom sheet and dialog patterns
// Consistent modals for confirmations, forms, and content display.
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoModal {
  KlasivoModal._();

  // ─── Confirmation Dialog ────────────────────────────────────────────────
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTypography.titleLarge),
        content: Text(message, style: AppTypography.bodyMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDangerous
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: Text(
              confirmLabel,
              style: isDangerous
                  ? const TextStyle(color: AppColors.error)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Bottom Sheet ──────────────────────────────────────────────────
  static Future<T?> showForm<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    double? heightFactor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            // Title
            Text(title, style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            // Content
            child,
          ],
        ),
      ),
    );
  }

  // ─── Content Bottom Sheet (for detail views, previews) ──────────────────
  static Future<T?> showContent<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTypography.headlineSmall),
                  ),
                  if (actions != null) ...actions,
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

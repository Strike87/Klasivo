import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO DIALOG — Design-system dialog using AppColors, AppSpacing,
// AppRadius, AppTypography tokens.
// ═══════════════════════════════════════════════════════════════════════════════

enum KDialogType { info, warning, error, success, confirmation }

class KDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final KDialogType type;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool barrierDismissible;

  const KDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    this.type = KDialogType.info,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.barrierDismissible = true,
  });

  // ─── Show Methods ───────────────────────────────────────────────────────

  /// Show this dialog using the standard showDialog API.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    KDialogType type = KDialogType.info,
    String? confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => KDialog(
        title: title,
        message: message,
        content: content,
        type: type,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: onConfirm,
        onCancel: onCancel,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  /// Convenience: show a confirmation dialog.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    KDialogType type = KDialogType.confirmation,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => KDialog(
        title: title,
        message: message,
        type: type,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  /// Convenience: show an error dialog.
  static Future<void> error({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'OK',
  }) {
    return showDialog(
      context: context,
      builder: (context) => KDialog(
        title: title,
        message: message,
        type: KDialogType.error,
        confirmLabel: confirmLabel,
        onConfirm: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AlertDialog(
      backgroundColor: AppColors.surface(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      title: _buildTitle(brightness),
      content: _buildContent(brightness),
      actions: _buildActions(context, brightness),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    );
  }

  Widget? _buildTitle(Brightness brightness) {
    if (title == null && type != KDialogType.confirmation) return null;

    return Row(
      children: [
        Icon(
          _iconData,
          color: _iconColor(brightness),
          size: AppSpacing.iconSizeLg,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title ?? _defaultTitle,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Brightness brightness) {
    if (content != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                message!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
          content!,
        ],
      );
    }

    if (message != null) {
      return Text(
        message!,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary(brightness),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _buildActions(BuildContext context, Brightness brightness) {
    final actions = <Widget>[];

    if (onCancel != null || cancelLabel != null) {
      actions.add(
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(cancelLabel ?? 'Cancel'),
        ),
      );
    }

    if (onConfirm != null || confirmLabel != null) {
      actions.add(
        ElevatedButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: type == KDialogType.error
                ? AppColors.error
                : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: Text(
            confirmLabel ?? 'OK',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    return actions;
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  IconData get _iconData {
    switch (type) {
      case KDialogType.info:
        return Icons.info_outline_rounded;
      case KDialogType.warning:
        return Icons.warning_amber_rounded;
      case KDialogType.error:
        return Icons.error_outline_rounded;
      case KDialogType.success:
        return Icons.check_circle_outline_rounded;
      case KDialogType.confirmation:
        return Icons.help_outline_rounded;
    }
  }

  Color _iconColor(Brightness brightness) {
    switch (type) {
      case KDialogType.info:
        return AppColors.info;
      case KDialogType.warning:
        return AppColors.warning;
      case KDialogType.error:
        return AppColors.error;
      case KDialogType.success:
        return AppColors.success;
      case KDialogType.confirmation:
        return AppColors.primary;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case KDialogType.info:
        return 'Information';
      case KDialogType.warning:
        return 'Warning';
      case KDialogType.error:
        return 'Error';
      case KDialogType.success:
        return 'Success';
      case KDialogType.confirmation:
        return 'Confirm';
    }
  }
}

import 'package:flutter/material.dart';
import '../core/config/theme.dart';
import 'klasivo_components.dart';
import 'klasivo_button.dart';
import 'klasivo_modal.dart';
import 'klasivo_toast.dart';

/// A reusable empty state widget with icon, title, and subtitle.
/// Uses the KlasivoEmptyState from klasivo_components.dart for the new design.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KlasivoEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// A reusable loading indicator widget.
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KlasivoLoading(message: message);
  }
}

/// A reusable error widget with retry button.
class ErrorWidgetCustom extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorWidgetCustom({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.xxl),
              decoration: BoxDecoration(
                color: KlasivoColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: KlasivoColors.error,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),
            Text(
              message,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KlasivoSpacing.xxl),
              KlasivoButton(
                label: 'Retry',
                onPressed: onRetry,
                variant: KlasivoButtonVariant.secondary,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A reusable confirmation dialog.
/// @deprecated Use KlasivoModal.confirm() instead.
@Deprecated('Use KlasivoModal.confirm() instead')
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDangerous = false,
}) {
  return KlasivoModal.confirm(
    context: context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    isDangerous: isDangerous,
  );
}

/// A reusable snack bar helper.
/// @deprecated Use KlasivoToast.show(), KlasivoToast.success(), KlasivoToast.error(), etc. instead.
@Deprecated('Use KlasivoToast.show() or KlasivoToast.success()/error() instead')
void showSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  KlasivoToast.show(
    context,
    message: message,
    type: isError ? KlasivoToastType.error : KlasivoToastType.success,
  );
}

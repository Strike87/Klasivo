import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';
import 'klasivo_button.dart';
import 'klasivo_toast.dart';
import 'klasivo_modal.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ERROR BOUNDARY — Global error boundary wrapper widget
// Catches Flutter errors and displays a user-friendly recovery UI
// instead of crashing the app.
//
// Usage:
// ```dart
// KlasivoErrorBoundary(
//   child: MyApp(),
// )
// ```
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, FlutterErrorDetails error)?
      errorBuilder;

  const KlasivoErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
  }) : super(key: key);

  @override
  State<KlasivoErrorBoundary> createState() => _KlasivoErrorBoundaryState();
}

class _KlasivoErrorBoundaryState extends State<KlasivoErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    // Capture Flutter framework errors
    FlutterError.onError = (details) {
      _handleError(details);
    };
  }

  void _handleError(FlutterErrorDetails details) {
    if (!mounted) return;
    setState(() {
      _errorDetails = details;
    });
    // Also report to error reporting service in production
    debugPrint(
      'KlasivoErrorBoundary caught: ${details.exceptionAsString()}',
    );
  }

  void _recover() {
    setState(() {
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _errorDetails!);
      }
      return _DefaultErrorView(onRecover: _recover);
    }
    return widget.child;
  }
}

/// Default error recovery view with Klasivo styling
class _DefaultErrorView extends StatelessWidget {
  final VoidCallback onRecover;

  const _DefaultErrorView({required this.onRecover});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: const BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Something went wrong',
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The app encountered an unexpected error. '
                'You can try to recover or restart.',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              KlasivoButton(
                label: 'Recover',
                onPressed: onRecover,
                icon: Icons.refresh_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              KlasivoButton(
                label: 'Restart App',
                onPressed: () {
                  // Force restart by navigating to splash
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                variant: KlasivoButtonVariant.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Async error handler for wrapping async operations
/// Provides consistent error handling with KlasivoToast feedback
class KlasivoErrorHandler {
  KlasivoErrorHandler._();

  /// Run an async operation with error handling
  /// Returns the result on success, null on failure (shows toast)
  static Future<T?> run<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? errorMessage,
    bool showToast = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (showToast && context.mounted) {
        KlasivoToast.error(
          context,
          message: errorMessage ?? 'An error occurred. Please try again.',
        );
      }
      debugPrint('KlasivoErrorHandler: $e');
      return null;
    }
  }

  /// Run an async operation with confirmation dialog first
  static Future<T?> runWithConfirm<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDangerous = false,
    String? errorMessage,
  }) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      isDangerous: isDangerous,
    );

    if (confirmed != true) return null;

    return run(
      context: context,
      operation: operation,
      errorMessage: errorMessage,
    );
  }
}

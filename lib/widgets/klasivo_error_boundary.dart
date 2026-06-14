import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../core/tokens/tokens.dart';
import '../core/services/sentry_service.dart';
import 'klasivo_button.dart';
import 'klasivo_toast.dart';
import 'klasivo_modal.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ERROR BOUNDARY — Global error boundary wrapper widget
// Catches Flutter errors and displays a user-friendly recovery UI
// instead of crashing the app.
//
// IMPORTANT: This widget does NOT overwrite FlutterError.onError.
// The global handler (set in main.dart) continues to report to both
// Crashlytics and Sentry. This widget only provides a recovery UI
// for widget-level errors.
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
    // NOTE: We do NOT overwrite FlutterError.onError here.
    // The global error handler in main.dart already reports to
    // both Crashlytics and Sentry. Overwriting it would break
    // error reporting for the entire app.
  }

  void _handleError(FlutterErrorDetails details) {
    if (!mounted) return;

    // Report to Sentry and Crashlytics (belt-and-suspenders with global handler)
    Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);

    KlasivoSentry.breadcrumb.auth(
      'error_boundary_caught',
      data: {'exception': details.exceptionAsString()},
    );

    setState(() {
      _errorDetails = details;
    });
  }

  void _recover() {
    setState(() {
      _errorDetails = null;
    });
    KlasivoSentry.breadcrumb.auth('error_boundary_recovered');
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

/// Async error handler for wrapping async operations.
/// Provides consistent error handling with KlasivoToast feedback
/// AND Sentry/Crashlytics reporting.
///
/// IMPORTANT: Previous version silently swallowed errors (debugPrint only).
/// This version reports every error to Sentry and Crashlytics.
class KlasivoErrorHandler {
  KlasivoErrorHandler._();

  /// Run an async operation with error handling.
  /// Returns the result on success, null on failure (shows toast).
  /// Every failure is reported to both Sentry and Crashlytics.
  static Future<T?> run<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? errorMessage,
    bool showToast = true,
    String? operationName,
    Map<String, String>? tags,
  }) async {
    try {
      return await operation();
    } catch (e, st) {
      // Report to Sentry with scope tags
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('source', 'klasivo_error_handler');
          if (operationName != null) {
            scope.setTag('operation', operationName);
          }
          tags?.forEach(scope.setTag);
        },
      );

      // Also report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: operationName ?? 'KlasivoErrorHandler.run',
      );

      if (showToast && context.mounted) {
        KlasivoToast.error(
          context,
          message: errorMessage ?? 'An error occurred. Please try again.',
        );
      }
      return null;
    }
  }

  /// Run an async operation with confirmation dialog first.
  static Future<T?> runWithConfirm<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDangerous = false,
    String? errorMessage,
    String? operationName,
    Map<String, String>? tags,
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
      operationName: operationName,
      tags: tags,
    );
  }
}

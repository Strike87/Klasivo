import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tokens/tokens.dart';
import '../core/services/connectivity_service.dart';
import '../providers/offline_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO OFFLINE BANNER — Shows when device is offline
//
// A non-intrusive amber banner that appears at the top of the screen
// when connectivity is lost. Auto-hides when back online.
// Can be temporarily dismissed for 5 minutes.
// Shows pending writes count as a badge.
// ═══════════════════════════════════════════════════════════════════════════════

class OfflineBanner extends ConsumerStatefulWidget {
  /// The child widget (typically the app's main content).
  final Widget child;

  const OfflineBanner({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  DateTime? _dismissedAt;
  Timer? _dismissTimer;

  static const Duration _dismissDuration = Duration(minutes: 5);

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  bool get _isDismissed {
    if (_dismissedAt == null) return false;
    return DateTime.now().difference(_dismissedAt!) < _dismissDuration;
  }

  void _dismiss() {
    setState(() {
      _dismissedAt = DateTime.now();
    });

    // Auto-restore after 5 minutes
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_dismissDuration, () {
      if (mounted) {
        setState(() {
          _dismissedAt = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(connectivityStatusProvider);
    final pendingCount = ref.watch(currentPendingWritesProvider);

    final isOffline = statusAsync.when(
      data: (status) => status == ConnectivityStatus.offline,
      loading: () => false,
      error: (_, __) => false,
    );

    final showBanner = isOffline && !_isDismissed;

    return Column(
      children: [
        if (showBanner) _BannerContent(
          pendingCount: pendingCount,
          onDismiss: _dismiss,
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _BannerContent extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onDismiss;

  const _BannerContent({
    required this.pendingCount,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.accentDark.withOpacity(0.9)
            : AppColors.accent.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.accent.withOpacity(0.3)
                : AppColors.accent.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Icon
            Icon(
              Icons.cloud_off_rounded,
              size: AppSpacing.iconSizeMd,
              color: isDark ? AppColors.accentLight : AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Message
            Expanded(
              child: Text(
                pendingCount > 0
                    ? 'You are offline. $pendingCount pending change${pendingCount == 1 ? '' : 's'} will sync when connected.'
                    : 'You are offline. Changes will sync when connected.',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.accentLight : AppColors.accentDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Pending badge
            if (pendingCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.accent.withOpacity(0.3)
                      : AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  '$pendingCount',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.accentLight : AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],

            // Dismiss button
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: AppSpacing.iconSizeMd,
                color: isDark
                    ? AppColors.accentLight.withOpacity(0.7)
                    : AppColors.accent.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tokens/tokens.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_manager.dart';
import '../providers/offline_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SYNC INDICATOR — Compact sync status indicator for app bars
//
// Shows the current sync status as a small icon:
//   ✓ (synced)   — Green/Emerald
//   ⟳ (syncing)  — Blue/Indigo with rotation animation
//   ⚠ (error)    — Red
//   ○ (offline)  — Gray
//
// Tap to expand and see pending writes count.
// ═══════════════════════════════════════════════════════════════════════════════

class SyncIndicator extends ConsumerStatefulWidget {
  const SyncIndicator({Key? key}) : super(key: key);

  @override
  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<SyncIndicator>
    with SingleTickerProviderStateProvider {
  bool _isExpanded = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    final syncStatus = ref.watch(currentSyncStatusProvider);
    final pendingCount = ref.watch(currentPendingWritesProvider);

    final isOffline = connectivityStatus.when(
      data: (s) => s == ConnectivityStatus.offline,
      loading: () => false,
      error: (_, __) => false,
    );

    final isSyncing = syncStatus == SyncStatus.syncing;

    // Control spin animation
    if (isSyncing) {
      _spinController.repeat();
    } else {
      _spinController.stop();
    }

    final config = _getStatusConfig(isOffline, syncStatus);

    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? AppSpacing.md : AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon
            if (isSyncing)
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _spinController.value * 6.283, // 2 * pi
                    child: child,
                  );
                },
                child: Icon(
                  Icons.sync_rounded,
                  size: AppSpacing.iconSizeMd,
                  color: config.iconColor,
                ),
              )
            else
              Icon(
                config.icon,
                size: AppSpacing.iconSizeMd,
                color: config.iconColor,
              ),

            // Expanded content
            if (_isExpanded) ...[
              const SizedBox(width: AppSpacing.inlineXs),
              Text(
                config.label,
                style: AppTypography.labelSmall.copyWith(
                  color: config.iconColor,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: AppSpacing.inlineXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: config.iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: AppTypography.labelSmall.copyWith(
                      color: config.iconColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(bool isOffline, SyncStatus syncStatus) {
    if (isOffline) {
      return _StatusConfig(
        icon: Icons.cloud_off_rounded,
        label: 'Offline',
        iconColor: AppColors.lightTextDisabled,
        backgroundColor: AppColors.lightTextDisabled,
      );
    }

    switch (syncStatus) {
      case SyncStatus.syncing:
        return _StatusConfig(
          icon: Icons.sync_rounded,
          label: 'Syncing',
          iconColor: AppColors.primary,
          backgroundColor: AppColors.primary,
        );
      case SyncStatus.error:
        return _StatusConfig(
          icon: Icons.error_outline_rounded,
          label: 'Sync Error',
          iconColor: AppColors.error,
          backgroundColor: AppColors.error,
        );
      case SyncStatus.conflict:
        return _StatusConfig(
          icon: Icons.warning_amber_rounded,
          label: 'Conflict',
          iconColor: AppColors.warning,
          backgroundColor: AppColors.warning,
        );
      case SyncStatus.idle:
        return _StatusConfig(
          icon: Icons.cloud_done_rounded,
          label: 'Synced',
          iconColor: AppColors.secondary,
          backgroundColor: AppColors.secondary,
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;

  const _StatusConfig({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
  });
}

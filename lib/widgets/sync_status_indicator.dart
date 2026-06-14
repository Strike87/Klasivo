import 'dart:async';
import 'package:flutter/material.dart';

import '../core/tokens/tokens.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/sync_orchestrator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO EXAM SYNC STATUS INDICATOR — Exam-specific sync status widget
//
// A compact indicator for the exam screen header that shows:
//   ✓ (synced)     — Green checkmark when all data is synced
//   ⟳ (syncing)    — Amber spinner when syncing in progress
//   ⚠ (offline)    — Red warning when offline with pending data
//   Badge           — Count of unsynced items
//
// Tap to expand for more detail. Designed to be placed in an AppBar
// or exam screen header.
// ═══════════════════════════════════════════════════════════════════════════════

class ExamSyncStatusIndicator extends StatefulWidget {
  /// Optional exam instance ID to show answer-specific pending count.
  /// If null, shows total pending submission count.
  final String? examInstanceId;

  /// Optional student ID for answer-specific pending count.
  final String? studentId;

  const ExamSyncStatusIndicator({
    Key? key,
    this.examInstanceId,
    this.studentId,
  }) : super(key: key);

  @override
  State<ExamSyncStatusIndicator> createState() =>
      _ExamSyncStatusIndicatorState();
}

class _ExamSyncStatusIndicatorState extends State<ExamSyncStatusIndicator>
    with SingleTickerProviderStateProvider {
  bool _isExpanded = false;
  late AnimationController _spinController;
  StreamSubscription<ExamSyncStatus>? _statusSub;
  ExamSyncStatus _currentSyncStatus = ExamSyncStatus.idle;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Listen to sync status changes
    _statusSub = SyncOrchestrator.instance.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentSyncStatus = status;
        });
        _updatePendingCount();
      }
    });

    // Initial state
    _currentSyncStatus = SyncOrchestrator.instance.currentStatus;
    _updatePendingCount();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _updatePendingCount() {
    if (widget.examInstanceId != null && widget.studentId != null) {
      _pendingCount = SyncOrchestrator.instance.getUnsyncedAnswerCount(
        examInstanceId: widget.examInstanceId!,
        studentId: widget.studentId!,
      );
    } else {
      _pendingCount = SyncOrchestrator.instance.getPendingSubmissionCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline =
        ConnectivityService.instance.currentStatus ==
        ConnectivityStatus.offline;
    final isSyncing = _currentSyncStatus == ExamSyncStatus.syncing;

    // Control spin animation
    if (isSyncing) {
      _spinController.repeat();
    } else {
      _spinController.stop();
    }

    final config = _getStatusConfig(isOffline);

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
          color: config.backgroundColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(
            color: config.backgroundColor.withOpacity(0.2),
            width: 1,
          ),
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
              if (_pendingCount > 0) ...[
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
                    '$_pendingCount',
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

  _ExamStatusConfig _getStatusConfig(bool isOffline) {
    // If offline with pending data — highest priority warning
    if (isOffline && _pendingCount > 0) {
      return _ExamStatusConfig(
        icon: Icons.cloud_off_rounded,
        label: 'Offline — $_pendingCount pending',
        iconColor: AppColors.error,
        backgroundColor: AppColors.error,
      );
    }

    // If offline but no pending data
    if (isOffline) {
      return _ExamStatusConfig(
        icon: Icons.cloud_off_rounded,
        label: 'Offline',
        iconColor: AppColors.lightTextDisabled,
        backgroundColor: AppColors.lightTextDisabled,
      );
    }

    // Online — check sync status
    switch (_currentSyncStatus) {
      case ExamSyncStatus.syncing:
        return _ExamStatusConfig(
          icon: Icons.sync_rounded,
          label: 'Syncing',
          iconColor: AppColors.accent,
          backgroundColor: AppColors.accent,
        );
      case ExamSyncStatus.synced:
        return _ExamStatusConfig(
          icon: Icons.cloud_done_rounded,
          label: 'Synced',
          iconColor: AppColors.secondary,
          backgroundColor: AppColors.secondary,
        );
      case ExamSyncStatus.error:
        return _ExamStatusConfig(
          icon: Icons.error_outline_rounded,
          label: 'Sync Error',
          iconColor: AppColors.error,
          backgroundColor: AppColors.error,
        );
      case ExamSyncStatus.idle:
        // Idle with pending data means waiting to sync
        if (_pendingCount > 0) {
          return _ExamStatusConfig(
            icon: Icons.cloud_upload_outlined,
            label: '$_pendingCount pending',
            iconColor: AppColors.accent,
            backgroundColor: AppColors.accent,
          );
        }
        return _ExamStatusConfig(
          icon: Icons.cloud_done_rounded,
          label: 'Saved',
          iconColor: AppColors.secondary,
          backgroundColor: AppColors.secondary,
        );
    }
  }
}

class _ExamStatusConfig {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;

  const _ExamStatusConfig({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
  });
}

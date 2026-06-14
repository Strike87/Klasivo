/// Klasivo v2.0 - Top-level providers
///
/// Global Riverpod providers that must be initialized at app startup.
/// These providers are used across multiple feature modules and
/// represent cross-cutting concerns like auth, connectivity, and sync.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/feature_flag_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/offline_exam_service.dart';
import '../core/services/offline_manager.dart';
import '../core/services/permission_service.dart';
import '../core/services/sync_orchestrator.dart';

// ─── Auth State Providers ───────────────────────────────────────────────────

/// Whether the user is currently logged in (from Hive persistence).
final isLoggedInProvider = Provider<bool>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('isLoggedIn', defaultValue: false) as bool;
});

/// The current user's role (from Hive persistence).
final userRoleProvider = Provider<String>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userRole', defaultValue: '') as String;
});

/// The current user's organization ID (from Hive persistence).
final userOrgIdProvider = Provider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('organizationId') as String?;
});

/// Whether the current user has completed initial setup.
final hasCompletedSetupProvider = Provider<bool>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('hasCompletedSetup', defaultValue: true) as bool;
});

// ─── Connectivity Provider ──────────────────────────────────────────────────

/// Provider for the connectivity service singleton.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Whether the device is currently online.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.instance.onConnectivityChange.map(
    (status) => status == ConnectivityStatus.online,
  );
});

// ─── Sync Providers ─────────────────────────────────────────────────────────

/// Provider for the sync orchestrator singleton.
final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  return SyncOrchestrator.instance;
});

/// Provider for the offline exam service singleton.
final offlineExamServiceProvider = Provider<OfflineExamService>((ref) {
  return OfflineExamService.instance;
});

/// Provider for the offline manager singleton.
final offlineManagerProvider = Provider<OfflineManager>((ref) {
  return OfflineManager.instance;
});

// ─── Permission Provider ────────────────────────────────────────────────────

/// Provider for the permission service.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

// ─── Feature Flag Provider ──────────────────────────────────────────────────

/// Provider for the feature flag service.
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService();
});

// ─── Initialization ─────────────────────────────────────────────────────────

/// Global provider container for the application.
///
/// Use this for any top-level provider initialization
/// that needs to happen before the widget tree is built.
/// Most providers should be lazy-initialized via Riverpod.
final globalProviderContainer = ProviderContainer();

/// Initializes all global providers that must be ready
/// before the app starts (auth state, connectivity, etc.).
Future<void> initializeGlobalProviders() async {
  // Initialize connectivity monitoring
  try {
    await ConnectivityService.instance.startMonitoring();
  } catch (e) {
    // Graceful degradation
  }

  // Initialize offline mode
  try {
    await OfflineManager.instance.enableOfflineMode();
  } catch (e) {
    // Graceful degradation
  }

  // Initialize offline exam service
  try {
    await OfflineExamService.instance.initialize();
  } catch (e) {
    // Graceful degradation
  }

  // Initialize sync orchestrator
  try {
    await SyncOrchestrator.instance.initialize();
  } catch (e) {
    // Graceful degradation
  }

  // Initialize notification service
  try {
    await NotificationService.initialize();
  } catch (e) {
    // Graceful degradation
  }
}

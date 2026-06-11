import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/services/feature_flag_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO FEATURE FLAG PROVIDERS
// Riverpod integration for feature flags with real-time streaming.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Feature Flag Service Provider ────────────────────────────────────────
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService();
});

// ─── Current Organization ID (from auth) ──────────────────────────────────
final _currentOrgIdProvider = Provider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('organizationId') as String?;
});

// ─── Feature Flags Stream Provider ────────────────────────────────────────
// Loads flags once and streams real-time updates from Firestore.
final featureFlagsStreamProvider = StreamProvider<Map<String, FeatureFlag>>((ref) {
  final orgId = ref.watch(_currentOrgIdProvider);
  if (orgId == null) return Stream.value({});

  final service = ref.watch(featureFlagServiceProvider);
  return service.streamFlags(orgId);
});

// ─── All Feature Flags Provider ───────────────────────────────────────────
// Returns the current state of all feature flags (from stream or defaults).
final allFeatureFlagsProvider = Provider<Map<String, FeatureFlag>>((ref) {
  final asyncFlags = ref.watch(featureFlagsStreamProvider);
  return asyncFlags.valueOrNull ?? {};
});

// ─── Single Flag Enabled Check ────────────────────────────────────────────
// Usage: ref.watch(featureFlagEnabledProvider('lms'))
final featureFlagEnabledProvider = Provider.family<bool, String>((ref, flagKey) {
  final service = ref.watch(featureFlagServiceProvider);
  final orgId = ref.watch(_currentOrgIdProvider);

  // Get userId for user-level targeting
  final box = Hive.box(AppConstants.authBox);
  final userId = box.get('userId') as String?;

  return service.isEnabled(flagKey, userId: userId);
});

// ─── Feature Flag Detail Provider ─────────────────────────────────────────
// Returns the full FeatureFlag object for admin UI.
final featureFlagDetailProvider = Provider.family<FeatureFlag?, String>((ref, flagKey) {
  final flags = ref.watch(allFeatureFlagsProvider);
  return flags[flagKey];
});

// ─── Feature Flag Admin: Update a flag ────────────────────────────────────
// Async notifier for updating flags (admin panel use).
class FeatureFlagUpdate {
  final String flagKey;
  final bool enabled;
  final int? rolloutPercentage;
  final List<String>? allowedUserIds;

  const FeatureFlagUpdate({
    required this.flagKey,
    required this.enabled,
    this.rolloutPercentage,
    this.allowedUserIds,
  });
}

final featureFlagUpdateProvider = FutureProvider.family.autoDispose<void, FeatureFlagUpdate>((
  ref,
  update,
) async {
  final service = ref.watch(featureFlagServiceProvider);
  final orgId = ref.watch(_currentOrgIdProvider);
  if (orgId == null) throw Exception('No organization ID');

  await service.setFlag(
    orgId: orgId,
    flagKey: update.flagKey,
    enabled: update.enabled,
    rolloutPercentage: update.rolloutPercentage,
    allowedUserIds: update.allowedUserIds,
  );
});

// ─── Bulk Feature Flags Check ─────────────────────────────────────────────
// Returns a map of flagKey -> isEnabled for multiple flags at once.
final featureFlagsBulkProvider = Provider.family<Map<String, bool>, List<String>>((
  ref,
  flagKeys,
) {
  final result = <String, bool>{};
  for (final key in flagKeys) {
    result[key] = ref.watch(featureFlagEnabledProvider(key));
  }
  return result;
});

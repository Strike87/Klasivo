import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';
import 'module_flags.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO FEATURE FLAG ENGINE — Enhanced feature flag service
//
// Supports:
// - Plan-based defaults (free, starter, professional, enterprise)
// - Organization-level overrides via Firestore
// - User-level overrides
// - Gradual rollouts (percentage-based)
// - Time-based activation (schedule flags for future dates)
// - Real-time streaming updates
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a feature flag with full metadata.
class EnhancedFeatureFlag {
  final String key;
  final bool enabled;
  final String? description;
  final String? plan; // Which plan this flag belongs to (if plan-level)
  final double rolloutPercentage; // 0.0 to 100.0 — gradual rollout
  final DateTime? activateAt; // Scheduled activation
  final DateTime? deactivateAt; // Scheduled deactivation
  final Map<String, bool> userOverrides; // userId → enabled
  final DateTime updatedAt;

  const EnhancedFeatureFlag({
    required this.key,
    required this.enabled,
    this.description,
    this.plan,
    this.rolloutPercentage = 100.0,
    this.activateAt,
    this.deactivateAt,
    this.userOverrides = const {},
    this.updatedAt,
  });

  /// Check if the flag is currently active (respects time windows).
  bool get isActive {
    final now = DateTime.now();
    if (activateAt != null && now.isBefore(activateAt!)) return false;
    if (deactivateAt != null && now.isAfter(deactivateAt!)) return false;
    return enabled;
  }

  factory EnhancedFeatureFlag.fromFirestore(String key, Map<String, dynamic> data) {
    return EnhancedFeatureFlag(
      key: key,
      enabled: data['enabled'] as bool? ?? false,
      description: data['description'] as String?,
      plan: data['plan'] as String?,
      rolloutPercentage: (data['rolloutPercentage'] as num?)?.toDouble() ?? 100.0,
      activateAt: (data['activateAt'] as Timestamp?)?.toDate(),
      deactivateAt: (data['deactivateAt'] as Timestamp?)?.toDate(),
      userOverrides: _parseUserOverrides(data['userOverrides'] as Map?),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Map<String, bool> _parseUserOverrides(Map? data) {
    if (data == null) return {};
    return data.map((k, v) => MapEntry(k.toString(), v as bool? ?? false));
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabled': enabled,
      'description': description,
      'plan': plan,
      'rolloutPercentage': rolloutPercentage,
      'activateAt': activateAt != null ? Timestamp.fromDate(activateAt!) : null,
      'deactivateAt': deactivateAt != null ? Timestamp.fromDate(deactivateAt!) : null,
      'userOverrides': userOverrides,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class FeatureFlagEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache
  Map<String, EnhancedFeatureFlag> _flags = {};
  String? _loadedOrgId;
  String _currentPlan = 'free';

  // ─── Load & Stream ──────────────────────────────────────────────────────

  /// Load flags for an organization, merging Firestore overrides with plan defaults.
  Future<void> loadFlags(String orgId, {String plan = 'free'}) async {
    _loadedOrgId = orgId;
    _currentPlan = plan;

    // Start with plan defaults
    final defaults = ModuleFlags.planDefaults[plan] ?? ModuleFlags.planDefaults['free'] ?? {};
    _flags = {
      for (final entry in defaults.entries)
        entry.key: EnhancedFeatureFlag(
          key: entry.key,
          enabled: entry.value,
          plan: plan,
        ),
    };

    // Merge Firestore overrides
    try {
      final snapshot = await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .get();

      for (final doc in snapshot.docs) {
        final override = EnhancedFeatureFlag.fromFirestore(doc.id, doc.data());
        _flags[doc.id] = override;
      }
    } catch (e) {
      debugPrint('[FeatureFlagEngine] Failed to load flags: $e');
    }

    debugPrint('[FeatureFlagEngine] Loaded ${_flags.length} flags for org: $orgId (plan: $plan)');
  }

  /// Stream real-time flag updates from Firestore.
  Stream<Map<String, EnhancedFeatureFlag>> streamFlags(String orgId) {
    return _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.featureFlagsCollection)
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        final flag = EnhancedFeatureFlag.fromFirestore(doc.id, doc.data());
        _flags[doc.id] = flag;
      }
      return Map<String, EnhancedFeatureFlag>.from(_flags);
    });
  }

  // ─── Check Operations ───────────────────────────────────────────────────

  /// Check if a feature flag is enabled.
  bool isEnabled(String flagKey, {String? userId}) {
    final flag = _flags[flagKey];

    if (flag == null) {
      // Fall back to plan defaults
      final defaults = ModuleFlags.planDefaults[_currentPlan] ?? {};
      return defaults[flagKey] ?? false;
    }

    // 1. Check time-based activation
    if (!flag.isActive) return false;

    // 2. Check user-level override
    if (userId != null && flag.userOverrides.containsKey(userId)) {
      return flag.userOverrides[userId]!;
    }

    // 3. Check gradual rollout
    if (flag.rolloutPercentage < 100.0 && userId != null) {
      return _isInRollout(userId, flagKey, flag.rolloutPercentage);
    }

    // 4. Return the flag value
    return flag.enabled;
  }

  /// Get all current flags.
  Map<String, EnhancedFeatureFlag> getAllFlags() => Map.unmodifiable(_flags);

  /// Get a specific flag.
  EnhancedFeatureFlag? getFlag(String key) => _flags[key];

  // ─── Write Operations ───────────────────────────────────────────────────

  /// Set a flag override in Firestore.
  Future<void> setFlag({
    required String orgId,
    required String flagKey,
    required bool enabled,
    String? description,
    double? rolloutPercentage,
    DateTime? activateAt,
    DateTime? deactivateAt,
  }) async {
    final existing = _flags[flagKey];
    final flag = EnhancedFeatureFlag(
      key: flagKey,
      enabled: enabled,
      description: description ?? existing?.description,
      plan: existing?.plan ?? _currentPlan,
      rolloutPercentage: rolloutPercentage ?? existing?.rolloutPercentage ?? 100.0,
      activateAt: activateAt ?? existing?.activateAt,
      deactivateAt: deactivateAt ?? existing?.deactivateAt,
    );

    _flags[flagKey] = flag;

    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.featureFlagsCollection)
        .doc(flagKey)
        .set(flag.toFirestore(), SetOptions(merge: true));
  }

  /// Set a user-level override.
  Future<void> setUserOverride({
    required String orgId,
    required String flagKey,
    required String userId,
    required bool enabled,
  }) async {
    final flag = _flags[flagKey];
    if (flag == null) return;

    final updatedOverrides = Map<String, bool>.from(flag.userOverrides);
    updatedOverrides[userId] = enabled;

    final updatedFlag = EnhancedFeatureFlag(
      key: flag.key,
      enabled: flag.enabled,
      description: flag.description,
      plan: flag.plan,
      rolloutPercentage: flag.rolloutPercentage,
      activateAt: flag.activateAt,
      deactivateAt: flag.deactivateAt,
      userOverrides: updatedOverrides,
    );

    _flags[flagKey] = updatedFlag;

    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.featureFlagsCollection)
        .doc(flagKey)
        .set({'userOverrides': updatedOverrides, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  // ─── Gradual Rollout ────────────────────────────────────────────────────

  /// Deterministic hash-based rollout check.
  bool _isInRollout(String userId, String flagKey, double percentage) {
    final hash = _hashUserId(userId, flagKey);
    return (hash % 100) < percentage;
  }

  /// Simple deterministic hash for rollout bucketing.
  int _hashUserId(String userId, String flagKey) {
    var hash = 0;
    final combined = '$userId:$flagKey';
    for (final char in combined.codeUnits) {
      hash = ((hash << 5) - hash) + char;
      hash = hash & 0x7FFFFFFF; // Keep it positive
    }
    return hash % 100;
  }

  // ─── Plan Management ────────────────────────────────────────────────────

  /// Set the current plan and reload defaults.
  Future<void> setPlan(String orgId, String plan) async {
    _currentPlan = plan;
    await loadFlags(orgId, plan: plan);
  }

  /// Get the list of flags that differ from plan defaults.
  List<String> getOverriddenFlags() {
    final defaults = ModuleFlags.planDefaults[_currentPlan] ?? {};
    final overridden = <String>[];

    for (final entry in _flags.entries) {
      final defaultValue = defaults[entry.key];
      if (defaultValue != null && defaultValue != entry.value.enabled) {
        overridden.add(entry.key);
      }
    }

    return overridden;
  }
}

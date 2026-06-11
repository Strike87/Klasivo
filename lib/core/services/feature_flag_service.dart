import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO FEATURE FLAG SERVICE
// Manages feature flags for gradual rollout, A/B testing, and release control.
//
// Flags are stored in Firestore at: organizations/{orgId}/feature_flags/{flagKey}
// Fallback defaults are defined in code for offline/offline-first support.
// ═══════════════════════════════════════════════════════════════════════════════

class FeatureFlagService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── In-memory cache (populated from Firestore) ─────────────────────────
  static Map<String, FeatureFlag> _cache = {};
  static Map<String, bool> _localOverrides = {}; // For dev/testing

  // ─── Load all flags for an organization ──────────────────────────────────
  Future<void> loadFlags(String orgId) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .get();

      final Map<String, FeatureFlag> newCache = {};
      for (final doc in snapshot.docs) {
        newCache[doc.id] = FeatureFlag.fromFirestore(doc.id, doc.data());
      }

      _cache = newCache;
      debugPrint('[FeatureFlagService] Loaded ${_cache.length} flags for org $orgId');
    } catch (e) {
      debugPrint('[FeatureFlagService] Failed to load flags: $e');
      // Keep existing cache — graceful degradation
    }
  }

  // ─── Stream flags for real-time updates ─────────────────────────────────
  Stream<Map<String, FeatureFlag>> streamFlags(String orgId) {
    return _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.featureFlagsCollection)
        .snapshots()
        .map((snapshot) {
      final Map<String, FeatureFlag> newCache = {};
      for (final doc in snapshot.docs) {
        newCache[doc.id] = FeatureFlag.fromFirestore(doc.id, doc.data());
      }
      _cache = newCache;
      return _cache;
    });
  }

  // ─── Check if a flag is enabled ─────────────────────────────────────────
  bool isEnabled(String flagKey, {String? userId, Map<String, dynamic>? context}) {
    // 1. Check local overrides (for dev/testing)
    if (_localOverrides.containsKey(flagKey)) {
      return _localOverrides[flagKey]!;
    }

    // 2. Check cached Firestore flags
    final flag = _cache[flagKey];
    if (flag == null) {
      // 3. Fall back to hardcoded defaults
      return _defaults[flagKey]?.enabled ?? false;
    }

    // 4. Global off switch
    if (!flag.enabled) return false;

    // 5. If no user filtering, just return enabled
    if (userId == null) return flag.enabled;

    // 6. Check user-level targeting
    if (flag.allowedUserIds != null && flag.allowedUserIds!.isNotEmpty) {
      return flag.allowedUserIds!.contains(userId);
    }

    // 7. Check percentage rollout
    if (flag.rolloutPercentage != null && flag.rolloutPercentage! < 100) {
      final hash = _hashUser(userId, flagKey);
      return (hash % 100) < flag.rolloutPercentage!;
    }

    return flag.enabled;
  }

  // ─── Get all flags ──────────────────────────────────────────────────────
  Map<String, FeatureFlag> getAllFlags() => Map.unmodifiable(_cache);

  // ─── Set a flag (admin only) ────────────────────────────────────────────
  Future<void> setFlag({
    required String orgId,
    required String flagKey,
    required bool enabled,
    int? rolloutPercentage,
    List<String>? allowedUserIds,
    DateTime? expiresAt,
  }) async {
    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.featureFlagsCollection)
        .doc(flagKey)
        .set({
      'enabled': enabled,
      if (rolloutPercentage != null) 'rolloutPercentage': rolloutPercentage,
      if (allowedUserIds != null) 'allowedUserIds': allowedUserIds,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Local overrides (for dev/testing) ──────────────────────────────────
  static void setOverride(String flagKey, bool enabled) {
    _localOverrides[flagKey] = enabled;
  }

  static void clearOverrides() {
    _localOverrides.clear();
  }

  // ─── Deterministic hash for percentage rollout ──────────────────────────
  int _hashUser(String userId, String flagKey) {
    var hash = 0;
    final combined = '$userId:$flagKey';
    for (var i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF; // Keep it positive
    }
    return hash;
  }

  // ─── Default flag values (code-level fallbacks) ─────────────────────────
  static const Map<String, _FlagDefault> _defaults = {
    // v1.6 — All enabled (existing features)
    FeatureFlags.exams: _FlagDefault(enabled: true),
    FeatureFlags.questionBank: _FlagDefault(enabled: true),
    FeatureFlags.attendance: _FlagDefault(enabled: true),
    FeatureFlags.assignments: _FlagDefault(enabled: true),
    FeatureFlags.analytics: _FlagDefault(enabled: true),
    FeatureFlags.notifications: _FlagDefault(enabled: true),
    FeatureFlags.qrEnrollment: _FlagDefault(enabled: true),
    FeatureFlags.excelImport: _FlagDefault(enabled: true),
    FeatureFlags.violationTracking: _FlagDefault(enabled: true),
    FeatureFlags.deepLinks: _FlagDefault(enabled: true),

    // v1.7 — New features (gradual rollout)
    FeatureFlags.lms: _FlagDefault(enabled: false),
    FeatureFlags.parentPortal: _FlagDefault(enabled: false),
    FeatureFlags.progressTracking: _FlagDefault(enabled: false),
    FeatureFlags.lessonPlans: _FlagDefault(enabled: false),
    FeatureFlags.communicationHub: _FlagDefault(enabled: false),

    // v1.8 — Cross-cutting features
    FeatureFlags.globalSearch: _FlagDefault(enabled: false),
    FeatureFlags.commandPalette: _FlagDefault(enabled: false),
    FeatureFlags.dashboardPriorityMatrix: _FlagDefault(enabled: false),
    FeatureFlags.enhancedEmptyStates: _FlagDefault(enabled: false),
    FeatureFlags.academicSetupWizard: _FlagDefault(enabled: false),

    // v1.9 — ERP features
    FeatureFlags.fees: _FlagDefault(enabled: false),
    FeatureFlags.payments: _FlagDefault(enabled: false),
    FeatureFlags.payroll: _FlagDefault(enabled: false),
    FeatureFlags.inventory: _FlagDefault(enabled: false),
    FeatureFlags.frenchLocalization: _FlagDefault(enabled: false),
    FeatureFlags.azureAdSso: _FlagDefault(enabled: false),

    // v2.0 — Future
    FeatureFlags.samlSso: _FlagDefault(enabled: false),
    FeatureFlags.turkishLocalization: _FlagDefault(enabled: false),
    FeatureFlags.publicApi: _FlagDefault(enabled: false),
    FeatureFlags.ltiIntegration: _FlagDefault(enabled: false),
    FeatureFlags.campusManagement: _FlagDefault(enabled: false),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE FLAG KEYS — Centralized string constants
// ═══════════════════════════════════════════════════════════════════════════════

class FeatureFlags {
  FeatureFlags._();

  // v1.6 — Existing features
  static const String exams = 'exams';
  static const String questionBank = 'question_bank';
  static const String attendance = 'attendance';
  static const String assignments = 'assignments';
  static const String analytics = 'analytics';
  static const String notifications = 'notifications';
  static const String qrEnrollment = 'qr_enrollment';
  static const String excelImport = 'excel_import';
  static const String violationTracking = 'violation_tracking';
  static const String deepLinks = 'deep_links';

  // v1.7 — LMS + Parent Experience
  static const String lms = 'lms';
  static const String parentPortal = 'parent_portal';
  static const String progressTracking = 'progress_tracking';
  static const String lessonPlans = 'lesson_plans';
  static const String communicationHub = 'communication_hub';

  // v1.8 — Cross-cutting
  static const String globalSearch = 'global_search';
  static const String commandPalette = 'command_palette';
  static const String dashboardPriorityMatrix = 'dashboard_priority_matrix';
  static const String enhancedEmptyStates = 'enhanced_empty_states';
  static const String academicSetupWizard = 'academic_setup_wizard';

  // v1.9 — ERP
  static const String fees = 'fees';
  static const String payments = 'payments';
  static const String payroll = 'payroll';
  static const String inventory = 'inventory';
  static const String frenchLocalization = 'french_localization';
  static const String azureAdSso = 'azure_ad_sso';

  // v2.0 — Future
  static const String samlSso = 'saml_sso';
  static const String turkishLocalization = 'turkish_localization';
  static const String publicApi = 'public_api';
  static const String ltiIntegration = 'lti_integration';
  static const String campusManagement = 'campus_management';
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE FLAG MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class FeatureFlag {
  final String key;
  final bool enabled;
  final int? rolloutPercentage;     // 0-100, null = no percentage rollout
  final List<String>? allowedUserIds; // null = all users
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  const FeatureFlag({
    required this.key,
    required this.enabled,
    this.rolloutPercentage,
    this.allowedUserIds,
    this.expiresAt,
    this.updatedAt,
  });

  factory FeatureFlag.fromFirestore(String key, Map<String, dynamic> data) {
    return FeatureFlag(
      key: key,
      enabled: data['enabled'] as bool? ?? false,
      rolloutPercentage: data['rolloutPercentage'] as int?,
      allowedUserIds: (data['allowedUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      if (rolloutPercentage != null) 'rolloutPercentage': rolloutPercentage,
      if (allowedUserIds != null) 'allowedUserIds': allowedUserIds,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }
}

class _FlagDefault {
  final bool enabled;
  const _FlagDefault({required this.enabled});
}

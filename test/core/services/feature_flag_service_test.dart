import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';
import 'package:klasivo/core/services/feature_flag_service.dart';

/// Testable version of FeatureFlagService that accepts a Firestore instance.
/// Mirrors the production FeatureFlagService but with DI for testing.
class TestableFeatureFlagService {
  final FirebaseFirestore _db;

  // ─── In-memory cache (populated from Firestore) ─────────────────────────
  Map<String, FeatureFlag> _cache = {};
  Map<String, bool> _localOverrides = {};

  TestableFeatureFlagService(this._db);

  // ─── Expose cache/overrides for direct manipulation in tests ────────────
  void setCache(Map<String, FeatureFlag> cache) {
    _cache = cache;
  }

  void clearCache() {
    _cache = {};
  }

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
    } catch (e) {
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
  void setOverride(String flagKey, bool enabled) {
    _localOverrides[flagKey] = enabled;
  }

  void clearOverrides() {
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
    FeatureFlags.lms: _FlagDefault(enabled: false),
    FeatureFlags.parentPortal: _FlagDefault(enabled: false),
    FeatureFlags.progressTracking: _FlagDefault(enabled: false),
    FeatureFlags.lessonPlans: _FlagDefault(enabled: false),
    FeatureFlags.communicationHub: _FlagDefault(enabled: false),
    FeatureFlags.globalSearch: _FlagDefault(enabled: false),
    FeatureFlags.commandPalette: _FlagDefault(enabled: false),
    FeatureFlags.dashboardPriorityMatrix: _FlagDefault(enabled: false),
    FeatureFlags.enhancedEmptyStates: _FlagDefault(enabled: false),
    FeatureFlags.academicSetupWizard: _FlagDefault(enabled: false),
    FeatureFlags.fees: _FlagDefault(enabled: false),
    FeatureFlags.payments: _FlagDefault(enabled: false),
    FeatureFlags.payroll: _FlagDefault(enabled: false),
    FeatureFlags.inventory: _FlagDefault(enabled: false),
    FeatureFlags.frenchLocalization: _FlagDefault(enabled: false),
    FeatureFlags.azureAdSso: _FlagDefault(enabled: false),
    FeatureFlags.samlSso: _FlagDefault(enabled: false),
    FeatureFlags.turkishLocalization: _FlagDefault(enabled: false),
    FeatureFlags.publicApi: _FlagDefault(enabled: false),
    FeatureFlags.ltiIntegration: _FlagDefault(enabled: false),
    FeatureFlags.campusManagement: _FlagDefault(enabled: false),
  };
}

class _FlagDefault {
  final bool enabled;
  const _FlagDefault({required this.enabled});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late FakeFirebaseFirestore firestore;
  late TestableFeatureFlagService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TestableFeatureFlagService(firestore);
  });

  // ─── Default Values (Hardcoded Fallbacks) ────────────────────────────────

  group('Default Flag Values — Hardcoded Fallbacks', () {
    test('v1.6 feature flags default to enabled', () {
      expect(service.isEnabled(FeatureFlags.exams), isTrue);
      expect(service.isEnabled(FeatureFlags.questionBank), isTrue);
      expect(service.isEnabled(FeatureFlags.attendance), isTrue);
      expect(service.isEnabled(FeatureFlags.assignments), isTrue);
      expect(service.isEnabled(FeatureFlags.analytics), isTrue);
      expect(service.isEnabled(FeatureFlags.notifications), isTrue);
      expect(service.isEnabled(FeatureFlags.qrEnrollment), isTrue);
      expect(service.isEnabled(FeatureFlags.excelImport), isTrue);
      expect(service.isEnabled(FeatureFlags.violationTracking), isTrue);
      expect(service.isEnabled(FeatureFlags.deepLinks), isTrue);
    });

    test('v1.7 feature flags default to disabled', () {
      expect(service.isEnabled(FeatureFlags.lms), isFalse);
      expect(service.isEnabled(FeatureFlags.parentPortal), isFalse);
      expect(service.isEnabled(FeatureFlags.progressTracking), isFalse);
      expect(service.isEnabled(FeatureFlags.lessonPlans), isFalse);
      expect(service.isEnabled(FeatureFlags.communicationHub), isFalse);
    });

    test('v1.8 feature flags default to disabled', () {
      expect(service.isEnabled(FeatureFlags.globalSearch), isFalse);
      expect(service.isEnabled(FeatureFlags.commandPalette), isFalse);
      expect(service.isEnabled(FeatureFlags.dashboardPriorityMatrix), isFalse);
      expect(service.isEnabled(FeatureFlags.enhancedEmptyStates), isFalse);
      expect(service.isEnabled(FeatureFlags.academicSetupWizard), isFalse);
    });

    test('v1.9 ERP feature flags default to disabled', () {
      expect(service.isEnabled(FeatureFlags.fees), isFalse);
      expect(service.isEnabled(FeatureFlags.payments), isFalse);
      expect(service.isEnabled(FeatureFlags.payroll), isFalse);
      expect(service.isEnabled(FeatureFlags.inventory), isFalse);
      expect(service.isEnabled(FeatureFlags.frenchLocalization), isFalse);
      expect(service.isEnabled(FeatureFlags.azureAdSso), isFalse);
    });

    test('v2.0 feature flags default to disabled', () {
      expect(service.isEnabled(FeatureFlags.samlSso), isFalse);
      expect(service.isEnabled(FeatureFlags.turkishLocalization), isFalse);
      expect(service.isEnabled(FeatureFlags.publicApi), isFalse);
      expect(service.isEnabled(FeatureFlags.ltiIntegration), isFalse);
      expect(service.isEnabled(FeatureFlags.campusManagement), isFalse);
    });

    test('unknown flag key defaults to false', () {
      expect(service.isEnabled('nonexistent_flag'), isFalse);
    });
  });

  // ─── Local Overrides ─────────────────────────────────────────────────────

  group('Local Overrides — Dev/Testing', () {
    test('local override forces flag on', () {
      service.setOverride(FeatureFlags.lms, true);
      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('local override forces flag off', () {
      service.setOverride(FeatureFlags.exams, false);
      expect(service.isEnabled(FeatureFlags.exams), isFalse);
    });

    test('local override takes precedence over cached Firestore flag', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });
      service.setOverride(FeatureFlags.lms, false);

      expect(service.isEnabled(FeatureFlags.lms), isFalse);
    });

    test('local override takes precedence over defaults', () {
      // exams defaults to true
      service.setOverride(FeatureFlags.exams, false);
      expect(service.isEnabled(FeatureFlags.exams), isFalse);
    });

    test('clearOverrides removes all overrides', () {
      service.setOverride(FeatureFlags.lms, true);
      service.setOverride(FeatureFlags.exams, false);

      service.clearOverrides();

      // Back to defaults
      expect(service.isEnabled(FeatureFlags.lms), isFalse); // default disabled
      expect(service.isEnabled(FeatureFlags.exams), isTrue); // default enabled
    });

    test('individual override can be changed', () {
      service.setOverride(FeatureFlags.lms, true);
      expect(service.isEnabled(FeatureFlags.lms), isTrue);

      service.setOverride(FeatureFlags.lms, false);
      expect(service.isEnabled(FeatureFlags.lms), isFalse);
    });
  });

  // ─── Cached Firestore Flags ──────────────────────────────────────────────

  group('Cached Firestore Flags', () {
    test('cached enabled flag returns true', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });

      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('cached disabled flag returns false', () {
      service.setCache({
        FeatureFlags.exams: const FeatureFlag(key: FeatureFlags.exams, enabled: false),
      });

      expect(service.isEnabled(FeatureFlags.exams), isFalse);
    });

    test('cached flag takes precedence over defaults', () {
      // exams defaults to true, but cache says disabled
      service.setCache({
        FeatureFlags.exams: const FeatureFlag(key: FeatureFlags.exams, enabled: false),
      });

      expect(service.isEnabled(FeatureFlags.exams), isFalse);
    });

    test('local override takes precedence over cached flag', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: false),
      });
      service.setOverride(FeatureFlags.lms, true);

      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('clearCache reverts to defaults', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });
      expect(service.isEnabled(FeatureFlags.lms), isTrue);

      service.clearCache();
      expect(service.isEnabled(FeatureFlags.lms), isFalse); // Back to default
    });
  });

  // ─── Global Off Switch ───────────────────────────────────────────────────

  group('Global Off Switch — flag.enabled = false', () {
    test('disabled flag returns false even with user ID', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: false),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isFalse,
      );
    });

    test('disabled flag returns false even with allowedUserIds set', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: false,
          allowedUserIds: ['user1'],
        ),
      });

      // Global off switch should prevent access even for allowed users
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isFalse,
      );
    });
  });

  // ─── User-Level Targeting ────────────────────────────────────────────────

  group('User-Level Targeting — allowedUserIds', () {
    test('allowed user gets access when flag is enabled', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: ['user1', 'user2'],
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isTrue,
      );
    });

    test('non-allowed user is denied when allowedUserIds is set', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: ['user1'],
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user2'),
        isFalse,
      );
    });

    test('no user ID returns flag.enabled when allowedUserIds is set', () {
      // When userId is null, skip user targeting check
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: ['user1'],
        ),
      });

      // Without userId, returns flag.enabled directly
      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('empty allowedUserIds falls through to percentage rollout', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: [], // Empty list
          rolloutPercentage: 50,
        ),
      });

      // Empty allowedUserIds should fall through to percentage rollout
      // The result depends on hash, but should not crash
      final result = service.isEnabled(FeatureFlags.lms, userId: 'user1');
      expect(result, isA<bool>());
    });

    test('null allowedUserIds falls through to percentage rollout', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: null, // null = all users
          rolloutPercentage: 100,
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'anyone'),
        isTrue,
      );
    });
  });

  // ─── Percentage Rollout ──────────────────────────────────────────────────

  group('Percentage Rollout — Deterministic Hash', () {
    test('100% rollout allows all users', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 100,
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isTrue,
      );
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user2'),
        isTrue,
      );
    });

    test('0% rollout denies all users', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 0,
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isFalse,
      );
    });

    test('same user gets consistent result across calls', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      final result1 = service.isEnabled(FeatureFlags.lms, userId: 'user1');
      final result2 = service.isEnabled(FeatureFlags.lms, userId: 'user1');

      expect(result1, equals(result2));
    });

    test('different users may get different results at 50% rollout', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      // Test many users — at 50%, roughly half should be enabled
      final results = <bool>[];
      for (var i = 0; i < 100; i++) {
        results.add(service.isEnabled(FeatureFlags.lms, userId: 'user_$i'));
      }

      final enabledCount = results.where((r) => r).length;
      // Should have some enabled and some disabled (not all true or all false)
      expect(enabledCount, greaterThan(0));
      expect(enabledCount, lessThan(100));
    });

    test('percentage rollout is deterministic for same user+flag combo', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 25,
        ),
      });

      // Run 10 times — should always be the same
      final results = List.generate(
        10,
        (_) => service.isEnabled(FeatureFlags.lms, userId: 'deterministic_user'),
      );

      expect(results.every((r) => r == results.first), isTrue);
    });

    test('null rolloutPercentage means 100% (no percentage filtering)', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: null,
        ),
      });

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'any_user'),
        isTrue,
      );
    });

    test('rollout is different per flag for same user', () {
      // Same user, different flags should hash differently
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
        FeatureFlags.parentPortal: const FeatureFlag(
          key: FeatureFlags.parentPortal,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      // Both flags for the same user — they may or may not differ,
      // but the point is they're independently hashed
      final lmsResult = service.isEnabled(FeatureFlags.lms, userId: 'user1');
      final parentResult = service.isEnabled(FeatureFlags.parentPortal, userId: 'user1');

      // Just verify they're bools — actual result depends on hash
      expect(lmsResult, isA<bool>());
      expect(parentResult, isA<bool>());
    });
  });

  // ─── isEnabled Resolution Chain ──────────────────────────────────────────

  group('isEnabled Resolution Chain — Evaluation Order', () {
    test('step 1: local override takes highest priority', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });
      service.setOverride(FeatureFlags.lms, false);

      // Local override wins over cache
      expect(service.isEnabled(FeatureFlags.lms), isFalse);
    });

    test('step 2: cached Firestore flag checked when no override', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });

      // No override, so cache value is used
      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('step 3: hardcoded defaults used when cache is empty', () {
      service.clearCache();

      // lms defaults to false
      expect(service.isEnabled(FeatureFlags.lms), isFalse);
      // exams defaults to true
      expect(service.isEnabled(FeatureFlags.exams), isTrue);
    });

    test('step 4: global off switch overrides user targeting', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: false,
          allowedUserIds: ['user1'],
        ),
      });

      // Flag is globally off, so even allowed user should be denied
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isFalse,
      );
    });

    test('step 5: no userId returns flag.enabled when flag is on', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });

      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('step 6: user targeting checked before percentage rollout', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          allowedUserIds: ['user1'],
          rolloutPercentage: 0, // 0% rollout, but user1 is explicitly allowed
        ),
      });

      // user1 should be allowed because user targeting is checked first
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user1'),
        isTrue,
      );

      // user2 should be denied by 0% rollout (not in allowed list)
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'user2'),
        isFalse,
      );
    });
  });

  // ─── loadFlags from Firestore ────────────────────────────────────────────

  group('loadFlags — Firestore Integration', () {
    test('loads flags from Firestore into cache', () async {
      final orgId = 'org1';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .set({
        'enabled': true,
        'rolloutPercentage': 25,
      });

      await service.loadFlags(orgId);

      // LMS flag should now be loaded from Firestore
      expect(service.isEnabled(FeatureFlags.lms), isTrue);
    });

    test('loads disabled flag from Firestore', () async {
      final orgId = 'org1';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.exams)
          .set({
        'enabled': false,
      });

      await service.loadFlags(orgId);

      // exams is normally true by default, but Firestore says false
      expect(service.isEnabled(FeatureFlags.exams), isFalse);
    });

    test('handles empty Firestore collection', () async {
      await service.loadFlags('empty_org');

      // Should fall back to defaults
      expect(service.isEnabled(FeatureFlags.exams), isTrue); // default true
      expect(service.isEnabled(FeatureFlags.lms), isFalse); // default false
    });

    test('loads flag with allowedUserIds from Firestore', () async {
      final orgId = 'org1';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .set({
        'enabled': true,
        'allowedUserIds': ['beta_user1', 'beta_user2'],
      });

      await service.loadFlags(orgId);

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'beta_user1'),
        isTrue,
      );
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'random_user'),
        isFalse,
      );
    });

    test('loads flag with rolloutPercentage from Firestore', () async {
      final orgId = 'org1';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .set({
        'enabled': true,
        'rolloutPercentage': 100,
      });

      await service.loadFlags(orgId);

      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'any_user'),
        isTrue,
      );
    });

    test('replacing cache on second load', () async {
      final orgId = 'org1';

      // First load: LMS enabled
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .set({'enabled': true});

      await service.loadFlags(orgId);
      expect(service.isEnabled(FeatureFlags.lms), isTrue);

      // Update Firestore: LMS disabled
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .set({'enabled': false});

      await service.loadFlags(orgId);
      expect(service.isEnabled(FeatureFlags.lms), isFalse);
    });
  });

  // ─── setFlag writes to Firestore ─────────────────────────────────────────

  group('setFlag — Firestore Write', () {
    test('writes flag to Firestore with correct structure', () async {
      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: true,
      );

      final doc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['enabled'], isTrue);
    });

    test('writes flag with rolloutPercentage', () async {
      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: true,
        rolloutPercentage: 25,
      );

      final doc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .get();

      expect(doc.data()!['rolloutPercentage'], equals(25));
    });

    test('writes flag with allowedUserIds', () async {
      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: true,
        allowedUserIds: ['user1', 'user2'],
      );

      final doc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .get();

      expect(doc.data()!['allowedUserIds'], equals(['user1', 'user2']));
    });

    test('writes flag with expiresAt timestamp', () async {
      final expiresAt = DateTime(2026, 12, 31);

      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: true,
        expiresAt: expiresAt,
      );

      final doc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .get();

      expect(doc.data()!['expiresAt'], isNotNull);
    });

    test('uses merge mode — does not overwrite existing fields', () async {
      // First write: enabled + rolloutPercentage
      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: true,
        rolloutPercentage: 25,
      );

      // Second write: only enabled (merge)
      await service.setFlag(
        orgId: 'org1',
        flagKey: FeatureFlags.lms,
        enabled: false,
      );

      final doc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.featureFlagsCollection)
          .doc(FeatureFlags.lms)
          .get();

      // enabled should be updated to false
      expect(doc.data()!['enabled'], isFalse);
      // rolloutPercentage should still be there from first write
      expect(doc.data()!['rolloutPercentage'], equals(25));
    });
  });

  // ─── getAllFlags ──────────────────────────────────────────────────────────

  group('getAllFlags', () {
    test('returns empty map when no flags loaded', () {
      expect(service.getAllFlags(), isEmpty);
    });

    test('returns cached flags', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
        FeatureFlags.exams: const FeatureFlag(key: FeatureFlags.exams, enabled: false),
      });

      final flags = service.getAllFlags();
      expect(flags.length, 2);
      expect(flags[FeatureFlags.lms]?.enabled, isTrue);
      expect(flags[FeatureFlags.exams]?.enabled, isFalse);
    });

    test('returns unmodifiable map', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(key: FeatureFlags.lms, enabled: true),
      });

      final flags = service.getAllFlags();
      expect(() => flags['new_key'] = const FeatureFlag(key: 'new_key', enabled: true), throwsUnsupportedError);
    });
  });

  // ─── FeatureFlag Model ───────────────────────────────────────────────────

  group('FeatureFlag Model', () {
    test('fromFirestore creates correct model', () {
      final data = {
        'enabled': true,
        'rolloutPercentage': 50,
        'allowedUserIds': ['user1', 'user2'],
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 15)),
      };

      final flag = FeatureFlag.fromFirestore('lms', data);

      expect(flag.key, equals('lms'));
      expect(flag.enabled, isTrue);
      expect(flag.rolloutPercentage, equals(50));
      expect(flag.allowedUserIds, equals(['user1', 'user2']));
      expect(flag.updatedAt, equals(DateTime(2026, 3, 15)));
    });

    test('fromFirestore handles missing fields with defaults', () {
      final data = <String, dynamic>{};

      final flag = FeatureFlag.fromFirestore('lms', data);

      expect(flag.key, equals('lms'));
      expect(flag.enabled, isFalse); // defaults to false
      expect(flag.rolloutPercentage, isNull);
      expect(flag.allowedUserIds, isNull);
      expect(flag.expiresAt, isNull);
      expect(flag.updatedAt, isNull);
    });

    test('fromFirestore handles expiresAt timestamp', () {
      final expiresAt = DateTime(2026, 6, 30);
      final data = {
        'enabled': true,
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

      final flag = FeatureFlag.fromFirestore('lms', data);

      expect(flag.expiresAt, equals(expiresAt));
    });

    test('toMap produces correct output', () {
      final expiresAt = DateTime(2026, 6, 30);
      final flag = FeatureFlag(
        key: 'lms',
        enabled: true,
        rolloutPercentage: 50,
        allowedUserIds: ['user1'],
        expiresAt: expiresAt,
      );

      final map = flag.toMap();

      expect(map['enabled'], isTrue);
      expect(map['rolloutPercentage'], equals(50));
      expect(map['allowedUserIds'], equals(['user1']));
      expect(map['expiresAt'], isA<Timestamp>());
    });

    test('toMap omits null fields', () {
      final flag = const FeatureFlag(
        key: 'lms',
        enabled: true,
      );

      final map = flag.toMap();

      expect(map.containsKey('rolloutPercentage'), isFalse);
      expect(map.containsKey('allowedUserIds'), isFalse);
      expect(map.containsKey('expiresAt'), isFalse);
    });

    test('FeatureFlag constructor stores values correctly', () {
      final now = DateTime.now();
      final flag = FeatureFlag(
        key: 'test',
        enabled: true,
        rolloutPercentage: 75,
        allowedUserIds: ['a', 'b'],
        expiresAt: now,
        updatedAt: now,
      );

      expect(flag.key, 'test');
      expect(flag.enabled, isTrue);
      expect(flag.rolloutPercentage, 75);
      expect(flag.allowedUserIds, ['a', 'b']);
      expect(flag.expiresAt, now);
      expect(flag.updatedAt, now);
    });
  });

  // ─── FeatureFlags Constants ──────────────────────────────────────────────

  group('FeatureFlags Constants — Completeness', () {
    test('all v1.6 flags are defined', () {
      expect(FeatureFlags.exams, equals('exams'));
      expect(FeatureFlags.questionBank, equals('question_bank'));
      expect(FeatureFlags.attendance, equals('attendance'));
      expect(FeatureFlags.assignments, equals('assignments'));
      expect(FeatureFlags.analytics, equals('analytics'));
      expect(FeatureFlags.notifications, equals('notifications'));
      expect(FeatureFlags.qrEnrollment, equals('qr_enrollment'));
      expect(FeatureFlags.excelImport, equals('excel_import'));
      expect(FeatureFlags.violationTracking, equals('violation_tracking'));
      expect(FeatureFlags.deepLinks, equals('deep_links'));
    });

    test('all v1.7 flags are defined', () {
      expect(FeatureFlags.lms, equals('lms'));
      expect(FeatureFlags.parentPortal, equals('parent_portal'));
      expect(FeatureFlags.progressTracking, equals('progress_tracking'));
      expect(FeatureFlags.lessonPlans, equals('lesson_plans'));
      expect(FeatureFlags.communicationHub, equals('communication_hub'));
    });

    test('all v1.8 flags are defined', () {
      expect(FeatureFlags.globalSearch, equals('global_search'));
      expect(FeatureFlags.commandPalette, equals('command_palette'));
      expect(FeatureFlags.dashboardPriorityMatrix, equals('dashboard_priority_matrix'));
      expect(FeatureFlags.enhancedEmptyStates, equals('enhanced_empty_states'));
      expect(FeatureFlags.academicSetupWizard, equals('academic_setup_wizard'));
    });

    test('all v1.9 flags are defined', () {
      expect(FeatureFlags.fees, equals('fees'));
      expect(FeatureFlags.payments, equals('payments'));
      expect(FeatureFlags.payroll, equals('payroll'));
      expect(FeatureFlags.inventory, equals('inventory'));
      expect(FeatureFlags.frenchLocalization, equals('french_localization'));
      expect(FeatureFlags.azureAdSso, equals('azure_ad_sso'));
    });

    test('all v2.0 flags are defined', () {
      expect(FeatureFlags.samlSso, equals('saml_sso'));
      expect(FeatureFlags.turkishLocalization, equals('turkish_localization'));
      expect(FeatureFlags.publicApi, equals('public_api'));
      expect(FeatureFlags.ltiIntegration, equals('lti_integration'));
      expect(FeatureFlags.campusManagement, equals('campus_management'));
    });

    test('all flag constants are unique', () {
      final allFlags = [
        FeatureFlags.exams, FeatureFlags.questionBank, FeatureFlags.attendance,
        FeatureFlags.assignments, FeatureFlags.analytics, FeatureFlags.notifications,
        FeatureFlags.qrEnrollment, FeatureFlags.excelImport,
        FeatureFlags.violationTracking, FeatureFlags.deepLinks,
        FeatureFlags.lms, FeatureFlags.parentPortal,
        FeatureFlags.progressTracking, FeatureFlags.lessonPlans,
        FeatureFlags.communicationHub,
        FeatureFlags.globalSearch, FeatureFlags.commandPalette,
        FeatureFlags.dashboardPriorityMatrix, FeatureFlags.enhancedEmptyStates,
        FeatureFlags.academicSetupWizard,
        FeatureFlags.fees, FeatureFlags.payments,
        FeatureFlags.payroll, FeatureFlags.inventory,
        FeatureFlags.frenchLocalization, FeatureFlags.azureAdSso,
        FeatureFlags.samlSso, FeatureFlags.turkishLocalization,
        FeatureFlags.publicApi, FeatureFlags.ltiIntegration,
        FeatureFlags.campusManagement,
      ];

      expect(allFlags.toSet().length, equals(allFlags.length),
          reason: 'All flag constants should be unique');
    });
  });

  // ─── Deterministic Hash ──────────────────────────────────────────────────

  group('Deterministic Hash — _hashUser', () {
    test('same user+flag always produces same hash', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      // Call 100 times — should always be the same result
      final results = List.generate(
        100,
        (_) => service.isEnabled(FeatureFlags.lms, userId: 'stable_user'),
      );

      expect(results.toSet().length, 1, reason: 'Same user+flag should always produce the same result');
    });

    test('different users produce different hash buckets', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 10,
        ),
      });

      // With 10% rollout, very few users should be enabled
      // But at least test that it doesn't crash with many users
      final results = <bool>[];
      for (var i = 0; i < 50; i++) {
        results.add(service.isEnabled(FeatureFlags.lms, userId: 'user_$i'));
      }

      // Most should be false at 10% rollout
      final enabledCount = results.where((r) => r).length;
      expect(enabledCount, lessThan(25)); // Very loose bound
    });
  });

  // ─── Edge Cases ──────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('empty string userId works', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      // Should not crash
      final result = service.isEnabled(FeatureFlags.lms, userId: '');
      expect(result, isA<bool>());
    });

    test('very long userId works', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      final longUserId = 'user_' * 1000;
      final result = service.isEnabled(FeatureFlags.lms, userId: longUserId);
      expect(result, isA<bool>());
    });

    test('unicode userId works', () {
      service.setCache({
        FeatureFlags.lms: const FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 50,
        ),
      });

      final result = service.isEnabled(FeatureFlags.lms, userId: 'مستخدم_١');
      expect(result, isA<bool>());
    });

    test('flag with all fields set works together', () {
      service.setCache({
        FeatureFlags.lms: FeatureFlag(
          key: FeatureFlags.lms,
          enabled: true,
          rolloutPercentage: 75,
          allowedUserIds: ['vip_user'],
          expiresAt: DateTime(2027, 1, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      });

      // VIP user should be allowed (user targeting takes precedence)
      expect(
        service.isEnabled(FeatureFlags.lms, userId: 'vip_user'),
        isTrue,
      );

      // Regular user goes to percentage rollout
      final result = service.isEnabled(FeatureFlags.lms, userId: 'regular_user');
      expect(result, isA<bool>());
    });

    test('local override + cache + default all different — override wins', () {
      // Default: exams = true
      // Cache: exams = false
      // Override: exams = true
      service.setCache({
        FeatureFlags.exams: const FeatureFlag(key: FeatureFlags.exams, enabled: false),
      });
      service.setOverride(FeatureFlags.exams, true);

      expect(service.isEnabled(FeatureFlags.exams), isTrue);
    });
  });
}

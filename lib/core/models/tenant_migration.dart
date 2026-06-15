/// Klasivo v2.0 — Multi-Tenant Migration Utility
///
/// Migrates existing single-organization data to the multi-tenant structure.
/// Adds `tenantId` and `campusId` to all existing documents that lack them.
///
/// Typical migration flow:
///   1. Create a default tenant from the existing organization
///   2. Update the organization document with the new `tenantId`
///   3. Create a default campus for the organization
///   4. Update all sub-collections under the organization with `tenantId`
///      and `campusId`
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import 'tenant_model.dart';

/// Utility to migrate existing single-org data to multi-tenant structure.
///
/// All methods are static; this class is not meant to be instantiated.
class TenantMigration {
  TenantMigration._();

  // ─── Firestore reference ──────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Creates a default tenant for an existing organization and back-fills
  /// `tenantId` and `campusId` on all documents that belong to it.
  ///
  /// Returns the newly created tenant ID.
  ///
  /// Steps:
  ///   1. Create a [TenantData] document from the organization's data.
  ///   2. Update the organization with the new `tenantId`.
  ///   3. Create a default [CampusData] for the organization.
  ///   4. Update all sub-collections under the organization with `tenantId`
  ///      and `campusId`.
  ///
  /// This operation is **idempotent** — if the organization already has a
  /// `tenantId`, it will be returned immediately without any writes.
  static Future<String> migrateOrganizationToTenant({
    required String orgId,
    required String orgName,
    required String ownerId,
  }) async {
    try {
      // ── Step 0: Check if already migrated ────────────────────────────────
      final orgDoc = await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .get();

      if (!orgDoc.exists) {
        throw StateError('Organization $orgId does not exist');
      }

      final orgData = orgDoc.data()!;
      final existingTenantId = orgData['tenantId'] as String?;
      if (existingTenantId != null && existingTenantId.isNotEmpty) {
        debugPrint(
          '[TenantMigration] Org $orgId already has tenantId=$existingTenantId. '
          'Skipping migration.',
        );
        return existingTenantId;
      }

      // ── Step 1: Create tenant document ───────────────────────────────────
      final tenantId = await _createTenantFromOrg(
        orgId: orgId,
        orgName: orgName,
        ownerId: ownerId,
      );

      debugPrint('[TenantMigration] Created tenant $tenantId for org $orgId');

      // ── Step 2: Update organization with tenantId ────────────────────────
      await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update({
        'tenantId': tenantId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '[TenantMigration] Updated org $orgId with tenantId=$tenantId',
      );

      // ── Step 3: Create default campus ────────────────────────────────────
      final campusId = await _createDefaultCampus(
        orgId: orgId,
        tenantId: tenantId,
        orgName: orgName,
        managerId: ownerId,
      );

      debugPrint(
        '[TenantMigration] Created default campus $campusId for org $orgId',
      );

      // ── Step 4: Update organization with campusId ────────────────────────
      await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update({
        'campusId': campusId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── Step 5: Back-fill tenantId and campusId on all sub-collections ───
      await _backfillTenantFields(
        orgId: orgId,
        tenantId: tenantId,
        campusId: campusId,
      );

      debugPrint(
        '[TenantMigration] Migration complete for org $orgId → tenant $tenantId, '
        'campus $campusId',
      );

      return tenantId;
    } catch (e, st) {
      debugPrint('[TenantMigration] Migration FAILED for org $orgId: $e\n$st');
      rethrow;
    }
  }

  /// Back-fills `tenantId` (and optionally `campusId`) on all documents in
  /// a given collection that belong to the specified organization.
  ///
  /// This can be called independently for targeted back-fills if the full
  /// migration has already been run but some collections were missed.
  static Future<int> backfillCollection({
    required String orgId,
    required String tenantId,
    String? campusId,
    required String collectionName,
    int batchSize = 500,
  }) async {
    int updated = 0;

    try {
      final snapshot = await _db
          .collection(collectionName)
          .where('organizationId', isEqualTo: orgId)
          .limit(batchSize)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final needsUpdate =
            data['tenantId'] == null || (campusId != null && data['campusId'] == null);

        if (needsUpdate) {
          final updates = <String, dynamic>{
            'tenantId': tenantId,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (campusId != null) {
            updates['campusId'] = campusId;
          }

          await doc.reference.update(updates);
          updated++;
        }
      }

      debugPrint(
        '[TenantMigration] Back-filled $updated docs in $collectionName '
        'for org $orgId',
      );
    } catch (e) {
      debugPrint(
        '[TenantMigration] Back-fill FAILED for $collectionName/org $orgId: $e',
      );
      rethrow;
    }

    return updated;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  /// Creates a Tenant document from an existing organization.
  static Future<String> _createTenantFromOrg({
    required String orgId,
    required String orgName,
    required String ownerId,
  }) async {
    final slug = _slugify(orgName);
    final tenantData = TenantData(
      id: '', // Firestore will auto-generate
      name: orgName,
      slug: slug,
      type: TenantType.singleSchool,
      plan: TenantPlan.free,
      status: TenantStatus.active,
      ownerId: ownerId,
      adminIds: [ownerId],
      maxOrganizations: TenantPlan.free.maxOrganizations,
      maxUsersPerOrg: TenantPlan.free.maxUsersPerOrg,
      organizationCount: 1,
      createdBy: ownerId,
      createdAt: DateTime.now(),
    );

    final docRef = await _db.collection('tenants').add(tenantData.toMap());
    return docRef.id;
  }

  /// Creates a default campus for an organization.
  static Future<String> _createDefaultCampus({
    required String orgId,
    required String tenantId,
    required String orgName,
    required String managerId,
  }) async {
    final campusData = CampusData(
      id: '', // Firestore will auto-generate
      organizationId: orgId,
      tenantId: tenantId,
      name: 'Main Campus',
      managerId: managerId,
      createdBy: managerId,
      createdAt: DateTime.now(),
    );

    final docRef =
        await _db.collection(AppConstants.campusesCollection).add(campusData.toMap());
    return docRef.id;
  }

  /// Back-fills `tenantId` and `campusId` on all known sub-collections
  /// that belong to the given organization.
  static Future<void> _backfillTenantFields({
    required String orgId,
    required String tenantId,
    required String campusId,
  }) async {
    // All collections that have an organizationId field and need tenantId/campusId
    const collectionsToBackfill = [
      AppConstants.usersCollection,
      AppConstants.stagesCollection,
      AppConstants.classesCollection,
      AppConstants.subjectsCollection,
      AppConstants.groupsCollection,
      AppConstants.groupMembersCollection,
      AppConstants.teacherAssignmentsCollection,
      AppConstants.examsCollection,
      AppConstants.questionsCollection,
      AppConstants.questionBankCollection,
      AppConstants.examAttemptsCollection,
      AppConstants.submissionsCollection,
      AppConstants.answersCollection,
      AppConstants.examStatsCollection,
      AppConstants.violationsCollection,
      AppConstants.assignmentsCollection,
      AppConstants.assignmentSubmissionsCollection,
      AppConstants.attendanceCollection,
      AppConstants.conversationsCollection,
      AppConstants.messagesCollection,
      AppConstants.analyticsCacheCollection,
      AppConstants.notificationsCollection,
      AppConstants.unitsCollection,
      AppConstants.materialsCollection,
      AppConstants.lessonsCollection,
      AppConstants.lessonPlansCollection,
      AppConstants.resourcesCollection,
      AppConstants.contentProgressCollection,
      AppConstants.progressTrackingCollection,
      AppConstants.moderationQueueCollection,
      AppConstants.parentLinksCollection,
      AppConstants.parentNotificationsCollection,
      AppConstants.featureFlagsCollection,
      AppConstants.permissionsCollection,
      AppConstants.auditLogCollection,
      AppConstants.academicYearsCollection,
      AppConstants.announcementsCollection,
      AppConstants.calendarEventsCollection,
      AppConstants.gradebookCollection,
      AppConstants.examInstancesCollection,
      AppConstants.gradebookCategoriesCollection,
      AppConstants.gradebookEntriesCollection,
      AppConstants.feesCollection,
      AppConstants.feeStructuresCollection,
      AppConstants.paymentsCollection,
      AppConstants.payrollCollection,
      AppConstants.inventoryCollection,
    ];

    int totalUpdated = 0;

    for (final collectionName in collectionsToBackfill) {
      try {
        final updated = await backfillCollection(
          orgId: orgId,
          tenantId: tenantId,
          campusId: campusId,
          collectionName: collectionName,
        );
        totalUpdated += updated;
      } catch (e) {
        // Continue with other collections even if one fails
        debugPrint(
          '[TenantMigration] Skipping $collectionName due to error: $e',
        );
      }
    }

    debugPrint(
      '[TenantMigration] Back-fill complete: $totalUpdated documents updated '
      'across ${collectionsToBackfill.length} collections',
    );
  }

  /// Convert a name to a URL-friendly slug.
  static String _slugify(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return slug.length > AppConstants.maxSlugLength
        ? slug.substring(0, AppConstants.maxSlugLength)
        : slug;
  }

  // ─── Batch Migration ──────────────────────────────────────────────────────

  /// Migrates ALL organizations that don't yet have a tenantId.
  ///
  /// This is intended for one-time platform-wide migrations.
  /// Returns a map of {orgId: tenantId} for all migrated organizations.
  static Future<Map<String, String>> migrateAllOrganizations() async {
    final results = <String, String>{};

    try {
      final snapshot = await _db
          .collection(AppConstants.organizationsCollection)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final existingTenantId = data['tenantId'] as String?;

        // Skip organizations that are already migrated
        if (existingTenantId != null && existingTenantId.isNotEmpty) {
          results[doc.id] = existingTenantId;
          continue;
        }

        final orgName = data['name'] as String? ?? 'Unnamed Organization';
        final ownerId = data['ownerId'] as String? ?? '';

        if (ownerId.isEmpty) {
          debugPrint(
            '[TenantMigration] Skipping org ${doc.id} — no ownerId found',
          );
          continue;
        }

        final tenantId = await migrateOrganizationToTenant(
          orgId: doc.id,
          orgName: orgName,
          ownerId: ownerId,
        );

        results[doc.id] = tenantId;
      }

      debugPrint(
        '[TenantMigration] Batch migration complete: '
        '${results.length} organizations processed',
      );
    } catch (e, st) {
      debugPrint('[TenantMigration] Batch migration FAILED: $e\n$st');
      rethrow;
    }

    return results;
  }

  // ─── Rollback ─────────────────────────────────────────────────────────────

  /// Rolls back a migration by removing `tenantId` and `campusId` from the
  /// organization and its sub-collections, and deleting the tenant document.
  ///
  /// **WARNING:** This is a destructive operation. Use with extreme caution.
  static Future<void> rollbackMigration({
    required String orgId,
    required String tenantId,
  }) async {
    try {
      // 1. Remove tenantId and campusId from the organization
      await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update({
        'tenantId': FieldValue.delete(),
        'campusId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Delete the default campus
      final campusSnapshot = await _db
          .collection(AppConstants.campusesCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in campusSnapshot.docs) {
        await doc.reference.delete();
      }

      // 3. Delete the tenant document
      await _db.collection('tenants').doc(tenantId).delete();

      // 4. Remove tenantId and campusId from all sub-collections
      const collectionsToClean = [
        AppConstants.usersCollection,
        AppConstants.stagesCollection,
        AppConstants.classesCollection,
        AppConstants.subjectsCollection,
        AppConstants.groupsCollection,
        AppConstants.examsCollection,
        AppConstants.assignmentsCollection,
        AppConstants.attendanceCollection,
      ];

      for (final collectionName in collectionsToClean) {
        try {
          final snapshot = await _db
              .collection(collectionName)
              .where('organizationId', isEqualTo: orgId)
              .where('tenantId', isEqualTo: tenantId)
              .limit(500)
              .get();

          for (final doc in snapshot.docs) {
            await doc.reference.update({
              'tenantId': FieldValue.delete(),
              'campusId': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint(
            '[TenantMigration] Rollback: skipping $collectionName: $e',
          );
        }
      }

      debugPrint(
        '[TenantMigration] Rollback complete for org $orgId, '
        'tenant $tenantId',
      );
    } catch (e, st) {
      debugPrint('[TenantMigration] Rollback FAILED: $e\n$st');
      rethrow;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Scoped Query Builder
//
// Applies scope-based filtering to Firestore queries based on the
// current user's role and scope arrays.
//
// Architecture (per Q1 decision — Option C):
//   - Client-side: ScopedQueryBuilder filters queries for UX
//   - Firestore Rules: Org isolation + role validation (no scope rules)
//   - Cloud Functions: Scope validation for all write operations
//
// Usage:
//   final query = ScopedQueryBuilder.apply(
//     baseQuery: FirebaseFirestore.instance.collection('exams'),
//     scope: userScope,
//     role: 'teacher',
//     scopeType: 'class',
//   );
//   // Result: baseQuery.where('classId', whereIn: ['class_5A', 'class_5B'])
//
// For roles with ScopeAccessLevel.all, no filtering is applied —
// they see everything within their organization (org isolation is
// handled by Firestore Rules).
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

import '../rbac/roles.dart';
import '../rbac/scope_access_level.dart';
import '../rbac/user_scope.dart';
import '../rbac/scope_validator.dart';

/// Builds Firestore queries with scope-based filtering.
///
/// This is the client-side enforcement layer. It ensures users only
/// see data within their assigned scope. For UX optimization only —
/// Firestore Rules and Cloud Functions provide the actual security.
class ScopedQueryBuilder {
  ScopedQueryBuilder._();

  /// Maximum number of values in a Firestore `whereIn` query.
  /// Firestore limit is 30; we use 10 to leave room for pagination.
  static const int maxWhereInValues = 10;

  /// Apply scope filtering to a Firestore query.
  ///
  /// [baseQuery] — The base Firestore query (already filtered by org).
  /// [scope] — The current user's scope.
  /// [role] — The current user's role string.
  /// [scopeType] — The scope type to filter by:
  ///   'campus', 'stage', 'class', 'subject', 'academic_year', 'student'
  ///
  /// Returns the query with appropriate `where` clauses added,
  /// or the base query unchanged if the role has full access.
  ///
  /// For roles with ScopeAccessLevel.all: no filtering (they see everything).
  /// For scoped roles: adds `whereIn` filters based on their scope arrays.
  /// For student/parent: adds appropriate filters for their scope types.
  static Query<Map<String, dynamic>> apply({
    required Query<Map<String, dynamic>> baseQuery,
    required UserScope scope,
    required String role,
    required String scopeType,
  }) {
    final accessLevel = scopeAccessLevelForRole(role);
    final validator = ScopeValidator(scope: scope, accessLevel: accessLevel);

    // Non-scoped roles: no query filtering needed
    if (accessLevel == ScopeAccessLevel.all) {
      return baseQuery;
    }

    // Get the scope IDs for this type
    final scopeIds = validator.accessibleIdsFor(scopeType);

    // If null, means "all access" for this scope type (empty array for scoped role)
    // But with fail-closed, we should still not filter if the validator says it's all access
    // This handles the case where a scoped role has empty arrays
    if (scopeIds == null) {
      // Empty array = all access for this scope type (legacy behavior)
      // With fail-closed, this shouldn't happen in production, but we handle it
      // by returning the base query (no additional filtering)
      return baseQuery;
    }

    // No scope IDs assigned — return empty result set (fail-closed)
    if (scopeIds.isEmpty) {
      // Use an impossible filter to return no results
      return baseQuery.where(FieldPath.documentId, whereIn: ['__NO_RESULTS__']);
    }

    // Apply the scope filter
    final fieldName = _scopeTypeToFieldName(scopeType);

    if (scopeIds.length <= maxWhereInValues) {
      // Single whereIn query
      return baseQuery.where(fieldName, whereIn: scopeIds);
    }

    // If more than maxWhereInValues, we need to split into multiple queries.
    // For now, truncate to the first N values with a warning.
    // A more sophisticated approach would use multiple queries and merge results.
    // This is a known limitation that should be addressed in Sprint 5.
    final truncatedIds = scopeIds.take(maxWhereInValues).toList();
    return baseQuery.where(fieldName, whereIn: truncatedIds);
  }

  /// Apply scope filtering for a collection grouped by a parent scope type.
  ///
  /// For example, exams might be stored with a `campusId` field.
  /// A campus_manager should only see exams in their assigned campuses.
  ///
  /// [parentScopeType] — The field name in the documents to filter by.
  /// This is useful when the document's scope field doesn't match
  /// the standard scope type naming.
  static Query<Map<String, dynamic>> applyWithField({
    required Query<Map<String, dynamic>> baseQuery,
    required UserScope scope,
    required String role,
    required String fieldName,
    required String scopeType,
  }) {
    final accessLevel = scopeAccessLevelForRole(role);
    final validator = ScopeValidator(scope: scope, accessLevel: accessLevel);

    if (accessLevel == ScopeAccessLevel.all) {
      return baseQuery;
    }

    final scopeIds = validator.accessibleIdsFor(scopeType);

    if (scopeIds == null) {
      return baseQuery;
    }

    if (scopeIds.isEmpty) {
      return baseQuery.where(FieldPath.documentId, whereIn: ['__NO_RESULTS__']);
    }

    if (scopeIds.length <= maxWhereInValues) {
      return baseQuery.where(fieldName, whereIn: scopeIds);
    }

    final truncatedIds = scopeIds.take(maxWhereInValues).toList();
    return baseQuery.where(fieldName, whereIn: truncatedIds);
  }

  /// Check if a query needs scope filtering for the given role.
  ///
  /// Returns false for roles with ScopeAccessLevel.all,
  /// meaning no filtering is needed.
  static bool needsFiltering(String role) {
    final accessLevel = scopeAccessLevelForRole(role);
    return accessLevel != ScopeAccessLevel.all;
  }

  /// Get the Firestore field name for a scope type.
  ///
  /// Maps scope type strings to the field names used in Firestore documents.
  static String _scopeTypeToFieldName(String scopeType) {
    return switch (scopeType) {
      'campus' => 'campusId',
      'stage' => 'stageId',
      'class' => 'classId',
      'subject' => 'subjectId',
      'academic_year' => 'academicYearId',
      'student' => 'studentId',
      _ => scopeType, // Fallback: use the scope type as-is
    };
  }
}

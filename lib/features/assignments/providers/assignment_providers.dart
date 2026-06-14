import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../data/assignment_repository.dart';
import '../domain/assignment_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provides a singleton [AssignmentRepository] instance.
///
/// Uses the default [FirebaseFirestore.instance] in production.
/// Inject a mock FirebaseFirestore in tests for testability.
final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(FirebaseFirestore.instance);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Stream Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Streams the list of assignments for a given class.
///
/// Automatically re-fetches when assignments for the class change in Firestore.
/// Returns an empty list when no assignments exist for the class.
final assignmentListForClassProvider =
    StreamProvider.family<List<AssignmentModel>, String>((ref, classId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.assignmentsCollection)
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AssignmentModel.fromFirestore(doc.data(), doc.id))
          .toList());
});

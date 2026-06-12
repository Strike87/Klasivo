import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../data/submission_repository.dart';
import '../domain/submission_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provides a singleton [SubmissionRepository] instance.
///
/// Uses the default [FirebaseFirestore.instance] in production.
/// Inject a mock FirebaseFirestore in tests for testability.
final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository(FirebaseFirestore.instance);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Stream Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Streams the list of submissions for a given exam in real-time.
///
/// Automatically re-fetches when the exam's submissions change in Firestore.
/// Returns an empty list when no submissions exist for the exam.
final submissionListForExamProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, examId) {
  return ref.read(submissionRepositoryProvider).streamSubmissionsForExam(examId);
});

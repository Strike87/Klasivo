import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/violation_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final violationServiceProvider =
    Provider<ViolationService>((ref) => ViolationService());

// ─── Violations by Exam Stream ───────────────────────────────────────────────

final violationsByExamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, examId) {
  return ref.read(violationServiceProvider).getViolationsByExamStream(examId);
});

// ─── Violations by Student Stream ────────────────────────────────────────────

final violationsByStudentProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, studentId) {
  return ref
      .read(violationServiceProvider)
      .getViolationsByStudentStream(studentId);
});

// ─── Violations by Exam List ─────────────────────────────────────────────────

final violationsByExamListProvider =
    Provider.family<List<ViolationData>, String>((ref, examId) {
  final asyncViolations = ref.watch(violationsByExamProvider(examId));
  return asyncViolations.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ViolationData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Violations by Student List ──────────────────────────────────────────────

final violationsByStudentListProvider =
    Provider.family<List<ViolationData>, String>((ref, studentId) {
  final asyncViolations = ref.watch(violationsByStudentProvider(studentId));
  return asyncViolations.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ViolationData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Violation Summary for Exam ──────────────────────────────────────────────

final violationSummaryProvider =
    FutureProvider.family<ViolationSummary, String>((ref, examId) async {
  final service = ref.read(violationServiceProvider);
  return service.getViolationSummary(examId);
});

// ─── Teacher All Violations ──────────────────────────────────────────────────

final teacherAllViolationsProvider =
    FutureProvider<List<ViolationData>>((ref) async {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) return [];

  final service = ref.read(violationServiceProvider);
  return service.getTeacherViolations(teacherId);
});

// ─── Exam Violations (one-time fetch) ────────────────────────────────────────

final examViolationsProvider =
    FutureProvider.family<List<ViolationData>, String>((ref, examId) async {
  final service = ref.read(violationServiceProvider);
  return service.getExamViolations(examId);
});

// ════════════════════════════════════════════════════════════════════════════
// DATA MODELS (re-exported from violation_service.dart - ViolationData, ViolationSummary)
// ════════════════════════════════════════════════════════════════════════════
// ViolationData and ViolationSummary are defined in violation_service.dart

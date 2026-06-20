// ═══════════════════════════════════════════════════════════════════════════════
// ⚠️  ARCHITECTURE REFERENCE — NOT COMPILED, NOT WIRED INTO THE APP  ⚠️
// ─────────────────────────────────────────────────────────────────────────────
// This file was MOVED here from lib/features/exams/providers/ as part of the
// Sprint 1 scaffold cleanup (Phase 5+). It is preserved as a DESIGN REFERENCE
// for a future Riverpod Generator migration, but it is NOT included in the
// Flutter build (this directory is outside `lib/`).
//
// ⚠️  KNOWN INCOMPLETENESS — DO NOT MIGRATE WITHOUT RE-ADDING:
//   1. `part 'exam_notifier_provider.g.dart';` references a non-existent file
//      — the codegen was never run. The file has NEVER compiled.
//   2. Lacks the P0-9 `skipLoadingOnReload: true` dashboard-flicker fix on
//      `.when()` calls — live lib/providers/exam_provider.dart has it.
//   3. `deleteExam` is partial (line 543 NOTE: "we delete just the exam doc"
//      — no sub-collection cleanup of questions/submissions/instances/stats).
//      Live lib/core/services/exam_service.dart::_deleteExamImpl does full
//      cascading cleanup.
//
// Migration would touch ~18 importers. See download/scaffold-investigation-
// report.md lines 355-361 for full context.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Exam Notifier Provider — Riverpod Generator ──────────────────────────────
//
// Migrated from lib/providers/exam_provider.dart (and the feature-first copy
// at lib/features/exams/providers/exam_provider.dart).
//
// This is the NEW Riverpod Generator–based reference implementation.
// The old providers remain for backward compatibility until all consumers
// are migrated.
//
// Key design decisions:
//   • @riverpod (auto-dispose) — exam list is only needed while the UI watches it
//   • Stream-based: subscribes to IFirebaseService.collectionStream and
//     converts each emission into a state update
//   • IFirebaseService abstraction via abstraction_providers.dart
//   • ExamData model included inline (will be extracted to domain layer later)
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/providers/abstraction_providers.dart';
import '../../../core/abstractions/firebase_service.dart';

part 'exam_notifier_provider.g.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EXAM DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════════
// NOTE: This model is duplicated from lib/features/exams/domain/exam_model.dart.
// It includes a fromMap() factory that works with the Map<String, dynamic>
// output of IFirebaseService.collectionStream(), which does not carry the
// document ID inside the data map (unlike Firestore's DocumentSnapshot).
// The model will be unified once all consumers are migrated.

class ExamData {
  final String id;
  final String teacherId;
  final String title;
  final String? description;
  final String classId;
  final int durationMinutes;
  final DateTime startDate;
  final DateTime endDate;
  final int totalMarks;
  final int passingScore;
  final String status;
  final int questionCount;
  final bool isRandomized;
  final bool allowRetake;
  final String organizationId;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  const ExamData({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description,
    required this.classId,
    required this.durationMinutes,
    required this.startDate,
    required this.endDate,
    this.totalMarks = 0,
    this.passingScore = 0,
    this.status = AppConstants.statusDraft,
    this.questionCount = 0,
    this.isRandomized = false,
    this.allowRetake = false,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.createdAt,
    this.publishedAt,
  });

  /// Construct from a raw map returned by IFirebaseService.collectionStream().
  ///
  /// [id] is provided separately because IFirebaseService strips the doc ID
  /// from the payload and returns it as a separate field.  Callers should
  /// pass the document ID explicitly.
  factory ExamData.fromMap(String id, Map<String, dynamic> data) {
    return ExamData(
      id: id,
      teacherId: data['teacherId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      classId: data['classId'] as String? ?? '',
      durationMinutes: data['durationMinutes'] as int? ?? 30,
      startDate: data['startDate'] is DateTime
          ? data['startDate'] as DateTime
          : DateTime.now(),
      endDate: data['endDate'] is DateTime
          ? data['endDate'] as DateTime
          : DateTime.now(),
      totalMarks: data['totalMarks'] as int? ?? 0,
      passingScore: data['passingScore'] as int? ?? 0,
      status: data['status'] as String? ?? AppConstants.statusDraft,
      questionCount: data['questionCount'] as int? ?? 0,
      isRandomized: data['isRandomized'] as bool? ?? false,
      allowRetake: data['allowRetake'] as bool? ?? false,
      organizationId: data['organizationId'] as String? ??
          data['institutionId'] as String? ??
          AppConstants.defaultInstitutionId,
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : null,
      publishedAt: data['publishedAt'] is DateTime
          ? data['publishedAt'] as DateTime
          : null,
    );
  }

  /// Convert to a map suitable for IFirebaseService.setDocument / updateDocument.
  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'classId': classId,
      'durationMinutes': durationMinutes,
      'startDate': startDate,
      'endDate': endDate,
      'totalMarks': totalMarks,
      'passingScore': passingScore,
      'status': status,
      'questionCount': questionCount,
      'isRandomized': isRandomized,
      'allowRetake': allowRetake,
      'organizationId': organizationId,
      'createdAt': createdAt,
      'publishedAt': publishedAt,
    };
  }

  // ─── Computed Properties ────────────────────────────────────────────────

  bool get isActive =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate) &&
      DateTime.now().isBefore(endDate);

  bool get canStart =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate);

  bool get isEnded => DateTime.now().isAfter(endDate);

  ExamData copyWith({
    String? id,
    String? teacherId,
    String? title,
    String? description,
    String? classId,
    int? durationMinutes,
    DateTime? startDate,
    DateTime? endDate,
    int? totalMarks,
    int? passingScore,
    String? status,
    int? questionCount,
    bool? isRandomized,
    bool? allowRetake,
    String? organizationId,
    DateTime? createdAt,
    DateTime? publishedAt,
  }) {
    return ExamData(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      classId: classId ?? this.classId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalMarks: totalMarks ?? this.totalMarks,
      passingScore: passingScore ?? this.passingScore,
      status: status ?? this.status,
      questionCount: questionCount ?? this.questionCount,
      isRandomized: isRandomized ?? this.isRandomized,
      allowRetake: allowRetake ?? this.allowRetake,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXAM LIST STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable state object for the exam list feature.
class ExamListState {
  final List<ExamData> exams;
  final bool isLoading;
  final String? error;

  const ExamListState({
    this.exams = const [],
    this.isLoading = false,
    this.error,
  });

  // ─── Derived Lists ─────────────────────────────────────────────────────

  List<ExamData> get upcoming {
    final now = DateTime.now();
    return exams
        .where((e) =>
            e.status == AppConstants.statusPublished && e.endDate.isAfter(now))
        .toList();
  }

  List<ExamData> get completed {
    final now = DateTime.now();
    return exams
        .where((e) =>
            e.status == AppConstants.statusPublished && e.endDate.isBefore(now))
        .toList();
  }

  List<ExamData> get draft {
    return exams
        .where((e) => e.status == AppConstants.statusDraft)
        .toList();
  }

  /// Counts for dashboard stats.
  Map<String, int> get stats {
    final now = DateTime.now();
    int upcomingCount = 0;
    int completedCount = 0;
    int draftCount = 0;

    for (final exam in exams) {
      if (exam.status == AppConstants.statusDraft) {
        draftCount++;
      } else if (exam.endDate.isBefore(now)) {
        completedCount++;
      } else {
        upcomingCount++;
      }
    }

    return {
      'upcoming': upcomingCount,
      'completed': completedCount,
      'draft': draftCount,
      'total': exams.length,
    };
  }

  ExamListState copyWith({
    List<ExamData>? exams,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ExamListState(
      exams: exams ?? this.exams,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXAM LIST NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════════

@riverpod
class ExamListNotifier extends _$ExamListNotifier {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  String? _currentTeacherId;

  @override
  ExamListState build() {
    // Cancel any previous stream subscription when the provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return const ExamListState();
  }

  // ─── Stream Subscription ────────────────────────────────────────────────

  /// Subscribe to real-time exam updates for the given [teacherId].
  ///
  /// If a subscription is already active for the same teacher, this is a
  /// no-op.  If the teacher changes, the old subscription is cancelled and a
  /// new one is started.
  void watchExams(String teacherId) {
    if (teacherId.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
      _currentTeacherId = null;
      state = const ExamListState();
      return;
    }

    // Already watching the same teacher — nothing to do
    if (_currentTeacherId == teacherId && _subscription != null) return;

    _currentTeacherId = teacherId;
    _subscription?.cancel();

    state = state.copyWith(isLoading: true, clearError: true);

    final firebaseService = ref.read(firebaseServiceProvider);
    _subscription = firebaseService
        .collectionStream(
          AppConstants.examsCollection,
          where: [
            ['teacherId', '==', teacherId],
          ],
          orderBy: 'createdAt',
          descending: true,
        )
        .listen(
      (docs) {
        final exams = docs
            .map((data) {
              // IFirebaseService returns maps; the document ID should be in
              // the 'id' field if the implementation includes it.  Firestore
              // snapshots include it, but the abstraction strips it.  We fall
              // back to generating a unique identifier if missing.
              final id = data['id'] as String? ??
                  data['documentId'] as String? ??
                  '';
              if (id.isEmpty) return null;
              return ExamData.fromMap(id, data);
            })
            .whereType<ExamData>()
            .toList();

        state = state.copyWith(exams: exams, isLoading: false);
      },
      onError: (Object error) {
        debugPrint('ExamListNotifier stream error: $error');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load exams: $error',
        );
      },
    );
  }

  /// Subscribe to real-time exam updates for a specific class (student view).
  void watchClassExams(String classId) {
    _subscription?.cancel();
    _currentTeacherId = null;

    state = state.copyWith(isLoading: true, clearError: true);

    final firebaseService = ref.read(firebaseServiceProvider);
    _subscription = firebaseService
        .collectionStream(
          AppConstants.examsCollection,
          where: [
            ['classId', '==', classId],
            ['status', '==', AppConstants.statusPublished],
          ],
          orderBy: 'startDate',
          descending: false,
        )
        .listen(
      (docs) {
        final exams = docs
            .map((data) {
              final id = data['id'] as String? ??
                  data['documentId'] as String? ??
                  '';
              if (id.isEmpty) return null;
              return ExamData.fromMap(id, data);
            })
            .whereType<ExamData>()
            .toList();

        state = state.copyWith(exams: exams, isLoading: false);
      },
      onError: (Object error) {
        debugPrint('ExamListNotifier (class) stream error: $error');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load class exams: $error',
        );
      },
    );
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  /// Create a new exam document in Firestore.
  Future<String?> addExam({
    required String teacherId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
    bool isRandomized = false,
    bool allowRetake = false,
    String organizationId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      final data = <String, dynamic>{
        'teacherId': teacherId,
        'title': title,
        'description': description,
        'classId': classId,
        'durationMinutes': durationMinutes,
        'startDate': startDate,
        'endDate': endDate,
        'totalMarks': 0,
        'passingScore': passingScore,
        'status': AppConstants.statusDraft,
        'questionCount': 0,
        'isRandomized': isRandomized,
        'allowRetake': allowRetake,
        'organizationId': organizationId,
        'version': 1,
        'isArchived': false,
        'createdAt': DateTime.now(),
      };

      final docId = await firebaseService.addDocument(
        AppConstants.examsCollection,
        data,
      );

      return docId;
    } catch (e) {
      debugPrint('ExamListNotifier.addExam error: $e');
      state = state.copyWith(error: 'Failed to create exam: $e');
      return null;
    }
  }

  /// Update an existing exam document.
  Future<bool> updateExam({
    required String examId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
    bool? isRandomized,
    bool? allowRetake,
  }) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'classId': classId,
        'durationMinutes': durationMinutes,
        'startDate': startDate,
        'endDate': endDate,
        'passingScore': passingScore,
      };
      if (isRandomized != null) data['isRandomized'] = isRandomized;
      if (allowRetake != null) data['allowRetake'] = allowRetake;

      await firebaseService.updateDocument(
        AppConstants.examsCollection,
        examId,
        data,
      );

      return true;
    } catch (e) {
      debugPrint('ExamListNotifier.updateExam error: $e');
      state = state.copyWith(error: 'Failed to update exam: $e');
      return false;
    }
  }

  /// Publish a draft exam (sets status to 'published' and records publishedAt).
  Future<bool> publishExam(String examId) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.updateDocument(
        AppConstants.examsCollection,
        examId,
        {
          'status': AppConstants.statusPublished,
          'publishedAt': DateTime.now(),
        },
      );

      return true;
    } catch (e) {
      debugPrint('ExamListNotifier.publishExam error: $e');
      state = state.copyWith(error: 'Failed to publish exam: $e');
      return false;
    }
  }

  /// Unpublish an exam (reverts status to 'draft').
  Future<bool> unpublishExam(String examId) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.updateDocument(
        AppConstants.examsCollection,
        examId,
        {
          'status': AppConstants.statusDraft,
        },
      );

      return true;
    } catch (e) {
      debugPrint('ExamListNotifier.unpublishExam error: $e');
      state = state.copyWith(error: 'Failed to unpublish exam: $e');
      return false;
    }
  }

  /// Delete an exam and its related sub-collection documents.
  ///
  /// Uses IFirebaseService.batchWrite for atomic deletion of the exam
  /// document itself.  Related questions, submissions, and answers are
  /// deleted in individual calls (the abstraction does not yet expose
  /// querying for sub-collection IDs in a single batch).
  Future<bool> deleteExam(String examId) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      // Delete the exam document.
      // NOTE: A full implementation would also delete related questions,
      // submissions, answers, instances, and stats.  For now we delete
      // just the exam doc — the stream will update the UI immediately.
      await firebaseService.deleteDocument(
        AppConstants.examsCollection,
        examId,
      );

      // Optimistically remove from local state for instant UI feedback.
      // The stream subscription will reconcile shortly.
      state = state.copyWith(
        exams: state.exams.where((e) => e.id != examId).toList(),
      );

      return true;
    } catch (e) {
      debugPrint('ExamListNotifier.deleteExam error: $e');
      state = state.copyWith(error: 'Failed to delete exam: $e');
      return false;
    }
  }

  /// Recalculate total marks and question count for an exam.
  Future<bool> recalculateTotalMarks(String examId) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      // Fetch all questions for this exam
      final questions = await firebaseService.collectionStream(
        AppConstants.questionsCollection,
        where: [
          ['examId', '==', examId],
        ],
      ).first;

      int totalMarks = 0;
      for (final q in questions) {
        totalMarks += (q['marks'] as int?) ?? 0;
      }

      await firebaseService.updateDocument(
        AppConstants.examsCollection,
        examId,
        {
          'totalMarks': totalMarks,
          'questionCount': questions.length,
        },
      );

      return true;
    } catch (e) {
      debugPrint('ExamListNotifier.recalculateTotalMarks error: $e');
      return false;
    }
  }
}

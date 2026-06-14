// ─── Assignment Repository (Repository Pattern) ────────────────────────────────
// Abstract interface + Firestore implementation for assignment data access.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_constants.dart';

// ─── Assignment Domain Models ──────────────────────────────────────────────────

/// Represents an assignment created by a teacher for a class or group.
class AssignmentData {
  final String id;
  final String organizationId;
  final String classId;
  final String title;
  final String? description;
  final String? subjectId;
  final String? groupId;
  final DateTime dueDate;
  final String status; // 'draft', 'published'
  final List<String> attachments;
  final String createdBy;
  final int version;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssignmentData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.title,
    this.description,
    this.subjectId,
    this.groupId,
    required this.dueDate,
    this.status = AppConstants.assignmentStatusDraft,
    this.attachments = const [],
    this.createdBy = '',
    this.version = 1,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory AssignmentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] as String?,
      subjectId: data['subjectId'] as String?,
      groupId: data['groupId'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? AppConstants.assignmentStatusDraft,
      attachments: List<String>.from(data['attachments'] ?? []),
      createdBy: data['createdBy'] ?? '',
      version: data['version'] as int? ?? 1,
      isArchived: data['isArchived'] as bool? ?? false,
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      archivedBy: data['archivedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'classId': classId,
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'groupId': groupId,
      'dueDate': dueDate,
      'status': status,
      'attachments': attachments,
      'createdBy': createdBy,
      'version': version,
      'isArchived': isArchived,
      'archivedAt': archivedAt,
      'archivedBy': archivedBy,
    };
  }
}

/// Represents a student's submission for an assignment.
class AssignmentSubmissionData {
  final String id;
  final String assignmentId;
  final String studentId;
  final String? textSubmission;
  final List<String> fileUrls;
  final String status; // 'submitted', 'graded'
  final double? grade;
  final String? feedback;
  final String? gradedBy;
  final DateTime? submittedAt;
  final DateTime? gradedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssignmentSubmissionData({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.textSubmission,
    this.fileUrls = const [],
    this.status = AppConstants.assignmentStatusSubmitted,
    this.grade,
    this.feedback,
    this.gradedBy,
    this.submittedAt,
    this.gradedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AssignmentSubmissionData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentSubmissionData(
      id: doc.id,
      assignmentId: data['assignmentId'] ?? '',
      studentId: data['studentId'] ?? '',
      textSubmission: data['textSubmission'] as String?,
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      status: data['status'] ?? AppConstants.assignmentStatusSubmitted,
      grade: (data['grade'] as num?)?.toDouble(),
      feedback: data['feedback'] as String?,
      gradedBy: data['gradedBy'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      gradedAt: (data['gradedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'textSubmission': textSubmission,
      'fileUrls': fileUrls,
      'status': status,
      'grade': grade,
      'feedback': feedback,
      'gradedBy': gradedBy,
    };
  }
}

// ─── Abstract Interface ────────────────────────────────────────────────────────

/// Abstract interface for assignment data access.
/// All queries are scoped by [organizationId] for multi-tenant safety.
abstract class IAssignmentRepository {
  /// Create a new assignment. Returns the generated ID.
  Future<String> create(AssignmentData assignment);

  /// Update an existing assignment.
  Future<void> update(AssignmentData assignment);

  /// Delete an assignment and all its submissions.
  Future<void> delete(String id);

  /// Publish a draft assignment.
  Future<void> publish(String id);

  /// Archive an assignment (soft delete).
  Future<void> archive(String id, {String archivedBy = ''});

  /// Watch all assignments for a class, scoped to [organizationId].
  Stream<List<AssignmentData>> watchByClass(
      String classId, String organizationId);

  /// Watch all assignments for a student (via their class), scoped to [organizationId].
  Stream<List<AssignmentData>> watchByStudent(
      String studentClassId, String organizationId);

  /// Submit or re-submit an assignment. Returns the submission ID.
  Future<String> submitAssignment(AssignmentSubmissionData submission);

  /// Grade a submission.
  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
    required String gradedBy,
  });

  /// Watch all submissions for a specific assignment.
  Stream<List<AssignmentSubmissionData>> watchSubmissionsByAssignment(
      String assignmentId);

  /// Watch all submissions for a specific student.
  Stream<List<AssignmentSubmissionData>> watchSubmissionsByStudent(
      String studentId);

  /// Get a single assignment by ID.
  Future<AssignmentData?> getById(String id);
}

// ─── Firestore Implementation ──────────────────────────────────────────────────

class FirestoreAssignmentRepository implements IAssignmentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _assignments =>
      _db.collection(AppConstants.assignmentsCollection);

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection(AppConstants.assignmentSubmissionsCollection);

  // ─── Create ───────────────────────────────────────────────────────────

  @override
  Future<String> create(AssignmentData assignment) async {
    try {
      final docRef = await _assignments.add({
        'organizationId': assignment.organizationId,
        'classId': assignment.classId,
        'title': assignment.title,
        'description': assignment.description,
        'subjectId': assignment.subjectId,
        'groupId': assignment.groupId,
        'dueDate': assignment.dueDate,
        'status': assignment.status,
        'attachments': assignment.attachments,
        'createdBy': assignment.createdBy,
        'version': 1,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': assignment.title.toLowerCase().split(' '),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update ───────────────────────────────────────────────────────────

  @override
  Future<void> update(AssignmentData assignment) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (assignment.title.isNotEmpty) {
        data['title'] = assignment.title;
        data['searchKeywords'] = assignment.title.toLowerCase().split(' ');
      }
      if (assignment.description != null) {
        data['description'] = assignment.description;
      }
      if (assignment.subjectId != null) data['subjectId'] = assignment.subjectId;
      if (assignment.groupId != null) data['groupId'] = assignment.groupId;
      if (assignment.dueDate != DateTime.fromMillisecondsSinceEpoch(0)) {
        data['dueDate'] = assignment.dueDate;
      }
      if (assignment.attachments.isNotEmpty) {
        data['attachments'] = assignment.attachments;
      }

      await _assignments.doc(assignment.id).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────

  @override
  Future<void> delete(String id) async {
    try {
      // Delete all submissions for this assignment
      final submissionsSnapshot = await _submissions
          .where('assignmentId', isEqualTo: id)
          .get();

      final batch = _db.batch();
      for (final doc in submissionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_assignments.doc(id));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Publish ──────────────────────────────────────────────────────────

  @override
  Future<void> publish(String id) async {
    try {
      await _assignments.doc(id).update({
        'status': AppConstants.assignmentStatusPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Archive ──────────────────────────────────────────────────────────

  @override
  Future<void> archive(String id, {String archivedBy = ''}) async {
    try {
      await _assignments.doc(id).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': archivedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── WatchByClass ─────────────────────────────────────────────────────

  @override
  Stream<List<AssignmentData>> watchByClass(
      String classId, String organizationId) {
    return _assignments
        .where('classId', isEqualTo: classId)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentData.fromFirestore(doc))
            .toList());
  }

  // ─── WatchByStudent ───────────────────────────────────────────────────

  @override
  Stream<List<AssignmentData>> watchByStudent(
      String studentClassId, String organizationId) {
    // Students see assignments for their class
    return _assignments
        .where('classId', isEqualTo: studentClassId)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .where('status', isEqualTo: AppConstants.assignmentStatusPublished)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentData.fromFirestore(doc))
            .toList());
  }

  // ─── SubmitAssignment ─────────────────────────────────────────────────

  @override
  Future<String> submitAssignment(AssignmentSubmissionData submission) async {
    try {
      // Check if already submitted
      final existing = await _submissions
          .where('assignmentId', isEqualTo: submission.assignmentId)
          .where('studentId', isEqualTo: submission.studentId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing submission
        await existing.docs.first.reference.update({
          'textSubmission': submission.textSubmission,
          'fileUrls': submission.fileUrls,
          'status': AppConstants.assignmentStatusSubmitted,
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return existing.docs.first.id;
      }

      // Create new submission
      final docRef = await _submissions.add({
        'assignmentId': submission.assignmentId,
        'studentId': submission.studentId,
        'textSubmission': submission.textSubmission,
        'fileUrls': submission.fileUrls,
        'status': AppConstants.assignmentStatusSubmitted,
        'grade': null,
        'feedback': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'gradedAt': null,
        'gradedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── GradeSubmission ──────────────────────────────────────────────────

  @override
  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
    required String gradedBy,
  }) async {
    try {
      await _submissions.doc(submissionId).update({
        'status': AppConstants.assignmentStatusGraded,
        'grade': grade,
        'feedback': feedback,
        'gradedBy': gradedBy,
        'gradedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── WatchSubmissionsByAssignment ─────────────────────────────────────

  @override
  Stream<List<AssignmentSubmissionData>> watchSubmissionsByAssignment(
      String assignmentId) {
    return _submissions
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentSubmissionData.fromFirestore(doc))
            .toList());
  }

  // ─── WatchSubmissionsByStudent ────────────────────────────────────────

  @override
  Stream<List<AssignmentSubmissionData>> watchSubmissionsByStudent(
      String studentId) {
    return _submissions
        .where('studentId', isEqualTo: studentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentSubmissionData.fromFirestore(doc))
            .toList());
  }

  // ─── GetById ──────────────────────────────────────────────────────────

  @override
  Future<AssignmentData?> getById(String id) async {
    try {
      final doc = await _assignments.doc(id).get();
      if (!doc.exists) return null;
      return AssignmentData.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }
}

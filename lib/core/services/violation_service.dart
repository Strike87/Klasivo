import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class ViolationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // LOG VIOLATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Log a detailed violation with full context
  Future<String> logViolation({
    required String examId,
    required String submissionId,
    required String studentId,
    required String type,
    String? details,
    String? deviceInfo,
    String? sessionId,
    String? ipAddress,
    int? questionIndex,
    int? timeElapsedSeconds,
    String organizationId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef =
          await _firestore.collection(AppConstants.violationsCollection).add({
        'examId': examId,
        'submissionId': submissionId,
        'studentId': studentId,
        'type': type,
        'details': details,
        'deviceInfo': deviceInfo,
        'sessionId': sessionId,
        'ipAddress': ipAddress,
        'questionIndex': questionIndex,
        'timeElapsedSeconds': timeElapsedSeconds,
        'organizationId': organizationId,
        'severity': _calculateSeverity(type),
        'isReviewed': false,
        'reviewedBy': null,
        'reviewedAt': null,
        'reviewNotes': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update submission violation count
      await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .update({
        'violationCount': FieldValue.increment(1),
      });

      // Check if threshold exceeded - auto-flag
      final subDoc = await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .get();

      final violationCount = subDoc.data()?['violationCount'] as int? ?? 0;
      if (violationCount >= AppConstants.violationThreshold) {
        await _firestore
            .collection(AppConstants.submissionsCollection)
            .doc(submissionId)
            .update({
          'status': AppConstants.submissionStatusFlagged,
        });
      }

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate severity level based on violation type
  String _calculateSeverity(String type) {
    switch (type) {
      case AppConstants.violationScreenshotAttempt:
      case AppConstants.violationScreenRecording:
      case AppConstants.violationMultipleLogin:
        return 'high';
      case AppConstants.violationAppSwitched:
      case AppConstants.violationAppMinimized:
        return 'medium';
      case AppConstants.violationScreenOff:
        return 'low';
      default:
        return 'medium';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH VIOLATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<QuerySnapshot> getViolationsByExamStream(String examId) {
    return _firestore
        .collection(AppConstants.violationsCollection)
        .where('examId', isEqualTo: examId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getViolationsByStudentStream(String studentId) {
    return _firestore
        .collection(AppConstants.violationsCollection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getViolationsBySubmission(
      String submissionId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.violationsCollection)
          .where('submissionId', isEqualTo: submissionId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getViolationCount(String examId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.violationsCollection)
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIOLATION REVIEW
  // ══════════════════════════════════════════════════════════════════════════

  /// Mark a violation as reviewed
  Future<void> reviewViolation({
    required String violationId,
    required String reviewedBy,
    String? notes,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.violationsCollection)
          .doc(violationId)
          .update({
        'isReviewed': true,
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNotes': notes ?? '',
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Bulk review all violations for an exam
  Future<void> bulkReviewExamViolations({
    required String examId,
    required String reviewedBy,
    String? notes,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.violationsCollection)
          .where('examId', isEqualTo: examId)
          .where('isReviewed', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isReviewed': true,
          'reviewedBy': reviewedBy,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewNotes': notes ?? 'Bulk reviewed',
        });
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIOLATION ANALYTICS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get violation summary for an exam (aggregated by type and severity)
  Future<ViolationSummary> getViolationSummary(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.violationsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      final typeCounts = <String, int>{};
      final severityCounts = <String, int>{'low': 0, 'medium': 0, 'high': 0};
      final studentViolationCounts = <String, int>{};
      int reviewedCount = 0;
      int unreviewedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'unknown';
        final severity = data['severity'] as String? ?? 'medium';
        final studentId = data['studentId'] as String? ?? '';
        final isReviewed = data['isReviewed'] as bool? ?? false;

        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
        studentViolationCounts[studentId] =
            (studentViolationCounts[studentId] ?? 0) + 1;

        if (isReviewed) {
          reviewedCount++;
        } else {
          unreviewedCount++;
        }
      }

      final sortedStudents = studentViolationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topViolators = sortedStudents.take(10).toList();

      return ViolationSummary(
        totalViolations: snapshot.docs.length,
        typeCounts: typeCounts,
        severityCounts: severityCounts,
        studentViolationCounts: studentViolationCounts,
        topViolators: topViolators,
        reviewedCount: reviewedCount,
        unreviewedCount: unreviewedCount,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all violations for a teacher across exams
  Future<List<ViolationData>> getTeacherViolations(String teacherId) async {
    try {
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (examsSnapshot.docs.isEmpty) return [];

      final examIds = examsSnapshot.docs.map((d) => d.id).toList();

      final List<ViolationData> allViolations = [];
      for (var i = 0; i < examIds.length; i += 30) {
        final chunk = examIds.sublist(
            i, i + 30 > examIds.length ? examIds.length : i + 30);
        final snapshot = await _firestore
            .collection(AppConstants.violationsCollection)
            .where('examId', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .get();

        allViolations.addAll(
            snapshot.docs.map((doc) => ViolationData.fromFirestore(doc)));
      }

      return allViolations;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ViolationData>> getExamViolations(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.violationsCollection)
          .where('examId', isEqualTo: examId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ViolationData.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

class ViolationData {
  final String id;
  final String examId;
  final String submissionId;
  final String studentId;
  final String type;
  final String? details;
  final String? deviceInfo;
  final String? sessionId;
  final String? ipAddress;
  final int? questionIndex;
  final int? timeElapsedSeconds;
  final String organizationId;
  final String severity;
  final bool isReviewed;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime? timestamp;

  ViolationData({
    required this.id,
    required this.examId,
    required this.submissionId,
    required this.studentId,
    required this.type,
    this.details,
    this.deviceInfo,
    this.sessionId,
    this.ipAddress,
    this.questionIndex,
    this.timeElapsedSeconds,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.severity = 'medium',
    this.isReviewed = false,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.timestamp,
  });

  factory ViolationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ViolationData(
      id: doc.id,
      examId: data['examId'] ?? '',
      submissionId: data['submissionId'] ?? '',
      studentId: data['studentId'] ?? '',
      type: data['type'] ?? '',
      details: data['details'],
      deviceInfo: data['deviceInfo'],
      sessionId: data['sessionId'],
      ipAddress: data['ipAddress'],
      questionIndex: data['questionIndex'] as int?,
      timeElapsedSeconds: data['timeElapsedSeconds'] as int?,
      organizationId:
          data['organizationId'] ?? data['institutionId'] ?? AppConstants.defaultInstitutionId,
      severity: data['severity'] ?? 'medium',
      isReviewed: data['isReviewed'] as bool? ?? false,
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNotes: data['reviewNotes'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  String get typeLabel {
    switch (type) {
      case AppConstants.violationAppMinimized:
        return 'App Minimized';
      case AppConstants.violationAppSwitched:
        return 'App Switched';
      case AppConstants.violationScreenOff:
        return 'Screen Off';
      case AppConstants.violationScreenshotAttempt:
        return 'Screenshot Attempt';
      case AppConstants.violationScreenRecording:
        return 'Screen Recording';
      case AppConstants.violationMultipleLogin:
        return 'Multiple Login';
      default:
        return type;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case AppConstants.violationAppMinimized:
        return Icons.minimize;
      case AppConstants.violationAppSwitched:
        return Icons.swap_horiz;
      case AppConstants.violationScreenOff:
        return Icons.screen_lock_portrait;
      case AppConstants.violationScreenshotAttempt:
        return Icons.screenshot;
      case AppConstants.violationScreenRecording:
        return Icons.videocam;
      case AppConstants.violationMultipleLogin:
        return Icons.login;
      default:
        return Icons.warning;
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'submissionId': submissionId,
      'studentId': studentId,
      'type': type,
      'details': details,
      'severity': severity,
      'isReviewed': isReviewed,
      'organizationId': organizationId,
    };
  }
}

class ViolationSummary {
  final int totalViolations;
  final Map<String, int> typeCounts;
  final Map<String, int> severityCounts;
  final Map<String, int> studentViolationCounts;
  final List<MapEntry<String, int>> topViolators;
  final int reviewedCount;
  final int unreviewedCount;

  ViolationSummary({
    required this.totalViolations,
    required this.typeCounts,
    required this.severityCounts,
    required this.studentViolationCounts,
    required this.topViolators,
    required this.reviewedCount,
    required this.unreviewedCount,
  });
}

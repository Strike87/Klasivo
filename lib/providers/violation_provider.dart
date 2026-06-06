import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/violation_service.dart';

final violationServiceProvider = Provider<ViolationService>((ref) => ViolationService());

final violationsByExamProvider = StreamProvider.family<QuerySnapshot, String>((ref, examId) {
  return ref.read(violationServiceProvider).getViolationsByExamStream(examId);
});

final violationsByStudentProvider = StreamProvider.family<QuerySnapshot, String>((ref, studentId) {
  return ref.read(violationServiceProvider).getViolationsByStudentStream(studentId);
});

final violationsByExamListProvider = Provider.family<List<ViolationData>, String>((ref, examId) {
  final asyncViolations = ref.watch(violationsByExamProvider(examId));
  return asyncViolations.when(
    data: (snapshot) => snapshot.docs.map((doc) => ViolationData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class ViolationData {
  final String id;
  final String examId;
  final String submissionId;
  final String studentId;
  final String type;
  final String? details;
  final String institutionId;
  final DateTime? timestamp;

  ViolationData({
    required this.id,
    required this.examId,
    required this.submissionId,
    required this.studentId,
    required this.type,
    this.details,
    this.institutionId = AppConstants.defaultInstitutionId,
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
      institutionId: data['institutionId'] ?? AppConstants.defaultInstitutionId,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'submissionId': submissionId,
      'studentId': studentId,
      'type': type,
      'details': details,
      'institutionId': institutionId,
    };
  }
}

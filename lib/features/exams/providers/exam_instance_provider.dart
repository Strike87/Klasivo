import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/exam_instance_service.dart';
import '../core/services/qr_enrollment_service.dart';

// ==================== EXAM INSTANCE PROVIDERS ====================

final examInstanceServiceProvider = Provider<ExamInstanceService>((ref) {
  return ExamInstanceService();
});

/// Stream exam instances for a specific exam
final examInstancesStreamProvider = StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, examId) {
  return ref.read(examInstanceServiceProvider).getExamInstancesStream(examId);
});

/// Stream exam instances for a specific student
final studentInstancesStreamProvider = StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, studentId) {
  return ref.read(examInstanceServiceProvider).getStudentInstancesStream(studentId);
});

/// Exam instance data model
class ExamInstanceData {
  final String id;
  final String? organizationId;
  final String examId;
  final String studentId;
  final String? classId;
  final String? teacherId;
  final List<String> randomizedQuestions;
  final bool isRandomized;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? submissionId;

  ExamInstanceData({
    required this.id,
    this.organizationId,
    required this.examId,
    required this.studentId,
    this.classId,
    this.teacherId,
    this.randomizedQuestions = const [],
    this.isRandomized = false,
    this.startedAt,
    this.completedAt,
    this.submissionId,
  });

  factory ExamInstanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamInstanceData(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? data['institutionId'] as String?,
      examId: data['examId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String?,
      teacherId: data['teacherId'] as String?,
      randomizedQuestions: (data['randomizedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isRandomized: data['isRandomized'] as bool? ?? false,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      submissionId: data['submissionId'] as String?,
    );
  }

  bool get isCompleted => completedAt != null;
  bool get hasSubmission => submissionId != null;
}

// ==================== QR ENROLLMENT PROVIDERS ====================

final qrEnrollmentServiceProvider = Provider<QREnrollmentService>((ref) {
  return QREnrollmentService();
});

/// Holds scanned QR data
final scannedQRDataProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Class info retrieved from QR data (for preview before enrollment)
final qrClassInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final qrData = ref.watch(scannedQRDataProvider);
  if (qrData == null) return null;

  return ref.read(qrEnrollmentServiceProvider).getClassInfoFromQR(qrData);
});

/// Whether QR data is valid
final isQRValidProvider = FutureProvider<bool>((ref) async {
  final qrData = ref.watch(scannedQRDataProvider);
  if (qrData == null) return false;

  return ref.read(qrEnrollmentServiceProvider).validateQRData(qrData);
});

/// Enrollment state
final isEnrollingProvider = StateProvider<bool>((ref) => false);

/// Enrollment error message
final enrollmentErrorProvider = StateProvider<String?>((ref) => null);

/// Enrollment success flag
final enrollmentSuccessProvider = StateProvider<bool>((ref) => false);

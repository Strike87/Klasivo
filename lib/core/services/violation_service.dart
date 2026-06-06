import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class ViolationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> logViolation({
    required String examId,
    required String submissionId,
    required String studentId,
    required String type,
    String? details,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.violationsCollection).add({
        'examId': examId,
        'submissionId': submissionId,
        'studentId': studentId,
        'type': type,
        'details': details,
        'institutionId': institutionId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

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

  Future<List<Map<String, dynamic>>> getViolationsBySubmission(String submissionId) async {
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
}

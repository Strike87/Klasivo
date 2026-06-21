import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/app_constants.dart';

class ExamTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createTemplate({
    required String organizationId,
    required String teacherId,
    required String name,
    String? description,
    required int durationMinutes,
    required int questionCount,
    required double totalMarks,
    String? subjectId,
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
  }) async {
    try {
      final docRef =
          await _firestore.collection(AppConstants.examTemplatesCollection).add({
        'organizationId': organizationId,
        'teacherId': teacherId,
        'name': name,
        'description': description,
        'durationMinutes': durationMinutes,
        'questionCount': questionCount,
        'totalMarks': totalMarks,
        'subjectId': subjectId,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    int? durationMinutes,
    int? questionCount,
    double? totalMarks,
    String? subjectId,
    bool? shuffleQuestions,
    bool? shuffleOptions,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (durationMinutes != null) data['durationMinutes'] = durationMinutes;
      if (questionCount != null) data['questionCount'] = questionCount;
      if (totalMarks != null) data['totalMarks'] = totalMarks;
      if (subjectId != null) data['subjectId'] = subjectId;
      if (shuffleQuestions != null) data['shuffleQuestions'] = shuffleQuestions;
      if (shuffleOptions != null) data['shuffleOptions'] = shuffleOptions;

      await _firestore
          .collection(AppConstants.examTemplatesCollection)
          .doc(templateId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection(AppConstants.examTemplatesCollection)
          .doc(templateId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getTemplatesByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.examTemplatesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTemplatesByOrganizationStream(
      String organizationId) {
    return _firestore
        .collection(AppConstants.examTemplatesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createExamFromTemplate({
    required String templateId,
    required String classId,
    required String organizationId,
    required String createdBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final templateDoc = await _firestore
          .collection(AppConstants.examTemplatesCollection)
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        throw Exception('Template not found');
      }

      final templateData = templateDoc.data()!;

      final docRef =
          await _firestore.collection(AppConstants.examsCollection).add({
        'organizationId': organizationId,
        'teacherId': createdBy,
        'title': templateData['name'] ?? '',
        'description': templateData['description'],
        'classId': classId,
        'durationMinutes': templateData['durationMinutes'] ?? 0,
        'totalMarks': templateData['totalMarks'] ?? 0,
        'questionCount': templateData['questionCount'] ?? 0,
        'subjectId': templateData['subjectId'],
        'isRandomized': templateData['shuffleQuestions'] ?? false,
        'shuffleOptions': templateData['shuffleOptions'] ?? false,
        'status': AppConstants.statusDraft,
        'createdBy': createdBy,
        'templateId': templateId,
        'startDate': startDate,
        'endDate': endDate,
        'passingScore': 0,
        'allowRetake': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }
}

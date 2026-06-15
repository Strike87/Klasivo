import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'sentry_service.dart';

class QrService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate QR data for class enrollment
  static String generateClassQrData({
    required String classId,
    required String teacherId,
  }) {
    final data = {
      'type': 'class_enrollment',
      'classId': classId,
      'teacherId': teacherId,
    };
    return jsonEncode(data);
  }

  /// Parse QR data
  static Map<String, dynamic>? parseQrData(String data) {
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      if (decoded['type'] == 'class_enrollment' &&
          decoded['classId'] != null &&
          decoded['teacherId'] != null) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Enroll a student in a class by scanning QR code
  Future<bool> enrollStudentByQr({
    required String studentId,
    required String classId,
    required String teacherId,
  }) async {
    try {
      // Verify class exists
      final classDoc = await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Class not found');
      }

      final classData = classDoc.data()!;

      // Verify teacher owns this class (check both 'createdBy' and 'teacherId' for compatibility)
      final classOwner = classData['createdBy'] ?? classData['teacherId'];
      if (classOwner != teacherId) {
        throw Exception('Invalid class QR code');
      }

      // Update student's classId (students are stored in usersCollection)
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.usersCollection,
        docId: studentId,
        data: {
          'classId': classId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'qr_enrollment_simple',
        step: 'updateStudentClass',
      );

      KlasivoSentry.breadcrumb.registration('qr_simple_enrollment_success', data: {
        'studentId': studentId,
        'classId': classId,
      });

      return true;
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'QR student enrollment failed',
        tags: {'flow': 'qr_enrollment_simple', 'studentId': studentId, 'classId': classId},
      );
      rethrow;
    }
  }
}

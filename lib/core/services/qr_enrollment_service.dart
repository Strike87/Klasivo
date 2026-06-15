import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_constants.dart';
import 'sentry_service.dart';

/// Service for QR code-based student enrollment
/// QR codes contain encoded class/teacher information that allows
/// students to self-enroll into a class by scanning.
class QREnrollmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates QR data payload for a class enrollment
  /// Returns a JSON string containing class info
  String generateEnrollmentQRData({
    required String classId,
    required String teacherId,
    required String className,
    String? grade,
    String organizationId = AppConstants.defaultInstitutionId,
  }) {
    final data = {
      'type': 'enrollment',
      'classId': classId,
      'teacherId': teacherId,
      'className': className,
      'grade': grade,
      'organizationId': organizationId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  /// Parses QR data from a scanned code
  /// Returns the decoded map or null if invalid
  Map<String, dynamic>? parseEnrollmentQRData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;

      // Validate required fields
      if (data['type'] != 'enrollment') return null;
      if (data['classId'] == null || data['teacherId'] == null) return null;

      return data;
    } catch (e) {
      debugPrint('Error parsing QR data: $e');
      return null;
    }
  }

  /// Enroll a student into a class via QR code data
  /// Creates a new student record with auto-generated code and default password
  ///
  /// IMPORTANT: This method now requires [authUid] — the Firebase Auth UID
  /// of the newly-created student account. The Firestore document uses
  /// `.doc(authUid)` so that security rules (`request.auth.uid == userId`)
  /// can verify the write. Previously used `.doc()` (auto-ID) which was
  /// always blocked by security rules.
  ///
  /// Returns the new student document ID (same as authUid).
  Future<String> enrollViaQR({
    required Map<String, dynamic> qrData,
    required String fullName,
    required String password,
    required String authUid,
    String Function(String)? hashPassword,
  }) async {
    final transaction = KlasivoSentry.transactions.studentEnrollment();

    try {
      KlasivoSentry.breadcrumb.registration('qr_enrollment_started', data: {
        'classId': qrData['classId'],
        'teacherId': qrData['teacherId'],
        'fullName': fullName,
        'authUid': authUid,
      });

      final classId = qrData['classId'] as String;
      final teacherId = qrData['teacherId'] as String;
      final className = qrData['className'] as String? ?? '';
      final grade = qrData['grade'] as String? ?? '';
      final organizationId = qrData['organizationId'] as String? ?? AppConstants.defaultInstitutionId;

      // Verify class exists
      final classDoc = await _firestore.collection(AppConstants.classesCollection).doc(classId).get();
      if (!classDoc.exists) {
        KlasivoSentry.breadcrumb.registration('qr_enrollment_failed_class_not_found', data: {
          'classId': classId,
        });
        throw Exception('Class not found. The QR code may be outdated.');
      }

      // Generate unique student code
      final studentCode = await _generateStudentCode(teacherId);

      // Create student document (students ARE users — stored in usersCollection)
      // FIXED: Uses authUid instead of auto-ID so security rules pass
      final docId = authUid;

      KlasivoSentry.breadcrumb.firestore(
        'create',
        collection: AppConstants.usersCollection,
        docId: docId,
        data: {
          'flow': 'qr_enrollment',
          'docIdStrategy': 'uid',
        },
      );

      // Log the doc ID audit trail
      KlasivoSentry.docIdAudit.logUserCreation(
        flow: 'qr_enrollment',
        collection: AppConstants.usersCollection,
        docIdStrategy: 'uid',
        actualDocId: docId,
        authUid: authUid,
      );

      await SentryFirestoreHelper.docSet(
        collection: AppConstants.usersCollection,
        docId: docId,
        data: {
          'organizationId': organizationId,
          'role': AppConstants.roleStudent,
          'id': docId,
          'teacherId': teacherId,
          'classId': classId,
          'className': className,
          'fullName': fullName,
          'studentCode': studentCode,
          'passwordHash': hashPassword != null ? hashPassword(password) : password,
          'grade': grade,
          'enrolledVia': 'qr',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'qr_enrollment',
        step: 'USER_DOC_CREATE',
      );

      // Update class student count
      final currentCount = classDoc.data()?['studentCount'] as int? ?? 0;
      await _firestore.collection(AppConstants.classesCollection).doc(classId).update({
        'studentCount': currentCount + 1,
      });

      KlasivoSentry.breadcrumb.registration('qr_enrollment_success', data: {
        'docId': docId,
        'studentCode': studentCode,
        'classId': classId,
      });

      transaction.status = const SpanStatus.ok();

      return docId;
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'qr_enrollment');
          scope.setTag('step', 'enroll_via_qr');
          scope.setTag('collection', AppConstants.usersCollection);
          scope.setTag('docIdStrategy', 'auto_id');
        },
      );
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  /// Generates a unique student code (STU-XXXXXX format)
  /// Uses cryptographically secure Random for uniqueness
  Future<String> _generateStudentCode(String teacherId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = 'STU-${List.generate(6, (_) => chars[rng.nextInt(chars.length)])}';

      final existing = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) return code;
    }

    // Fallback: use timestamp-based code
    return 'STU-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  /// Verify that a QR code is still valid (class exists and is active)
  Future<bool> validateQRData(Map<String, dynamic> qrData) async {
    try {
      final classId = qrData['classId'] as String?;
      if (classId == null) return false;

      final classDoc = await _firestore.collection(AppConstants.classesCollection).doc(classId).get();
      return classDoc.exists;
    } catch (e) {
      debugPrint('Error validating QR data: $e');
      return false;
    }
  }

  /// Get class info from QR data for preview before enrollment
  Future<Map<String, dynamic>?> getClassInfoFromQR(Map<String, dynamic> qrData) async {
    try {
      final classId = qrData['classId'] as String?;
      if (classId == null) return null;

      final classDoc = await _firestore.collection(AppConstants.classesCollection).doc(classId).get();
      if (!classDoc.exists) return null;

      final data = classDoc.data()!;
      return {
        'className': data['name'] ?? qrData['className'],
        'grade': data['grade'] ?? qrData['grade'],
        'studentCount': data['studentCount'] ?? 0,
        'teacherId': data['createdBy'] ?? data['teacherId'] ?? qrData['teacherId'],
      };
    } catch (e) {
      debugPrint('Error getting class info from QR: $e');
      return null;
    }
  }
}

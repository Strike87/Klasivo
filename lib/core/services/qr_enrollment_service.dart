import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';

/// Service for QR code-based student enrollment
/// QR codes contain encoded class/teacher information that allows
/// students to self-enroll into a class by scanning.
class QREnrollmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // P0-11 PATCH: generateEnrollmentQRData() / parseEnrollmentQRData() removed.
  // Both were dead code with zero callers anywhere in lib/. The QR scan flow
  // that's actually wired up (features/qr/pages/qr_scan_screen.dart) uses
  // QrService.enrollStudentByQr() instead, which enrolls an already
  // authenticated, already-existing student into a class — a different flow
  // from the new-account-creation this file's QR data shape was designed for.

  // P0-11 PATCH: enrollViaQR() and its helper _generateStudentCode() removed.
  // enrollViaQR had zero callers anywhere in lib/ and predates the
  // createStudent Cloud Function pattern now used everywhere else for
  // student account creation (see student_service.dart addStudent(),
  // excel_import_service.dart importStudents()). It wrote directly to
  // Firestore from the client (blocked by security rules in practice) and
  // fell back to storing the PLAINTEXT password in the passwordHash field
  // whenever no hashPassword callback was supplied — a real bug, but one
  // that never shipped to users since nothing called this method.
  //
  // If QR-based new-account enrollment is needed in the future, it should
  // be built as a createStudent-style Cloud Function call, not a client-side
  // Firestore write.

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

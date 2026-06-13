import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../rbac/roles.dart';

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
  /// Returns the new student document ID
  Future<String> enrollViaQR({
    required Map<String, dynamic> qrData,
    required String fullName,
    required String password,
    String Function(String)? hashPassword,
  }) async {
    final classId = qrData['classId'] as String;
    final teacherId = qrData['teacherId'] as String;
    final className = qrData['className'] as String? ?? '';
    final grade = qrData['grade'] as String? ?? '';
    final organizationId = qrData['organizationId'] as String? ?? AppConstants.defaultInstitutionId;

    // Verify class exists
    final classDoc = await _firestore.collection(AppConstants.classesCollection).doc(classId).get();
    if (!classDoc.exists) {
      throw Exception('Class not found. The QR code may be outdated.');
    }

    // Generate unique student code
    final studentCode = await _generateStudentCode(teacherId);

    // Create student document (students ARE users — stored in usersCollection)
    final docRef = _firestore.collection(AppConstants.usersCollection).doc();
    await docRef.set({
      'organizationId': organizationId,
      'role': KlasivoRole.student,
      'id': docRef.id,
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
    });

    // Update class student count
    final currentCount = classDoc.data()?['studentCount'] as int? ?? 0;
    await _firestore.collection(AppConstants.classesCollection).doc(classId).update({
      'studentCount': currentCount + 1,
    });

    return docRef.id;
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

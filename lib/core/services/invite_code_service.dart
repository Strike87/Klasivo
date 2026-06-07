import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class InviteCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Generate a unique invite code
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Create an invite code for a teacher
  Future<String> createTeacherInviteCode({
    required String organizationId,
    required String createdBy,
    int maxUses = 1,
    DateTime? expiresAt,
  }) async {
    try {
      String code;
      bool exists;
      do {
        code = 'T-${_generateCode()}';
        final snapshot = await _firestore
            .collection(AppConstants.inviteCodesCollection)
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        exists = snapshot.docs.isNotEmpty;
      } while (exists);

      final docRef = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .add({
        'code': code,
        'type': AppConstants.inviteTypeTeacher,
        'organizationId': organizationId,
        'createdBy': createdBy,
        'isUsed': false,
        'usedBy': null,
        'usedAt': null,
        'maxUses': maxUses,
        'useCount': 0,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return code;
    } catch (e) {
      rethrow;
    }
  }

  /// Create an invite code for a student
  Future<String> createStudentInviteCode({
    required String organizationId,
    required String classId,
    required String createdBy,
    DateTime? expiresAt,
  }) async {
    try {
      String code;
      bool exists;
      do {
        code = 'S-${_generateCode()}';
        final snapshot = await _firestore
            .collection(AppConstants.inviteCodesCollection)
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        exists = snapshot.docs.isNotEmpty;
      } while (exists);

      final docRef = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .add({
        'code': code,
        'type': AppConstants.inviteTypeStudent,
        'organizationId': organizationId,
        'classId': classId,
        'createdBy': createdBy,
        'isUsed': false,
        'usedBy': null,
        'usedAt': null,
        'maxUses': 1,
        'useCount': 0,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return code;
    } catch (e) {
      rethrow;
    }
  }

  /// Validate an invite code
  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      // Check expiration
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        return null; // Code expired
      }

      // Check max uses
      final useCount = data['useCount'] as int? ?? 0;
      final maxUses = data['maxUses'] as int? ?? 1;
      if (useCount >= maxUses) {
        return null; // Code fully used
      }

      return {'id': doc.id, ...data};
    } catch (e) {
      rethrow;
    }
  }

  /// Get all invite codes for an organization
  Stream<QuerySnapshot> getInviteCodesStream(String organizationId) {
    return _firestore
        .collection(AppConstants.inviteCodesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Delete an invite code
  Future<void> deleteInviteCode(String codeId) async {
    try {
      await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .doc(codeId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate an invite code
  Future<void> deactivateInviteCode(String codeId) async {
    try {
      await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .doc(codeId)
          .update({'isUsed': true});
    } catch (e) {
      rethrow;
    }
  }
}

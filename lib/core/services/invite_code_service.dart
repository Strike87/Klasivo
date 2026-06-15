import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'deep_link_service.dart';
import 'sentry_service.dart';

class InviteCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  final DeepLinkService _deepLinkService = DeepLinkService();

  /// Generate a unique invite code string
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      AppConstants.inviteCodeLength,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Generate a URL-friendly code (no prefix, for join links)
  String _generateUrlCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I,O,0,1 to avoid confusion
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Create an invite code for a teacher.
  /// Returns both the code (T-XXXXXXXX) and the shareable join URL.
  Future<InviteCodeResult> createTeacherInviteCode({
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

      // Generate URL-friendly code for join links
      String urlCode;
      bool urlExists;
      do {
        urlCode = _generateUrlCode();
        final snapshot = await _firestore
            .collection(AppConstants.inviteCodesCollection)
            .where('urlCode', isEqualTo: urlCode)
            .limit(1)
            .get();
        urlExists = snapshot.docs.isNotEmpty;
      } while (urlExists);

      final joinUrl = _deepLinkService.generateJoinLink(urlCode);

      final docRef = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .add({
        'code': code,
        'urlCode': urlCode,
        'joinUrl': joinUrl,
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

      return InviteCodeResult(
        id: docRef.id,
        code: code,
        urlCode: urlCode,
        joinUrl: joinUrl,
        type: AppConstants.inviteTypeTeacher,
        organizationId: organizationId,
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to create teacher invite code',
        tags: {'flow': 'invite_code', 'type': 'teacher', 'organizationId': organizationId},
      );
      rethrow;
    }
  }

  /// Create an invite code for a student.
  /// Returns both the code (S-XXXXXXXX) and the shareable join URL.
  Future<InviteCodeResult> createStudentInviteCode({
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

      // Generate URL-friendly code for join links
      String urlCode;
      bool urlExists;
      do {
        urlCode = _generateUrlCode();
        final snapshot = await _firestore
            .collection(AppConstants.inviteCodesCollection)
            .where('urlCode', isEqualTo: urlCode)
            .limit(1)
            .get();
        urlExists = snapshot.docs.isNotEmpty;
      } while (urlExists);

      final joinUrl = _deepLinkService.generateJoinLink(urlCode);

      final docRef = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .add({
        'code': code,
        'urlCode': urlCode,
        'joinUrl': joinUrl,
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

      return InviteCodeResult(
        id: docRef.id,
        code: code,
        urlCode: urlCode,
        joinUrl: joinUrl,
        type: AppConstants.inviteTypeStudent,
        organizationId: organizationId,
        classId: classId,
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to create student invite code',
        tags: {'flow': 'invite_code', 'type': 'student', 'organizationId': organizationId},
      );
      rethrow;
    }
  }

  /// Validate an invite code (supports both T-XXXXXXXX format and URL code).
  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    try {
      // Try exact code match first (T-XXXXXXXX or S-XXXXXXXX)
      var snapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      // If not found, try URL code match (from join link)
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection(AppConstants.inviteCodesCollection)
            .where('urlCode', isEqualTo: code)
            .where('isUsed', isEqualTo: false)
            .limit(1)
            .get();
      }

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
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to validate invite code',
        tags: {'flow': 'invite_code', 'step': 'validate'},
      );
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
      await SentryFirestoreHelper.docDelete(
        collection: AppConstants.inviteCodesCollection,
        docId: codeId,
        flow: 'invite_code_delete',
        step: 'deleteInviteCode',
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to delete invite code',
        tags: {'flow': 'invite_code_delete', 'codeId': codeId},
      );
      rethrow;
    }
  }

  /// Deactivate an invite code
  Future<void> deactivateInviteCode(String codeId) async {
    try {
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.inviteCodesCollection,
        docId: codeId,
        data: {'isUsed': true},
        flow: 'invite_code_deactivate',
        step: 'deactivateInviteCode',
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to deactivate invite code',
        tags: {'flow': 'invite_code_deactivate', 'codeId': codeId},
      );
      rethrow;
    }
  }

  /// Generate a shareable text for an invite code
  String generateShareText({
    required String organizationName,
    required String joinUrl,
    required String type,
  }) {
    final roleLabel = type == AppConstants.inviteTypeTeacher ? 'teacher' : 'student';
    return 'Join $organizationName on Klasivo as a $roleLabel!\n\n'
        '$joinUrl\n\n'
        'Or enter code in the Klasivo app.';
  }
}

/// Result of creating an invite code, including the shareable URL.
class InviteCodeResult {
  final String id;
  final String code;          // T-XXXXXXXX or S-XXXXXXXX
  final String urlCode;       // XXXXXXXX (URL-friendly, no prefix)
  final String joinUrl;       // https://klasivo.app/join/XXXXXXXX
  final String type;
  final String organizationId;
  final String? classId;

  InviteCodeResult({
    required this.id,
    required this.code,
    required this.urlCode,
    required this.joinUrl,
    required this.type,
    required this.organizationId,
    this.classId,
  });
}

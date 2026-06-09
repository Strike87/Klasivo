import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new announcement
  Future<String> createAnnouncement({
    required String organizationId,
    required String title,
    required String content,
    required String targetType, // 'organization', 'class', 'group'
    required String targetId,
    String? createdBy,
    String? createdByName,
    bool isPinned = false,
    DateTime? expiresAt,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.announcementsCollection)
          .add({
        'organizationId': organizationId,
        'title': title,
        'content': content,
        'targetType': targetType,
        'targetId': targetId,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'isPinned': isPinned,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'isActive': true,
        'readBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      rethrow;
    }
  }

  /// Update an announcement
  Future<void> updateAnnouncement(String announcementId, {
    String? title,
    String? content,
    String? targetType,
    String? targetId,
    bool? isPinned,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (content != null) data['content'] = content;
      if (targetType != null) data['targetType'] = targetType;
      if (targetId != null) data['targetId'] = targetId;
      if (isPinned != null) data['isPinned'] = isPinned;
      if (expiresAt != null) data['expiresAt'] = Timestamp.fromDate(expiresAt);
      if (isActive != null) data['isActive'] = isActive;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating announcement: $e');
      rethrow;
    }
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      rethrow;
    }
  }

  /// Get a single announcement
  Future<Map<String, dynamic>?> getAnnouncement(String announcementId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('Error getting announcement: $e');
      rethrow;
    }
  }

  /// Stream announcements by organization (for owners/teachers)
  Stream<QuerySnapshot> getAnnouncementsByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.announcementsCollection)
        .where('organizationId', orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream announcements for a specific target (class or group)
  Stream<QuerySnapshot> getAnnouncementsByTargetStream(String orgId, String targetType, String targetId) {
    return _firestore
        .collection(AppConstants.announcementsCollection)
        .where('organizationId', orgId)
        .where('targetType', targetType)
        .where('targetId', targetId)
        .where('isActive', isEqualTo: true)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream announcements visible to a student (org-wide + class-specific + group-specific)
  Stream<QuerySnapshot> getAnnouncementsForStudentStream(String orgId, String classId) {
    return _firestore
        .collection(AppConstants.announcementsCollection)
        .where('organizationId', orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Mark announcement as read by a user
  Future<void> markAsRead(String announcementId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      debugPrint('Error marking announcement as read: $e');
      rethrow;
    }
  }

  /// Toggle pin status
  Future<void> togglePin(String announcementId, bool isPinned) async {
    try {
      await _firestore
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .update({
        'isPinned': isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling pin: $e');
      rethrow;
    }
  }
}

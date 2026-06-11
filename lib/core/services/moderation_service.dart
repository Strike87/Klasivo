import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

/// Service for resource moderation workflow.
/// Resources uploaded by teachers enter a moderation queue for owner review.
/// Status flow: pending → approved | rejected
class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a resource for moderation review.
  Future<String> submitForReview({
    required String organizationId,
    required String resourceId,
    required String resourceType, // 'resource', 'material', 'lesson'
    required String title,
    String? description,
    String? fileUrl,
    required String submittedBy,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.moderationQueueCollection)
          .add({
        'organizationId': organizationId,
        'resourceId': resourceId,
        'resourceType': resourceType,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'submittedBy': submittedBy,
        'status': 'pending', // pending | approved | rejected
        'reviewedBy': null,
        'reviewedAt': null,
        'reviewNote': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Approve a resource in the moderation queue.
  Future<void> approveItem({
    required String itemId,
    required String reviewedBy,
    String? reviewNote,
  }) async {
    try {
      // Get the item to find the resourceId
      final itemDoc = await _firestore
          .collection(AppConstants.moderationQueueCollection)
          .doc(itemId)
          .get();

      if (!itemDoc.exists) throw Exception('Moderation item not found');

      final itemData = itemDoc.data() as Map<String, dynamic>;
      final resourceId = itemData['resourceId'] as String?;
      final resourceType = itemData['resourceType'] as String? ?? 'resource';

      final batch = _firestore.batch();

      // Update moderation queue item
      batch.update(itemDoc.reference, {
        'status': 'approved',
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reviewNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the actual resource's moderation status
      if (resourceId != null) {
        String collection;
        switch (resourceType) {
          case 'material':
            collection = AppConstants.materialsCollection;
            break;
          case 'lesson':
            collection = AppConstants.lessonsCollection;
            break;
          default:
            collection = AppConstants.resourcesCollection;
        }
        batch.update(_firestore.collection(collection).doc(resourceId), {
          'moderationStatus': 'approved',
          'moderatedBy': reviewedBy,
          'moderatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a resource in the moderation queue.
  Future<void> rejectItem({
    required String itemId,
    required String reviewedBy,
    String? reviewNote,
  }) async {
    try {
      final itemDoc = await _firestore
          .collection(AppConstants.moderationQueueCollection)
          .doc(itemId)
          .get();

      if (!itemDoc.exists) throw Exception('Moderation item not found');

      final itemData = itemDoc.data() as Map<String, dynamic>;
      final resourceId = itemData['resourceId'] as String?;
      final resourceType = itemData['resourceType'] as String? ?? 'resource';

      final batch = _firestore.batch();

      // Update moderation queue item
      batch.update(itemDoc.reference, {
        'status': 'rejected',
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reviewNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the actual resource's moderation status
      if (resourceId != null) {
        String collection;
        switch (resourceType) {
          case 'material':
            collection = AppConstants.materialsCollection;
            break;
          case 'lesson':
            collection = AppConstants.lessonsCollection;
            break;
          default:
            collection = AppConstants.resourcesCollection;
        }
        batch.update(_firestore.collection(collection).doc(resourceId), {
          'moderationStatus': 'rejected',
          'moderatedBy': reviewedBy,
          'moderatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending items stream for an organization.
  Stream<QuerySnapshot> getPendingItemsStream(String organizationId) {
    return _firestore
        .collection(AppConstants.moderationQueueCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all items (any status) for an organization.
  Stream<QuerySnapshot> getAllItemsStream(String organizationId) {
    return _firestore
        .collection(AppConstants.moderationQueueCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get moderation statistics for an organization.
  Future<Map<String, int>> getStats(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.moderationQueueCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();

      int pending = 0, approved = 0, rejected = 0;
      for (final doc in snapshot.docs) {
        final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
        if (status == 'pending') pending++;
        else if (status == 'approved') approved++;
        else if (status == 'rejected') rejected++;
      }

      return {'pending': pending, 'approved': approved, 'rejected': rejected, 'total': snapshot.docs.length};
    } catch (e) {
      rethrow;
    }
  }
}

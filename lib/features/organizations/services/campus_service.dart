import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';
import '../domain/campus_model.dart';

/// Service layer for CRUD operations on the `campuses` Firestore collection.
///
/// All methods scope queries by [organizationId] to enforce multi-tenancy.
/// Follows the same patterns as [OrganizationService] in this codebase.
class CampusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Stream: Campuses for an organization ─────────────────────────────────

  /// Returns a real-time stream of active campuses for [organizationId],
  /// ordered by creation date (newest first).
  Stream<List<CampusModel>> getCampuses(String organizationId) {
    return _firestore
        .collection(AppConstants.campusesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CampusModel.fromFirestore(doc))
            .toList());
  }

  // ─── Read: Single campus ─────────────────────────────────────────────────

  /// Fetch a single campus document by ID.
  Future<CampusModel?> getCampus(String campusId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.campusesCollection)
          .doc(campusId)
          .get();

      if (!doc.exists) return null;
      return CampusModel.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  /// Create a new campus document. Returns the generated document ID.
  ///
  /// If [isMain] is true, any existing main campus for this organization
  /// will be demoted (isMain → false) to ensure only one main campus exists.
  Future<String> createCampus({
    required String organizationId,
    required String name,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool isMain = false,
    String? headId,
  }) async {
    try {
      // If this campus is set as main, demote the existing main campus
      if (isMain) {
        await _demoteExistingMainCampus(organizationId);
      }

      final docRef = await _firestore
          .collection(AppConstants.campusesCollection)
          .add({
        'organizationId': organizationId,
        'name': name,
        'address': address,
        'city': city,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'email': email,
        'isActive': true,
        'isMain': isMain,
        'headId': headId,
        'studentCount': 0,
        'teacherCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  /// Update an existing campus with the provided fields.
  /// Only non-null fields will be written.
  Future<void> updateCampus({
    required String campusId,
    String? name,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool? isActive,
    bool? isMain,
    String? headId,
    int? studentCount,
    int? teacherCount,
    String? organizationId, // needed for main campus demotion
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (city != null) data['city'] = city;
      if (country != null) data['country'] = country;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (isActive != null) data['isActive'] = isActive;
      if (headId != null) data['headId'] = headId;
      if (studentCount != null) data['studentCount'] = studentCount;
      if (teacherCount != null) data['teacherCount'] = teacherCount;

      // If setting as main campus, demote existing main first
      if (isMain == true && organizationId != null) {
        await _demoteExistingMainCampus(organizationId, excludeId: campusId);
        data['isMain'] = true;
      } else if (isMain != null) {
        data['isMain'] = isMain;
      }

      await _firestore
          .collection(AppConstants.campusesCollection)
          .doc(campusId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Archive (soft delete) ───────────────────────────────────────────────

  /// Soft-delete a campus by setting [isActive] to false.
  /// The data is preserved and can be recovered by updating [isActive] back.
  Future<void> archiveCampus(String campusId) async {
    try {
      await _firestore
          .collection(AppConstants.campusesCollection)
          .doc(campusId)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete (hard delete with cascade) ───────────────────────────────────

  /// Permanently delete a campus document.
  /// Also removes the [campusId] from any users referencing this campus.
  ///
  /// **Use with caution** — this is irreversible.
  Future<void> deleteCampus(String campusId) async {
    try {
      final batch = _firestore.batch();

      // Remove campusId from users that belong to this campus
      final usersSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('campusId', isEqualTo: campusId)
          .get();

      for (final doc in usersSnapshot.docs) {
        batch.update(doc.reference, {
          'campusId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete the campus document itself
      batch.delete(
        _firestore.collection(AppConstants.campusesCollection).doc(campusId),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Private: Demote existing main campus ────────────────────────────────

  /// Sets [isMain] to false on any campus that currently has [isMain] == true
  /// for the given [organizationId]. Optionally [excludeId] to skip a campus
  /// (useful during update to avoid clearing the campus we're promoting).
  Future<void> _demoteExistingMainCampus(
    String organizationId, {
    String? excludeId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.campusesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('isMain', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        if (excludeId != null && doc.id == excludeId) continue;
        await doc.reference.update({
          'isMain': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class AcademicYearService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new academic year
  Future<String> createAcademicYear({
    required String organizationId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
    String? createdBy,
  }) async {
    try {
      // If marking as current, unset any existing current year
      if (isCurrent) {
        final snapshot = await _firestore
            .collection(AppConstants.academicYearsCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('isCurrent', isEqualTo: true)
            .get();
        for (final doc in snapshot.docs) {
          await doc.reference.update({'isCurrent': false});
        }
      }

      final docRef = await _firestore
          .collection(AppConstants.academicYearsCollection)
          .add({
        'organizationId': organizationId,
        'name': name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isCurrent': isCurrent,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating academic year: $e');
      rethrow;
    }
  }

  /// Update an academic year
  Future<void> updateAcademicYear(String yearId, {
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    bool? isArchived,
  }) async {
    try {
      // If marking as current, unset any existing current year
      if (isCurrent == true) {
        final orgId = await _getOrgIdForYear(yearId);
        if (orgId != null) {
          final snapshot = await _firestore
              .collection(AppConstants.academicYearsCollection)
              .where('organizationId', isEqualTo: orgId)
              .where('isCurrent', isEqualTo: true)
              .get();
          for (final doc in snapshot.docs) {
            await doc.reference.update({'isCurrent': false});
          }
        }
      }

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (startDate != null) data['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) data['endDate'] = Timestamp.fromDate(endDate);
      if (isCurrent != null) data['isCurrent'] = isCurrent;
      if (isArchived != null) data['isArchived'] = isArchived;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.academicYearsCollection)
          .doc(yearId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating academic year: $e');
      rethrow;
    }
  }

  /// Delete an academic year
  Future<void> deleteAcademicYear(String yearId) async {
    try {
      await _firestore
          .collection(AppConstants.academicYearsCollection)
          .doc(yearId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting academic year: $e');
      rethrow;
    }
  }

  /// Get the organization ID for a given academic year
  Future<String?> _getOrgIdForYear(String yearId) async {
    final doc = await _firestore
        .collection(AppConstants.academicYearsCollection)
        .doc(yearId)
        .get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['organizationId'] as String?;
  }

  /// Stream academic years by organization
  Stream<QuerySnapshot> getAcademicYearsStream(String orgId) {
    return _firestore
        .collection(AppConstants.academicYearsCollection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  /// Get the current academic year for an organization
  Future<Map<String, dynamic>?> getCurrentAcademicYear(String orgId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.academicYearsCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()!};
    } catch (e) {
      debugPrint('Error getting current academic year: $e');
      rethrow;
    }
  }

  /// Set a year as current (unsets previous)
  Future<void> setCurrentAcademicYear(String orgId, String yearId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.academicYearsCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('isCurrent', isEqualTo: true)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.update({'isCurrent': false});
      }
      await _firestore
          .collection(AppConstants.academicYearsCollection)
          .doc(yearId)
          .update({'isCurrent': true, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error setting current academic year: $e');
      rethrow;
    }
  }

  /// Archive an academic year
  Future<void> archiveAcademicYear(String yearId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.academicYearsCollection)
          .doc(yearId)
          .update({
        'isArchived': true,
        'isCurrent': false,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': archivedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error archiving academic year: $e');
      rethrow;
    }
  }
}

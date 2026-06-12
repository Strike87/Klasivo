import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';
import '../domain/organization_model.dart';

/// Repository layer that wraps FirebaseFirestore and returns [OrganizationModel]
/// domain objects for the organizations feature.
class OrganizationRepository {
  final FirebaseFirestore _firestore;

  OrganizationRepository(this._firestore);

  // ─── Read Operations ──────────────────────────────────────────────────────

  /// Fetch a single organization by its document ID.
  Future<OrganizationModel?> getOrganization(String orgId) async {
    final doc = await _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .get();

    if (!doc.exists) return null;
    return OrganizationModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Fetch the organization owned by the given [ownerId].
  Future<OrganizationModel?> getOrganizationByOwner(String ownerId) async {
    final snapshot = await _firestore
        .collection(AppConstants.organizationsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return OrganizationModel.fromFirestore(
        snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  // ─── Write Operations ─────────────────────────────────────────────────────

  /// Update an existing organization and return the updated model.
  Future<OrganizationModel> updateOrganization(
      String orgId, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .update(data);

    final doc = await _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .get();

    return OrganizationModel.fromFirestore(doc.data()!, doc.id);
  }

  // ─── Stream Operations ────────────────────────────────────────────────────

  /// Stream a single organization document in real-time.
  Stream<OrganizationModel?> streamOrganization(String orgId) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return OrganizationModel.fromFirestore(doc.data()!, doc.id);
    });
  }
}

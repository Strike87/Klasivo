import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import '../rbac/roles.dart';

class OrganizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new organization. Called automatically when a user registers.
  /// Auto-generates a slug from the organization name.
  Future<String> createOrganization({
    required String ownerId,
    required String name,
    String? description,
    String? logoUrl,
    String? contactEmail,
    String? contactPhone,
    String? website,
  }) async {
    try {
      // Generate a unique slug from the name
      final slug = await _generateUniqueSlug(name);

      final docRef = await _firestore
          .collection(AppConstants.organizationsCollection)
          .add({
        'ownerId': ownerId,
        'name': name,
        'slug': slug,
        'description': description,
        'logoUrl': logoUrl,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'website': website,
        'isActive': true,
        'isPortalEnabled': false, // Portal disabled by default
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update organization details
  Future<void> updateOrganization({
    required String organizationId,
    String? name,
    String? slug,
    String? description,
    String? logoUrl,
    bool? isActive,
    bool? isPortalEnabled,
    String? contactEmail,
    String? contactPhone,
    String? website,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (logoUrl != null) data['logoUrl'] = logoUrl;
      if (isActive != null) data['isActive'] = isActive;
      if (isPortalEnabled != null) data['isPortalEnabled'] = isPortalEnabled;
      if (contactEmail != null) data['contactEmail'] = contactEmail;
      if (contactPhone != null) data['contactPhone'] = contactPhone;
      if (website != null) data['website'] = website;

      // If slug is being updated, validate uniqueness
      if (slug != null) {
        final isUnique = await _isSlugUnique(slug, excludeOrgId: organizationId);
        if (!isUnique) {
          throw Exception('This URL is already taken. Please choose a different one.');
        }
        data['slug'] = slug;
      }

      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get organization by ID
  Future<Map<String, dynamic>?> getOrganization(String organizationId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .get();
      return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get organization by owner ID
  Future<Map<String, dynamic>?> getOrganizationByOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
    } catch (e) {
      rethrow;
    }
  }

  /// Stream organization data in real-time
  Stream<DocumentSnapshot> getOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .snapshots();
  }

  /// Get all members (users) in an organization
  Stream<QuerySnapshot> getOrganizationMembersStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get teachers in an organization
  Stream<QuerySnapshot> getOrganizationTeachersStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: KlasivoRole.teacher)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get member count by role
  Future<Map<String, int>> getMemberCounts(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();

      int owners = 0;
      int teachers = 0;
      int students = 0;

      for (final doc in snapshot.docs) {
        final role = doc.data()['role'] as String? ?? '';
        switch (role) {
          case 'owner':
            owners++;
            break;
          case 'teacher':
            teachers++;
            break;
          case 'student':
            students++;
            break;
        }
      }

      return {
        'owners': owners,
        'teachers': teachers,
        'students': students,
        'total': snapshot.docs.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Delete organization and all its data (use with caution!)
  Future<void> deleteOrganization(String organizationId) async {
    try {
      final batch = _firestore.batch();

      // Delete all users in this organization
      final usersSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in usersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all stages
      final stagesSnapshot = await _firestore
          .collection(AppConstants.stagesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in stagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all classes
      final classesSnapshot = await _firestore
          .collection(AppConstants.classesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in classesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all subjects
      final subjectsSnapshot = await _firestore
          .collection(AppConstants.subjectsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in subjectsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all groups
      final groupsSnapshot = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in groupsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all teacher assignments
      final assignmentsSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in assignmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all exams
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in examsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all question banks
      final qbSnapshot = await _firestore
          .collection(AppConstants.questionBankCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in qbSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all invite codes
      final codesSnapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in codesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all attendance records
      final attSnapshot = await _firestore
          .collection(AppConstants.attendanceCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in attSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all conversations
      final convsSnapshot = await _firestore
          .collection(AppConstants.conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in convsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all analytics cache
      final analyticsSnapshot = await _firestore
          .collection(AppConstants.analyticsCacheCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in analyticsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the organization document itself
      batch.delete(_firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId));

      await batch.commit();

      // Messages don't have organizationId directly - delete via conversations
      // This requires a separate step since conversations were already deleted above
      // The Cloud Function handles this more thoroughly
    } catch (e) {
      rethrow;
    }
  }

  // ─── Slug Utilities ──────────────────────────────────────────────────────

  /// Convert an organization name to a URL-friendly slug.
  /// Examples:
  ///   "Ahmed Academy" → "ahmed-academy"
  ///   "Math Center (Cairo)" → "math-center-cairo"
  ///   "Al-Noor School 2024" → "al-noor-school-2024"
  String _slugify(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-')      // Spaces to hyphens
        .replaceAll(RegExp(r'-+'), '-')        // Multiple hyphens to single
        .replaceAll(RegExp(r'^-|-$'), '');     // Trim hyphens

    // Use slug.length (not name.length) since slugification shortens the string
    return slug.length > AppConstants.maxSlugLength
        ? slug.substring(0, AppConstants.maxSlugLength)
        : slug;
  }

  /// Generate a unique slug by checking Firestore for collisions.
  /// If "ahmed-academy" exists, tries "ahmed-academy-2", "ahmed-academy-3", etc.
  Future<String> _generateUniqueSlug(String name) async {
    final baseSlug = _slugify(name);
    String slug = baseSlug;
    int suffix = 2;

    while (!await _isSlugUnique(slug)) {
      slug = '$baseSlug-$suffix';
      suffix++;
    }

    return slug;
  }

  /// Check if a slug is unique in the organizations collection.
  Future<bool> _isSlugUnique(String slug, {String? excludeOrgId}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return true;

      // If we're updating an existing org, the slug might belong to it
      if (excludeOrgId != null && snapshot.docs.first.id == excludeOrgId) {
        return true;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// Get organization by slug (for public portal pages).
  Future<Map<String, dynamic>?> getOrganizationBySlug(String slug) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('slug', isEqualTo: slug)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
    } catch (e) {
      rethrow;
    }
  }

  /// Generate the public portal URL for an organization.
  String getOrgPortalUrl(String slug) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathOrg}/$slug';
  }
}

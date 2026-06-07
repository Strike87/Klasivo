import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/organization_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final organizationServiceProvider =
    Provider<OrganizationService>((ref) => OrganizationService());

// ─── Current Organization ID ─────────────────────────────────────────────────

final currentOrganizationIdProvider = StateProvider<String?>((ref) => null);

// ─── Current Organization Stream ─────────────────────────────────────────────

final currentOrganizationProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return Stream.value(null);

  return ref
      .read(organizationServiceProvider)
      .getOrganizationStream(orgId)
      .map((doc) {
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  });
});

// ─── Organization Members Stream ──────────────────────────────────────────────

final organizationMembersProvider =
    StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(organizationServiceProvider)
      .getOrganizationMembersStream(orgId);
});

// ─── Organization Teachers Stream ─────────────────────────────────────────────

final organizationTeachersProvider =
    StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(organizationServiceProvider)
      .getOrganizationTeachersStream(orgId);
});

// ─── Organization Data Model ─────────────────────────────────────────────────

class OrganizationData {
  final String id;
  final String ownerId;
  final String name;
  final String? slug;
  final String? description;
  final String? logoUrl;
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final bool isActive;
  final bool isPortalEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrganizationData({
    required this.id,
    required this.ownerId,
    required this.name,
    this.slug,
    this.description,
    this.logoUrl,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.isActive = true,
    this.isPortalEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Get the public portal URL for this organization.
  String get portalUrl => slug != null
      ? '${AppConstants.appBaseUrl}${AppConstants.pathOrg}/$slug'
      : '';

  factory OrganizationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizationData(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      slug: data['slug'],
      description: data['description'],
      logoUrl: data['logoUrl'],
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      website: data['website'],
      isActive: data['isActive'] ?? true,
      isPortalEnabled: data['isPortalEnabled'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory OrganizationData.fromMap(Map<String, dynamic> map) {
    return OrganizationData(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      slug: map['slug'],
      description: map['description'],
      logoUrl: map['logoUrl'],
      contactEmail: map['contactEmail'],
      contactPhone: map['contactPhone'],
      website: map['website'],
      isActive: map['isActive'] ?? true,
      isPortalEnabled: map['isPortalEnabled'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'slug': slug,
      'description': description,
      'logoUrl': logoUrl,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'website': website,
      'isActive': isActive,
      'isPortalEnabled': isPortalEnabled,
    };
  }
}

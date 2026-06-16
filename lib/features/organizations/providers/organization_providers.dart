import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../data/organization_repository.dart';
import '../domain/organization_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provides a singleton [OrganizationRepository] instance.
///
/// Uses the default [FirebaseFirestore.instance] in production.
/// Inject a mock FirebaseFirestore in tests for testability.
final organizationRepositoryProvider =
    Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(FirebaseFirestore.instance);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Stream Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Streams the current user's organization in real-time.
///
/// Watches [currentOrgIdProvider] from auth providers to determine which
/// organization to stream. When the org ID changes (e.g., user switches
/// organization), this provider automatically re-subscribes to the new org doc.
///
/// Returns null when no organization ID is available (e.g., user not logged in).
final currentOrganizationProvider =
    StreamProvider<OrganizationModel?>((ref) {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return Stream.value(null);

  return ref
      .read(organizationRepositoryProvider)
      .streamOrganization(orgId);
});

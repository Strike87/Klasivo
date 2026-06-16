import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../providers/organization_provider.dart';
import '../domain/campus_model.dart';
import '../services/campus_service.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

/// Provides a singleton [CampusService] instance.
final campusServiceProvider = Provider<CampusService>((ref) => CampusService());

// ─── Campus List Stream ─────────────────────────────────────────────────────

/// Streams the list of active campuses for the current organization.
///
/// Returns an empty list when no organization is selected.
/// Automatically re-fetches when the organization changes.
final campusListProvider = StreamProvider<List<CampusModel>>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return Stream.value([]);

  return ref.read(campusServiceProvider).getCampuses(orgId);
});

// ─── Campus List by Org ID ──────────────────────────────────────────────────

/// Streams campuses for a specific [organizationId].
///
/// Use this when you need campuses for an org other than the current one,
/// or when you want a family provider that can be invalidated independently.
final campusListByOrgProvider =
    StreamProvider.family<List<CampusModel>, String>((ref, orgId) {
  return ref.read(campusServiceProvider).getCampuses(orgId);
});

// ─── Current Organization ID (re-export for convenience) ────────────────────

/// Convenience accessor for the current organization ID from Hive storage.
/// Screens can watch this to reactively rebuild when the org changes.
final campusCurrentOrgIdProvider = Provider<String?>((ref) {
  return ref.watch(currentOrganizationIdProvider);
});

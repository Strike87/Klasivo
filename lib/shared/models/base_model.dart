/// Base model for all Klasivo documents.
///
/// Includes multi-tenant fields ([tenantId], [organizationId], [campusId])
/// and audit fields ([createdAt], [updatedAt], [createdBy]).
///
/// Every Firestore document in the platform should implement this interface
/// so that multi-tenant boundary checks can be applied uniformly.
abstract class BaseModel {
  /// Unique identifier for this document.
  String get id;

  /// The tenant this document belongs to.
  ///
  /// `null` only for platform-level documents that transcend tenants.
  String? get tenantId;

  /// The organization this document belongs to.
  ///
  /// `null` for tenant-level documents (e.g., tenant settings).
  String? get organizationId;

  /// The campus this document belongs to.
  ///
  /// `null` when the document is not scoped to a specific campus.
  String? get campusId;

  /// When this document was created.
  DateTime get createdAt;

  /// When this document was last updated.
  ///
  /// `null` if the document has never been updated.
  DateTime? get updatedAt;

  /// The user ID of the person who created this document.
  ///
  /// `null` for system-generated documents.
  String? get createdBy;

  /// Serialize this model to a Firestore-compatible map.
  Map<String, dynamic> toMap();

  /// Returns `true` if this document belongs to the given tenant.
  bool belongsToTenant(String tid) => tenantId == tid;

  /// Returns `true` if this document belongs to the given organization.
  bool belongsToOrganization(String oid) => organizationId == oid;

  /// Returns `true` if this document belongs to the given campus.
  bool belongsToCampus(String cid) => campusId == cid;
}

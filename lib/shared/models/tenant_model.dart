import 'base_model.dart';
import '../../features/staff_approval/domain/staff_approval_policy.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TENANT — Top-level entity (school chain, university system, tutoring franchise)
// ═══════════════════════════════════════════════════════════════════════════════

/// The lifecycle status of a tenant.
enum TenantStatus { active, suspended, trial, expired }

/// The subscription plan of a tenant.
///
/// Plans are ordered by feature availability — higher-index plans include
/// all features from lower plans plus additional modules.
enum TenantPlan { free, starter, professional, enterprise }

/// Tenant = Top-level entity (school chain, university system, tutoring franchise).
///
/// A tenant owns one or more [OrganizationData] instances. Feature modules
/// are enabled/disabled at the tenant level via [enabledModules].
class TenantData implements BaseModel {
  @override
  final String id;

  final String name;

  final String? logoUrl;

  /// Custom domain for the tenant (e.g., 'acme.klasivo.app').
  final String? domain;

  final TenantStatus status;

  final TenantPlan plan;

  /// Number of organizations under this tenant.
  final int organizationCount;

  /// Total number of students across all organizations.
  final int totalStudentCount;

  /// Feature module toggle map.
  /// Keys are module IDs (e.g., 'attendance', 'lms', 'finance', 'transport').
  /// Values indicate whether the module is enabled for this tenant.
  final Map<String, bool> enabledModules;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  /// Tenant-level documents have no parent tenant.
  @override
  String? get tenantId => null;

  /// Tenant-level documents have no parent organization.
  @override
  String? get organizationId => null;

  /// Tenant-level documents have no parent campus.
  @override
  String? get campusId => null;

  @override
  final DateTime? updatedAt;

  const TenantData({
    required this.id,
    required this.name,
    this.logoUrl,
    this.domain,
    required this.status,
    required this.plan,
    this.organizationCount = 0,
    this.totalStudentCount = 0,
    this.enabledModules = const {},
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory TenantData.fromMap(String id, Map<String, dynamic> map) {
    return TenantData(
      id: id,
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      domain: map['domain'] as String?,
      status: _tenantStatusFromId(map['status'] as String?),
      plan: _tenantPlanFromId(map['plan'] as String?),
      organizationCount: map['organizationCount'] as int? ?? 0,
      totalStudentCount: map['totalStudentCount'] as int? ?? 0,
      enabledModules: Map<String, bool>.from(
        map['enabledModules'] as Map? ?? {},
      ),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : DateTime.now(),
      createdBy: map['createdBy'] as String?,
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'domain': domain,
      'status': status.name,
      'plan': plan.name,
      'organizationCount': organizationCount,
      'totalStudentCount': totalStudentCount,
      'enabledModules': enabledModules,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  /// Whether a feature module is enabled for this tenant.
  bool isModuleEnabled(String moduleId) =>
      enabledModules[moduleId] ?? false;

  TenantData copyWith({
    String? name,
    String? logoUrl,
    String? domain,
    TenantStatus? status,
    TenantPlan? plan,
    int? organizationCount,
    int? totalStudentCount,
    Map<String, bool>? enabledModules,
    DateTime? updatedAt,
  }) {
    return TenantData(
      id: id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      domain: domain ?? this.domain,
      status: status ?? this.status,
      plan: plan ?? this.plan,
      organizationCount: organizationCount ?? this.organizationCount,
      totalStudentCount: totalStudentCount ?? this.totalStudentCount,
      enabledModules: enabledModules ?? this.enabledModules,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORGANIZATION — Single school/institution within a tenant
// ═══════════════════════════════════════════════════════════════════════════════

/// The status of an organization.
enum OrgStatus { active, suspended, archived }

/// Organization = Single school/institution within a tenant.
///
/// An organization belongs to exactly one [TenantData] (via [tenantId]) and
/// may have multiple [CampusData] instances for multi-campus schools.
class OrganizationData implements BaseModel {
  @override
  final String id;

  /// Links to the parent tenant.
  @override
  final String? tenantId;

  final String name;

  final String? logoUrl;

  final String? address;

  final String? phone;

  final String? email;

  /// The user ID of the organization owner.
  final String ownerId;

  final OrgStatus status;

  /// Staff approval policy for this organization.
  /// Controls how staff members join: manual review, invite-only, or auto-approve.
  /// Defaults to [StaffApprovalPolicy.manual] if missing in Firestore.
  final StaffApprovalPolicy staffApprovalPolicy;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  /// Organization-level documents have no campus.
  @override
  String? get campusId => null;

  /// Convenience getter — [tenantId] is always non-null for organizations.
  String get tenantIdOrThrow => tenantId!;

  const OrganizationData({
    required this.id,
    required this.tenantId,
    required this.name,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    required this.ownerId,
    required this.status,
    this.staffApprovalPolicy = StaffApprovalPolicy.manual,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory OrganizationData.fromMap(String id, Map<String, dynamic> map) {
    return OrganizationData(
      id: id,
      tenantId: map['tenantId'] as String?,
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      status: _orgStatusFromId(map['status'] as String?),
      // Defensive: missing field defaults to manual
      staffApprovalPolicy: StaffApprovalPolicy.fromId(
          map['staffApprovalPolicy'] as String?),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : DateTime.now(),
      createdBy: map['createdBy'] as String?,
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'name': name,
      'logoUrl': logoUrl,
      'address': address,
      'phone': phone,
      'email': email,
      'ownerId': ownerId,
      'status': status.name,
      'staffApprovalPolicy': staffApprovalPolicy.id,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  OrganizationData copyWith({
    String? name,
    String? logoUrl,
    String? address,
    String? phone,
    String? email,
    String? ownerId,
    OrgStatus? status,
    StaffApprovalPolicy? staffApprovalPolicy,
    DateTime? updatedAt,
  }) {
    return OrganizationData(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      staffApprovalPolicy: staffApprovalPolicy ?? this.staffApprovalPolicy,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPUS — Physical campus of an organization (for multi-campus schools)
// ═══════════════════════════════════════════════════════════════════════════════

/// Campus = Physical campus of an organization.
///
/// For single-campus schools, there is typically one campus record.
/// Multi-campus organizations create one [CampusData] per physical location.
class CampusData implements BaseModel {
  @override
  final String id;

  @override
  final String? organizationId;

  @override
  final String? tenantId;

  final String name;

  final String? address;

  final String? phone;

  /// The user ID of the campus manager.
  final String campusManagerId;

  /// IDs of stages/levels belonging to this campus.
  final List<String> stageIds;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  /// Campus-level documents use [id] as [campusId].
  @override
  String? get campusId => id;

  const CampusData({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    required this.name,
    this.address,
    this.phone,
    required this.campusManagerId,
    this.stageIds = const [],
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory CampusData.fromMap(String id, Map<String, dynamic> map) {
    return CampusData(
      id: id,
      organizationId: map['organizationId'] as String?,
      tenantId: map['tenantId'] as String?,
      name: map['name'] as String? ?? '',
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      campusManagerId: map['campusManagerId'] as String? ?? '',
      stageIds: List<String>.from(map['stageIds'] as List? ?? []),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : DateTime.now(),
      createdBy: map['createdBy'] as String?,
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'tenantId': tenantId,
      'name': name,
      'address': address,
      'phone': phone,
      'campusManagerId': campusManagerId,
      'stageIds': stageIds,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  CampusData copyWith({
    String? name,
    String? address,
    String? phone,
    String? campusManagerId,
    List<String>? stageIds,
    DateTime? updatedAt,
  }) {
    return CampusData(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      campusManagerId: campusManagerId ?? this.campusManagerId,
      stageIds: stageIds ?? this.stageIds,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS — Enum parsing from Firestore strings
// ═══════════════════════════════════════════════════════════════════════════════

TenantStatus _tenantStatusFromId(String? id) {
  switch (id) {
    case 'active':
      return TenantStatus.active;
    case 'suspended':
      return TenantStatus.suspended;
    case 'trial':
      return TenantStatus.trial;
    case 'expired':
      return TenantStatus.expired;
    default:
      return TenantStatus.trial;
  }
}

TenantPlan _tenantPlanFromId(String? id) {
  switch (id) {
    case 'free':
      return TenantPlan.free;
    case 'starter':
      return TenantPlan.starter;
    case 'professional':
      return TenantPlan.professional;
    case 'enterprise':
      return TenantPlan.enterprise;
    default:
      return TenantPlan.free;
  }
}

OrgStatus _orgStatusFromId(String? id) {
  switch (id) {
    case 'active':
      return OrgStatus.active;
    case 'suspended':
      return OrgStatus.suspended;
    case 'archived':
      return OrgStatus.archived;
    default:
      return OrgStatus.active;
  }
}

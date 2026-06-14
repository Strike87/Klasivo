/// Klasivo v2.0 — Multi-Tenant Data Model
///
/// Defines the complete multi-tenant hierarchy:
///   Tenant → Organization → Campus → Stage → Grade → Class → Group
///
/// A [TenantData] is the top-level entity for school chains, university
/// systems, franchises, or single schools. Each tenant owns one or more
/// [OrganizationData] instances, which in turn may contain multiple
/// [CampusData] records for multi-campus institutions.
library;

import '../../shared/models/base_model.dart';
import '../../features/staff_approval/domain/staff_approval_policy.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// The type of tenant, determining feature availability and UI flows.
enum TenantType {
  /// A chain of schools (e.g., "Al-Noor Education Group").
  schoolChain('school_chain'),

  /// A university system with multiple faculties or branches.
  universitySystem('university_system'),

  /// A franchise of tutoring centers.
  tutoringFranchise('tutoring_franchise'),

  /// A single independent school (no sub-organizations).
  singleSchool('single_school');

  const TenantType(this.id);

  /// String identifier stored in Firestore.
  final String id;

  /// Look up a [TenantType] by its Firestore [id].
  ///
  /// Returns [TenantType.singleSchool] as the default if no match is found.
  static TenantType fromId(String? id) {
    switch (id) {
      case 'school_chain':
        return TenantType.schoolChain;
      case 'university_system':
        return TenantType.universitySystem;
      case 'tutoring_franchise':
        return TenantType.tutoringFranchise;
      case 'single_school':
        return TenantType.singleSchool;
      default:
        return TenantType.singleSchool;
    }
  }
}

/// The subscription plan of a tenant.
///
/// Plans are ordered by feature availability — higher-index plans include
/// all features from lower plans plus additional modules.
enum TenantPlan {
  free('free'),
  starter('starter'),
  professional('professional'),
  enterprise('enterprise');

  const TenantPlan(this.id);

  /// String identifier stored in Firestore.
  final String id;

  /// Look up a [TenantPlan] by its Firestore [id].
  ///
  /// Returns [TenantPlan.free] as the default if no match is found.
  static TenantPlan fromId(String? id) {
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

  /// Maximum number of organizations allowed under this plan.
  int get maxOrganizations {
    switch (this) {
      case TenantPlan.free:
        return 1;
      case TenantPlan.starter:
        return 3;
      case TenantPlan.professional:
        return 10;
      case TenantPlan.enterprise:
        return -1; // unlimited
    }
  }

  /// Maximum number of users per organization under this plan.
  int get maxUsersPerOrg {
    switch (this) {
      case TenantPlan.free:
        return 50;
      case TenantPlan.starter:
        return 200;
      case TenantPlan.professional:
        return 1000;
      case TenantPlan.enterprise:
        return -1; // unlimited
    }
  }
}

/// The lifecycle status of a tenant.
enum TenantStatus {
  active('active'),
  suspended('suspended'),
  trial('trial'),
  expired('expired');

  const TenantStatus(this.id);

  /// String identifier stored in Firestore.
  final String id;

  /// Look up a [TenantStatus] by its Firestore [id].
  ///
  /// Returns [TenantStatus.trial] as the default if no match is found.
  static TenantStatus fromId(String? id) {
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
}

/// The status of an organization.
enum OrgStatus {
  active('active'),
  suspended('suspended'),
  archived('archived');

  const OrgStatus(this.id);

  /// String identifier stored in Firestore.
  final String id;

  /// Look up an [OrgStatus] by its Firestore [id].
  ///
  /// Returns [OrgStatus.active] as the default if no match is found.
  static OrgStatus fromId(String? id) {
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// TENANT — Top-level entity (school chain, university system, tutoring franchise)
// ═══════════════════════════════════════════════════════════════════════════════

/// Tenant = Top-level entity for school chains, university systems,
/// tutoring franchises, or single independent schools.
///
/// A tenant owns one or more [OrganizationData] instances. Feature modules
/// are enabled/disabled at the tenant level via [enabledModules].
class TenantData implements BaseModel {
  @override
  final String id;

  /// Human-readable name (e.g., "Al-Noor Education Group").
  final String name;

  /// URL-friendly identifier (e.g., "al-noor-education-group").
  final String slug;

  /// Optional logo URL for the tenant.
  final String? logoUrl;

  /// Optional description of the tenant.
  final String? description;

  /// The type of tenant, which determines available features and UI flows.
  final TenantType type;

  /// The subscription plan of the tenant.
  final TenantPlan plan;

  /// The lifecycle status of the tenant.
  final TenantStatus status;

  /// User ID of the person who created the tenant.
  final String ownerId;

  /// IDs of tenant-level administrators.
  final List<String> adminIds;

  /// Tenant-wide settings (locale, timezone, academic config, etc.).
  final Map<String, dynamic> settings;

  /// Feature module toggle map.
  /// Keys are module IDs (e.g., 'attendance', 'lms', 'finance', 'transport').
  /// Values indicate whether the module is enabled for this tenant.
  final Map<String, bool> enabledModules;

  /// Plan limit — maximum number of organizations under this tenant.
  final int maxOrganizations;

  /// Plan limit — maximum number of users per organization.
  final int maxUsersPerOrg;

  /// Number of organizations currently under this tenant.
  final int organizationCount;

  /// Total number of students across all organizations.
  final int totalStudentCount;

  /// Custom domain for the tenant (e.g., 'acme.klasivo.app').
  final String? domain;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  /// Tenant-level documents have no parent tenant.
  @override
  String? get tenantId => null;

  /// Tenant-level documents have no parent organization.
  @override
  String? get organizationId => null;

  /// Tenant-level documents have no parent campus.
  @override
  String? get campusId => null;

  const TenantData({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    required this.type,
    required this.plan,
    required this.status,
    required this.ownerId,
    this.adminIds = const [],
    this.settings = const {},
    this.enabledModules = const {},
    required this.maxOrganizations,
    required this.maxUsersPerOrg,
    this.organizationCount = 0,
    this.totalStudentCount = 0,
    this.domain,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory TenantData.fromMap(String id, Map<String, dynamic> map) {
    return TenantData(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      description: map['description'] as String?,
      type: TenantType.fromId(map['type'] as String?),
      plan: TenantPlan.fromId(map['plan'] as String?),
      status: TenantStatus.fromId(map['status'] as String?),
      ownerId: map['ownerId'] as String? ?? '',
      adminIds: List<String>.from(map['adminIds'] as List? ?? []),
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
      enabledModules: Map<String, bool>.from(
        map['enabledModules'] as Map? ?? {},
      ),
      maxOrganizations: map['maxOrganizations'] as int? ?? 1,
      maxUsersPerOrg: map['maxUsersPerOrg'] as int? ?? 50,
      organizationCount: map['organizationCount'] as int? ?? 0,
      totalStudentCount: map['totalStudentCount'] as int? ?? 0,
      domain: map['domain'] as String?,
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
      'slug': slug,
      'logoUrl': logoUrl,
      'description': description,
      'type': type.id,
      'plan': plan.id,
      'status': status.id,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'settings': settings,
      'enabledModules': enabledModules,
      'maxOrganizations': maxOrganizations,
      'maxUsersPerOrg': maxUsersPerOrg,
      'organizationCount': organizationCount,
      'totalStudentCount': totalStudentCount,
      'domain': domain,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  /// Whether a feature module is enabled for this tenant.
  bool isModuleEnabled(String moduleId) =>
      enabledModules[moduleId] ?? false;

  /// Whether this tenant has reached its organization limit.
  bool get hasReachedOrgLimit {
    if (maxOrganizations < 0) return false; // unlimited
    return organizationCount >= maxOrganizations;
  }

  /// Whether the plan is unlimited for the given metric value.
  static bool isUnlimited(int limit) => limit < 0;

  TenantData copyWith({
    String? name,
    String? slug,
    String? logoUrl,
    String? description,
    TenantType? type,
    TenantPlan? plan,
    TenantStatus? status,
    String? ownerId,
    List<String>? adminIds,
    Map<String, dynamic>? settings,
    Map<String, bool>? enabledModules,
    int? maxOrganizations,
    int? maxUsersPerOrg,
    int? organizationCount,
    int? totalStudentCount,
    String? domain,
    DateTime? updatedAt,
  }) {
    return TenantData(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      type: type ?? this.type,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      settings: settings ?? this.settings,
      enabledModules: enabledModules ?? this.enabledModules,
      maxOrganizations: maxOrganizations ?? this.maxOrganizations,
      maxUsersPerOrg: maxUsersPerOrg ?? this.maxUsersPerOrg,
      organizationCount: organizationCount ?? this.organizationCount,
      totalStudentCount: totalStudentCount ?? this.totalStudentCount,
      domain: domain ?? this.domain,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORGANIZATION — A single school/university within a tenant
// ═══════════════════════════════════════════════════════════════════════════════

/// Organization = A single school/university within a tenant.
///
/// An organization belongs to exactly one [TenantData] (via [tenantId]) and
/// may have multiple [CampusData] instances for multi-campus schools.
/// For single-campus organizations, [campusId] may reference a default campus.
class OrganizationData implements BaseModel {
  @override
  final String id;

  /// Links to the parent tenant.
  @override
  final String? tenantId;

  /// Human-readable name (e.g., "Al-Noor School — Riyadh Branch").
  final String name;

  /// URL-friendly identifier (e.g., "al-noor-riyadh").
  final String slug;

  /// Optional logo URL for the organization.
  final String? logoUrl;

  /// Optional description.
  final String? description;

  /// The user ID of the organization owner.
  final String ownerId;

  /// If this organization IS a campus (for single-campus orgs),
  /// this references the default campus ID.
  final String? campusId;

  /// Organization-level settings.
  final Map<String, dynamic> settings;

  /// Organization status.
  final OrgStatus status;

  /// Staff approval policy for this organization.
  /// Controls how staff members join: manual review, invite-only, or auto-approve.
  /// Defaults to [StaffApprovalPolicy.manual] if missing in Firestore.
  final StaffApprovalPolicy staffApprovalPolicy;

  /// Optional address.
  final String? address;

  /// Optional phone number.
  final String? phone;

  /// Optional email address.
  final String? email;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  /// Convenience getter — [tenantId] is always non-null for organizations.
  String get tenantIdOrThrow => tenantId!;

  const OrganizationData({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    required this.ownerId,
    this.campusId,
    this.settings = const {},
    required this.status,
    this.staffApprovalPolicy = StaffApprovalPolicy.manual,
    this.address,
    this.phone,
    this.email,
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
      slug: map['slug'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      description: map['description'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      campusId: map['campusId'] as String?,
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
      status: OrgStatus.fromId(map['status'] as String?),
      // Defensive: missing field defaults to manual
      staffApprovalPolicy: StaffApprovalPolicy.fromId(
          map['staffApprovalPolicy'] as String?),
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
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
      'slug': slug,
      'logoUrl': logoUrl,
      'description': description,
      'ownerId': ownerId,
      'campusId': campusId,
      'settings': settings,
      'status': status.id,
      'staffApprovalPolicy': staffApprovalPolicy.id,
      'address': address,
      'phone': phone,
      'email': email,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  OrganizationData copyWith({
    String? name,
    String? slug,
    String? logoUrl,
    String? description,
    String? ownerId,
    String? campusId,
    Map<String, dynamic>? settings,
    OrgStatus? status,
    StaffApprovalPolicy? staffApprovalPolicy,
    String? address,
    String? phone,
    String? email,
    DateTime? updatedAt,
  }) {
    return OrganizationData(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      campusId: campusId ?? this.campusId,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      staffApprovalPolicy: staffApprovalPolicy ?? this.staffApprovalPolicy,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPUS — A physical campus within an organization
// ═══════════════════════════════════════════════════════════════════════════════

/// Campus = A physical campus of an organization.
///
/// For single-campus schools, there is typically one campus record.
/// Multi-campus organizations create one [CampusData] per physical location.
class CampusData implements BaseModel {
  @override
  final String id;

  /// Links to the parent organization.
  @override
  final String? organizationId;

  /// Denormalized for fast queries — same as the parent organization's tenantId.
  @override
  final String? tenantId;

  /// Human-readable name (e.g., "Main Campus", "North Branch").
  final String name;

  /// Physical address of the campus.
  final String? address;

  /// Phone number for the campus.
  final String? phone;

  /// Email address for the campus.
  final String? email;

  /// Geographic latitude for map display.
  final double? latitude;

  /// Geographic longitude for map display.
  final double? longitude;

  /// The user ID of the campus manager.
  final String managerId;

  /// Campus-level settings.
  final Map<String, dynamic> settings;

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
    this.email,
    this.latitude,
    this.longitude,
    required this.managerId,
    this.settings = const {},
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
      email: map['email'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      managerId: map['managerId'] as String? ?? '',
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
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
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'managerId': managerId,
      'settings': settings,
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
    String? email,
    double? latitude,
    double? longitude,
    String? managerId,
    Map<String, dynamic>? settings,
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
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      managerId: managerId ?? this.managerId,
      settings: settings ?? this.settings,
      stageIds: stageIds ?? this.stageIds,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE — Academic stage/level within a campus (e.g., "Primary", "Grade 10")
// ═══════════════════════════════════════════════════════════════════════════════

/// Stage = An academic stage or level within a campus.
///
/// Stages group grades/classes under a common level. For example,
/// "Primary Stage" might contain Grades 1-6, while "Secondary Stage"
/// contains Grades 7-12.
class StageData implements BaseModel {
  @override
  final String id;

  @override
  final String? organizationId;

  @override
  final String? tenantId;

  @override
  final String? campusId;

  /// Human-readable name (e.g., "Primary", "Secondary", "Grade 10").
  final String name;

  /// Ordering index for display.
  final int sortOrder;

  /// IDs of grades under this stage.
  final List<String> gradeIds;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  const StageData({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    required this.campusId,
    required this.name,
    this.sortOrder = 0,
    this.gradeIds = const [],
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory StageData.fromMap(String id, Map<String, dynamic> map) {
    return StageData(
      id: id,
      organizationId: map['organizationId'] as String?,
      tenantId: map['tenantId'] as String?,
      campusId: map['campusId'] as String?,
      name: map['name'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      gradeIds: List<String>.from(map['gradeIds'] as List? ?? []),
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
      'campusId': campusId,
      'name': name,
      'sortOrder': sortOrder,
      'gradeIds': gradeIds,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  StageData copyWith({
    String? name,
    int? sortOrder,
    List<String>? gradeIds,
    DateTime? updatedAt,
  }) {
    return StageData(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      gradeIds: gradeIds ?? this.gradeIds,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRADE — A grade level within a stage (e.g., "Grade 5", "Year 3")
// ═══════════════════════════════════════════════════════════════════════════════

/// Grade = A specific grade level within a stage.
///
/// A grade belongs to a [StageData] and contains multiple class sections.
class GradeData implements BaseModel {
  @override
  final String id;

  @override
  final String? organizationId;

  @override
  final String? tenantId;

  @override
  final String? campusId;

  /// The stage this grade belongs to.
  final String stageId;

  /// Human-readable name (e.g., "Grade 5", "Year 3").
  final String name;

  /// Ordering index for display.
  final int sortOrder;

  /// IDs of classes (sections) under this grade.
  final List<String> classIds;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  const GradeData({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    required this.campusId,
    required this.stageId,
    required this.name,
    this.sortOrder = 0,
    this.classIds = const [],
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory GradeData.fromMap(String id, Map<String, dynamic> map) {
    return GradeData(
      id: id,
      organizationId: map['organizationId'] as String?,
      tenantId: map['tenantId'] as String?,
      campusId: map['campusId'] as String?,
      stageId: map['stageId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      classIds: List<String>.from(map['classIds'] as List? ?? []),
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
      'campusId': campusId,
      'stageId': stageId,
      'name': name,
      'sortOrder': sortOrder,
      'classIds': classIds,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  GradeData copyWith({
    String? name,
    int? sortOrder,
    List<String>? classIds,
    DateTime? updatedAt,
  }) {
    return GradeData(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      stageId: stageId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      classIds: classIds ?? this.classIds,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLASS SECTION — A class section within a grade (e.g., "5-A", "5-B")
// ═══════════════════════════════════════════════════════════════════════════════

/// ClassSection = A specific class section within a grade.
///
/// This represents the "Class" level in the hierarchy. Each class section
/// belongs to a [GradeData] and may contain multiple [GroupData] instances
/// for subject-based or ability-based grouping.
class ClassSectionData implements BaseModel {
  @override
  final String id;

  @override
  final String? organizationId;

  @override
  final String? tenantId;

  @override
  final String? campusId;

  /// The grade this class belongs to.
  final String gradeId;

  /// The stage this class belongs to (denormalized for fast queries).
  final String stageId;

  /// Human-readable name (e.g., "5-A", "5-B", "Science Section").
  final String name;

  /// IDs of groups within this class.
  final List<String> groupIds;

  /// IDs of teachers assigned to this class.
  final List<String> teacherIds;

  /// Number of students in this class.
  final int studentCount;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  const ClassSectionData({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    required this.campusId,
    required this.gradeId,
    required this.stageId,
    required this.name,
    this.groupIds = const [],
    this.teacherIds = const [],
    this.studentCount = 0,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory ClassSectionData.fromMap(String id, Map<String, dynamic> map) {
    return ClassSectionData(
      id: id,
      organizationId: map['organizationId'] as String?,
      tenantId: map['tenantId'] as String?,
      campusId: map['campusId'] as String?,
      gradeId: map['gradeId'] as String? ?? '',
      stageId: map['stageId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      groupIds: List<String>.from(map['groupIds'] as List? ?? []),
      teacherIds: List<String>.from(map['teacherIds'] as List? ?? []),
      studentCount: map['studentCount'] as int? ?? 0,
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
      'campusId': campusId,
      'gradeId': gradeId,
      'stageId': stageId,
      'name': name,
      'groupIds': groupIds,
      'teacherIds': teacherIds,
      'studentCount': studentCount,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  ClassSectionData copyWith({
    String? name,
    List<String>? groupIds,
    List<String>? teacherIds,
    int? studentCount,
    DateTime? updatedAt,
  }) {
    return ClassSectionData(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      gradeId: gradeId,
      stageId: stageId,
      name: name ?? this.name,
      groupIds: groupIds ?? this.groupIds,
      teacherIds: teacherIds ?? this.teacherIds,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROUP — A subject or ability group within a class (e.g., "Math Group A")
// ═══════════════════════════════════════════════════════════════════════════════

/// Group = A subject-based or ability-based group within a class section.
///
/// Groups allow for fine-grained management of students within a class,
/// such as advanced math groups, remedial reading groups, etc.
class GroupData implements BaseModel {
  @override
  final String id;

  @override
  final String? organizationId;

  @override
  final String? tenantId;

  @override
  final String? campusId;

  /// The class this group belongs to.
  final String classId;

  /// The grade this group belongs to (denormalized).
  final String gradeId;

  /// The stage this group belongs to (denormalized).
  final String stageId;

  /// Human-readable name (e.g., "Math Group A", "Advanced Science").
  final String name;

  /// Optional subject ID if this is a subject-specific group.
  final String? subjectId;

  /// IDs of students in this group.
  final List<String> studentIds;

  /// IDs of teachers assigned to this group.
  final List<String> teacherIds;

  @override
  final DateTime createdAt;

  @override
  final String? createdBy;

  @override
  final DateTime? updatedAt;

  const GroupData({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    required this.campusId,
    required this.classId,
    required this.gradeId,
    required this.stageId,
    required this.name,
    this.subjectId,
    this.studentIds = const [],
    this.teacherIds = const [],
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  /// Construct from a Firestore document map.
  factory GroupData.fromMap(String id, Map<String, dynamic> map) {
    return GroupData(
      id: id,
      organizationId: map['organizationId'] as String?,
      tenantId: map['tenantId'] as String?,
      campusId: map['campusId'] as String?,
      classId: map['classId'] as String? ?? '',
      gradeId: map['gradeId'] as String? ?? '',
      stageId: map['stageId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      subjectId: map['subjectId'] as String?,
      studentIds: List<String>.from(map['studentIds'] as List? ?? []),
      teacherIds: List<String>.from(map['teacherIds'] as List? ?? []),
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
      'campusId': campusId,
      'classId': classId,
      'gradeId': gradeId,
      'stageId': stageId,
      'name': name,
      'subjectId': subjectId,
      'studentIds': studentIds,
      'teacherIds': teacherIds,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  GroupData copyWith({
    String? name,
    String? subjectId,
    List<String>? studentIds,
    List<String>? teacherIds,
    DateTime? updatedAt,
  }) {
    return GroupData(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      classId: classId,
      gradeId: gradeId,
      stageId: stageId,
      name: name ?? this.name,
      subjectId: subjectId ?? this.subjectId,
      studentIds: studentIds ?? this.studentIds,
      teacherIds: teacherIds ?? this.teacherIds,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Klasivo Role Hierarchy
///
/// Tenant-level:
///   - superAdmin: Platform administrator across all tenants
///   - tenantOwner: Owner of a tenant (school chain, university system)
///
/// Organization-level:
///   - owner: Organization/school owner
///   - admin: Organization administrator
///   - academicManager: Manages academic programs and curricula
///   - campusManager: Manages a specific campus
///
/// Operational:
///   - stageSupervisor: Supervises a stage/level
///   - teacher: Teaches classes and manages exams
///   - assistantTeacher: Assists a teacher (limited permissions)
///   - student: Takes exams and views own data
///   - parent: Views linked student data
///   - observer: Read-only access for auditors/inspectors

/// The scope at which a role operates.
///
/// Roles with broader scopes implicitly have access to narrower scopes
/// within their hierarchy (e.g., an organization-scoped role can access
/// campus- and class-level resources within that organization).
enum RoleScope {
  /// Platform-wide across all tenants
  tenant,

  /// Within a single organization/school
  organization,

  /// Within a single campus of an organization
  campus,

  /// Within a single academic stage/level
  stage,

  /// Within a single class section
  class_,

  /// Only the individual's own data
  individual,
}

/// All roles in the Klasivo platform, ordered from highest to lowest privilege.
///
/// Each role carries an [id] (stored in Firestore), a human-readable
/// [displayName], and the [scope] at which it operates.
enum KlasivoRole {
  superAdmin('super_admin', 'Super Admin', scope: RoleScope.tenant),
  tenantOwner('tenant_owner', 'Tenant Owner', scope: RoleScope.tenant),
  owner('owner', 'Owner', scope: RoleScope.organization),
  admin('admin', 'Admin', scope: RoleScope.organization),
  academicManager('academic_manager', 'Academic Manager', scope: RoleScope.organization),
  campusManager('campus_manager', 'Campus Manager', scope: RoleScope.campus),
  stageSupervisor('stage_supervisor', 'Stage Supervisor', scope: RoleScope.stage),
  teacher('teacher', 'Teacher', scope: RoleScope.class_),
  assistantTeacher('assistant_teacher', 'Assistant Teacher', scope: RoleScope.class_),
  student('student', 'Student', scope: RoleScope.individual),
  parent('parent', 'Parent', scope: RoleScope.individual),
  observer('observer', 'Observer', scope: RoleScope.organization);

  const KlasivoRole(this.id, this.displayName, {required this.scope});

  /// The string identifier stored in Firestore documents.
  final String id;

  /// Human-readable name for display in the UI.
  final String displayName;

  /// The scope at which this role operates.
  final RoleScope scope;

  /// Look up a [KlasivoRole] by its Firestore [id].
  ///
  /// Returns `null` if no matching role is found.
  static KlasivoRole? fromId(String id) {
    for (final role in KlasivoRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }

  /// Whether this role has a scope that encompasses [otherScope].
  ///
  /// A broader scope (lower index in [RoleScope]) encompasses narrower ones.
  bool hasScope(RoleScope otherScope) {
    return scope.index <= otherScope.index;
  }

  /// Whether this role is at least as privileged as [other] in the hierarchy.
  ///
  /// This is determined by comparing the enum order (which is ordered from
  /// highest to lowest privilege) and the scope level.
  bool isAtLeast(KlasivoRole other) {
    return index <= other.index;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Unified Permission Constants
//
// Colon notation (e.g., 'exam:create') for hierarchical permissions.
// Wildcards: '*' = all permissions, 'exam:*' = all exam permissions.
//
// Categories:
//   Organization · Users · Students · Attendance · Assignments · Exams
//   Questions · Messaging · Analytics · Billing · Reports · Notifications
//   Stages · Classes · Subjects · Groups · Results
//   LMS (Lessons, Materials, Progress) · Parent · Integrity
//   ERP (Fees, Payments, Payroll, Inventory) · Staff Approval
// ═══════════════════════════════════════════════════════════════════════════════

/// Comprehensive permission constants for Klasivo RBAC v2.0.
///
/// Usage:
/// ```dart
/// if (permissionService.can(Permission.examCreate)) { ... }
/// if (permissionService.canAny([Permission.examCreate, Permission.examEdit])) { ... }
/// ```
class Permission {
  Permission._();

  // ─── Wildcard ──────────────────────────────────────────────────────────
  /// Grants all permissions across all organizations.
  static const String all = '*';

  // ─── Organization ──────────────────────────────────────────────────────
  static const String orgView = 'org:view';
  static const String orgEdit = 'org:edit';
  static const String orgDelete = 'org:delete';
  static const String orgSettings = 'org:settings';
  static const String orgManage = 'org:manage';
  static const String orgBilling = 'org:billing';
  static const String orgInvite = 'org:invite';
  static const String orgAudit = 'org:audit';

  // ─── Users ─────────────────────────────────────────────────────────────
  static const String userCreate = 'user:create';
  static const String userView = 'user:view';
  static const String userEdit = 'user:edit';
  static const String userDelete = 'user:delete';
  static const String userAssignRole = 'user:assign_role';
  static const String userManage = 'user:manage'; // Composite: create + edit + delete + assign_role

  // ─── Students ──────────────────────────────────────────────────────────
  static const String studentCreate = 'student:create';
  static const String studentView = 'student:view';
  static const String studentEdit = 'student:edit';
  static const String studentDelete = 'student:delete';
  static const String studentExport = 'student:export';

  // ─── Attendance ────────────────────────────────────────────────────────
  static const String attendanceView = 'attendance:view';
  static const String attendanceMark = 'attendance:mark';
  static const String attendanceEdit = 'attendance:edit';
  static const String attendanceDelete = 'attendance:delete';
  static const String attendanceExport = 'attendance:export';

  // ─── Assignments ───────────────────────────────────────────────────────
  static const String assignmentView = 'assignment:view';
  static const String assignmentCreate = 'assignment:create';
  static const String assignmentEdit = 'assignment:edit';
  static const String assignmentPublish = 'assignment:publish';
  static const String assignmentGrade = 'assignment:grade';
  static const String assignmentDelete = 'assignment:delete';
  static const String assignmentSubmit = 'assignment:submit';
  static const String assignmentExport = 'assignment:export';

  // ─── Exams ─────────────────────────────────────────────────────────────
  static const String examView = 'exam:view';
  static const String examCreate = 'exam:create';
  static const String examEdit = 'exam:edit';
  static const String examPublish = 'exam:publish';
  static const String examGrade = 'exam:grade';
  static const String examDelete = 'exam:delete';
  static const String examTake = 'exam:take';
  static const String examExport = 'exam:export';
  static const String examEditOwn = 'exam:edit_own';
  static const String examDeleteOwn = 'exam:delete_own';
  static const String examGradeOwn = 'exam:grade_own';

  // ─── Questions ─────────────────────────────────────────────────────────
  static const String questionView = 'question:view';
  static const String questionCreate = 'question:create';
  static const String questionEdit = 'question:edit';
  static const String questionDelete = 'question:delete';
  static const String questionEditOwn = 'question:edit_own';

  // ─── Messaging ─────────────────────────────────────────────────────────
  static const String messageSend = 'message:send';
  static const String messageReceive = 'message:receive';
  static const String messageBroadcast = 'message:broadcast';

  // ─── Analytics ─────────────────────────────────────────────────────────
  static const String analyticsView = 'analytics:view';
  static const String analyticsExport = 'analytics:export';

  // ─── Billing ───────────────────────────────────────────────────────────
  static const String billingView = 'billing:view';
  static const String billingManage = 'billing:manage';

  // ─── Reports ───────────────────────────────────────────────────────────
  static const String reportView = 'report:view';
  static const String reportGenerate = 'report:generate';
  static const String reportExport = 'report:export';

  // ─── Notifications ─────────────────────────────────────────────────────
  static const String notificationView = 'notification:view';
  static const String notificationSend = 'notification:send';
  static const String notificationManage = 'notification:manage';

  // ─── Stages ────────────────────────────────────────────────────────────
  static const String stageView = 'stage:view';
  static const String stageCreate = 'stage:create';
  static const String stageEdit = 'stage:edit';
  static const String stageDelete = 'stage:delete';

  // ─── Classes ───────────────────────────────────────────────────────────
  static const String classView = 'class:view';
  static const String classCreate = 'class:create';
  static const String classEdit = 'class:edit';
  static const String classDelete = 'class:delete';

  // ─── Subjects ──────────────────────────────────────────────────────────
  static const String subjectView = 'subject:view';
  static const String subjectCreate = 'subject:create';
  static const String subjectEdit = 'subject:edit';
  static const String subjectDelete = 'subject:delete';

  // ─── Groups ────────────────────────────────────────────────────────────
  static const String groupView = 'group:view';
  static const String groupCreate = 'group:create';
  static const String groupEdit = 'group:edit';
  static const String groupDelete = 'group:delete';

  // ─── Results ───────────────────────────────────────────────────────────
  static const String resultView = 'result:view';
  static const String resultExport = 'result:export';
  static const String resultViewOwn = 'result:view_own';

  // ─── LMS: Lessons ──────────────────────────────────────────────────────
  static const String lessonView = 'lesson:view';
  static const String lessonCreate = 'lesson:create';
  static const String lessonEdit = 'lesson:edit';
  static const String lessonDelete = 'lesson:delete';

  // ─── LMS: Materials ────────────────────────────────────────────────────
  static const String materialView = 'material:view';
  static const String materialUpload = 'material:upload';
  static const String materialDelete = 'material:delete';

  // ─── LMS: Progress ─────────────────────────────────────────────────────
  static const String progressView = 'progress:view';
  static const String progressViewOwn = 'progress:view_own';

  // ─── Parent ────────────────────────────────────────────────────────────
  static const String parentLink = 'parent:link';
  static const String parentView = 'parent:view';
  static const String parentViewOwnChildren = 'parent:view_own_children';
  static const String parentViewOwnChildrenProgress =
      'parent:view_own_children_progress';

  // ─── Integrity ─────────────────────────────────────────────────────────
  static const String integrityView = 'integrity:view';
  static const String integrityManage = 'integrity:manage';

  // ─── ERP: Fees ─────────────────────────────────────────────────────────
  static const String feesView = 'fees:view';
  static const String feesManage = 'fees:manage';

  // ─── ERP: Payments ─────────────────────────────────────────────────────
  static const String paymentsView = 'payments:view';
  static const String paymentsManage = 'payments:manage';

  // ─── ERP: Payroll ──────────────────────────────────────────────────────
  static const String payrollView = 'payroll:view';
  static const String payrollManage = 'payroll:manage';

  // ─── ERP: Inventory ────────────────────────────────────────────────────
  static const String inventoryView = 'inventory:view';
  static const String inventoryManage = 'inventory:manage';

  // ─── Staff Approval ───────────────────────────────────────────────────
  /// Approve a pending staff application.
  static const String staffApprove = 'staff:approve';

  /// Reject a pending staff application.
  static const String staffReject = 'staff:reject';

  /// Revoke access for an approved staff member.
  static const String staffRevoke = 'staff:revoke';

  /// Send an invitation to a prospective staff member.
  static const String staffInvite = 'staff:invite';

  /// View staff applications (pending and historical).
  static const String staffViewApplications = 'staff:view_applications';

  // ═══════════════════════════════════════════════════════════════════════
  // Category helpers
  // ═══════════════════════════════════════════════════════════════════════

  /// Extract the category prefix from a permission string.
  /// Example: 'exam:create' → 'exam'
  static String categoryOf(String permission) {
    final idx = permission.indexOf(':');
    if (idx == -1) return permission;
    return permission.substring(0, idx);
  }

  /// Build a category wildcard.
  /// Example: 'exam' → 'exam:*'
  static String wildcardFor(String category) => '$category:*';

  // ═══════════════════════════════════════════════════════════════════════
  // Complete list (for iteration, validation, and UI display)
  // ═══════════════════════════════════════════════════════════════════════

  static const List<String> allPermissions = [
    // Organization
    orgView, orgEdit, orgDelete, orgSettings, orgManage, orgBilling, orgInvite, orgAudit,
    // Users
    userCreate, userView, userEdit, userDelete, userAssignRole, userManage,
    // Students
    studentCreate, studentView, studentEdit, studentDelete, studentExport,
    // Attendance
    attendanceView, attendanceMark, attendanceEdit, attendanceDelete, attendanceExport,
    // Assignments
    assignmentView, assignmentCreate, assignmentEdit, assignmentPublish, assignmentGrade, assignmentDelete, assignmentSubmit, assignmentExport,
    // Exams
    examView, examCreate, examEdit, examPublish, examGrade, examDelete, examTake, examExport, examEditOwn, examDeleteOwn, examGradeOwn,
    // Questions
    questionView, questionCreate, questionEdit, questionDelete, questionEditOwn,
    // Messaging
    messageSend, messageReceive, messageBroadcast,
    // Analytics
    analyticsView, analyticsExport,
    // Billing
    billingView, billingManage,
    // Reports
    reportView, reportGenerate, reportExport,
    // Notifications
    notificationView, notificationSend, notificationManage,
    // Stages
    stageView, stageCreate, stageEdit, stageDelete,
    // Classes
    classView, classCreate, classEdit, classDelete,
    // Subjects
    subjectView, subjectCreate, subjectEdit, subjectDelete,
    // Groups
    groupView, groupCreate, groupEdit, groupDelete,
    // Results
    resultView, resultExport, resultViewOwn,
    // LMS: Lessons
    lessonView, lessonCreate, lessonEdit, lessonDelete,
    // LMS: Materials
    materialView, materialUpload, materialDelete,
    // LMS: Progress
    progressView, progressViewOwn,
    // Parent
    parentLink, parentView, parentViewOwnChildren, parentViewOwnChildrenProgress,
    // Integrity
    integrityView, integrityManage,
    // ERP: Fees
    feesView, feesManage,
    // ERP: Payments
    paymentsView, paymentsManage,
    // ERP: Payroll
    payrollView, payrollManage,
    // ERP: Inventory
    inventoryView, inventoryManage,
    // Staff Approval
    staffApprove, staffReject, staffRevoke, staffInvite, staffViewApplications,
  ];

  /// Category → permissions mapping (for UI grouping)
  static const Map<String, List<String>> categories = {
    'organization': [orgView, orgEdit, orgDelete, orgSettings, orgManage, orgBilling, orgInvite, orgAudit],
    'users': [userCreate, userView, userEdit, userDelete, userAssignRole, userManage],
    'students': [studentCreate, studentView, studentEdit, studentDelete, studentExport],
    'attendance': [attendanceView, attendanceMark, attendanceEdit, attendanceDelete, attendanceExport],
    'assignments': [assignmentView, assignmentCreate, assignmentEdit, assignmentPublish, assignmentGrade, assignmentDelete, assignmentSubmit, assignmentExport],
    'exams': [examView, examCreate, examEdit, examPublish, examGrade, examDelete, examTake, examExport, examEditOwn, examDeleteOwn, examGradeOwn],
    'questions': [questionView, questionCreate, questionEdit, questionDelete, questionEditOwn],
    'messaging': [messageSend, messageReceive, messageBroadcast],
    'analytics': [analyticsView, analyticsExport],
    'billing': [billingView, billingManage],
    'reports': [reportView, reportGenerate, reportExport],
    'notifications': [notificationView, notificationSend, notificationManage],
    'stages': [stageView, stageCreate, stageEdit, stageDelete],
    'classes': [classView, classCreate, classEdit, classDelete],
    'subjects': [subjectView, subjectCreate, subjectEdit, subjectDelete],
    'groups': [groupView, groupCreate, groupEdit, groupDelete],
    'results': [resultView, resultExport, resultViewOwn],
    'lessons': [lessonView, lessonCreate, lessonEdit, lessonDelete],
    'materials': [materialView, materialUpload, materialDelete],
    'progress': [progressView, progressViewOwn],
    'parent': [parentLink, parentView, parentViewOwnChildren, parentViewOwnChildrenProgress],
    'integrity': [integrityView, integrityManage],
    'fees': [feesView, feesManage],
    'payments': [paymentsView, paymentsManage],
    'payroll': [payrollView, payrollManage],
    'inventory': [inventoryView, inventoryManage],
    'staff': [staffApprove, staffReject, staffRevoke, staffInvite, staffViewApplications],
  };
}

import 'app_environment.dart';

class AppConstants {
  // Local Storage
  static const String authBox = 'auth_box';

  // ─── Firebase Collections ────────────────────────────────────────────────

  // Core
  static const String organizationsCollection = 'organizations';
  static const String usersCollection = 'users';
  static const String studentsCollection = 'users'; // Students ARE users (same collection, role='student')
  static const String inviteCodesCollection = 'invite_codes';

  // Academic Structure
  static const String stagesCollection = 'stages';
  static const String classesCollection = 'classes';
  static const String subjectsCollection = 'subjects';
  static const String groupsCollection = 'groups';
  static const String groupMembersCollection = 'group_members';
  static const String teacherAssignmentsCollection = 'teacher_assignments';

  // Students (stored in users collection with role='student')
  // No separate students collection — students ARE users

  // Exams
  static const String examsCollection = 'exams';
  static const String questionsCollection = 'questions';
  static const String questionBankCollection = 'question_banks';
  static const String examAttemptsCollection = 'exam_attempts';
  static const String submissionsCollection = 'submissions';
  static const String answersCollection = 'answers';
  static const String examStatsCollection = 'exam_stats';
  static const String violationsCollection = 'violations';

  // Assignments
  static const String assignmentsCollection = 'assignments';
  static const String assignmentSubmissionsCollection = 'assignment_submissions';

  // Attendance
  static const String attendanceCollection = 'attendance';

  // Messaging
  static const String conversationsCollection = 'conversations';
  static const String messagesCollection = 'messages';

  // Analytics
  static const String analyticsCacheCollection = 'analytics_cache';

  // Communication
  static const String notificationsCollection = 'notifications';

  // ─── v1.7+ Collections ──────────────────────────────────────────────────

  // LMS (Units → Lessons → Materials)
  static const String unitsCollection = 'units';
  static const String materialsCollection = 'materials';
  static const String lessonsCollection = 'lessons';
  static const String lessonPlansCollection = 'lesson_plans';
  static const String resourcesCollection = 'resources';
  static const String contentProgressCollection = 'content_progress';
  static const String progressTrackingCollection = 'progress_tracking';
  static const String moderationQueueCollection = 'moderation_queue';

  // Parent Portal
  static const String parentLinksCollection = 'parent_links';
  static const String parentNotificationsCollection = 'parent_notifications';

  // Enterprise
  static const String featureFlagsCollection = 'feature_flags';
  static const String permissionsCollection = 'permissions';
  static const String auditLogCollection = 'audit_log';
  static const String auditLogsCollection = 'audit_logs'; // Alias used by AuditLogService
  static const String academicYearsCollection = 'academic_years';
  static const String campusesCollection = 'campuses';
  static const String announcementsCollection = 'announcements';
  static const String calendarEventsCollection = 'calendar_events';
  static const String gradebookCollection = 'gradebook';

  // v1.9 ERP Collections
  static const String feesCollection = 'fees';
  static const String feeStructuresCollection = 'fee_structures';
  static const String paymentsCollection = 'payments';
  static const String payrollCollection = 'payroll';
  static const String inventoryCollection = 'inventory';

  // ─── User Roles (v1.7+: 8 roles for granular RBAC) ─────────────────────────

  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
  static const String roleTeacher = 'teacher';
  static const String roleStudent = 'student';
  static const String roleParent = 'parent';
  static const String roleCampusManager = 'campus_manager';
  static const String roleObserver = 'observer';
  static const String roleSuperAdmin = 'super_admin';

  // ─── Navigation Tabs ─────────────────────────────────────────────────────
  // Dashboard / Academic / People / Inbox / Settings

  static const int tabDashboard = 0;
  static const int tabAcademic = 1;
  static const int tabPeople = 2;
  static const int tabInbox = 3;
  static const int tabSettings = 4;

  // ─── App Route Paths ─────────────────────────────────────────────────────

  // Auth
  static const String routeSplash = '/';
  static const String routeAuth = '/auth';
  static const String routeTeacherLogin = '/auth/teacher-login';
  static const String routeTeacherRegister = '/auth/teacher-register';
  static const String routeOwnerRegister = '/auth/owner-register';
  static const String routeStudentLogin = '/auth/student-login';
  static const String routeParentRegister = '/auth/parent-register';
  static const String routeWelcome = '/welcome'; // Post-login org naming

  // Owner/Teacher Shell
  static const String routeDashboard = '/dashboard';
  static const String routeAcademic = '/academic';
  static const String routePeople = '/people';
  static const String routeInbox = '/inbox';
  static const String routeSettings = '/settings';

  // Academic sub-routes
  static const String routeStages = '/academic/stages';
  static const String routeClasses = '/academic/classes';
  static const String routeSubjects = '/academic/subjects';
  static const String routeExams = '/academic/exams';
  static const String routeAssignments = '/academic/assignments';
  static const String routeAttendance = '/academic/attendance';

  // Inbox sub-routes (Messages + Notifications + Announcements)
  static const String routeNotifications = '/inbox/notifications';
  static const String routeNotificationDetail = '/inbox/notifications/:id';
  static const String routeMessages = '/inbox/messages';
  static const String routeConversation = '/inbox/messages/:id';
  static const String routeAnnouncements = '/inbox/announcements';

  // Calendar
  static const String routeCalendar = '/calendar';
  static const String routeCalendarEventCreate = '/calendar/create';

  // Academic Years
  static const String routeAcademicYears = '/academic/years';
  static const String routeAcademicYearCreate = '/academic/years/create';

  // Audit Logs
  static const String routeAuditLog = '/settings/audit-log';

  // People sub-routes
  static const String routeTeachers = '/people/teachers';
  static const String routeStudents = '/people/students';
  static const String routeInviteCodes = '/people/invites';

  // Settings sub-routes
  static const String routeOrganization = '/settings/organization';
  static const String routeProfile = '/settings/profile';

  // Student Shell
  static const String routeStudentHome = '/student';
  static const String routeStudentExams = '/student/exams';
  static const String routeStudentResults = '/student/results';
  static const String routeStudentInbox = '/student/inbox';
  static const String routeStudentSettings = '/student/settings';

  // Deep link routes
  static const String routeJoin = '/join';
  static const String routeExamDeep = '/exam';
  static const String routeResultDeep = '/result';
  static const String routeOrgPortal = '/org';
  static const String routeReset = '/reset';
  static const String routeVerify = '/verify';

  // ─── v1.7+ Route Paths ──────────────────────────────────────────────────

  // LMS Routes
  static const String routeLms = '/lms';
  static const String routeContentBrowser = '/academic/lms/content';
  static const String routeLessonManager = '/academic/lms/lessons';
  static const String routeLessonDetail = '/academic/lms/lessons/:lessonId';

  // Parent Routes
  static const String routeParentHome = '/parent';
  static const String routeParentResults = '/parent/results';
  static const String routeParentAttendance = '/parent/attendance';
  static const String routeParentAssignments = '/parent/assignments';
  static const String routeParentProgress = '/parent/progress';
  static const String routeParentAnnouncements = '/parent/announcements';
  static const String routeParentProfile = '/parent/profile';
  static const String routeParentLogin = '/auth/parent-login';
  static const String routeParentLink = '/auth/parent-link';
  static const String routeParentDashboard = '/parent';
  static const String routeParentOnboarding = '/parent/onboarding';

  // v1.8 Routes
  static const String routeGlobalSearch = '/search';
  static const String routeSetupWizard = '/setup';
  static const String routeCommunicationHub = '/inbox/communication';

  // ─── Exam Status ─────────────────────────────────────────────────────────

  static const String statusDraft = 'draft';
  static const String statusPublished = 'published';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';

  // ─── Question Types ──────────────────────────────────────────────────────

  static const String questionTypeMultipleChoice = 'multiple_choice';
  static const String questionTypeTrueFalse = 'true_false';
  static const String questionTypeShortAnswer = 'short_answer';

  // ─── Question Difficulty ─────────────────────────────────────────────────

  static const String difficultyEasy = 'easy';
  static const String difficultyMedium = 'medium';
  static const String difficultyHard = 'hard';

  // ─── Gradebook Category Types ────────────────────────────────────────────

  static const String categoryExam = 'exam';
  static const String categoryHomework = 'homework';
  static const String categoryQuiz = 'quiz';
  static const String categoryParticipation = 'participation';
  static const String categoryProject = 'project';
  static const String categoryFinal = 'final';

  // ─── Parent Link Status ────────────────────────────────────────────────────

  static const String parentLinkPending = 'pending';
  static const String parentLinkApproved = 'approved';
  static const String parentLinkRevoked = 'revoked';

  // ─── Submission Status ───────────────────────────────────────────────────

  static const String submissionStatusStarted = 'started';
  static const String submissionStatusSubmitted = 'submitted';
  static const String submissionStatusFlagged = 'flagged';

  // ─── Assignment Status ───────────────────────────────────────────────────

  static const String assignmentStatusDraft = 'draft';
  static const String assignmentStatusPublished = 'published';
  static const String assignmentStatusSubmitted = 'submitted';
  static const String assignmentStatusGraded = 'graded';

  // ─── Invite Code Types ───────────────────────────────────────────────────

  static const String inviteTypeTeacher = 'teacher';
  static const String inviteTypeStudent = 'student';

  // ─── Violation Types ─────────────────────────────────────────────────────

  static const String violationAppMinimized = 'app_minimized';
  static const String violationAppSwitched = 'app_switched';
  static const String violationScreenOff = 'screen_off';
  static const String violationScreenshotAttempt = 'screenshot_attempt';
  static const String violationScreenRecording = 'screen_recording';
  static const String violationMultipleLogin = 'multiple_login';
  static const String violationClipboardActivity = 'clipboard_activity';
  static const String violationBackNavigation = 'back_navigation';
  static const String violationIdleTimeout = 'idle_timeout';

  // ─── Attendance Status ────────────────────────────────────────────────────

  static const String attendanceStatusPresent = 'present';
  static const String attendanceStatusAbsent = 'absent';
  static const String attendanceStatusLate = 'late';
  static const String attendanceStatusExcused = 'excused';

  // ─── Notification Types ──────────────────────────────────────────────────

  static const String notificationExamPublished = 'exam_published';
  static const String notificationExamReminder = 'exam_reminder';
  static const String notificationResultPublished = 'result_published';
  static const String notificationAnnouncement = 'announcement';
  static const String notificationViolation = 'violation';
  static const String notificationNewMessage = 'new_message';
  static const String notificationAssignmentPublished = 'assignment_published';
  static const String notificationAssignmentGraded = 'assignment_graded';
  static const String notificationAttendance = 'attendance';
  static const String notificationTeacherInvited = 'teacher_invited';
  static const String notificationStudentJoined = 'student_joined';
  static const String notificationOrgUpdate = 'org_update';

  // ─── v1.7+ Notification Types ───────────────────────────────────────────

  static const String notificationLessonCreated = 'lesson_created';
  static const String notificationMaterialUploaded = 'material_uploaded';
  static const String notificationProgressUpdate = 'progress_update';
  static const String notificationParentLinked = 'parent_linked';
  static const String notificationParentMessage = 'parent_message';
  static const String notificationFeeDue = 'fee_due';
  static const String notificationPaymentReceived = 'payment_received';

  // ─── Calendar Event Types ──────────────────────────────────────────────

  static const String calendarEventExam = 'exam';
  static const String calendarEventAssignment = 'assignment';
  static const String calendarEventHoliday = 'holiday';
  static const String calendarEventEvent = 'event';
  static const String calendarEventMeeting = 'meeting';
  static const String calendarEventDeadline = 'deadline';

  // ─── Audit Log Actions ────────────────────────────────────────────────

  static const String auditActionCreate = 'create';
  static const String auditActionUpdate = 'update';
  static const String auditActionDelete = 'delete';
  static const String auditActionPublish = 'publish';
  static const String auditActionArchive = 'archive';
  static const String auditActionSubmit = 'submit';
  static const String auditActionGrade = 'grade';
  static const String auditActionLink = 'link';
  static const String auditActionRevoke = 'revoke';

  // ─── Material Types (v1.7 LMS) ──────────────────────────────────────────

  static const String materialTypeVideo = 'video';
  static const String materialTypeDocument = 'document';
  static const String materialTypeLink = 'link';
  static const String materialTypeImage = 'image';
  static const String materialTypeAudio = 'audio';
  static const String materialTypeEmbedded = 'embedded';

  // ─── Academic Year Status ────────────────────────────────────────────────

  static const String academicYearUpcoming = 'upcoming';
  static const String academicYearActive = 'active';
  static const String academicYearArchived = 'archived';

  // ─── Analytics Types ──────────────────────────────────────────────────────

  static const String analyticsTypeStudent = 'student';
  static const String analyticsTypeClass = 'class';
  static const String analyticsTypeTeacher = 'teacher';

  // ─── Domain & Deep Links ──────────────────────────────────────────────────

  static const String appDomain = 'klasivo.app';
  static const String appBaseUrl = 'https://klasivo.app';
  static const String apiSubdomain = 'api.klasivo.app';
  static const String apiBaseUrl = 'https://api.klasivo.app/v1';

  // Deep link paths
  static const String pathJoin = '/join';         // /join/{code}
  static const String pathExam = '/exam';          // /exam/{examId}
  static const String pathResult = '/result';      // /result/{code}
  static const String pathOrg = '/org';            // /org/{slug}
  static const String pathReset = '/reset';        // /reset
  static const String pathVerify = '/verify';      // /verify
  static const String pathNotifications = '/notifications'; // /notifications
  static const String pathNotification = '/notification';   // /notification/{id}

  // Professional email addresses
  static const String supportEmail = 'support@klasivo.app';
  static const String adminEmail = 'admin@klasivo.app';
  static const String accountsEmail = 'accounts@klasivo.app';
  static const String helloEmail = 'hello@klasivo.app';

  // Deep link parameter keys
  static const String paramCode = 'code';
  static const String paramOrgId = 'orgId';
  static const String paramExamId = 'examId';
  static const String paramResultId = 'resultId';
  static const String paramSlug = 'slug';
  static const String paramInviteCode = 'inviteCode';
  static const String paramRole = 'role';
  static const String paramNotificationId = 'notificationId';

  // Firebase Dynamic Links / App Links configuration
  static const String androidPackageName = 'com.klasivo.app';
  static const String iosBundleId = 'com.klasivo.app';
  static const String dynamicLinkDomain = 'klasivo.page.link';
  static const String deepLinkScheme = 'klasivo';

  // ─── Config ──────────────────────────────────────────────────────────────

  static const int autoSaveInterval = 5;
  static const int violationThreshold = 3;
  static const String defaultStudentPassword = '123456';
  static const int maxMessageLength = 2000;
  static const int analyticsCacheDurationHours = 1;
  static const int inviteCodeLength = 8;
  static const int maxSlugLength = 40;
  static const int notificationsPageSize = 50;

  // ─── Timing (seconds) ───────────────────────────────────────────────────

  /// Splash screen display duration before navigation
  static const int splashDurationSeconds = 2;
  /// Default toast/snackbar display duration
  static const int toastDurationSeconds = 3;
  /// Clipboard monitoring check interval during exams
  static const int clipboardCheckIntervalSeconds = 2;
  /// Connectivity ping interval (Firestore health check)
  static const int connectivityPingIntervalSeconds = 30;
  /// Threshold for "poor" connectivity detection
  static const int poorConnectivityThresholdSeconds = 2;
  /// Sync indicator animation duration
  static const int syncIndicatorAnimSeconds = 1;
  /// Sync queue batch size per cycle
  static const int syncBatchSize = 10;
  /// Max retry attempts before dead-lettering a sync queue entry
  static const int syncMaxRetries = 5;
  /// Image cache max size in MB
  static const int imageCacheMaxSizeMB = 100;
  /// Firestore cache size in MB
  static const int firestoreCacheSizeMB = 100;

  // ─── Environment ────────────────────────────────────────────────────────

  /// The name of the current environment ("dev", "staging", or "prod").
  static String get environmentName =>
      EnvironmentConfig.current.environment.name;

  /// Convenience: `true` when the app is running in the dev environment.
  static bool get isDevEnvironment => EnvironmentConfig.current.isDev;

  // ─── Default Values ──────────────────────────────────────────────────────

  /// Environment-aware default institution ID.
  /// Both dev and prod use 'default'; the prefix isolation is handled
  /// via [EnvironmentConfig.databasePrefix] at the collection level.
  static String get defaultInstitutionId => 'default';

  // ─── Extra Collections (referenced by services) ─────────────────────────

  static const String examInstancesCollection = 'exam_instances';
}

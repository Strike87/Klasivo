// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ROUTE NAMES — Centralized route path constants
// Extracted from app_constants.dart for clean separation of concerns.
// ═══════════════════════════════════════════════════════════════════════════════

class RouteNames {
  RouteNames._();

  // ─── Auth ──────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String auth = '/auth';
  static const String teacherLogin = '/auth/teacher-login';
  static const String teacherRegister = '/auth/teacher-register';
  static const String ownerRegister = '/auth/owner-register';
  static const String studentLogin = '/auth/student-login';
  static const String parentRegister = '/auth/parent-register';
  static const String welcome = '/welcome';

  // ─── Owner/Teacher Shell ───────────────────────────────────────────────
  static const String dashboard = '/dashboard';
  static const String academic = '/academic';
  static const String people = '/people';
  static const String inbox = '/inbox';
  static const String settings = '/settings';

  // ─── Academic sub-routes ───────────────────────────────────────────────
  static const String stages = '/academic/stages';
  static const String classes = '/academic/classes';
  static const String subjects = '/academic/subjects';
  static const String exams = '/academic/exams';
  static const String assignments = '/academic/assignments';
  static const String attendance = '/academic/attendance';

  // ─── Inbox sub-routes ──────────────────────────────────────────────────
  static const String notifications = '/inbox/notifications';
  static const String notificationDetail = '/inbox/notifications/:id';
  static const String messages = '/inbox/messages';
  static const String conversation = '/inbox/messages/:id';
  static const String announcements = '/inbox/announcements';

  // ─── Calendar ──────────────────────────────────────────────────────────
  static const String calendar = '/calendar';
  static const String calendarEventCreate = '/calendar/create';

  // ─── Academic Years ────────────────────────────────────────────────────
  static const String academicYears = '/academic/years';
  static const String academicYearCreate = '/academic/years/create';

  // ─── Audit Logs ────────────────────────────────────────────────────────
  static const String auditLog = '/settings/audit-log';

  // ─── People sub-routes ─────────────────────────────────────────────────
  static const String teachers = '/people/teachers';
  static const String students = '/people/students';
  static const String inviteCodes = '/people/invites';

  // ─── Settings sub-routes ───────────────────────────────────────────────
  static const String organization = '/settings/organization';
  static const String profile = '/settings/profile';

  // ─── Student Shell ─────────────────────────────────────────────────────
  static const String studentHome = '/student';
  static const String studentExams = '/student/exams';
  static const String studentResults = '/student/results';
  static const String studentInbox = '/student/inbox';
  static const String studentSettings = '/student/settings';

  // ─── Deep link routes ──────────────────────────────────────────────────
  static const String join = '/join';
  static const String examDeep = '/exam';
  static const String resultDeep = '/result';
  static const String orgPortal = '/org';
  static const String reset = '/reset';
  static const String verify = '/verify';

  // ─── LMS Routes ────────────────────────────────────────────────────────
  static const String lms = '/lms';
  static const String contentBrowser = '/academic/lms/content';
  static const String lessonManager = '/academic/lms/lessons';
  static const String lessonDetail = '/academic/lms/lessons/:lessonId';

  // ─── Parent Routes ─────────────────────────────────────────────────────
  static const String parentHome = '/parent';
  static const String parentResults = '/parent/results';
  static const String parentAttendance = '/parent/attendance';
  static const String parentAssignments = '/parent/assignments';
  static const String parentProgress = '/parent/progress';
  static const String parentAnnouncements = '/parent/announcements';
  static const String parentProfile = '/parent/profile';
  static const String parentLogin = '/auth/parent-login';
  static const String parentLink = '/auth/parent-link';
  static const String parentDashboard = '/parent';
  static const String parentOnboarding = '/parent/onboarding';

  // ─── v1.8 Routes ───────────────────────────────────────────────────────
  static const String globalSearch = '/search';
  static const String setupWizard = '/setup';
  static const String communicationHub = '/inbox/communication';
}

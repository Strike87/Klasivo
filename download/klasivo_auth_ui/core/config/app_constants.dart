import 'package:flutter/widgets.dart';

/// App-wide route path constants used by GoRouter.
class AppRoutes {
  AppRoutes._();

  // ── Auth ──
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String orgNaming = '/org-naming';
  static const String studentLogin = '/student-login';

  // ── Teacher Shell (5-tab bottom navigation) ──
  static const String dashboard = '/dashboard';
  static const String academic = '/academic';
  static const String people = '/people';
  static const String inbox = '/inbox';
  static const String settings = '/settings';

  // ── Student Shell ──
  static const String studentDashboard = '/student-dashboard';

  // ── Academic Sub-routes ──
  static const String stageList = '/academic/stages';
  static const String gradeList = '/academic/grades';
  static const String groupList = '/academic/groups';
  static const String classList = '/academic/classes';
  static const String classForm = '/academic/classes/form';
  static const String classDetail = '/academic/classes/:classId';

  // ── Exam Sub-routes ──
  static const String examList = '/academic/exams';
  static const String examForm = '/academic/exams/form';
  static const String examDetail = '/academic/exams/:examId';

  // ── People Sub-routes ──
  static const String allStudents = '/people/students';
  static const String studentForm = '/people/students/form';
  static const String studentDetail = '/people/students/:studentId';
  static const String excelImport = '/people/students/import';

  // ── Inbox ──
  static const String notificationCenter = '/inbox/notifications';
  static const String notificationDetail = '/inbox/notifications/:notificationId';
}

/// Navigation tab configuration for the 5-tab bottom navigation.
class NavTab {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// Note: NavTab list requires Flutter's IconData, so it's defined
// in the shell/navigation widget file, not here.

/// Firestore collection names
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String organizations = 'organizations';
  static const String stages = 'stages';
  static const String grades = 'grades';
  static const String groups = 'groups';
  static const String classes = 'classes';
  static const String exams = 'exams';
  static const String examResults = 'exam_results';
  static const String notifications = 'notifications';

  // Aliases
  static const String studentsCollection = users; // Students ARE users
}

/// Notification types for auto-generated notifications
class NotificationTypes {
  NotificationTypes._();

  static const String examCreated = 'exam_created';
  static const String examUpdated = 'exam_updated';
  static const String examPublished = 'exam_published';
  static const String examResultAvailable = 'exam_result_available';
  static const String studentAdded = 'student_added';
  static const String studentRemoved = 'student_removed';
  static const String classCreated = 'class_created';
  static const String classUpdated = 'class_updated';
  static const String stageCreated = 'stage_created';
  static const String gradeCreated = 'grade_created';
}

/// User roles
class UserRoles {
  UserRoles._();

  static const String owner = 'owner';
  static const String teacher = 'teacher';
  static const String student = 'student';
}

/// Deep link paths
class DeepLinkPaths {
  DeepLinkPaths._();

  static const String exam = '/exam';
  static const String classGroup = '/class';
  static const String result = '/result';
}

/// Klasivo v2.0 - Route constants
/// 
/// All route paths and names defined as constants
/// for type-safe navigation throughout the app.
/// Used by app/router.dart and GoRouter configuration.
library;

/// Top-level route paths
class AppRoutes {
  // Auth
  static const String splash = "/";
  static const String welcome = "/welcome";
  static const String login = "/login";
  static const String register = "/register";
  static const String forgotPassword = "/forgot-password";
  static const String roleSelection = "/role-selection";

  // Teacher
  static const String teacherHome = "/teacher";
  static const String teacherExams = "/teacher/exams";
  static const String teacherClasses = "/teacher/classes";
  static const String teacherStudents = "/teacher/students";
  static const String teacherAttendance = "/teacher/attendance";
  static const String teacherAssignments = "/teacher/assignments";
  static const String teacherAnalytics = "/teacher/analytics";
  static const String teacherMessaging = "/teacher/messaging";

  // Student
  static const String studentHome = "/student";
  static const String studentExams = "/student/exams";
  static const String studentAssignments = "/student/assignments";

  // Parent
  static const String parentHome = "/parent";
  static const String parentLink = "/parent/link";

  // Owner
  static const String ownerHome = "/owner";
  static const String ownerSettings = "/owner/settings";

  // LiveKit (Sprint 1+2)
  static const String scheduledClasses = "/live-classes";
  static const String liveClassLobby = "/live-classes/:roomId/lobby";
  static const String liveClassRoom = "/live-classes/:roomId";
  static const String sessionAnalytics = "/live-classes/:roomId/analytics";

  // User Management (Sprint 1+2)
  static const String peopleHub = "/people";
  static const String userDetail = "/people/users/:userId";
  static const String roleMatrix = "/people/roles";

  // Shared
  static const String notifications = "/notifications";
  static const String settings = "/settings";
  static const String profile = "/profile";
}


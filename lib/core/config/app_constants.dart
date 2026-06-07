class AppConstants {
  // Local Storage
  static const String authBox = 'auth_box';

  // ─── Firebase Collections ────────────────────────────────────────────────

  // Core
  static const String organizationsCollection = 'organizations';
  static const String usersCollection = 'users';
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

  // Communication
  static const String notificationsCollection = 'notifications';

  // ─── User Roles ──────────────────────────────────────────────────────────

  static const String roleOwner = 'owner';
  static const String roleTeacher = 'teacher';
  static const String roleStudent = 'student';

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

  // ─── Notification Types ──────────────────────────────────────────────────

  static const String notificationExamPublished = 'exam_published';
  static const String notificationExamReminder = 'exam_reminder';
  static const String notificationResultPublished = 'result_published';
  static const String notificationAnnouncement = 'announcement';
  static const String notificationViolation = 'violation';

  // ─── Config ──────────────────────────────────────────────────────────────

  // Auto-save interval (seconds)
  static const int autoSaveInterval = 5;

  // Violation threshold
  static const int violationThreshold = 3;

  // Default student password (before hashing)
  static const String defaultStudentPassword = '123456';
}

class AppConstants {
  // Local Storage
  static const String authBox = 'auth_box';

  // Default Institution ID
  static const String defaultInstitutionId = 'default';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String studentsCollection = 'students';
  static const String classesCollection = 'classes';
  static const String examsCollection = 'exams';
  static const String questionsCollection = 'questions';
  static const String submissionsCollection = 'submissions';
  static const String answersCollection = 'answers';
  static const String stagesCollection = 'stages';
  static const String gradesCollection = 'grades';
  static const String groupsCollection = 'groups';
  static const String questionBankCollection = 'question_bank';
  static const String violationsCollection = 'violations';
  static const String notificationsCollection = 'notifications';
  static const String examInstancesCollection = 'exam_instances';
  static const String examStatsCollection = 'exam_stats';

  // User Roles
  static const String roleTeacher = 'teacher';
  static const String roleStudent = 'student';

  // Exam Status
  static const String statusDraft = 'draft';
  static const String statusPublished = 'published';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';

  // Question Types
  static const String questionTypeMultipleChoice = 'multiple_choice';
  static const String questionTypeTrueFalse = 'true_false';
  static const String questionTypeShortAnswer = 'short_answer';

  // Question Difficulty
  static const String difficultyEasy = 'easy';
  static const String difficultyMedium = 'medium';
  static const String difficultyHard = 'hard';

  // Submission Status
  static const String submissionStatusStarted = 'started';
  static const String submissionStatusSubmitted = 'submitted';
  static const String submissionStatusFlagged = 'flagged';

  // Violation Types
  static const String violationAppMinimized = 'app_minimized';
  static const String violationAppSwitched = 'app_switched';
  static const String violationScreenOff = 'screen_off';
  static const String violationScreenshotAttempt = 'screenshot_attempt';
  static const String violationScreenRecording = 'screen_recording';
  static const String violationMultipleLogin = 'multiple_login';

  // Notification Types
  static const String notificationExamPublished = 'exam_published';
  static const String notificationExamReminder = 'exam_reminder';
  static const String notificationResultPublished = 'result_published';
  static const String notificationAnnouncement = 'announcement';
  static const String notificationViolation = 'violation';

  // Auto-save interval (seconds)
  static const int autoSaveInterval = 5;

  // Violation threshold
  static const int violationThreshold = 3;

  // Default student password (before hashing)
  static const String defaultStudentPassword = '123456';
}

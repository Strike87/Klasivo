class AppConstants {
  // Local Storage
  static const String authBox = 'auth_box';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String studentsCollection = 'students';
  static const String classesCollection = 'classes';
  static const String examsCollection = 'exams';
  static const String questionsCollection = 'questions';
  static const String submissionsCollection = 'submissions';
  static const String answersCollection = 'answers';

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

  // Submission Status
  static const String submissionStatusStarted = 'started';
  static const String submissionStatusSubmitted = 'submitted';
  static const String submissionStatusFlagged = 'flagged';

  // Auto-save interval (seconds)
  static const int autoSaveInterval = 5;

  // Violation threshold
  static const int violationThreshold = 3;
}

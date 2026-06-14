import 'package:firebase_analytics/firebase_analytics.dart';

/// Service for tracking Firebase Analytics events across the app.
///
/// Usage:
///   ```dart
///   await FirebaseAnalyticsService.logSignupCompleted(method: 'email', role: 'teacher');
///   ```
///
/// Events tracked:
///   - signup_completed, login
///   - school_created
///   - teacher_invited
///   - exam_created, exam_started, exam_submitted
///   - announcement_sent
///   - contact_form_sent
///   - assignment_created, assignment_submitted
///   - parent_linked
class FirebaseAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── User Properties ───────────────────────────────────────────────

  /// Set user properties after authentication.
  static Future<void> setUserProperties({
    required String uid,
    required String role,
    String? organizationId,
  }) async {
    await _analytics.setUserId(id: uid);
    await _analytics.setUserProperty(name: 'user_role', value: role);
    if (organizationId != null) {
      await _analytics.setUserProperty(
        name: 'organization_id',
        value: organizationId,
      );
    }
  }

  /// Clear user properties on sign-out.
  static Future<void> clearUserProperties() async {
    await _analytics.setUserId(id: null);
    await _analytics.setUserProperty(name: 'user_role', value: null);
    await _analytics.setUserProperty(name: 'organization_id', value: null);
  }

  // ─── Auth Events ───────────────────────────────────────────────────

  static Future<void> logSignupCompleted({
    required String method,
    required String role,
  }) async {
    await _analytics.logEvent(
      name: 'signup_completed',
      parameters: {'method': method, 'role': role},
    );
  }

  static Future<void> logLogin({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // ─── Organization / School Events ──────────────────────────────────

  static Future<void> logSchoolCreated({
    required String schoolId,
    required String schoolName,
  }) async {
    await _analytics.logEvent(
      name: 'school_created',
      parameters: {
        'school_id': schoolId,
        'school_name': _truncate(schoolName, 40),
      },
    );
  }

  // ─── Teacher Events ────────────────────────────────────────────────

  static Future<void> logTeacherInvited({required String orgId}) async {
    await _analytics.logEvent(
      name: 'teacher_invited',
      parameters: {'org_id': orgId},
    );
  }

  // ─── Exam Events ───────────────────────────────────────────────────

  static Future<void> logExamCreated({
    required String examId,
    required String classId,
    int? questionCount,
  }) async {
    await _analytics.logEvent(
      name: 'exam_created',
      parameters: {
        'exam_id': examId,
        'class_id': classId,
        if (questionCount != null) 'question_count': questionCount,
      },
    );
  }

  static Future<void> logExamStarted({
    required String examId,
    required String studentId,
  }) async {
    await _analytics.logEvent(
      name: 'exam_started',
      parameters: {'exam_id': examId, 'student_id': studentId},
    );
  }

  static Future<void> logExamSubmitted({
    required String examId,
    required String studentId,
    double? score,
  }) async {
    await _analytics.logEvent(
      name: 'exam_submitted',
      parameters: {
        'exam_id': examId,
        'student_id': studentId,
        if (score != null) 'score': score.round(),
      },
    );
  }

  // ─── Announcement Events ───────────────────────────────────────────

  static Future<void> logAnnouncementSent({
    required String schoolId,
    required String priority,
    int? recipientCount,
  }) async {
    await _analytics.logEvent(
      name: 'announcement_sent',
      parameters: {
        'school_id': schoolId,
        'priority': priority,
        if (recipientCount != null) 'recipient_count': recipientCount,
      },
    );
  }

  // ─── Contact Form Events ───────────────────────────────────────────

  static Future<void> logContactFormSent() async {
    await _analytics.logEvent(name: 'contact_form_sent');
  }

  // ─── Assignment Events ─────────────────────────────────────────────

  static Future<void> logAssignmentCreated({
    required String assignmentId,
    required String classId,
  }) async {
    await _analytics.logEvent(
      name: 'assignment_created',
      parameters: {'assignment_id': assignmentId, 'class_id': classId},
    );
  }

  static Future<void> logAssignmentSubmitted({
    required String assignmentId,
    required String studentId,
  }) async {
    await _analytics.logEvent(
      name: 'assignment_submitted',
      parameters: {'assignment_id': assignmentId, 'student_id': studentId},
    );
  }

  // ─── Parent Events ─────────────────────────────────────────────────

  static Future<void> logParentLinked({
    required String parentId,
    required String studentId,
  }) async {
    await _analytics.logEvent(
      name: 'parent_linked',
      parameters: {'parent_id': parentId, 'student_id': studentId},
    );
  }

  // ─── Screen Tracking ───────────────────────────────────────────────

  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  /// Firebase Analytics parameter values must be <= 100 chars.
  static String _truncate(String value, int max) {
    return value.length > max ? value.substring(0, max) : value;
  }
}

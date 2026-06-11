import 'dart:async';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO EVENT BUS — Cross-module event-driven communication
//
// Decouples modules so they don't need direct imports of each other.
// Events flow: Producer → EventBus → Consumers (Riverpod providers, widgets)
//
// Design principles:
// 1. Events are immutable data classes (no logic)
// 2. Events are typed — consumers filter by type
// 3. Events are async — no synchronous side effects
// 4. Events are local only — not a replacement for Firestore listeners
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoEventBus {
  KlasivoEventBus._();

  static final KlasivoEventBus _instance = KlasivoEventBus._();
  static KlasivoEventBus get instance => _instance;

  // ─── Broadcast controller (multiple listeners allowed) ──────────────────
  final StreamController<KlasivoEvent> _controller =
      StreamController<KlasivoEvent>.broadcast();

  /// Stream of all events. Consumers filter by type.
  Stream<KlasivoEvent> get stream => _controller.stream;

  /// Stream of events of a specific type.
  Stream<T> on<T extends KlasivoEvent>() {
    return stream.where((event) => event is T).cast<T>();
  }

  /// Fire an event to all listeners.
  void fire(KlasivoEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
      if (kDebugMode) {
        debugPrint('[EventBus] ${event.eventType} — ${event.description}');
      }
    }
  }

  /// Dispose the bus (call in app dispose).
  void dispose() {
    _controller.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BASE EVENT CLASS
// ═══════════════════════════════════════════════════════════════════════════════

abstract class KlasivoEvent {
  /// Event type identifier for logging and filtering.
  String get eventType;

  /// Human-readable description for debugging.
  String get description;

  /// Timestamp when the event was created.
  final DateTime timestamp;

  /// Optional metadata for event context.
  final Map<String, dynamic>? metadata;

  KlasivoEvent({DateTime? timestamp, this.metadata})
      : timestamp = timestamp ?? DateTime.now();
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT MODELS — Organized by domain
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Auth Events ──────────────────────────────────────────────────────────

class UserLoggedInEvent extends KlasivoEvent {
  final String userId;
  final String role;
  final String? orgId;

  UserLoggedInEvent({
    required this.userId,
    required this.role,
    this.orgId,
  }) : super();

  @override
  String get eventType => 'user_logged_in';

  @override
  String get description => 'User $userId ($role) logged in';
}

class UserLoggedOutEvent extends KlasivoEvent {
  final String userId;

  UserLoggedOutEvent({required this.userId}) : super();

  @override
  String get eventType => 'user_logged_out';

  @override
  String get description => 'User $userId logged out';
}

class UserRoleChangedEvent extends KlasivoEvent {
  final String userId;
  final String oldRole;
  final String newRole;

  UserRoleChangedEvent({
    required this.userId,
    required this.oldRole,
    required this.newRole,
  }) : super();

  @override
  String get eventType => 'user_role_changed';

  @override
  String get description => 'User $userId role changed from $oldRole to $newRole';
}

// ─── Exam Events ──────────────────────────────────────────────────────────

class ExamCreatedEvent extends KlasivoEvent {
  final String examId;
  final String orgId;
  final String createdBy;

  ExamCreatedEvent({
    required this.examId,
    required this.orgId,
    required this.createdBy,
  }) : super();

  @override
  String get eventType => 'exam_created';

  @override
  String get description => 'Exam $examId created';
}

class ExamPublishedEvent extends KlasivoEvent {
  final String examId;
  final String orgId;

  ExamPublishedEvent({required this.examId, required this.orgId}) : super();

  @override
  String get eventType => 'exam_published';

  @override
  String get description => 'Exam $examId published';
}

class ExamStartedEvent extends KlasivoEvent {
  final String examId;
  final String studentId;

  ExamStartedEvent({required this.examId, required this.studentId}) : super();

  @override
  String get eventType => 'exam_started';

  @override
  String get description => 'Student $studentId started exam $examId';
}

class ExamSubmittedEvent extends KlasivoEvent {
  final String examId;
  final String studentId;
  final String submissionId;

  ExamSubmittedEvent({
    required this.examId,
    required this.studentId,
    required this.submissionId,
  }) : super();

  @override
  String get eventType => 'exam_submitted';

  @override
  String get description => 'Student $studentId submitted exam $examId';
}

class ExamGradedEvent extends KlasivoEvent {
  final String examId;
  final String submissionId;
  final String gradedBy;

  ExamGradedEvent({
    required this.examId,
    required this.submissionId,
    required this.gradedBy,
  }) : super();

  @override
  String get eventType => 'exam_graded';

  @override
  String get description => 'Submission $submissionId graded by $gradedBy';
}

// ─── Academic Structure Events ────────────────────────────────────────────

class StageCreatedEvent extends KlasivoEvent {
  final String stageId;
  final String orgId;

  StageCreatedEvent({required this.stageId, required this.orgId}) : super();

  @override
  String get eventType => 'stage_created';

  @override
  String get description => 'Stage $stageId created';
}

class ClassCreatedEvent extends KlasivoEvent {
  final String classId;
  final String stageId;
  final String orgId;

  ClassCreatedEvent({
    required this.classId,
    required this.stageId,
    required this.orgId,
  }) : super();

  @override
  String get eventType => 'class_created';

  @override
  String get description => 'Class $classId created in stage $stageId';
}

class StudentEnrolledEvent extends KlasivoEvent {
  final String studentId;
  final String classId;
  final String orgId;

  StudentEnrolledEvent({
    required this.studentId,
    required this.classId,
    required this.orgId,
  }) : super();

  @override
  String get eventType => 'student_enrolled';

  @override
  String get description => 'Student $studentId enrolled in class $classId';
}

class StudentRemovedEvent extends KlasivoEvent {
  final String studentId;
  final String classId;

  StudentRemovedEvent({required this.studentId, required this.classId}) : super();

  @override
  String get eventType => 'student_removed';

  @override
  String get description => 'Student $studentId removed from class $classId';
}

// ─── Attendance Events ────────────────────────────────────────────────────

class AttendanceMarkedEvent extends KlasivoEvent {
  final String classId;
  final String markedBy;
  final int present;
  final int absent;
  final int late;

  AttendanceMarkedEvent({
    required this.classId,
    required this.markedBy,
    required this.present,
    required this.absent,
    required this.late,
  }) : super();

  @override
  String get eventType => 'attendance_marked';

  @override
  String get description => 'Attendance marked for class $classId: $present present, $absent absent, $late late';
}

// ─── Assignment Events ────────────────────────────────────────────────────

class AssignmentCreatedEvent extends KlasivoEvent {
  final String assignmentId;
  final String classId;

  AssignmentCreatedEvent({required this.assignmentId, required this.classId})
      : super();

  @override
  String get eventType => 'assignment_created';

  @override
  String get description => 'Assignment $assignmentId created for class $classId';
}

class AssignmentSubmittedEvent extends KlasivoEvent {
  final String assignmentId;
  final String studentId;

  AssignmentSubmittedEvent({required this.assignmentId, required this.studentId})
      : super();

  @override
  String get eventType => 'assignment_submitted';

  @override
  String get description => 'Student $studentId submitted assignment $assignmentId';
}

// ─── LMS Events (v1.7) ───────────────────────────────────────────────────

class LessonCreatedEvent extends KlasivoEvent {
  final String lessonId;
  final String subjectId;
  final String createdBy;

  LessonCreatedEvent({
    required this.lessonId,
    required this.subjectId,
    required this.createdBy,
  }) : super();

  @override
  String get eventType => 'lesson_created';

  @override
  String get description => 'Lesson $lessonId created for subject $subjectId';
}

class MaterialUploadedEvent extends KlasivoEvent {
  final String materialId;
  final String lessonId;
  final String uploadedBy;

  MaterialUploadedEvent({
    required this.materialId,
    required this.lessonId,
    required this.uploadedBy,
  }) : super();

  @override
  String get eventType => 'material_uploaded';

  @override
  String get description => 'Material $materialId uploaded to lesson $lessonId';
}

class ProgressUpdatedEvent extends KlasivoEvent {
  final String studentId;
  final String lessonId;
  final double completionPercentage;

  ProgressUpdatedEvent({
    required this.studentId,
    required this.lessonId,
    required this.completionPercentage,
  }) : super();

  @override
  String get eventType => 'progress_updated';

  @override
  String get description => 'Student $studentId progress on lesson $lessonId: ${(completionPercentage * 100).toInt()}%';
}

// ─── Parent Events (v1.7) ────────────────────────────────────────────────

class ParentLinkedEvent extends KlasivoEvent {
  final String parentId;
  final String studentId;
  final String orgId;

  ParentLinkedEvent({
    required this.parentId,
    required this.studentId,
    required this.orgId,
  }) : super();

  @override
  String get eventType => 'parent_linked';

  @override
  String get description => 'Parent $parentId linked to student $studentId';
}

class ParentNotificationSentEvent extends KlasivoEvent {
  final String parentId;
  final String notificationType;
  final String title;

  ParentNotificationSentEvent({
    required this.parentId,
    required this.notificationType,
    required this.title,
  }) : super();

  @override
  String get eventType => 'parent_notification_sent';

  @override
  String get description => 'Notification sent to parent $parentId: $title';
}

// ─── Integrity Events ────────────────────────────────────────────────────

class ViolationDetectedEvent extends KlasivoEvent {
  final String studentId;
  final String examId;
  final String violationType;

  ViolationDetectedEvent({
    required this.studentId,
    required this.examId,
    required this.violationType,
  }) : super();

  @override
  String get eventType => 'violation_detected';

  @override
  String get description => 'Violation detected: $violationType for student $studentId in exam $examId';
}

// ─── Organization Events ─────────────────────────────────────────────────

class OrgSettingsUpdatedEvent extends KlasivoEvent {
  final String orgId;
  final String updatedBy;

  OrgSettingsUpdatedEvent({required this.orgId, required this.updatedBy})
      : super();

  @override
  String get eventType => 'org_settings_updated';

  @override
  String get description => 'Organization $orgId settings updated by $updatedBy';
}

class TeacherInvitedEvent extends KlasivoEvent {
  final String orgId;
  final String inviteCode;

  TeacherInvitedEvent({required this.orgId, required this.inviteCode}) : super();

  @override
  String get eventType => 'teacher_invited';

  @override
  String get description => 'Teacher invited to org $orgId with code $inviteCode';
}

class TeacherJoinedEvent extends KlasivoEvent {
  final String orgId;
  final String teacherId;

  TeacherJoinedEvent({required this.orgId, required this.teacherId}) : super();

  @override
  String get eventType => 'teacher_joined';

  @override
  String get description => 'Teacher $teacherId joined org $orgId';
}

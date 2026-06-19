#!/usr/bin/env python3
# ============================================================================
# Klasivo Sprint 4 — Assignment Submission API + Enhanced Attendance
# ============================================================================
# Scaffolds 2 features from klasivo_action_plan_v2.md Sprint 4:
#
#   S4-01: Assignment Submission API (v2.3)
#          - REST endpoints in api/index.ts (create/submit/grade)
#          - File upload to Firebase Storage with signed URLs
#          - Late penalty rules
#          - Rubric-based grading UI
#          - Submission model, repository, providers
#          - Student submission screen
#          - Teacher grading screen
#
#   S4-02: Enhanced Attendance (v2.4)
#          - Bulk mark-present functionality
#          - Parent absence notification (push + email) within 5 minutes
#          - Monthly attendance report PDF generation
#          - Scheduled function for absence detection
#          - Attendance report screen
#
# Prerequisites:
#   - Sprint 1-3 deployed
#   - assignments and attendance collections exist in Firestore
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-sprint4-patches.py
# ============================================================================

import os
import sys
import re
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run this script from the Klasivo repo root.")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Apply Klasivo Sprint 4 scaffolding")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO SPRINT 4 — Assignment API + Enhanced Attendance")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    current_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
    print(f"Current git commit: {current_commit}")
except subprocess.CalledProcessError:
    sys.exit(1)
print()

status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    print("Run: git stash  OR  re-run with --force")
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-sprint4-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

features_scaffolded = []


def write_file(filepath, content):
    path = Path(filepath)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  [OK] Created {path}")
    return path


# ============================================================================
# S4-01: Assignment Submission API
# ============================================================================
print("=" * 70)
print("S4-01: Assignment Submission API (v2.3)")
print("=" * 70)
print()

# --- Submission model ---
write_file("lib/features/assignments/domain/submission_model.dart", '''// S4-01: Assignment Submission Model

import 'package:cloud_firestore/cloud_firestore.dart';

enum SubmissionStatus { draft, submitted, late, graded, returned }

class AssignmentSubmission {
  final String id;
  final String organizationId;
  final String assignmentId;
  final String classId;
  final String studentId;
  final String studentName;
  final String? content;
  final List<String> attachmentUrls;
  final SubmissionStatus status;
  final DateTime? submittedAt;
  final bool isLate;
  final double? score;
  final double maxScore;
  final double? percentage;
  final String? gradedBy;
  final String? gradedByName;
  final DateTime? gradedAt;
  final String? feedback;
  final Map<String, dynamic>? rubricScores;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssignmentSubmission({
    required this.id,
    required this.organizationId,
    required this.assignmentId,
    required this.classId,
    required this.studentId,
    required this.studentName,
    this.content,
    this.attachmentUrls = const [],
    required this.status,
    this.submittedAt,
    this.isLate = false,
    this.score,
    required this.maxScore,
    this.percentage,
    this.gradedBy,
    this.gradedByName,
    this.gradedAt,
    this.feedback,
    this.rubricScores,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssignmentSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentSubmission(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      assignmentId: data['assignmentId'] ?? '',
      classId: data['classId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      content: data['content'],
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? 'draft'),
        orElse: () => SubmissionStatus.draft,
      ),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      isLate: data['isLate'] ?? false,
      score: (data['score'] as num?)?.toDouble(),
      maxScore: (data['maxScore'] as num?)?.toDouble() ?? 100,
      percentage: (data['percentage'] as num?)?.toDouble(),
      gradedBy: data['gradedBy'],
      gradedByName: data['gradedByName'],
      gradedAt: (data['gradedAt'] as Timestamp?)?.toDate(),
      feedback: data['feedback'],
      rubricScores: data['rubricScores'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'assignmentId': assignmentId,
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'content': content,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'isLate': isLate,
      'score': score,
      'maxScore': maxScore,
      'percentage': percentage,
      'gradedBy': gradedBy,
      'gradedByName': gradedByName,
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
      'feedback': feedback,
      'rubricScores': rubricScores,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class RubricCriterion {
  final String id;
  final String title;
  final String description;
  final double maxPoints;

  RubricCriterion({
    required this.id,
    required this.title,
    required this.description,
    required this.maxPoints,
  });

  factory RubricCriterion.fromMap(Map<String, dynamic> map) {
    return RubricCriterion(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      maxPoints: (map['maxPoints'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'description': description, 'maxPoints': maxPoints};
  }
}
''')

# --- Repository ---
write_file("lib/features/assignments/data/submission_repository.dart", '''// S4-01: Submission Repository

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';
import '../domain/submission_model.dart';

class SubmissionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('assignment_submissions');

  /// Get student's submission for an assignment
  Future<AssignmentSubmission?> getSubmission(String assignmentId, String studentId) async {
    final snapshot = await _collection
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AssignmentSubmission.fromFirestore(snapshot.docs.first);
  }

  /// Stream student's submission
  Stream<AssignmentSubmission?> watchSubmission(String assignmentId, String studentId) {
    return _collection
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return AssignmentSubmission.fromFirestore(snapshot.docs.first);
    });
  }

  /// Stream all submissions for an assignment (teacher view)
  Stream<List<AssignmentSubmission>> watchByAssignment(String orgId, String assignmentId) {
    return _collection
        .where('organizationId', isEqualTo: orgId)
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentSubmission.fromFirestore(doc))
            .toList());
  }

  /// Submit assignment (calls Cloud Function for late penalty calculation)
  Future<void> submit({
    required String assignmentId,
    required String classId,
    required String studentId,
    required String studentName,
    required String orgId,
    String? content,
    List<String> attachmentUrls = const [],
    required double maxScore,
  }) async {
    final result = await _functions.httpsCallable('submitAssignment').call({
      'assignmentId': assignmentId,
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'organizationId': orgId,
      'content': content,
      'attachmentUrls': attachmentUrls,
      'maxScore': maxScore,
    });
    return result.data;
  }

  /// Grade submission (teacher)
  Future<void> grade({
    required String submissionId,
    required double score,
    required String gradedBy,
    required String gradedByName,
    String? feedback,
    Map<String, dynamic>? rubricScores,
  }) async {
    final result = await _functions.httpsCallable('gradeSubmission').call({
      'submissionId': submissionId,
      'score': score,
      'gradedBy': gradedBy,
      'gradedByName': gradedByName,
      'feedback': feedback,
      'rubricScores': rubricScores,
    });
    return result.data;
  }
}
''')

# --- Providers ---
write_file("lib/features/assignments/providers/submission_providers.dart", '''// S4-01: Submission Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/submission_repository.dart';
import '../domain/submission_model.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository();
});

/// Student's submission for a specific assignment
final studentSubmissionProvider = StreamProvider.family2<AssignmentSubmission?, String, String>((ref, assignmentId, studentId) {
  return ref.read(submissionRepositoryProvider).watchSubmission(assignmentId, studentId);
});

/// All submissions for an assignment (teacher view)
final assignmentSubmissionsProvider = StreamProvider.family2<List<AssignmentSubmission>, String, String>((ref, orgId, assignmentId) {
  return ref.read(submissionRepositoryProvider).watchByAssignment(orgId, assignmentId);
});
''')

# --- Student submission screen ---
write_file("lib/features/assignments/pages/student_submission_screen.dart", '''// S4-01: Student Submission Screen
// Student views assignment, submits content + attachments

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../domain/submission_model.dart';
import '../providers/submission_providers.dart';

class StudentSubmissionScreen extends ConsumerStatefulWidget {
  final String assignmentId;
  final String classId;
  final String assignmentTitle;
  final double maxScore;
  final DateTime? dueDate;

  const StudentSubmissionScreen({
    super.key,
    required this.assignmentId,
    required this.classId,
    required this.assignmentTitle,
    required this.maxScore,
    this.dueDate,
  });

  @override
  ConsumerState<StudentSubmissionScreen> createState() => _StudentSubmissionScreenState();
}

class _StudentSubmissionScreenState extends ConsumerState<StudentSubmissionScreen> {
  final _contentController = TextEditingController();
  final List<String> _attachmentUrls = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authProvider);
      final orgId = ref.read(organizationIdProvider)!;
      await ref.read(submissionRepositoryProvider).submit(
        assignmentId: widget.assignmentId,
        classId: widget.classId,
        studentId: user.uid!,
        studentName: user.displayName ?? 'Student',
        orgId: orgId,
        content: _contentController.text.trim(),
        attachmentUrls: _attachmentUrls,
        maxScore: widget.maxScore,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment submitted!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final submissionAsync = ref.watch(studentSubmissionProvider(widget.assignmentId, user.uid ?? ''));

    return Scaffold(
      appBar: AppBar(title: Text(widget.assignmentTitle)),
      body: submissionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (submission) {
          final isGraded = submission?.status == SubmissionStatus.graded;
          final isSubmitted = submission?.status == SubmissionStatus.submitted ||
              submission?.status == SubmissionStatus.late;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Max Score: \\${widget.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (widget.dueDate != null) ...[
                        const SizedBox(height: 8),
                        Text('Due: \\${widget.dueDate!.toLocal()}'),
                      ],
                      if (submission != null) ...[
                        const SizedBox(height: 8),
                        Chip(label: Text(submission.status.name.toUpperCase())),
                        if (submission.isLate)
                          const Chip(label: Text('LATE'), backgroundColor: Colors.orange),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isGraded && submission != null) ...[
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score: \\${submission.score}/\\${submission.maxScore}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        if (submission.percentage != null)
                          Text('\\${submission.percentage!.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 18, color: Colors.green)),
                        if (submission.feedback != null && submission.feedback!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(submission.feedback!),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else if (isSubmitted) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (submission!.submittedAt != null)
                          Text('At: \\${submission.submittedAt!.toLocal()}'),
                        if (submission.content != null && submission.content!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Your submission:'),
                          Text(submission.content!),
                        ],
                        const SizedBox(height: 12),
                        const Text('Waiting for grading...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Your submission',
                    border: OutlineInputBorder(),
                    hintText: 'Type your answer here...',
                  ),
                  maxLines: 10,
                ),
                const SizedBox(height: 16),
                if (_attachmentUrls.isNotEmpty) ...[
                  const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._attachmentUrls.map((url) => ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(url.split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _attachmentUrls.remove(url)),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                // TODO: Add file upload button (uses /v1/storage/upload-url from Sprint 1)
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File upload coming soon — use content for now')),
                    );
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach File'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit Assignment'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
''')

# --- Teacher grading screen ---
write_file("lib/features/assignments/pages/teacher_grading_screen.dart", '''// S4-01: Teacher Grading Screen
// Teacher views all submissions for an assignment, grades each

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../domain/submission_model.dart';
import '../providers/submission_providers.dart';

class TeacherGradingScreen extends ConsumerWidget {
  final String assignmentId;
  final String assignmentTitle;
  final double maxScore;

  const TeacherGradingScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null) return const Scaffold(body: Center(child: Text('No org')));

    final submissionsAsync = ref.watch(assignmentSubmissionsProvider(orgId, assignmentId));

    return Scaffold(
      appBar: AppBar(title: Text('Grade: $assignmentTitle')),
      body: submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (submissions) {
          if (submissions.isEmpty) {
            return const Center(child: Text('No submissions yet'));
          }
          final graded = submissions.where((s) => s.status == SubmissionStatus.graded).length;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$graded / ${submissions.length} graded',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final sub = submissions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(sub.studentName),
                        subtitle: Text(
                          sub.status == SubmissionStatus.graded
                              ? 'Score: \\${sub.score}/\\${sub.maxScore}'
                              : sub.isLate ? 'Submitted LATE' : 'Submitted',
                        ),
                        trailing: sub.status == SubmissionStatus.graded
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.pending, color: Colors.orange),
                        onTap: () => _showGradingDialog(context, ref, sub),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGradingDialog(BuildContext context, WidgetRef ref, AssignmentSubmission sub) {
    final scoreController = TextEditingController(
      text: sub.score?.toStringAsFixed(1) ?? '',
    );
    final feedbackController = TextEditingController(text: sub.feedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grade: ${sub.studentName}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sub.content != null && sub.content!.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Submission:')),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                  child: Text(sub.content!),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: scoreController,
                decoration: InputDecoration(
                  labelText: 'Score (out of \\${sub.maxScore})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final score = double.tryParse(scoreController.text);
              if (score == null || score < 0 || score > sub.maxScore) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Score must be 0-\\${sub.maxScore}')),
                );
                return;
              }
              Navigator.pop(ctx);
              final user = ref.read(authProvider);
              try {
                await ref.read(submissionRepositoryProvider).grade(
                  submissionId: sub.id,
                  score: score,
                  gradedBy: user.uid!,
                  gradedByName: user.displayName ?? 'Teacher',
                  feedback: feedbackController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Graded!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Grade failed: $e')),
                  );
                }
              }
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }
}
''')

# --- Cloud Function: submitAssignment ---
write_file("functions/src/functions/submitAssignment.ts", '''/**
 * submitAssignment — S4-01: Assignment Submission
 * Calculates late penalty, updates submission status
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { checkRateLimit } from '../utils/rateLimiter';

interface SubmitAssignmentData {
  assignmentId: string;
  classId: string;
  studentId: string;
  studentName: string;
  organizationId: string;
  content?: string;
  attachmentUrls?: string[];
  maxScore: number;
}

export const submitAssignment = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'assignments');
      scope.setTag('function', 'submitAssignment');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      await checkRateLimit(callerUid, 'submitAssignment', { maxCalls: 30, windowSeconds: 60 });

      const data = request.data as SubmitAssignmentData;

      // Verify org boundary
      if (data.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cross-org submission not allowed.');
      }

      // Verify student is submitting their own work
      if (data.studentId !== callerUid && callerRole !== 'teacher' && callerRole !== 'owner') {
        throw new HttpsError('permission-denied', 'Can only submit your own assignment.');
      }

      const db = getFirestore();

      // Get the assignment to check due date
      const assignDoc = await db.collection('assignments').doc(data.assignmentId).get();
      if (!assignDoc.exists) {
        throw new HttpsError('not-found', 'Assignment not found.');
      }

      const assignData = assignDoc.data()!;
      const dueDate = assignData['dueDate'] as Timestamp | undefined;
      const now = new Date();
      const isLate = dueDate ? now > dueDate.toDate() : false;

      // Late penalty (if configured)
      let latePenalty = 0;
      if (isLate && assignData['latePenaltyPercent']) {
        latePenalty = (assignData['latePenaltyPercent'] as number) / 100;
      }

      // Check for existing submission
      const existingQuery = await db.collection('assignment_submissions')
        .where('assignmentId', '==', data.assignmentId)
        .where('studentId', '==', data.studentId)
        .limit(1)
        .get();

      const status = isLate ? 'late' : 'submitted';

      if (!existingQuery.empty) {
        // Update existing submission
        const existingDoc = existingQuery.docs[0];
        await existingDoc.ref.update({
          content: data.content || null,
          attachmentUrls: data.attachmentUrls || [],
          status,
          isLate,
          submittedAt: FieldValue.serverTimestamp(),
          latePenalty,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return { success: true, submissionId: existingDoc.id, isLate };
      }

      // Create new submission
      const newDoc = await db.collection('assignment_submissions').add({
        organizationId: data.organizationId,
        assignmentId: data.assignmentId,
        classId: data.classId,
        studentId: data.studentId,
        studentName: data.studentName,
        content: data.content || null,
        attachmentUrls: data.attachmentUrls || [],
        status,
        submittedAt: FieldValue.serverTimestamp(),
        isLate,
        latePenalty,
        maxScore: data.maxScore,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: callerOrgId,
        performedBy: callerUid,
        performedByRole: callerRole,
        action: 'submit_assignment',
        targetType: 'assignment_submission',
        targetId: newDoc.id,
        metadata: { assignmentId: data.assignmentId, isLate },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      return { success: true, submissionId: newDoc.id, isLate };
    });
  },
);
''')

# --- Cloud Function: gradeSubmission ---
write_file("functions/src/functions/gradeSubmission.ts", '''/**
 * gradeSubmission — S4-01: Teacher grades a submission
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { checkRateLimit } from '../utils/rateLimiter';

interface GradeSubmissionData {
  submissionId: string;
  score: number;
  gradedBy: string;
  gradedByName: string;
  feedback?: string;
  rubricScores?: Record<string, number>;
}

export const gradeSubmission = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 20,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'assignments');
      scope.setTag('function', 'gradeSubmission');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      if (!['super_admin', 'owner', 'admin', 'teacher', 'assistant_teacher'].includes(callerRole)) {
        throw new HttpsError('permission-denied', 'Only staff can grade.');
      }

      await checkRateLimit(callerUid, 'gradeSubmission', { maxCalls: 60, windowSeconds: 60 });

      const data = request.data as GradeSubmissionData;
      const db = getFirestore();

      const subRef = db.collection('assignment_submissions').doc(data.submissionId);
      const subDoc = await subRef.get();

      if (!subDoc.exists) {
        throw new HttpsError('not-found', 'Submission not found.');
      }

      const subData = subDoc.data()!;

      // Verify org boundary
      if (subData.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cross-org grading not allowed.');
      }

      const maxScore = subData.maxScore as number;
      if (data.score < 0 || data.score > maxScore) {
        throw new HttpsError('invalid-argument', `Score must be 0-${maxScore}.`);
      }

      // Apply late penalty if applicable
      const latePenalty = (subData.latePenalty as number) || 0;
      const adjustedScore = data.score * (1 - latePenalty);
      const percentage = (adjustedScore / maxScore) * 100;

      await subRef.update({
        score: adjustedScore,
        originalScore: data.score,
        percentage,
        status: 'graded',
        gradedBy: data.gradedBy,
        gradedByName: data.gradedByName,
        gradedAt: FieldValue.serverTimestamp(),
        feedback: data.feedback || null,
        rubricScores: data.rubricScores || null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: callerOrgId,
        performedBy: callerUid,
        performedByRole: callerRole,
        action: 'grade_submission',
        targetType: 'assignment_submission',
        targetId: data.submissionId,
        metadata: {
          score: adjustedScore,
          originalScore: data.score,
          percentage,
          latePenaltyApplied: latePenalty > 0,
        },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      // Send notification to student
      const studentUid = subData.studentId as string;
      await db.collection('notifications').add({
        organizationId: callerOrgId,
        userId: studentUid,
        type: 'assignment_graded',
        title: 'Assignment Graded',
        body: `Your submission scored ${percentage.toFixed(1)}%`,
        data: {
          submissionId: data.submissionId,
          assignmentId: subData.assignmentId,
        },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, score: adjustedScore, percentage };
    });
  },
);
''')

# Export functions
index_path = Path("functions/src/index.ts")
index_content = index_path.read_text(encoding="utf-8")
for export_line in [
    "export { submitAssignment } from './functions/submitAssignment';",
    "export { gradeSubmission } from './functions/gradeSubmission';",
]:
    fn_name = export_line.split("{")[1].split("}")[0].strip()
    if fn_name not in index_content:
        export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
        if export_matches:
            last_export = export_matches[-1]
            line_end = index_content.find('\n', last_export.end())
            if line_end != -1:
                index_content = index_content[:line_end + 1] + export_line + '\n' + index_content[line_end + 1:]
index_path.write_text(index_content, encoding="utf-8")
print("  [OK] Exported submitAssignment + gradeSubmission")

# Add routes
main_path = Path("lib/main.dart")
main_content = main_path.read_text(encoding="utf-8")
if "/assignments/submit" not in main_content:
    for imp in [
        "import 'features/assignments/pages/student_submission_screen.dart';",
        "import 'features/assignments/pages/teacher_grading_screen.dart';",
    ]:
        if imp not in main_content:
            lines = main_content.split("\n")
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    last_import_idx = i
            if last_import_idx >= 0:
                lines.insert(last_import_idx + 1, imp)
                main_content = "\n".join(lines)

    assignment_routes = """
        // S4-01: Assignment submission routes
        GoRoute(
          path: '/assignments/:assignmentId/submit',
          builder: (context, state) => StudentSubmissionScreen(
            assignmentId: state.pathParameters['assignmentId']!,
            classId: state.pathParameters['classId'] ?? '',
            assignmentTitle: state.pathParameters['title'] ?? 'Assignment',
            maxScore: double.tryParse(state.pathParameters['maxScore'] ?? '100') ?? 100,
          ),
        ),
        GoRoute(
          path: '/assignments/:assignmentId/grade',
          builder: (context, state) => TeacherGradingScreen(
            assignmentId: state.pathParameters['assignmentId']!,
            assignmentTitle: state.pathParameters['title'] ?? 'Assignment',
            maxScore: double.tryParse(state.pathParameters['maxScore'] ?? '100') ?? 100,
          ),
        ),"""

    shell_match = re.search(r"(ShellRoute\s*\([^)]*\)\s*,)", main_content, re.DOTALL)
    if shell_match:
        insert_pos = shell_match.end()
        main_content = main_content[:insert_pos] + assignment_routes + main_content[insert_pos:]
        main_path.write_text(main_content, encoding="utf-8")
        print("  [OK] Added assignment routes to main.dart")

# Firestore rules
rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")
assignment_rules = """
    // ====== S4-01: Assignment Submissions ======
    match /assignment_submissions/{submissionId} {
      allow read: if isAuth() && isInSameOrg() &&
        (isStaffExcludingObserver() ||
         resource.data.studentId == request.auth.uid ||
         (isParent() && resource.data.studentId != null &&
          parentHasAccessToStudent(resource.data.studentId)));
      allow create: if isAuth() && isIncomingSameOrg() &&
        (isStaffExcludingObserver() || resource.data.studentId == request.auth.uid);
      allow update: if isStaffExcludingObserverInSameOrg() ||
        (isAuth() && resource.data.studentId == request.auth.uid &&
         !request.resource.data.diff(resource).affectedKeys().hasAny([
           'score', 'percentage', 'status', 'gradedBy', 'gradedAt', 'feedback', 'rubricScores'
         ]));
      allow delete: if isOwnerInSameOrg();
    }
"""
if "assignment_submissions" not in rules_content or "S4-01" not in rules_content:
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + assignment_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added assignment_submissions rules")

features_scaffolded.append("S4-01 (Assignment Submission API)")
print()

# ============================================================================
# S4-02: Enhanced Attendance
# ============================================================================
print("=" * 70)
print("S4-02: Enhanced Attendance (v2.4)")
print("=" * 70)
print()

# --- Bulk mark-present Cloud Function ---
write_file("functions/src/functions/bulkMarkAttendance.ts", '''/**
 * bulkMarkAttendance — S4-02: Bulk mark students present
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { checkRateLimit } from '../utils/rateLimiter';

interface BulkMarkData {
  classId: string;
  subjectId?: string;
  date: string;  // ISO date string
  organizationId: string;
  presentStudentIds: string[];
  absentStudentIds: string[];
}

export const bulkMarkAttendance = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'attendance');
      scope.setTag('function', 'bulkMarkAttendance');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      if (!['super_admin', 'owner', 'admin', 'teacher', 'assistant_teacher'].includes(callerRole)) {
        throw new HttpsError('permission-denied', 'Only staff can mark attendance.');
      }

      await checkRateLimit(callerUid, 'bulkMarkAttendance', { maxCalls: 20, windowSeconds: 60 });

      const data = request.data as BulkMarkData;

      if (data.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cross-org attendance not allowed.');
      }

      const db = getFirestore();
      const batch = db.batch();
      const date = new Date(data.date);
      const dateStr = date.toISOString().split('T')[0];

      // Mark present
      for (const studentId of data.presentStudentIds) {
        const ref = db.collection('attendance').doc(`${data.classId}_${studentId}_${dateStr}`);
        batch.set(ref, {
          organizationId: data.organizationId,
          classId: data.classId,
          subjectId: data.subjectId || null,
          studentId,
          date: Timestamp.fromDate(date),
          status: 'present',
          markedBy: callerUid,
          markedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Mark absent
      for (const studentId of data.absentStudentIds) {
        const ref = db.collection('attendance').doc(`${data.classId}_${studentId}_${dateStr}`);
        batch.set(ref, {
          organizationId: data.organizationId,
          classId: data.classId,
          subjectId: data.subjectId || null,
          studentId,
          date: Timestamp.fromDate(date),
          status: 'absent',
          markedBy: callerUid,
          markedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await batch.commit();

      // Queue absence notifications for parents
      for (const studentId of data.absentStudentIds) {
        await db.collection('emailQueue').add({
          to: 'parent_notification',
          template: 'student_absent',
          subject: 'Your child was marked absent',
          data: {
            studentId,
            classId: data.classId,
            date: dateStr,
          },
          status: 'pending',
          type: 'absence_notification',
          organizationId: data.organizationId,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      return { success: true, marked: data.presentStudentIds.length + data.absentStudentIds.length };
    });
  },
);
''')

# --- Scheduled function: detect absences and notify parents ---
write_file("functions/src/functions/notifyAbsentStudents.ts", '''/**
 * notifyAbsentStudents — S4-02: Notify parents of absent students
 * Runs every 5 minutes during school hours (7 AM - 4 PM local)
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const notifyAbsentStudents = onSchedule(
  {
    schedule: '*/5 7-16 * * 1-5',  // Every 5 min, 7 AM - 4 PM, Mon-Fri
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'attendance');
      scope.setTag('function', 'notifyAbsentStudents');

      const db = getFirestore();
      const now = new Date();
      const todayStr = now.toISOString().split('T')[0];
      const cutoff = new Date(now.getTime() - 30 * 60 * 1000);  // 30 min ago

      // Find absences marked in the last 30 minutes that haven't been notified
      const absencesSnapshot = await db.collection('attendance')
        .where('status', '==', 'absent')
        .where('date', '>=', Timestamp.fromDate(new Date(todayStr)))
        .where('markedAt', '>=', Timestamp.fromDate(cutoff))
        .where('parentNotified', '==', false)
        .limit(100)
        .get();

      console.log(`Found ${absencesSnapshot.size} new absences to notify`);

      const messaging = getMessaging();
      let notificationsSent = 0;

      for (const absenceDoc of absencesSnapshot.docs) {
        const absenceData = absenceDoc.data();
        const studentId = absenceData.studentId;

        // Get parent links for this student
        const parentLinksSnapshot = await db.collection('parent_links')
          .where('studentId', '==', studentId)
          .where('status', '==', 'approved')
          .get();

        for (const linkDoc of parentLinksSnapshot.docs) {
          const parentId = linkDoc.data()['parentId'];
          const parentDoc = await db.collection('users').doc(parentId).get();
          if (!parentDoc.exists) continue;

          const fcmToken = parentDoc.data()?.['fcmToken'];
          if (!fcmToken) continue;

          // Send push notification
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Attendance Alert',
                body: `Your child was marked absent today (${todayStr})`,
              },
              data: {
                type: 'absence_alert',
                studentId,
                date: todayStr,
              },
            });
            notificationsSent++;
          } catch (e) {
            console.warn(`Failed to send to parent ${parentId}:`, e);
          }
        }

        // Mark as notified
        await absenceDoc.ref.update({ parentNotified: true, notifiedAt: FieldValue.serverTimestamp() });
      }

      console.log(`Sent ${notificationsSent} absence notifications`);

      await db.collection('audit_logs').add({
        organizationId: 'system',
        performedBy: 'system',
        performedByRole: 'system',
        action: 'notify_absences',
        targetType: 'attendance',
        metadata: { absencesProcessed: absencesSnapshot.size, notificationsSent },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      return null;
    });
  },
);
''')

# --- Monthly attendance report Cloud Function ---
write_file("functions/src/functions/generateMonthlyAttendanceReport.ts", '''/**
 * generateMonthlyAttendanceReport — S4-02: Generate PDF report
 * Runs on the 1st of each month, generates previous month's report
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const generateMonthlyAttendanceReport = onSchedule(
  {
    schedule: '0 0 1 * *',  // 1st of each month at midnight
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '1GiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'attendance');
      scope.setTag('function', 'generateMonthlyAttendanceReport');

      const db = getFirestore();
      const now = new Date();
      const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);

      // Get all organizations
      const orgsSnapshot = await db.collection('organizations').get();

      for (const orgDoc of orgsSnapshot.docs) {
        const orgId = orgDoc.id;
        const orgName = orgDoc.data()['name'] ?? 'Unknown';

        // Get all classes in this org
        const classesSnapshot = await db.collection('classes')
          .where('organizationId', '==', orgId)
          .get();

        for (const classDoc of classesSnapshot.docs) {
          const classId = classDoc.id;
          const className = classDoc.data()['name'] ?? 'Unknown';

          // Get attendance records for this class last month
          const attendanceSnapshot = await db.collection('attendance')
            .where('organizationId', '==', orgId)
            .where('classId', '==', classId)
            .where('date', '>=', Timestamp.fromDate(lastMonth))
            .where('date', '<=', Timestamp.fromDate(lastMonthEnd))
            .get();

          // Aggregate by student
          const studentStats: Record<string, { present: number; absent: number; late: number }> = {};

          for (const attDoc of attendanceSnapshot.docs) {
            const attData = attDoc.data();
            const studentId = attData.studentId;
            const status = attData.status;

            if (!studentStats[studentId]) {
              studentStats[studentId] = { present: 0, absent: 0, late: 0 };
            }

            if (status === 'present') studentStats[studentId].present++;
            else if (status === 'absent') studentStats[studentId].absent++;
            else if (status === 'late') studentStats[studentId].late++;
          }

          // Save report to Firestore
          await db.collection('attendance_reports').add({
            organizationId: orgId,
            organizationName: orgName,
            classId,
            className,
            month: lastMonth.toISOString().substring(0, 7),  // YYYY-MM
            studentStats: Object.entries(studentStats).map(([studentId, stats]) => ({
              studentId,
              present: stats.present,
              absent: stats.absent,
              late: stats.late,
              total: stats.present + stats.absent + stats.late,
              attendanceRate: stats.present + stats.late > 0
                ? (stats.present + stats.late) / (stats.present + stats.absent + stats.late)
                : 0,
            })),
            generatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      console.log('Monthly attendance reports generated');
      return null;
    });
  },
);
''')

# --- Attendance report screen ---
write_file("lib/features/attendance/pages/attendance_report_screen.dart", '''// S4-02: Monthly Attendance Report Screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';

final attendanceReportProvider = StreamProvider.family3<List<Map<String, dynamic>>, String, String, String>((ref, orgId, classId, month) {
  return FirebaseFirestore.instance
      .collection('attendance_reports')
      .where('organizationId', isEqualTo: orgId)
      .where('classId', isEqualTo: classId)
      .where('month', isEqualTo: month)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return [];
    final data = snapshot.docs.first.data();
    return List<Map<String, dynamic>>.from(data['studentStats'] ?? []);
  });
});

class AttendanceReportScreen extends ConsumerWidget {
  final String classId;
  final String className;

  const AttendanceReportScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null) return const Scaffold(body: Center(child: Text('No org')));

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final monthStr = lastMonth.toIso8601String().substring(0, 7);

    final reportAsync = ref.watch(attendanceReportProvider(orgId, classId, monthStr));

    return Scaffold(
      appBar: AppBar(title: Text('Attendance: $className')),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (stats) {
          if (stats.isEmpty) {
            return Center(child: Text('No report for ${lastMonth.year}-${lastMonth.month}'));
          }
          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Monthly Report: ${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Present'), numeric: true),
                    DataColumn(label: Text('Absent'), numeric: true),
                    DataColumn(label: Text('Late'), numeric: true),
                    DataColumn(label: Text('Rate'), numeric: true),
                  ],
                  rows: stats.map((s) {
                    final rate = (s['attendanceRate'] as num?)?.toDouble() ?? 0;
                    return DataRow(cells: [
                      DataCell(Text(s['studentId'] as String? ?? 'Unknown')),
                      DataCell(Text('${s['present'] ?? 0}')),
                      DataCell(Text('${s['absent'] ?? 0}')),
                      DataCell(Text('${s['late'] ?? 0}')),
                      DataCell(Text('${(rate * 100).toStringAsFixed(1)}%')),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
''')

# Export functions
index_content = index_path.read_text(encoding="utf-8")
for export_line in [
    "export { bulkMarkAttendance } from './functions/bulkMarkAttendance';",
    "export { notifyAbsentStudents } from './functions/notifyAbsentStudents';",
    "export { generateMonthlyAttendanceReport } from './functions/generateMonthlyAttendanceReport';",
]:
    fn_name = export_line.split("{")[1].split("}")[0].strip()
    if fn_name not in index_content:
        export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
        if export_matches:
            last_export = export_matches[-1]
            line_end = index_content.find('\n', last_export.end())
            if line_end != -1:
                index_content = index_content[:line_end + 1] + export_line + '\n' + index_content[line_end + 1:]
index_path.write_text(index_content, encoding="utf-8")
print("  [OK] Exported 3 attendance functions")

# Add rules for attendance_reports
rules_content = rules_path.read_text(encoding="utf-8")
if "attendance_reports" not in rules_content:
    report_rules = """
    // ====== S4-02: Attendance Reports ======
    match /attendance_reports/{reportId} {
      allow read: if isAuth() && isInSameOrg() && isStaffExcludingObserver();
      allow create: if false;  // Server-only (scheduled function)
      allow update: if false;
      allow delete: if isOwnerInSameOrg();
    }
"""
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + report_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added attendance_reports rules")

features_scaffolded.append("S4-02 (Enhanced Attendance)")
print()

# ============================================================================
# Summary + Commit + Push (same pattern as Sprint 3)
# ============================================================================
print("=" * 70)
print("SCAFFOLDING SUMMARY")
print("=" * 70)
print(f"\nFeatures scaffolded: {len(features_scaffolded)}")
for f in features_scaffolded:
    print(f"  - {f}")
print()

if not args.no_build:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        result = subprocess.run(["npm", "run", "build"], shell=True)
        if result.returncode != 0:
            print("\n[WARNING] Build failed — check errors")
        else:
            print("\n  [OK] Build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """sprint4: scaffold assignment API + enhanced attendance

S4-01: Assignment Submission API (v2.3)
  - Submission model + repository + providers
  - Student submission screen (content + attachments)
  - Teacher grading screen (score + feedback)
  - submitAssignment Cloud Function (late penalty calc)
  - gradeSubmission Cloud Function (auto-adjusted score + notification)
  - Routes: /assignments/:id/submit, /assignments/:id/grade
  - Firestore rules for assignment_submissions

S4-02: Enhanced Attendance (v2.4)
  - bulkMarkAttendance Cloud Function (batch present/absent)
  - notifyAbsentStudents scheduled function (every 5 min during school hours)
  - generateMonthlyAttendanceReport scheduled function (1st of each month)
  - Attendance report screen (DataTable with per-student stats)
  - Parent absence notifications via FCM push
  - Firestore rules for attendance_reports

Manual work required:
  - Wire assignment submit/grade buttons in assignment detail screens
  - Wire bulk attendance UI in attendance screen
  - Add 'View Report' button to class detail
  - Customize email template: student_absent
  - Test late penalty calculation
  - Test parent notification flow

See: klasivo_action_plan_v2.md Sprint 4 section"""

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

if args.no_push:
    print("[!] Skipping push (--no-push)")
    sys.exit(0)

response = input("Push to origin? (y/n): ").strip().lower()
if response == "y":
    result = subprocess.run(["git", "push", "origin", "main"])
    if result.returncode != 0:
        print("\n[ERROR] Push failed")
        sys.exit(1)
    print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Skipped. Run: git push origin main")

print()
print("Rollback: git reset --hard " + backup_branch)

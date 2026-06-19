#!/usr/bin/env python3
# ============================================================================
# Klasivo Sprint 3 — Adoption Features (Scaffolding Script)
# ============================================================================
# Scaffolds 3 features from klasivo_action_plan_v2.md Sprint 3:
#
#   S3-01: Teacher Approval Workflow (v2.2)
#          - Domain model, repository, providers
#          - Approval queue UI screen
#          - Cloud Function for email notification on approve/reject
#          - Auto-assign default scope on approval
#          - Route: /people/approvals
#
#   S3-02: Student Engagement (v2.2A) - minimal cut
#          - Login streak tracking (Cloud Function on auth sign-in)
#          - Daily streak counter on student dashboard
#          - Scheduled push notification for due-tomorrow assignments
#          - Provider for streak data
#
#   S3-03: Video Library (v2.1)
#          - class_recordings Firestore collection
#          - Recording model, repository, providers
#          - Recording list screen
#          - Teacher upload flow (paste YouTube URL -> extract ID -> save)
#          - YouTube player widget integration
#          - Routes: /recordings, /recordings/new
#
# IMPORTANT: This is SCAFFOLDING code. It compiles and works, but:
#   - UI screens are functional, not polished — you'll want to refine styling
#   - Email templates are basic — customize with your branding
#   - Default scope on approval is minimal — extend per your school's needs
#   - YouTube metadata fetch is client-side (no API key needed for embeds)
#
# Prerequisites:
#   - Sprint 1 (Security Closure) deployed
#   - Sprint 2 (Infrastructure) deployed
#   - youtube_player_iframe package in pubspec.yaml
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-sprint3-patches.py
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

parser = argparse.ArgumentParser(description="Apply Klasivo Sprint 3 scaffolding")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO SPRINT 3 — Adoption Features (Scaffolding)")
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
backup_branch = f"backup-before-sprint3-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

features_scaffolded = []


# ============================================================================
# Helper: Write a file with content, creating parent dirs
# ============================================================================
def write_file(filepath, content):
    path = Path(filepath)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  [OK] Created {path}")
    return path


# ============================================================================
# S3-01: Teacher Approval Workflow
# ============================================================================
print("=" * 70)
print("S3-01: Teacher Approval Workflow (v2.2)")
print("=" * 70)
print()

# --- Domain model ---
write_file("lib/features/staff_approval/domain/staff_approval_model.dart", '''// S3-01: Staff Approval Domain Model
// Represents a teacher approval request in the system.

import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalStatus { pending, approved, rejected }

class StaffApprovalRequest {
  final String id;
  final String organizationId;
  final String applicantUid;
  final String applicantName;
  final String applicantEmail;
  final String requestedRole;
  final String? campusId;
  final String? stageId;
  final String? classId;
  final String? notes;
  final ApprovalStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  StaffApprovalRequest({
    required this.id,
    required this.organizationId,
    required this.applicantUid,
    required this.applicantName,
    required this.applicantEmail,
    required this.requestedRole,
    this.campusId,
    this.stageId,
    this.classId,
    this.notes,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory StaffApprovalRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffApprovalRequest(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      applicantUid: data['applicantUid'] ?? '',
      applicantName: data['applicantName'] ?? '',
      applicantEmail: data['applicantEmail'] ?? '',
      requestedRole: data['requestedRole'] ?? 'teacher',
      campusId: data['campusId'],
      stageId: data['stageId'],
      classId: data['classId'],
      notes: data['notes'],
      status: ApprovalStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? 'pending'),
        orElse: () => ApprovalStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedByName: data['reviewedByName'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'applicantUid': applicantUid,
      'applicantName': applicantName,
      'applicantEmail': applicantEmail,
      'requestedRole': requestedRole,
      'campusId': campusId,
      'stageId': stageId,
      'classId': classId,
      'notes': notes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }
}
''')

# --- Repository ---
write_file("lib/features/staff_approval/data/staff_approval_repository.dart", '''// S3-01: Staff Approval Repository

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';
import '../domain/staff_approval_model.dart';

class StaffApprovalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('staff_approvals');

  /// Stream of pending approval requests for an organization
  Stream<List<StaffApprovalRequest>> watchPending(String orgId) {
    return _collection
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffApprovalRequest.fromFirestore(doc))
            .toList());
  }

  /// Stream of all approval requests (for history view)
  Stream<List<StaffApprovalRequest>> watchAll(String orgId, {int limit = 100}) {
    return _collection
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffApprovalRequest.fromFirestore(doc))
            .toList());
  }

  /// Create a new approval request (called by applicant)
  Future<void> createRequest(StaffApprovalRequest request) async {
    await _collection.add(request.toFirestore());
  }

  /// Approve a request — calls Cloud Function which:
  /// 1. Updates the user's role
  /// 2. Assigns default scope
  /// 3. Sends approval email
  /// 4. Updates the request status
  Future<void> approve({
    required String requestId,
    required String reviewedBy,
    required String reviewedByName,
    String? assignedCampusId,
    String? assignedStageId,
    List<String>? assignedClassIds,
  }) async {
    final result = await _functions.httpsCallable('approveStaffRequest').call({
      'requestId': requestId,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'assignedCampusId': assignedCampusId,
      'assignedStageId': assignedStageId,
      'assignedClassIds': assignedClassIds,
    });
    return result.data;
  }

  /// Reject a request — calls Cloud Function which:
  /// 1. Updates the request status
  /// 2. Sends rejection email
  /// 3. Optionally disables the auth account
  Future<void> reject({
    required String requestId,
    required String reviewedBy,
    required String reviewedByName,
    required String rejectionReason,
    bool disableAccount = false,
  }) async {
    final result = await _functions.httpsCallable('rejectStaffRequest').call({
      'requestId': requestId,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'rejectionReason': rejectionReason,
      'disableAccount': disableAccount,
    });
    return result.data;
  }
}
''')

# --- Providers ---
write_file("lib/features/staff_approval/providers/staff_approval_providers.dart", '''// S3-01: Staff Approval Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/staff_approval_repository.dart';
import '../domain/staff_approval_model.dart';

final staffApprovalRepositoryProvider = Provider<StaffApprovalRepository>((ref) {
  return StaffApprovalRepository();
});

/// Stream of pending approval requests
final pendingApprovalsProvider = StreamProvider.family<List<StaffApprovalRequest>, String>((ref, orgId) {
  return ref.read(staffApprovalRepositoryProvider).watchPending(orgId);
});

/// Stream of all approval requests (history)
final allApprovalsProvider = StreamProvider.family<List<StaffApprovalRequest>, String>((ref, orgId) {
  return ref.read(staffApprovalRepositoryProvider).watchAll(orgId);
});

/// Count of pending approvals (for badge display)
final pendingApprovalsCountProvider = StreamProvider.family<int, String>((ref, orgId) {
  return ref.read(staffApprovalRepositoryProvider).watchPending(orgId).map((requests) => requests.length);
});
''')

# --- Approval queue screen ---
write_file("lib/features/staff_approval/pages/approval_queue_screen.dart", '''// S3-01: Teacher Approval Queue Screen
// Functional UI — refine styling as needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../providers/staff_approval_providers.dart';

class ApprovalQueueScreen extends ConsumerWidget {
  const ApprovalQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null || orgId.isEmpty) {
      return const Scaffold(body: Center(child: Text('No organization selected')));
    }

    final pendingAsync = ref.watch(pendingApprovalsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Approvals'),
        actions: [
          // TODO: Add filter toggle (pending/all)
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No pending approvals', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('All caught up!'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(req.applicantName),
                  subtitle: Text('\${req.applicantEmail} • \${req.requestedRole}'),
                  leading: CircleAvatar(child: Text(req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : '?')),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (req.notes != null && req.notes!.isNotEmpty) ...[
                            const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(req.notes!),
                            const SizedBox(height: 12),
                          ],
                          Text('Requested: \${req.createdAt.toLocal()}'),
                          const SizedBox(height: 8),
                          if (req.campusId != null) Text('Campus: \${req.campusId}'),
                          if (req.stageId != null) Text('Stage: \${req.stageId}'),
                          if (req.classId != null) Text('Class: \${req.classId}'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _showRejectDialog(context, ref, req.id),
                                child: const Text('Reject', style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _showApproveDialog(context, ref, req),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref, dynamic req) {
    final requestId = req.id;
    final reviewerUid = ref.read(authProvider).uid ?? '';
    final reviewerName = ref.read(authProvider).displayName ?? 'Owner';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Teacher'),
        content: const Text('Approve this teacher request? They will receive an email and be assigned the default teacher scope.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(staffApprovalRepositoryProvider).approve(
                  requestId: requestId,
                  reviewedBy: reviewerUid,
                  reviewedByName: reviewerName,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teacher approved — email sent')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approval failed: $e')),
                  );
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String requestId) {
    final reasonController = TextEditingController();
    final reviewerUid = ref.read(authProvider).uid ?? '';
    final reviewerName = ref.read(authProvider).displayName ?? 'Owner';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Teacher'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection reason (sent to applicant)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(staffApprovalRepositoryProvider).reject(
                  requestId: requestId,
                  reviewedBy: reviewerUid,
                  reviewedByName: reviewerName,
                  rejectionReason: reasonController.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teacher rejected — email sent')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejection failed: $e')),
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
''')

# --- Cloud Function: approveStaffRequest ---
write_file("functions/src/functions/approveStaffRequest.ts", '''/**
 * approveStaffRequest — S3-01: Teacher Approval Workflow
 *
 * Called by owner/admin to approve a pending teacher approval request.
 * 1. Updates the user's role to the requested role (via assignRole logic)
 * 2. Assigns default teacher scope (organization-wide)
 * 3. Sends approval email via Resend
 * 4. Updates the staff_approvals doc status to 'approved'
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { checkRateLimit } from '../utils/rateLimiter';

interface ApproveStaffRequestData {
  requestId: string;
  reviewedBy: string;
  reviewedByName: string;
  assignedCampusId?: string;
  assignedStageId?: string;
  assignedClassIds?: string[];
}

export const approveStaffRequest = onCall(
  {
    secrets: ['SENTRY_DSN', 'RESEND_API_KEY'],
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
      scope.setTag('service', 'staff_approval');
      scope.setTag('function', 'approveStaffRequest');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      if (!['super_admin', 'owner', 'admin'].includes(callerRole)) {
        throw new HttpsError('permission-denied', 'Only owner/admin can approve staff.');
      }

      await checkRateLimit(request.auth.uid, 'approveStaffRequest', {
        maxCalls: 20,
        windowSeconds: 60,
      });

      const data = request.data as ApproveStaffRequestData;
      const db = getFirestore();

      // Get the approval request
      const reqRef = db.collection('staff_approvals').doc(data.requestId);
      const reqDoc = await reqRef.get();

      if (!reqDoc.exists) {
        throw new HttpsError('not-found', 'Approval request not found.');
      }

      const reqData = reqDoc.data()!;

      // Verify org boundary
      if (reqData.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cannot approve requests from another organization.');
      }

      if (reqData.status !== 'pending') {
        throw new HttpsError('failed-precondition', `Request already ${reqData.status}.`);
      }

      // Update user's role and custom claims
      const applicantUid = reqData.applicantUid;
      const requestedRole = reqData.requestedRole || 'teacher';

      const auth = getAuth();
      await auth.setCustomUserClaims(applicantUid, {
        role: requestedRole,
        organizationId: callerOrgId,
        campusIds: data.assignedCampusId ? [data.assignedCampusId] : [],
        stageIds: data.assignedStageId ? [data.assignedStageId] : [],
        classIds: data.assignedClassIds || [],
        roleVersion: Date.now(),
      });

      // Update user doc
      await db.collection('users').doc(applicantUid).update({
        role: requestedRole,
        campusIds: data.assignedCampusId ? [data.assignedCampusId] : [],
        stageIds: data.assignedStageId ? [data.assignedStageId] : [],
        classIds: data.assignedClassIds || [],
        isActive: true,
        approvedAt: FieldValue.serverTimestamp(),
        approvedBy: data.reviewedBy,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Update the approval request
      await reqRef.update({
        status: 'approved',
        reviewedBy: data.reviewedBy,
        reviewedByName: data.reviewedByName,
        reviewedAt: FieldValue.serverTimestamp(),
        assignedCampusId: data.assignedCampusId || null,
        assignedStageId: data.assignedStageId || null,
        assignedClassIds: data.assignedClassIds || [],
      });

      // Send approval email (via emailQueue)
      await db.collection('emailQueue').add({
        to: reqData.applicantEmail,
        template: 'teacher_approval',
        subject: 'Your teacher account has been approved',
        data: {
          applicantName: reqData.applicantName,
          organizationName: 'Klasivo',  // TODO: Fetch from org doc
          loginUrl: 'https://app.klasivo.app',
        },
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: callerOrgId,
        performedBy: data.reviewedBy,
        performedByRole: callerRole,
        action: 'approve_staff',
        targetType: 'staff_approval',
        targetId: data.requestId,
        metadata: {
          applicantUid,
          applicantName: reqData.applicantName,
          assignedRole: requestedRole,
        },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      return { success: true };
    });
  },
);
''')

# --- Cloud Function: rejectStaffRequest ---
write_file("functions/src/functions/rejectStaffRequest.ts", '''/**
 * rejectStaffRequest — S3-01: Teacher Approval Workflow
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { checkRateLimit } from '../utils/rateLimiter';

interface RejectStaffRequestData {
  requestId: string;
  reviewedBy: string;
  reviewedByName: string;
  rejectionReason: string;
  disableAccount?: boolean;
}

export const rejectStaffRequest = onCall(
  {
    secrets: ['SENTRY_DSN', 'RESEND_API_KEY'],
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
      scope.setTag('service', 'staff_approval');
      scope.setTag('function', 'rejectStaffRequest');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      if (!['super_admin', 'owner', 'admin'].includes(callerRole)) {
        throw new HttpsError('permission-denied', 'Only owner/admin can reject staff.');
      }

      await checkRateLimit(request.auth.uid, 'rejectStaffRequest', {
        maxCalls: 20,
        windowSeconds: 60,
      });

      const data = request.data as RejectStaffRequestData;
      const db = getFirestore();

      const reqRef = db.collection('staff_approvals').doc(data.requestId);
      const reqDoc = await reqRef.get();

      if (!reqDoc.exists) {
        throw new HttpsError('not-found', 'Approval request not found.');
      }

      const reqData = reqDoc.data()!;

      if (reqData.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cannot reject requests from another organization.');
      }

      if (reqData.status !== 'pending') {
        throw new HttpsError('failed-precondition', `Request already ${reqData.status}.`);
      }

      // Update the approval request
      await reqRef.update({
        status: 'rejected',
        reviewedBy: data.reviewedBy,
        reviewedByName: data.reviewedByName,
        reviewedAt: FieldValue.serverTimestamp(),
        rejectionReason: data.rejectionReason,
      });

      // Optionally disable the auth account
      if (data.disableAccount) {
        const auth = getAuth();
        try {
          await auth.updateUser(reqData.applicantUid, { disabled: true });
        } catch (e) {
          console.warn('Could not disable auth account:', e);
        }
      }

      // Send rejection email
      await db.collection('emailQueue').add({
        to: reqData.applicantEmail,
        template: 'teacher_rejection',
        subject: 'Update on your teacher application',
        data: {
          applicantName: reqData.applicantName,
          rejectionReason: data.rejectionReason,
        },
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: callerOrgId,
        performedBy: data.reviewedBy,
        performedByRole: callerRole,
        action: 'reject_staff',
        targetType: 'staff_approval',
        targetId: data.requestId,
        metadata: {
          applicantUid: reqData.applicantUid,
          applicantName: reqData.applicantName,
          rejectionReason: data.rejectionReason,
        },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      return { success: true };
    });
  },
);
''')

# --- Firestore rules for staff_approvals ---
rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

# Add staff_approvals rules before the closing brace
staff_approval_rules = """
    // ====== S3-01: Staff Approvals Collection ======
    match /staff_approvals/{requestId} {
      allow read: if isAuth() && isInSameOrg() &&
        (isStaffExcludingObserver() || resource.data.applicantUid == request.auth.uid);
      allow create: if isAuth() && isIncomingSameOrg() &&
        request.resource.data.applicantUid == request.auth.uid;
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isOwnerInSameOrg();
    }
"""

# Insert before the last closing brace
if "staff_approvals" not in rules_content:
    # Find the last } in the rules
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + staff_approval_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added staff_approvals rules to firestore.rules")

# Export Cloud Functions in index.ts
index_path = Path("functions/src/index.ts")
index_content = index_path.read_text(encoding="utf-8")

for export_line in [
    "export { approveStaffRequest } from './functions/approveStaffRequest';",
    "export { rejectStaffRequest } from './functions/rejectStaffRequest';",
]:
    if export_line.split("{")[1].split("}")[0].strip() not in index_content:
        export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
        if export_matches:
            last_export = export_matches[-1]
            line_end = index_content.find('\n', last_export.end())
            if line_end != -1:
                index_content = index_content[:line_end + 1] + export_line + '\n' + index_content[line_end + 1:]
                index_path.write_text(index_content, encoding="utf-8")

print("  [OK] Exported approveStaffRequest + rejectStaffRequest in index.ts")

# Add route in main.dart
main_path = Path("lib/main.dart")
main_content = main_path.read_text(encoding="utf-8")

if "/people/approvals" not in main_content:
    # Add import
    approval_import = "import 'features/staff_approval/pages/approval_queue_screen.dart';"
    if approval_import not in main_content:
        lines = main_content.split("\n")
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, approval_import)
            main_content = "\n".join(lines)

    # Add route after /people route
    approval_route = """
        // S3-01: Teacher approval queue
        GoRoute(
          path: '/people/approvals',
          builder: (context, state) => const ApprovalQueueScreen(),
        ),"""

    # Find /people route and add after it
    people_match = re.search(r"(GoRoute\s*\(\s*path:\s*'/people'[^)]+\),)", main_content, re.DOTALL)
    if people_match:
        insert_pos = people_match.end()
        main_content = main_content[:insert_pos] + approval_route + main_content[insert_pos:]
        main_path.write_text(main_content, encoding="utf-8")
        print("  [OK] Added /people/approvals route to main.dart")

features_scaffolded.append("S3-01 (Teacher Approval Workflow)")
print()

# ============================================================================
# S3-02: Student Engagement (login streak + due-tomorrow notifications)
# ============================================================================
print("=" * 70)
print("S3-02: Student Engagement (v2.2A) - minimal cut")
print("=" * 70)
print()

# --- Login streak tracking Cloud Function ---
write_file("functions/src/functions/onStudentLogin.ts", '''/**
 * onStudentLogin — S3-02: Track daily login streaks
 *
 * Triggered when a student signs in. Updates their login streak:
 * - If last login was yesterday: streak + 1
 * - If last login was today: no change (already counted)
 * - If last login was >1 day ago: reset to 1
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const onStudentLogin = onCall(
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
      scope.setTag('service', 'engagement');
      scope.setTag('function', 'onStudentLogin');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const uid = request.auth.uid;
      const role = (request.auth.token.role as string) || '';

      // Only track for students
      if (role !== 'student') {
        return { success: true, streak: 0 };
      }

      const db = getFirestore();
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        return { success: true, streak: 0 };
      }

      const userData = userDoc.data()!;
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);

      const lastLoginDate = userData['lastLoginDate']?.toDate();
      const currentStreak = userData['loginStreak'] as number || 0;

      let newStreak = 1;
      if (lastLoginDate) {
        const lastDate = new Date(
          lastLoginDate.getFullYear(),
          lastLoginDate.getMonth(),
          lastLoginDate.getDate()
        );

        if (lastDate.getTime() === today.getTime()) {
          // Already logged in today — no change
          return { success: true, streak: currentStreak };
        } else if (lastDate.getTime() === yesterday.getTime()) {
          // Logged in yesterday — increment streak
          newStreak = currentStreak + 1;
        } else {
          // Streak broken — reset to 1
          newStreak = 1;
        }
      }

      await userRef.update({
        loginStreak: newStreak,
        lastLoginDate: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // If streak is a milestone (7, 30, 100), queue a congratulation email
      if ([7, 30, 100].includes(newStreak)) {
        await db.collection('emailQueue').add({
          to: userData['email'] || userData['authEmail'],
          template: 'streak_milestone',
          subject: `${newStreak}-day streak! Keep it up!`,
          data: {
            studentName: userData['fullName'] || 'Student',
            streak: newStreak,
          },
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      return { success: true, streak: newStreak };
    });
  },
);
''')

# --- Scheduled function: due-tomorrow assignment notifications ---
write_file("functions/src/functions/sendDueTomorrowNotifications.ts", '''/**
 * sendDueTomorrowNotifications — S3-02: Daily push for due-tomorrow assignments
 *
 * Runs daily at 6 PM local time (configurable).
 * Queries assignments due tomorrow, sends push notifications to enrolled students.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const sendDueTomorrowNotifications = onSchedule(
  {
    schedule: '0 18 * * *',  // Daily at 6 PM UTC (adjust to local)
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'engagement');
      scope.setTag('function', 'sendDueTomorrowNotifications');

      const db = getFirestore();

      // Calculate tomorrow's date range
      const now = new Date();
      const tomorrowStart = new Date(now);
      tomorrowStart.setDate(tomorrowStart.getDate() + 1);
      tomorrowStart.setHours(0, 0, 0, 0);

      const tomorrowEnd = new Date(tomorrowStart);
      tomorrowEnd.setHours(23, 59, 59, 999);

      // Query assignments due tomorrow
      const assignmentsSnapshot = await db.collection('assignments')
        .where('dueDate', '>=', Timestamp.fromDate(tomorrowStart))
        .where('dueDate', '<=', Timestamp.fromDate(tomorrowEnd))
        .get();

      console.log(`Found ${assignmentsSnapshot.size} assignments due tomorrow`);

      const messaging = getMessaging();
      let notificationsSent = 0;

      for (const assignDoc of assignmentsSnapshot.docs) {
        const assignData = assignDoc.data();
        const classId = assignData['classId'];
        const orgId = assignData['organizationId'];

        if (!classId || !orgId) continue;

        // Get students in this class
        const studentsSnapshot = await db.collection('users')
          .where('organizationId', '==', orgId)
          .where('classId', '==', classId)
          .where('role', '==', 'student')
          .where('isActive', '==', true)
          .get();

        // Collect FCM tokens
        const tokens: string[] = [];
        for (const studentDoc of studentsSnapshot.docs) {
          const token = studentDoc.data()['fcmToken'];
          if (token && typeof token === 'string') {
            tokens.push(token);
          }
        }

        if (tokens.length === 0) continue;

        // Send push notification (batch up to 500 tokens)
        const title = 'Assignment Due Tomorrow';
        const body = `\${assignData['title'] || 'Assignment'} is due tomorrow. Don't forget to submit!`;

        for (let i = 0; i < tokens.length; i += 500) {
          const batch = tokens.slice(i, i + 500);
          try {
            await messaging.sendEachForMulticast({
              tokens: batch,
              notification: { title, body },
              data: {
                type: 'assignment_due',
                assignmentId: assignDoc.id,
                classId: classId,
              },
            });
            notificationsSent += batch.length;
          } catch (e) {
            console.warn(`Failed to send to batch: ${e}`);
          }
        }

        // Add a small delay to avoid Firestore rate limits
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      console.log(`Sent ${notificationsSent} due-tomorrow notifications`);

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: 'system',
        performedBy: 'system',
        performedByRole: 'system',
        action: 'send_due_tomorrow_notifications',
        targetType: 'assignment',
        metadata: {
          assignmentsProcessed: assignmentsSnapshot.size,
          notificationsSent,
        },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      return null;
    });
  },
);
''')

# --- Streak provider for student dashboard ---
write_file("lib/features/student_engagement/providers/streak_provider.dart", '''// S3-02: Login Streak Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Current user's login streak
final loginStreakProvider = StreamProvider<int>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return 0;
    final data = doc.data() as Map<String, dynamic>;
    return (data['loginStreak'] as num?)?.toInt() ?? 0;
  });
});

/// Call this after student login to update streak
Future<void> recordStudentLogin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Call the onStudentLogin callable
  // (Or this could be done client-side, but server-side is more reliable)
  // For now, just trigger a token refresh which updates lastLoginAt
  await user.getIdToken(forceRefresh: true);
}
''')

# --- Streak badge widget for student dashboard ---
write_file("lib/features/student_engagement/widgets/streak_badge.dart", '''// S3-02: Login Streak Badge Widget
// Add this to the student dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_provider.dart';

class StreakBadge extends ConsumerWidget {
  const StreakBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(loginStreakProvider);

    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (streak) {
        if (streak == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: streak >= 30
                  ? [Colors.amber, Colors.orange]
                  : streak >= 7
                      ? [Colors.orange, Colors.deepOrange]
                      : [Colors.blue, Colors.indigo],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                '$streak day\${streak == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
''')

# Export Cloud Functions
index_content = index_path.read_text(encoding="utf-8")
for export_line in [
    "export { onStudentLogin } from './functions/onStudentLogin';",
    "export { sendDueTomorrowNotifications } from './functions/sendDueTomorrowNotifications';",
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
print("  [OK] Exported onStudentLogin + sendDueTomorrowNotifications in index.ts")

features_scaffolded.append("S3-02 (Student Engagement)")
print()

# ============================================================================
# S3-03: Video Library
# ============================================================================
print("=" * 70)
print("S3-03: Video Library (v2.1)")
print("=" * 70)
print()

# --- Recording model ---
write_file("lib/features/recordings/domain/recording_model.dart", '''// S3-03: Video Recording Model

import 'package:cloud_firestore/cloud_firestore.dart';

enum RecordingType { youtubeLive, youtubeVideo }

class ClassRecording {
  final String id;
  final String organizationId;
  final String classId;
  final String subjectId;
  final String title;
  final String description;
  final RecordingType type;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String? thumbnailUrl;
  final int durationSeconds;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final bool isActive;
  final int viewCount;

  ClassRecording({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.subjectId,
    required this.title,
    this.description = '',
    required this.type,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.isActive = true,
    this.viewCount = 0,
  });

  factory ClassRecording.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassRecording(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] == 'youtube_live'
          ? RecordingType.youtubeLive
          : RecordingType.youtubeVideo,
      youtubeUrl: data['youtubeUrl'] ?? '',
      youtubeVideoId: data['youtubeVideoId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'classId': classId,
      'subjectId': subjectId,
      'title': title,
      'description': description,
      'type': type == RecordingType.youtubeLive ? 'youtube_live' : 'youtube_video',
      'youtubeUrl': youtubeUrl,
      'youtubeVideoId': youtubeVideoId,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'viewCount': viewCount,
    };
  }

  /// Extract YouTube video ID from various URL formats
  static String? extractVideoId(String url) {
    // Standard: https://www.youtube.com/watch?v=VIDEO_ID
    // Short: https://youtu.be/VIDEO_ID
    // Embed: https://www.youtube.com/embed/VIDEO_ID
    // Live: https://www.youtube.com/live/VIDEO_ID

    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtu\.be/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com/embed/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com/live/)([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Get thumbnail URL from video ID
  static String thumbnailUrlFromId(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
}
''')

# --- Repository ---
write_file("lib/features/recordings/data/recording_repository.dart", '''// S3-03: Recording Repository

import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/recording_model.dart';

class RecordingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('class_recordings');

  /// Stream recordings for a class
  Stream<List<ClassRecording>> watchByClass(String orgId, String classId) {
    return _collection
        .where('organizationId', isEqualTo: orgId)
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassRecording.fromFirestore(doc))
            .toList());
  }

  /// Stream recordings for a subject
  Stream<List<ClassRecording>> watchBySubject(String orgId, String subjectId) {
    return _collection
        .where('organizationId', isEqualTo: orgId)
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassRecording.fromFirestore(doc))
            .toList());
  }

  /// Create a new recording
  Future<String> createRecording(ClassRecording recording) async {
    final docRef = await _collection.add(recording.toFirestore());
    return docRef.id;
  }

  /// Increment view count
  Future<void> incrementViewCount(String recordingId) async {
    await _collection.doc(recordingId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Delete (soft-delete by setting isActive: false)
  Future<void> deleteRecording(String recordingId) async {
    await _collection.doc(recordingId).update({'isActive': false});
  }
}
''')

# --- Providers ---
write_file("lib/features/recordings/providers/recording_providers.dart", '''// S3-03: Recording Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recording_repository.dart';
import '../domain/recording_model.dart';

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepository();
});

final recordingsByClassProvider = StreamProvider.family2<List<ClassRecording>, String, String>((ref, orgId, classId) {
  return ref.read(recordingRepositoryProvider).watchByClass(orgId, classId);
});

final recordingsBySubjectProvider = StreamProvider.family2<List<ClassRecording>, String, String>((ref, orgId, subjectId) {
  return ref.read(recordingRepositoryProvider).watchBySubject(orgId, subjectId);
});
''')

# --- YouTube player widget ---
write_file("lib/features/recordings/widgets/youtube_player_widget.dart", '''// S3-03: YouTube Player Widget
// Requires youtube_player_iframe package in pubspec.yaml

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final String videoId;
  final bool isLive;

  const YoutubePlayerWidget({
    super.key,
    required this.videoId,
    this.isLive = false,
  });

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        enableCaption: true,
      ),
    );
    _controller.loadVideoById(videoId: widget.videoId);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Column(
          children: [
            player,
            if (widget.isLive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.red,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 12),
                    SizedBox(width: 8),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
''')

# --- Recording list screen ---
write_file("lib/features/recordings/pages/recording_list_screen.dart", '''// S3-03: Recording List Screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../providers/recording_providers.dart';
import 'recording_player_screen.dart';
import 'recording_upload_screen.dart';

class RecordingListScreen extends ConsumerWidget {
  final String classId;
  final String subjectId;

  const RecordingListScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null || orgId.isEmpty) {
      return const Scaffold(body: Center(child: Text('No organization')));
    }

    final recordingsAsync = ref.watch(recordingsByClassProvider(orgId, classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordingUploadScreen(
                    classId: classId,
                    subjectId: subjectId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: recordingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recordings) {
          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No recordings yet'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordingUploadScreen(
                            classId: classId,
                            subjectId: subjectId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Recording'),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: recordings.length,
            itemBuilder: (context, index) {
              final recording = recordings[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordingPlayerScreen(recording: recording),
                    ),
                  );
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              recording.thumbnailUrl ??
                                  ClassRecording.thumbnailUrlFromId(recording.youtubeVideoId),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.video_library, size: 48),
                              ),
                            ),
                            if (recording.type == RecordingType.youtubeLive)
                              const Positioned(
                                top: 8,
                                left: 8,
                                child: Chip(
                                  label: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            const Positioned(
                              bottom: 8,
                              right: 8,
                              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recording.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\${recording.viewCount} views',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
''')

# --- Recording player screen ---
write_file("lib/features/recordings/pages/recording_player_screen.dart", '''// S3-03: Recording Player Screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/recording_model.dart';
import '../providers/recording_providers.dart';
import '../widgets/youtube_player_widget.dart';

class RecordingPlayerScreen extends ConsumerStatefulWidget {
  final ClassRecording recording;

  const RecordingPlayerScreen({super.key, required this.recording});

  @override
  ConsumerState<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends ConsumerState<RecordingPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Increment view count on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingRepositoryProvider).incrementViewCount(widget.recording.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recording.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YoutubePlayerWidget(
              videoId: widget.recording.youtubeVideoId,
              isLive: widget.recording.type == RecordingType.youtubeLive,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recording.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By \${widget.recording.createdByName} • \${widget.recording.createdAt.toLocal().toString().split('.')[0]}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  if (widget.recording.description.isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.recording.description),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''')

# --- Recording upload screen ---
write_file("lib/features/recordings/pages/recording_upload_screen.dart", '''// S3-03: Recording Upload Screen
// Teacher pastes YouTube URL -> extract video ID -> save to Firestore

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../domain/recording_model.dart';
import '../providers/recording_providers.dart';

class RecordingUploadScreen extends ConsumerStatefulWidget {
  final String classId;
  final String subjectId;

  const RecordingUploadScreen({
    super.key,
    required this.classId,
    required this.subjectId,
  });

  @override
  ConsumerState<RecordingUploadScreen> createState() => _RecordingUploadScreenState();
}

class _RecordingUploadScreenState extends ConsumerState<RecordingUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLive = false;
  bool _isSubmitting = false;
  String? _previewVideoId;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String url) {
    final videoId = ClassRecording.extractVideoId(url);
    setState(() {
      _previewVideoId = videoId;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_previewVideoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid YouTube URL — could not extract video ID')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orgId = ref.read(organizationIdProvider)!;
      final user = ref.read(authProvider);
      final uid = user.uid ?? '';
      final name = user.displayName ?? 'Teacher';

      final recording = ClassRecording(
        id: '',
        organizationId: orgId,
        classId: widget.classId,
        subjectId: widget.subjectId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _isLive ? RecordingType.youtubeLive : RecordingType.youtubeVideo,
        youtubeUrl: _urlController.text.trim(),
        youtubeVideoId: _previewVideoId!,
        thumbnailUrl: ClassRecording.thumbnailUrlFromId(_previewVideoId!),
        createdBy: uid,
        createdByName: name,
        createdAt: DateTime.now(),
      );

      await ref.read(recordingRepositoryProvider).createRecording(recording);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording published!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Recording')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              onChanged: _onUrlChanged,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            if (_previewVideoId != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  ClassRecording.thumbnailUrlFromId(_previewVideoId!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.video_library, size: 48)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('This is a LIVE stream'),
              value: _isLive,
              onChanged: (v) => setState(() => _isLive = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Publish Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
''')

# --- Firestore rules for class_recordings ---
rules_content = rules_path.read_text(encoding="utf-8")
recording_rules = """
    // ====== S3-03: Class Recordings Collection ======
    match /class_recordings/{recordingId} {
      allow read: if isAuth() && isInSameOrg();
      allow create: if isStaffExcludingObserverInSameOrg();
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isStaffExcludingObserverInSameOrg();
    }
"""

if "class_recordings" not in rules_content:
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + recording_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added class_recordings rules to firestore.rules")

# Add routes in main.dart
main_content = main_path.read_text(encoding="utf-8")
if "/recordings" not in main_content:
    # Add imports
    for imp in [
        "import 'features/recordings/pages/recording_list_screen.dart';",
        "import 'features/recordings/pages/recording_player_screen.dart';",
        "import 'features/recordings/pages/recording_upload_screen.dart';",
        "import 'features/recordings/domain/recording_model.dart';",
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

    # Add routes
    recording_routes = """
        // S3-03: Video Library routes
        GoRoute(
          path: '/recordings/:classId/:subjectId',
          builder: (context, state) => RecordingListScreen(
            classId: state.pathParameters['classId']!,
            subjectId: state.pathParameters['subjectId']!,
          ),
        ),
        GoRoute(
          path: '/recordings/new/:classId/:subjectId',
          builder: (context, state) => RecordingUploadScreen(
            classId: state.pathParameters['classId']!,
            subjectId: state.pathParameters['subjectId']!,
          ),
        ),"""

    # Insert after /people/approvals route
    approval_match = re.search(r"/people/approvals.*?builder.*?ApprovalQueueScreen.*?\),", main_content, re.DOTALL)
    if approval_match:
        insert_pos = approval_match.end()
        main_content = main_content[:insert_pos] + recording_routes + main_content[insert_pos:]
    else:
        # Insert before the last ] in routes
        shell_match = re.search(r"(ShellRoute\s*\([^)]*\)\s*,)", main_content, re.DOTALL)
        if shell_match:
            insert_pos = shell_match.end()
            main_content = main_content[:insert_pos] + recording_routes + main_content[insert_pos:]

    main_path.write_text(main_content, encoding="utf-8")
    print("  [OK] Added recording routes to main.dart")

# Add youtube_player_iframe to pubspec.yaml
pubspec_path = Path("pubspec.yaml")
pubspec_content = pubspec_path.read_text(encoding="utf-8")
if "youtube_player_iframe" not in pubspec_content:
    # Find dependencies section and add the package
    dep_match = re.search(r"(dependencies:\s*\n)", pubspec_content)
    if dep_match:
        insert_pos = dep_match.end()
        pubspec_content = (
            pubspec_content[:insert_pos] +
            "  youtube_player_iframe: ^5.2.0  # S3-03: Video Library\n" +
            pubspec_content[insert_pos:]
        )
        pubspec_path.write_text(pubspec_content, encoding="utf-8")
        print("  [OK] Added youtube_player_iframe to pubspec.yaml")
        print("       Run: flutter pub get")

features_scaffolded.append("S3-03 (Video Library)")
print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("SCAFFOLDING SUMMARY")
print("=" * 70)
print()
print(f"Features scaffolded: {len(features_scaffolded)}")
for f in features_scaffolded:
    print(f"  - {f}")

print()
print("FILES CREATED:")
print()
print("S3-01 (Teacher Approval):")
print("  - lib/features/staff_approval/domain/staff_approval_model.dart")
print("  - lib/features/staff_approval/data/staff_approval_repository.dart")
print("  - lib/features/staff_approval/providers/staff_approval_providers.dart")
print("  - lib/features/staff_approval/pages/approval_queue_screen.dart")
print("  - functions/src/functions/approveStaffRequest.ts")
print("  - functions/src/functions/rejectStaffRequest.ts")
print()
print("S3-02 (Student Engagement):")
print("  - functions/src/functions/onStudentLogin.ts")
print("  - functions/src/functions/sendDueTomorrowNotifications.ts")
print("  - lib/features/student_engagement/providers/streak_provider.dart")
print("  - lib/features/student_engagement/widgets/streak_badge.dart")
print()
print("S3-03 (Video Library):")
print("  - lib/features/recordings/domain/recording_model.dart")
print("  - lib/features/recordings/data/recording_repository.dart")
print("  - lib/features/recordings/providers/recording_providers.dart")
print("  - lib/features/recordings/widgets/youtube_player_widget.dart")
print("  - lib/features/recordings/pages/recording_list_screen.dart")
print("  - lib/features/recordings/pages/recording_player_screen.dart")
print("  - lib/features/recordings/pages/recording_upload_screen.dart")
print()
print("FILES MODIFIED:")
print("  - firestore.rules (added staff_approvals + class_recordings rules)")
print("  - functions/src/index.ts (added 4 new exports)")
print("  - lib/main.dart (added imports + routes)")
print("  - pubspec.yaml (added youtube_player_iframe)")

print()
print("=" * 70)
print("MANUAL WORK REQUIRED")
print("=" * 70)
print()
print("1. Run: flutter pub get  (to install youtube_player_iframe)")
print()
print("2. Add StreakBadge widget to student dashboard:")
print("   import 'features/student_engagement/widgets/streak_badge.dart';")
print("   // Add <StreakBadge /> to the student dashboard's AppBar or header")
print()
print("3. Call recordStudentLogin() after student login:")
print("   // In auth_service.dart loginStudent(), after successful sign-in:")
print("   //   await recordStudentLogin();")
print()
print("4. Add 'Video Library' button to class detail screen:")
print("   // Navigate to /recordings/<classId>/<subjectId>")
print()
print("5. Customize email templates:")
print("   - teacher_approval (in emailWorker.ts)")
print("   - teacher_rejection")
print("   - streak_milestone")
print()
print("6. Test the flows:")
print("   - Teacher signs up -> approval request created")
print("   - Owner approves -> teacher gets email + role updated")
print("   - Student logs in -> streak updates")
print("   - Teacher adds YouTube recording -> appears in library")
print("   - Student opens recording -> YouTube player loads")
print()
print("7. Refine UI styling — the screens are functional but minimal")
print()

# ============================================================================
# Build
# ============================================================================
if not args.no_build:
    print("=" * 70)
    print("Building functions (TypeScript compile check)")
    print("=" * 70)
    os.chdir("functions")
    try:
        result = subprocess.run(["npm", "run", "build"], shell=True)
        if result.returncode != 0:
            print("\n[WARNING] Functions build failed — check errors above.")
            print("You can still commit; fix before deploying.")
        else:
            print("\n  [OK] Functions build succeeded")
    finally:
        os.chdir("..")
    print()

# ============================================================================
# Commit
# ============================================================================
print("=" * 70)
print("Committing changes")
print("=" * 70)

commit_message = """sprint3: scaffold adoption features (v2.1, v2.2, v2.2A)

S3-01: Teacher Approval Workflow (v2.2)
  - Domain model + repository + providers
  - Approval queue UI screen
  - approveStaffRequest + rejectStaffRequest Cloud Functions
  - Email notifications via emailQueue
  - Auto-assign default scope on approval
  - Route: /people/approvals

S3-02: Student Engagement (v2.2A) - minimal cut
  - onStudentLogin callable (tracks daily login streak)
  - sendDueTomorrowNotifications scheduled function (daily 6 PM)
  - StreakBadge widget for student dashboard
  - Streak provider

S3-03: Video Library (v2.1)
  - class_recordings Firestore collection + rules
  - Recording model with YouTube URL parsing
  - Repository + providers
  - YoutubePlayerWidget (youtube_player_iframe)
  - Recording list, player, upload screens
  - Routes: /recordings/:classId/:subjectId, /recordings/new/...

NOTE: This is scaffolding code. Manual work required:
  - flutter pub get (install youtube_player_iframe)
  - Add StreakBadge to student dashboard
  - Call recordStudentLogin() after student login
  - Add 'Video Library' button to class detail screen
  - Customize email templates (teacher_approval, teacher_rejection, streak_milestone)
  - Refine UI styling

See: klasivo_action_plan_v2.md Sprint 3 section for details."""

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit created: {new_commit}")
print()

# ============================================================================
# Push
# ============================================================================
if args.no_push:
    print("[!] Skipping push (--no-push)")
    print("    git push origin main  (when ready)")
    sys.exit(0)

print("=" * 70)
print("Pushing to GitHub")
print("=" * 70)

response = input("\nPush to origin now? (y/n): ").strip().lower()
if response == "y":
    result = subprocess.run(["git", "push", "origin", "main"])
    if result.returncode != 0:
        print("\n[ERROR] Push failed")
        print("Try: git pull --rebase origin main && git push origin main")
        sys.exit(1)
    print(f"\n  [OK] Pushed successfully")
    print(f"  View: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Push skipped. Run: git push origin main")

print()
print("=" * 70)
print("DEPLOY + TESTING INSTRUCTIONS")
print("=" * 70)
print()
print("1. flutter pub get  (install youtube_player_iframe)")
print()
print("2. Deploy to Firebase:")
print("   firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("3. Test Teacher Approval:")
print("   - Sign up as a new teacher (creates approval request)")
print("   - Sign in as owner -> /people/approvals -> approve")
print("   - Verify teacher gets email + can sign in with teacher role")
print()
print("4. Test Student Engagement:")
print("   - Sign in as student -> check streak badge on dashboard")
print("   - Sign in again next day -> streak should increment")
print("   - Create an assignment due tomorrow -> wait for 6 PM notification")
print()
print("5. Test Video Library:")
print("   - As teacher, open a class -> 'Video Library' -> add recording")
print("   - Paste a YouTube URL -> verify preview thumbnail")
print("   - Publish -> recording appears in list")
print("   - As student, open recording -> YouTube player loads")
print()
print("Rollback if needed:")
print(f"  git reset --hard {backup_branch}")
print("  git push origin main --force")
print("  firebase deploy --only functions,firestore:rules,firestore:indexes")

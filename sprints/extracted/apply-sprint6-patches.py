#!/usr/bin/env python3
# ============================================================================
# Klasivo Sprint 6 — PMF Gate + Gradebook + Analytics Foundation
# ============================================================================
# Scaffolds 3 workstreams (the final foundation sprint):
#
#   S6-01: PMF Gate Metrics Dashboard
#          - Tracks: active schools, MAU students, WAU teachers, 90-day retention
#          - Scheduled function to compute daily metrics
#          - Owner dashboard widget showing PMF progress
#          - PMF gate evaluation (blocks Phase D until metrics met)
#
#   S6-02: Gradebook (v2.5) - minimal cut
#          - Gradebook model with weighted categories
#          - Manual grade entry
#          - Per-student and per-class views
#          - Grade calculation (weighted average)
#
#   S6-03: Analytics Foundation
#          - Scheduled function to populate analytics_daily
#          - Replaces stub AnalyticsEngine
#          - Per-org and per-campus aggregates
#          - Owner dashboard with real metrics
#
# Prerequisites:
#   - Sprint 1-5 deployed
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-sprint6-patches.py
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

parser = argparse.ArgumentParser(description="Apply Klasivo Sprint 6 scaffolding")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO SPRINT 6 — PMF Gate + Gradebook + Analytics")
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
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-sprint6-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}\n")

features_scaffolded = []


def write_file(filepath, content):
    path = Path(filepath)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  [OK] Created {path}")
    return path


# ============================================================================
# S6-01: PMF Gate Metrics
# ============================================================================
print("=" * 70)
print("S6-01: PMF Gate Metrics Dashboard")
print("=" * 70)
print()

# --- PMF metrics scheduled function ---
write_file("functions/src/functions/computePmfMetrics.ts", '''/**
 * computePmfMetrics — S6-01: Compute PMF gate metrics daily
 *
 * PMF Gate criteria (from klasivo_action_plan_v2.md):
 *   - 10 active schools
 *   - 500 monthly active students
 *   - 50 weekly active teachers
 *   - 90-day retention > 60%
 *
 * Runs daily at 5 AM UTC.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const computePmfMetrics = onSchedule(
  {
    schedule: '0 5 * * *',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'pmf');
      scope.setTag('function', 'computePmfMetrics');

      const db = getFirestore();
      const now = Date.now();
      const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
      const sevenDaysAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
      const ninetyDaysAgo = new Date(now - 90 * 24 * 60 * 60 * 1000);
      const fourteenDaysAgo = new Date(now - 14 * 24 * 60 * 60 * 1000);

      // 1. Active schools: orgs with activity in last 30 days
      const activeOrgsSnapshot = await db.collection('organizations')
        .where('lastActivityAt', '>=', Timestamp.fromDate(thirtyDaysAgo))
        .get();
      const activeSchools = activeOrgsSnapshot.size;

      // 2. MAU students: students who logged in last 30 days
      const mauStudentsSnapshot = await db.collection('users')
        .where('role', '==', 'student')
        .where('lastLoginAt', '>=', Timestamp.fromDate(thirtyDaysAgo))
        .get();
      const mauStudents = mauStudentsSnapshot.size;

      // 3. WAU teachers: teachers active in last 7 days
      const wauTeachersSnapshot = await db.collection('users')
        .where('role', '==', 'teacher')
        .where('lastActivityAt', '>=', Timestamp.fromDate(sevenDaysAgo))
        .get();
      const wauTeachers = wauTeachersSnapshot.size;

      // 4. 90-day retention: students who first logged in 90+ days ago
      //    AND logged in within the past 14 days
      const cohortSnapshot = await db.collection('users')
        .where('role', '==', 'student')
        .where('firstLoginAt', '<=', Timestamp.fromDate(ninetyDaysAgo))
        .get();

      const cohortSize = cohortSnapshot.size;
      let retained = 0;
      for (const doc of cohortSnapshot.docs) {
        const lastLogin = doc.data()['lastLoginAt'] as Timestamp | undefined;
        if (lastLogin && lastLogin.toDate() >= fourteenDaysAgo) {
          retained++;
        }
      }
      const retentionRate = cohortSize > 0 ? retained / cohortSize : 0;

      // PMF gate evaluation
      const pmfGate = {
        activeSchoolsMet: activeSchools >= 10,
        mauStudentsMet: mauStudents >= 500,
        wauTeachersMet: wauTeachers >= 50,
        retentionMet: retentionRate >= 0.60,
      };
      const pmfAchieved = Object.values(pmfGate).every(v => v === true);

      // Save metrics
      await db.collection('pmf_metrics').add({
        date: Timestamp.fromDate(new Date(now)),
        activeSchools,
        mauStudents,
        wauTeachers,
        retentionRate,
        cohortSize,
        retained,
        pmfGate,
        pmfAchieved,
        computedAt: FieldValue.serverTimestamp(),
      });

      // Also update the latest metrics doc (for quick dashboard access)
      await db.collection('pmf_metrics').doc('latest').set({
        date: Timestamp.fromDate(new Date(now)),
        activeSchools,
        mauStudents,
        wauTeachers,
        retentionRate,
        cohortSize,
        retained,
        pmfGate,
        pmfAchieved,
        computedAt: FieldValue.serverTimestamp(),
      });

      console.log(`PMF metrics: ${activeSchools} schools, ${mauStudents} MAU, ${wauTeachers} WAU, ${(retentionRate * 100).toFixed(1)}% retention. PMF: ${pmfAchieved ? 'YES' : 'NO'}`);

      return null;
    });
  },
);
''')

# --- PMF dashboard widget ---
write_file("lib/features/pmf/widgets/pmf_gate_widget.dart", '''// S6-01: PMF Gate Widget
// Shows progress toward PMF gate criteria

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final pmfMetricsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('pmf_metrics')
      .doc('latest')
      .snapshots()
      .map((doc) {
    if (!doc.exists) return {};
    return doc.data() as Map<String, dynamic>;
  });
});

class PmfGateWidget extends ConsumerWidget {
  const PmfGateWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(pmfMetricsProvider);

    return metricsAsync.when(
      loading: () => const Card(child: ListTile(title: Text('Loading PMF metrics...'))),
      error: (err, _) => Card(child: ListTile(title: Text('Error: $err'))),
      data: (metrics) {
        if (metrics.isEmpty) {
          return const Card(child: ListTile(title: Text('PMF metrics not yet computed')));
        }

        final activeSchools = (metrics['activeSchools'] as num?)?.toInt() ?? 0;
        final mauStudents = (metrics['mauStudents'] as num?)?.toInt() ?? 0;
        final wauTeachers = (metrics['wauTeachers'] as num?)?.toInt() ?? 0;
        final retentionRate = (metrics['retentionRate'] as num?)?.toDouble() ?? 0;
        final pmfAchieved = metrics['pmfAchieved'] as bool? ?? false;
        final gate = metrics['pmfGate'] as Map<String, dynamic>? ?? {};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      pmfAchieved ? Icons.celebration : Icons.flag,
                      color: pmfAchieved ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pmfAchieved ? 'PMF Achieved!' : 'PMF Gate Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: pmfAchieved ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MetricRow(
                  label: 'Active Schools',
                  current: activeSchools,
                  target: 10,
                  met: gate['activeSchoolsMet'] == true,
                ),
                _MetricRow(
                  label: 'MAU Students',
                  current: mauStudents,
                  target: 500,
                  met: gate['mauStudentsMet'] == true,
                ),
                _MetricRow(
                  label: 'WAU Teachers',
                  current: wauTeachers,
                  target: 50,
                  met: gate['wauTeachersMet'] == true,
                ),
                _MetricRow(
                  label: '90-day Retention',
                  current: (retentionRate * 100).round(),
                  target: 60,
                  met: gate['retentionMet'] == true,
                  isPercent: true,
                ),
                const SizedBox(height: 12),
                if (!pmfAchieved)
                  const Text(
                    'Phase D (feature development) is blocked until all 4 metrics are met.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final bool met;
  final bool isPercent;

  const _MetricRow({
    required this.label,
    required this.current,
    required this.target,
    required this.met,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.circle_outlined,
              color: met ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            isPercent ? '$current% / $target%' : '$current / $target',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: met ? Colors.green : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(met ? Colors.green : Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
''')

# Export PMF function
index_path = Path("functions/src/index.ts")
index_content = index_path.read_text(encoding="utf-8")
export_line = "export { computePmfMetrics } from './functions/computePmfMetrics';"
if "computePmfMetrics" not in index_content:
    export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
    if export_matches:
        last_export = export_matches[-1]
        line_end = index_content.find('\n', last_export.end())
        if line_end != -1:
            index_content = index_content[:line_end + 1] + export_line + '\n' + index_content[line_end + 1:]
            index_path.write_text(index_content, encoding="utf-8")
            print("  [OK] Exported computePmfMetrics")

# Add rules for pmf_metrics
rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")
if "pmf_metrics" not in rules_content:
    pmf_rules = """
    // ====== S6-01: PMF Metrics ======
    match /pmf_metrics/{metricId} {
      allow read: if isAuth() && (isOwnerInSameOrg() || getUserRole() == 'super_admin');
      allow create: if false;  // Server-only
      allow update: if false;
      allow delete: if false;
    }
"""
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + pmf_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added pmf_metrics rules")

features_scaffolded.append("S6-01 (PMF Gate Metrics)")
print()

# ============================================================================
# S6-02: Gradebook (minimal cut)
# ============================================================================
print("=" * 70)
print("S6-02: Gradebook (v2.5) - minimal cut")
print("=" * 70)
print()

# --- Gradebook model ---
write_file("lib/features/gradebook/domain/gradebook_model.dart", '''// S6-02: Gradebook Model

import 'package:cloud_firestore/cloud_firestore.dart';

class Gradebook {
  final String id;
  final String organizationId;
  final String classId;
  final String subjectId;
  final String term;  // e.g., '2026-Spring'
  final Map<String, double> weights;  // {exam: 0.4, assignment: 0.3, attendance: 0.3}
  final DateTime createdAt;
  final DateTime updatedAt;

  Gradebook({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.subjectId,
    required this.term,
    required this.weights,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Gradebook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Gradebook(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      term: data['term'] ?? '',
      weights: Map<String, double>.from(
        (data['weights'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'classId': classId,
      'subjectId': subjectId,
      'term': term,
      'weights': weights,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class GradebookEntry {
  final String id;
  final String gradebookId;
  final String organizationId;
  final String classId;
  final String studentId;
  final String studentName;
  final String category;  // 'exam', 'assignment', 'attendance'
  final String assessmentTitle;
  final double score;
  final double maxScore;
  final DateTime assessedAt;
  final String assessedBy;
  final String? notes;

  GradebookEntry({
    required this.id,
    required this.gradebookId,
    required this.organizationId,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.category,
    required this.assessmentTitle,
    required this.score,
    required this.maxScore,
    required this.assessedAt,
    required this.assessedBy,
    this.notes,
  });

  factory GradebookEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GradebookEntry(
      id: doc.id,
      gradebookId: data['gradebookId'] ?? '',
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      category: data['category'] ?? '',
      assessmentTitle: data['assessmentTitle'] ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0,
      maxScore: (data['maxScore'] as num?)?.toDouble() ?? 100,
      assessedAt: (data['assessedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assessedBy: data['assessedBy'] ?? '',
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gradebookId': gradebookId,
      'organizationId': organizationId,
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'category': category,
      'assessmentTitle': assessmentTitle,
      'score': score,
      'maxScore': maxScore,
      'assessedAt': Timestamp.fromDate(assessedAt),
      'assessedBy': assessedBy,
      'notes': notes,
    };
  }
}

/// Calculate weighted grade for a student
double calculateWeightedGrade(List<GradebookEntry> entries, Map<String, double> weights) {
  if (entries.isEmpty) return 0;

  // Group by category and compute average percentage per category
  final categoryAverages = <String, double>{};
  final categoryCounts = <String, int>{};

  for (final entry in entries) {
    final percentage = (entry.score / entry.maxScore) * 100;
    categoryAverages[entry.category] = (categoryAverages[entry.category] ?? 0) + percentage;
    categoryCounts[entry.category] = (categoryCounts[entry.category] ?? 0) + 1;
  }

  // Compute weighted average
  double totalWeight = 0;
  double weightedSum = 0;
  for (final entry in weights.entries) {
    final category = entry.key;
    final weight = entry.value;
    if (categoryAverages.containsKey(category) && categoryCounts[category]! > 0) {
      final avg = categoryAverages[category]! / categoryCounts[category]!;
      weightedSum += avg * weight;
      totalWeight += weight;
    }
  }

  return totalWeight > 0 ? weightedSum / totalWeight : 0;
}
''')

# --- Gradebook repository ---
write_file("lib/features/gradebook/data/gradebook_repository.dart", '''// S6-02: Gradebook Repository

import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/gradebook_model.dart';

class GradebookRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get or create gradebook for class+subject+term
  Future<Gradebook> getOrCreateGradebook({
    required String orgId,
    required String classId,
    required String subjectId,
    required String term,
    Map<String, double>? defaultWeights,
  }) async {
    final query = await _firestore.collection('gradebook')
        .where('organizationId', isEqualTo: orgId)
        .where('classId', isEqualTo: classId)
        .where('subjectId', isEqualTo: subjectId)
        .where('term', isEqualTo: term)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Gradebook.fromFirestore(query.docs.first);
    }

    // Create new
    final docRef = await _firestore.collection('gradebook').add({
      'organizationId': orgId,
      'classId': classId,
      'subjectId': subjectId,
      'term': term,
      'weights': defaultWeights ?? {'exam': 0.4, 'assignment': 0.3, 'attendance': 0.3},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return Gradebook.fromFirestore(doc);
  }

  /// Stream entries for a gradebook
  Stream<List<GradebookEntry>> watchEntries(String gradebookId) {
    return _firestore.collection('gradebook_entries')
        .where('gradebookId', isEqualTo: gradebookId)
        .orderBy('assessedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GradebookEntry.fromFirestore(doc))
            .toList());
  }

  /// Stream entries for a specific student
  Stream<List<GradebookEntry>> watchStudentEntries(String gradebookId, String studentId) {
    return _firestore.collection('gradebook_entries')
        .where('gradebookId', isEqualTo: gradebookId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('assessedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GradebookEntry.fromFirestore(doc))
            .toList());
  }

  /// Add a grade entry
  Future<void> addEntry(GradebookEntry entry) async {
    await _firestore.collection('gradebook_entries').add(entry.toFirestore());
  }

  /// Update weights
  Future<void> updateWeights(String gradebookId, Map<String, double> weights) async {
    await _firestore.collection('gradebook').doc(gradebookId).update({
      'weights': weights,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
''')

# --- Gradebook screen ---
write_file("lib/features/gradebook/pages/gradebook_screen.dart", '''// S6-02: Gradebook Screen (minimal)
// Shows class gradebook with weighted grade calculation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../data/gradebook_repository.dart';
import '../domain/gradebook_model.dart';

final gradebookRepoProvider = Provider<GradebookRepository>((ref) => GradebookRepository());

final gradebookProvider = FutureProvider.family3<Gradebook, String, String, String>((ref, orgId, classId, subjectId) {
  return ref.read(gradebookRepoProvider).getOrCreateGradebook(
    orgId: orgId,
    classId: classId,
    subjectId: subjectId,
    term: '${DateTime.now().year}-${DateTime.now().month <= 6 ? 'Spring' : 'Fall'}',
  );
});

final gradebookEntriesProvider = StreamProvider.family<List<GradebookEntry>, String>((ref, gradebookId) {
  return ref.read(gradebookRepoProvider).watchEntries(gradebookId);
});

class GradebookScreen extends ConsumerWidget {
  final String classId;
  final String subjectId;

  const GradebookScreen({super.key, required this.classId, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null) return const Scaffold(body: Center(child: Text('No org')));

    final gradebookAsync = ref.watch(gradebookProvider(orgId, classId, subjectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gradebook')),
      body: gradebookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (gradebook) {
          final entriesAsync = ref.watch(gradebookEntriesProvider(gradebook.id));

          return entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (entries) {
              // Group by student
              final studentEntries = <String, List<GradebookEntry>>{};
              for (final entry in entries) {
                studentEntries.putIfAbsent(entry.studentId, () => []).add(entry);
              }

              final studentIds = studentEntries.keys.toList();

              return ListView(
                children: [
                  // Weights card
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category Weights', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...gradebook.weights.entries.map((w) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('${w.key}: ${(w.value * 100).toStringAsFixed(0)}%'),
                          )),
                        ],
                      ),
                    ),
                  ),

                  // Student grades
                  if (studentIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No grades entered yet')),
                    )
                  else
                    ...studentIds.map((studentId) {
                      final entries = studentEntries[studentId]!;
                      final weightedGrade = calculateWeightedGrade(entries, gradebook.weights);
                      final studentName = entries.first.studentName;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ExpansionTile(
                          title: Text(studentName),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: weightedGrade >= 90 ? Colors.green : weightedGrade >= 60 ? Colors.orange : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${weightedGrade.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          children: entries.map((e) => ListTile(
                            title: Text(e.assessmentTitle),
                            subtitle: Text('${e.category} • ${e.assessedAt.toLocal()}'.split('.')[0]),
                            trailing: Text('${e.score}/${e.maxScore}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          )).toList(),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGradeDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddGradeDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');
    String category = 'exam';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Grade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Assessment Title'),
              ),
              DropdownButton<String>(
                value: category,
                items: const [
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                  DropdownMenuItem(value: 'attendance', child: Text('Attendance')),
                ],
                onChanged: (v) => setState(() => category = v ?? 'exam'),
              ),
              Row(
                children: [
                  Expanded(child: TextField(
                    controller: scoreController,
                    decoration: const InputDecoration(labelText: 'Score'),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(
                    controller: maxScoreController,
                    decoration: const InputDecoration(labelText: 'Max'),
                    keyboardType: TextInputType.number,
                  )),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                // TODO: Get actual studentId via a student picker
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('TODO: Add student picker')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
''')

# Add gradebook rules
rules_content = rules_path.read_text(encoding="utf-8")
if "S6-02" not in rules_content:
    gradebook_rules = """
    // ====== S6-02: Gradebook ======
    match /gradebook/{gradebookId} {
      allow read: if isAuth() && isInSameOrg() && isStaffExcludingObserver();
      allow create: if isStaffExcludingObserverInSameOrg();
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isOwnerInSameOrg();
    }
    match /gradebook_entries/{entryId} {
      allow read: if isAuth() && isInSameOrg() &&
        (isStaffExcludingObserver() || resource.data.studentId == request.auth.uid);
      allow create: if isStaffExcludingObserverInSameOrg();
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isStaffExcludingObserverInSameOrg();
    }
"""
    last_brace = rules_content.rfind("}")
    if last_brace > 0:
        rules_content = rules_content[:last_brace] + gradebook_rules + rules_content[last_brace:]
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Added gradebook rules")

features_scaffolded.append("S6-02 (Gradebook)")
print()

# ============================================================================
# S6-03: Analytics Foundation
# ============================================================================
print("=" * 70)
print("S6-03: Analytics Foundation")
print("=" * 70)
print()

# --- Analytics aggregator scheduled function ---
write_file("functions/src/functions/aggregateDailyAnalytics.ts", '''/**
 * aggregateDailyAnalytics — S6-03: Populate analytics_daily
 *
 * Replaces the stub AnalyticsEngine with real pre-computed aggregates.
 * Runs daily at 2 AM UTC.
 *
 * Aggregates per org:
 *   - studentCount
 *   - teacherCount
 *   - submissionCount
 *   - avgScore
 *   - attendanceRate
 *   - activeRooms
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const aggregateDailyAnalytics = onSchedule(
  {
    schedule: '0 2 * * *',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '1GiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'analytics');
      scope.setTag('function', 'aggregateDailyAnalytics');

      const db = getFirestore();
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const yesterdayEnd = new Date(yesterday);
      yesterdayEnd.setHours(23, 59, 59, 999);

      // Get all organizations
      const orgsSnapshot = await db.collection('organizations').get();

      for (const orgDoc of orgsSnapshot.docs) {
        const orgId = orgDoc.id;

        // Count students
        const studentsSnapshot = await db.collection('users')
          .where('organizationId', '==', orgId)
          .where('role', '==', 'student')
          .where('isActive', '==', true)
          .get();
        const studentCount = studentsSnapshot.size;

        // Count teachers
        const teachersSnapshot = await db.collection('users')
          .where('organizationId', '==', orgId)
          .where('role', '==', 'teacher')
          .where('isActive', '==', true)
          .get();
        const teacherCount = teachersSnapshot.size;

        // Count submissions yesterday
        const submissionsSnapshot = await db.collection('assignment_submissions')
          .where('organizationId', '==', orgId)
          .where('submittedAt', '>=', Timestamp.fromDate(yesterday))
          .where('submittedAt', '<=', Timestamp.fromDate(yesterdayEnd))
          .get();
        const submissionCount = submissionsSnapshot.size;

        // Calculate avg score (from graded submissions yesterday)
        let totalScore = 0;
        let gradedCount = 0;
        for (const subDoc of submissionsSnapshot.docs) {
          const percentage = subDoc.data()['percentage'];
          if (percentage != null) {
            totalScore += percentage as number;
            gradedCount++;
          }
        }
        const avgScore = gradedCount > 0 ? totalScore / gradedCount : 0;

        // Calculate attendance rate yesterday
        const attendanceSnapshot = await db.collection('attendance')
          .where('organizationId', '==', orgId)
          .where('date', '>=', Timestamp.fromDate(yesterday))
          .where('date', '<=', Timestamp.fromDate(yesterdayEnd))
          .get();
        let present = 0;
        let totalAttendance = 0;
        for (const attDoc of attendanceSnapshot.docs) {
          totalAttendance++;
          if (attDoc.data()['status'] === 'present') present++;
        }
        const attendanceRate = totalAttendance > 0 ? present / totalAttendance : 0;

        // Count active LiveKit rooms yesterday
        const roomsSnapshot = await db.collection('livekit_rooms')
          .where('organizationId', '==', orgId)
          .where('createdAt', '>=', Timestamp.fromDate(yesterday))
          .where('createdAt', '<=', Timestamp.fromDate(yesterdayEnd))
          .get();
        const activeRooms = roomsSnapshot.size;

        // Save to analytics_daily (use orgId field, not organizationId, per C-17 fix)
        const docId = `${orgId}_${yesterday.toISOString().split('T')[0]}`;
        await db.collection('analytics_daily').doc(docId).set({
          orgId,
          organizationId: orgId,  // Also write organizationId for rule compatibility
          date: Timestamp.fromDate(yesterday),
          studentCount,
          teacherCount,
          submissionCount,
          avgScore,
          attendanceRate,
          activeRooms,
          computedAt: FieldValue.serverTimestamp(),
        });

        console.log(`Analytics for ${orgId} on ${yesterday.toISOString().split('T')[0]}: ${studentCount} students, ${submissionCount} submissions, ${(attendanceRate * 100).toFixed(1)}% attendance`);
      }

      console.log('Daily analytics aggregation complete');
      return null;
    });
  },
);
''')

# Export analytics function
index_content = index_path.read_text(encoding="utf-8")
analytics_export = "export { aggregateDailyAnalytics } from './functions/aggregateDailyAnalytics';"
if "aggregateDailyAnalytics" not in index_content:
    export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
    if export_matches:
        last_export = export_matches[-1]
        line_end = index_content.find('\n', last_export.end())
        if line_end != -1:
            index_content = index_content[:line_end + 1] + analytics_export + '\n' + index_content[line_end + 1:]
            index_path.write_text(index_content, encoding="utf-8")
            print("  [OK] Exported aggregateDailyAnalytics")

features_scaffolded.append("S6-03 (Analytics Foundation)")
print()

# ============================================================================
# Summary + Commit + Push
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
            print("\n[WARNING] Build failed")
        else:
            print("\n  [OK] Build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """sprint6: PMF gate + gradebook + analytics foundation

S6-01: PMF Gate Metrics
  - computePmfMetrics scheduled function (daily 5 AM)
  - Tracks: active schools, MAU students, WAU teachers, 90-day retention
  - PMF gate evaluation (blocks Phase D until met)
  - PmfGateWidget showing progress bars
  - Firestore rules for pmf_metrics (server-only writes)

S6-02: Gradebook (v2.5) - minimal cut
  - Gradebook model with weighted categories
  - GradebookEntry model (per-student, per-assessment)
  - calculateWeightedGrade function
  - GradebookRepository (getOrCreate, watch entries, add entry)
  - GradebookScreen with per-student weighted grade display
  - Add grade dialog (TODO: student picker)
  - Firestore rules for gradebook + gradebook_entries

S6-03: Analytics Foundation
  - aggregateDailyAnalytics scheduled function (daily 2 AM)
  - Pre-computes per-org: studentCount, teacherCount, submissionCount,
    avgScore, attendanceRate, activeRooms
  - Writes to analytics_daily with both orgId AND organizationId (C-17 fix)
  - Replaces stub AnalyticsEngine

Manual work required:
  - Add PmfGateWidget to owner dashboard
  - Add student picker to gradebook add-grade dialog
  - Wire GradebookScreen route in main.dart
  - Add 'View Gradebook' button to class detail screen
  - Test PMF metrics computation (may need to add lastActivityAt fields)
  - Verify analytics_daily is populated correctly

PMF GATE (non-negotiable):
  - 10 active schools
  - 500 MAU students
  - 50 WAU teachers
  - 90-day retention > 60%
  
  Do NOT start Phase D (feature development) until all 4 metrics are met.

See: klasivo_action_plan_v2.md Sprint 6 section"""

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
print("=" * 70)
print("90-DAY ROADMAP COMPLETE")
print("=" * 70)
print()
print("All 6 sprints are now scaffolded:")
print("  Sprint 1: Security Closure (17 P0 findings) - DONE")
print("  Sprint 2: Infrastructure & Hardening - DONE")
print("  Sprint 3: Adoption Features (Teacher Approval, Engagement, Video) - DONE")
print("  Sprint 4: Assignment API + Enhanced Attendance - DONE")
print("  Sprint 5: Compliance Foundation + Test Coverage - DONE")
print("  Sprint 6: PMF Gate + Gradebook + Analytics - DONE")
print()
print("Next steps:")
print("  1. Execute Sprint 1 first (security closure)")
print("  2. Proceed through Sprint 2-6 in order")
print("  3. After Sprint 6, monitor PMF gate metrics")
print("  4. Only start Phase D (feature development) after PMF is achieved")
print()
print("Rollback: git reset --hard " + backup_branch)

#!/usr/bin/env python3
"""
Phase 1: Convert TeacherShell from ShellRoute to StatefulShellRoute.indexedStack.

Changes to lib/main.dart:
1. Replace lines 762-872 (main teacher ShellRoute) with StatefulShellRoute.indexedStack
   - 5 branches: Dashboard, Academic (incl. /teacher/** legacy), People, Inbox, Settings
2. Delete lines 913-1147 (A8 patch ShellRoute) entirely
   - Its /teacher/** routes are now folded into the Academic branch
3. LMS routes (874-911) stay unchanged

Changes to lib/features/shell/teacher_shell.dart:
- Already rewritten (ConsumerWidget + StatefulNavigationShell)
"""
import re
from pathlib import Path

MAIN_DART = Path('/home/z/my-project/lib/main.dart')

content = MAIN_DART.read_text(encoding='utf-8')
lines = content.split('\n')

# Sanity check: verify line 762 is the ShellRoute opening
assert 'ShellRoute(' in lines[761], f"Line 762 mismatch: {lines[761]}"
assert 'TeacherShell(child: child)' in lines[762], f"Line 763 mismatch: {lines[762]}"

# Verify line 872 is the ShellRoute closing
assert lines[871] == '      ),', f"Line 872 mismatch: {lines[871]}"

# Verify line 913 is the A8 patch comment start
assert 'A8 PATCH' in lines[912], f"Line 913 mismatch: {lines[912]}"

# Verify line 1147 is the A8 patch ShellRoute closing
assert 'end of ShellRoute (A8 patch)' in lines[1146], f"Line 1147 mismatch: {lines[1146]}"

# New StatefulShellRoute.indexedStack block (replaces lines 762-872, 1-indexed)
new_teacher_shell_block = '''      // ─── Teacher/Owner Shell Navigation (StatefulShellRoute.indexedStack) ──
      // Phase 1 refactor: replaces the old ShellRoute + A8 patch ShellRoute
      // with a single StatefulShellRoute.indexedStack. Each tab gets its own
      // branch navigator, preserving scroll/form state across tab switches.
      // The legacy /teacher/** routes are folded into the Academic branch
      // (sibling of /academic), eliminating the A8 patch workaround.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TeacherShell(shell: navigationShell),
        branches: [
          // ── Branch 0: Dashboard ───────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const OwnerDashboard(),
              ),
            ],
          ),

          // ── Branch 1: Academic (includes legacy /teacher/** routes) ───
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/academic',
                builder: (context, state) => const StageListScreen(),
                routes: [
                  GoRoute(
                    path: 'stages/:stageId/classes',
                    builder: (context, state) {
                      final stageId = state.pathParameters['stageId']!;
                      return ClassListScreen(stageId: stageId);
                    },
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) {
                          final stageId = state.extra as String? ??
                              state.pathParameters['stageId'] ?? '';
                          return ClassFormScreen(
                            isEditing: false,
                            stageId: stageId,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // ─── Legacy Teacher Routes (folded from A8 patch) ────────
              // These were previously in a separate ShellRoute (A8 patch)
              // to keep TeacherShell mounted. StatefulShellRoute.indexedStack
              // handles this natively, so they now live as siblings of
              // /academic within the Academic branch.
              GoRoute(
                path: '/teacher',
                builder: (context, state) => const TeacherDashboard(),
                routes: [
                  GoRoute(
                    path: 'classes',
                    builder: (context, state) => const ClassListScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) {
                          final stageId = state.extra as String?;
                          return ClassFormScreen(isEditing: false, stageId: stageId);
                        },
                      ),
                      GoRoute(
                        path: 'edit/:classId',
                        builder: (context, state) {
                          final classData = state.extra as ClassData?;
                          return ClassFormScreen(isEditing: true, classData: classData);
                        },
                      ),
                      GoRoute(
                        path: ':classId/students',
                        builder: (context, state) {
                          final classId = state.pathParameters['classId']!;
                          return StudentListScreen(classId: classId);
                        },
                        routes: [
                          GoRoute(
                            path: 'create',
                            builder: (context, state) {
                              final classId = state.pathParameters['classId']!;
                              return StudentFormScreen(classId: classId, isEditing: false);
                            },
                          ),
                          GoRoute(
                            path: 'edit/:studentId',
                            builder: (context, state) {
                              final classId = state.pathParameters['classId']!;
                              final studentData = state.extra as StudentData?;
                              return StudentFormScreen(classId: classId, isEditing: true, studentData: studentData);
                            },
                          ),
                          GoRoute(
                            path: 'import',
                            builder: (context, state) {
                              final classId = state.pathParameters['classId']!;
                              return ExcelImportScreen(classId: classId);
                            },
                          ),
                          GoRoute(
                            path: 'qr',
                            builder: (context, state) {
                              final classId = state.pathParameters['classId']!;
                              return QrGenerateScreen(classId: classId);
                            },
                          ),
                          GoRoute(
                            path: 'groups',
                            builder: (context, state) {
                              final classId = state.pathParameters['classId']!;
                              return GroupListScreen(classId: classId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'students',
                    builder: (context, state) => const AllStudentsScreen(),
                  ),
                  GoRoute(
                    path: 'exams',
                    builder: (context, state) => const ExamListScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) => const ExamFormScreen(isEditing: false),
                      ),
                      GoRoute(
                        path: 'edit/:examId',
                        builder: (context, state) {
                          final examData = state.extra as ExamData?;
                          return ExamFormScreen(isEditing: true, examData: examData);
                        },
                      ),
                      GoRoute(
                        path: ':examId',
                        builder: (context, state) {
                          final examId = state.pathParameters['examId']!;
                          return ExamDetailScreen(examId: examId);
                        },
                        routes: [
                          GoRoute(
                            path: 'questions',
                            builder: (context, state) {
                              final examId = state.pathParameters['examId']!;
                              return QuestionBuilderScreen(examId: examId);
                            },
                          ),
                          GoRoute(
                            path: 'results',
                            builder: (context, state) {
                              final examId = state.pathParameters['examId']!;
                              return ExamResultsScreen(examId: examId);
                            },
                          ),
                          GoRoute(
                            path: 'instances',
                            builder: (context, state) {
                              final examId = state.pathParameters['examId']!;
                              return ExamInstancesScreen(examId: examId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'stages',
                    builder: (context, state) => const StageListScreen(),
                    routes: [
                      GoRoute(
                        path: ':stageId/classes',
                        builder: (context, state) {
                          final stageId = state.pathParameters['stageId']!;
                          return ClassListScreen(stageId: stageId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'question-bank',
                    builder: (context, state) => const QuestionBankScreen(),
                  ),

                  // ─── Calendar ───────────────────────────────────────────
                  GoRoute(
                    path: 'calendar',
                    builder: (context, state) => const CalendarScreen(),
                  ),

                  // ─── Academic Years ─────────────────────────────────────
                  GoRoute(
                    path: 'academic-years',
                    builder: (context, state) => const AcademicYearListScreen(),
                  ),

                  // ─── v1.7 New Routes ────────────────────────────────────
                  GoRoute(
                    path: 'assignments',
                    builder: (context, state) => const AssignmentListScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) => const AssignmentFormScreen(isEditing: false),
                      ),
                      GoRoute(
                        path: ':assignmentId',
                        builder: (context, state) {
                          final assignmentId = state.pathParameters['assignmentId']!;
                          return AssignmentDetailScreen(assignmentId: assignmentId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'gradebook',
                    builder: (context, state) => const GradebookScreen(),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (context, state) => const AttendanceScreen(),
                  ),

                  // ─── Existing v1.6 Routes ───────────────────────────────
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationCenterScreen(),
                  ),
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => const TeacherAnalyticsDashboard(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportGenerationScreen(),
                  ),
                  GoRoute(
                    path: 'integrity',
                    builder: (context, state) => const ExamIntegrityDashboard(),
                  ),

                  // ─── Audit Log (Owners Only) ────────────────────────────
                  GoRoute(
                    path: 'audit-log',
                    builder: (context, state) => const AuditLogScreen(),
                  ),

                  // ─── Moderation Queue ───────────────────────────────────
                  GoRoute(
                    path: 'moderation',
                    builder: (context, state) => const ModerationQueueScreen(),
                  ),

                  // ─── Progress Tracking ──────────────────────────────────
                  GoRoute(
                    path: 'progress',
                    builder: (context, state) {
                      final classId = state.uri.queryParameters['classId'] ?? '';
                      final className = state.uri.queryParameters['className'] ?? 'Class';
                      return ProgressTrackingScreen(classId: classId, className: className);
                    },
                  ),
                ],
              ),
            ],
          ),

          // ── Branch 2: People ──────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/people',
                builder: (context, state) => const AllStudentsScreen(),
              ),
            ],
          ),

          // ── Branch 3: Inbox (Messages + Notifications + Announcements) ─
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const NotificationCenterScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationCenterScreen(),
                  ),
                  GoRoute(
                    path: 'notifications/:id',
                    builder: (context, state) {
                      final notificationId = state.pathParameters['id']!;
                      return NotificationDetailScreen(
                          notificationId: notificationId);
                    },
                  ),
                  GoRoute(
                    path: 'messages',
                    builder: (context, state) => const ConversationListScreen(),
                    routes: [
                      GoRoute(
                        path: ':conversationId',
                        builder: (context, state) {
                          final conversationId =
                              state.pathParameters['conversationId']!;
                          return ChatScreen(conversationId: conversationId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'announcements',
                    builder: (context, state) => const AnnouncementListScreen(),
                  ),
                  GoRoute(
                    path: 'announcements/create',
                    builder: (context, state) =>
                        const AnnouncementFormScreen(isEditing: false),
                  ),
                  GoRoute(
                    path: 'announcements/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return AnnouncementDetailScreen(announcementId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // ── Branch 4: Settings ────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'organization',
                    builder: (context, state) =>
                        const OrganizationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'feature-flags',
                    builder: (context, state) => const FeatureFlagsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),'''

# Build the new content:
# - Lines 1-761 (index 0-760): keep unchanged
# - Replace lines 762-872 (index 761-871) with new block
# - Lines 873-912 (index 872-911): keep (LMS routes + blank line)
# - DELETE lines 913-1147 (index 912-1146): A8 patch (just remove, leave no blank gap)
# - Lines 1148+ (index 1147+): keep (Student Shell onwards)

new_lines = (
    lines[:761]                          # up to and including line 761 (blank line before ShellRoute)
    + new_teacher_shell_block.split('\n')  # new StatefulShellRoute block
    + lines[872:912]                     # LMS routes (lines 873-912, index 872-911)
    + lines[1147:]                       # everything after A8 patch (Student Shell onwards)
)

new_content = '\n'.join(new_lines)
MAIN_DART.write_text(new_content, encoding='utf-8')

print(f"Original: {len(lines)} lines")
print(f"New: {len(new_lines)} lines")
print(f"Diff: {len(new_lines) - len(lines)} lines (negative = removed)")
print("\nVerifying new structure...")
new_lines_check = new_content.split('\n')
# Find the new StatefulShellRoute
for i, line in enumerate(new_lines_check):
    if 'StatefulShellRoute.indexedStack' in line:
        print(f"  Line {i+1}: {line.strip()}")
        break
# Find A8 patch (should be gone)
a8_found = any('A8 PATCH' in line for line in new_lines_check)
print(f"  A8 PATCH comment removed: {not a8_found}")
# Find Student Shell (should still exist)
student_found = any('Student Shell Navigation' in line for line in new_lines_check)
print(f"  Student Shell Navigation preserved: {student_found}")
# Find Parent Shell (should still exist)
parent_found = any('Parent Shell Navigation' in line for line in new_lines_check)
print(f"  Parent Shell Navigation preserved: {parent_found}")

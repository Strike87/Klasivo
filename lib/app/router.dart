import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/config/theme.dart';
import '../core/services/feature_flag_service.dart';
import '../core/services/permission_service.dart';
import '../features/livekit/pages/scheduled_classes_screen.dart';
import '../features/livekit/pages/session_analytics_dashboard.dart';
import '../features/user_management/pages/people_hub_screen.dart';
import '../features/user_management/pages/user_detail_screen.dart';
import '../features/user_management/pages/role_matrix_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/feature_flag_provider.dart';
import '../providers/permission_provider.dart';

// ─── Auth Change Notifier for GoRouter refresh ──────────────────────────────

class AuthChangeNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _firebaseSub;
  StreamSubscription? _hiveSub;

  AuthChangeNotifier() {
    _firebaseSub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
      onError: (_) => notifyListeners(),
    );
    _startHiveWatch();
  }

  void _startHiveWatch() {
    _hiveSub = Hive.box(AppConstants.authBox).watch().listen((event) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    _hiveSub?.cancel();
    super.dispose();
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// ─── GoRouter Provider ──────────────────────────────────────────────────────

final klasivoRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: (context, state) {
      final box = Hive.box(AppConstants.authBox);
      final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
      final userRole = box.get('userRole', defaultValue: '') as String;
      final hasCompletedSetup = box.get('hasCompletedSetup', defaultValue: true) as bool;

      final isOnSplash = state.matchedLocation == '/';
      final isOnAuth = state.matchedLocation.startsWith('/auth');
      final isOnWelcome = state.matchedLocation == '/welcome';
      final isOnDashboard = state.matchedLocation.startsWith('/dashboard') ||
          state.matchedLocation.startsWith('/academic') ||
          state.matchedLocation.startsWith('/people') ||
          state.matchedLocation.startsWith('/inbox') ||
          state.matchedLocation.startsWith('/settings') ||
          state.matchedLocation.startsWith('/teacher') ||
          state.matchedLocation.startsWith('/lms');
      final isOnStudent = state.matchedLocation.startsWith('/student');
      final isOnParent = state.matchedLocation.startsWith('/parent') ||
          state.matchedLocation.startsWith('/auth/parent');

      // Splash → redirect based on auth state
      if (isOnSplash) {
        if (isLoggedIn && userRole.isNotEmpty) {
          if (userRole == AppConstants.roleOwner && !hasCompletedSetup) {
            return '/welcome';
          }
          if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {
            return '/dashboard';
          }
          if (userRole == AppConstants.roleStudent) return '/student';
          if (userRole == AppConstants.roleParent) return '/parent';
        }
        return '/auth';
      }

      // Welcome screen — only accessible to logged-in owners who haven't completed setup
      if (isOnWelcome) {
        if (!isLoggedIn) return '/auth';
        if (userRole != AppConstants.roleOwner) return '/dashboard';
        if (hasCompletedSetup) return '/dashboard';
        return null;
      }

      // Auth screens → redirect if already logged in
      if (isOnAuth) {
        if (isLoggedIn && userRole.isNotEmpty) {
          if (userRole == AppConstants.roleOwner && !hasCompletedSetup) {
            return '/welcome';
          }
          if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {
            return '/dashboard';
          }
          if (userRole == AppConstants.roleStudent) return '/student';
          if (userRole == AppConstants.roleParent) return '/parent';
        }
        return null;
      }

      // Protected screens → require login
      if (isOnDashboard || isOnStudent || isOnParent) {
        if (!isLoggedIn) return '/auth';
        if (userRole.isEmpty) return '/auth';

        if (userRole == AppConstants.roleOwner && !hasCompletedSetup) {
          return '/welcome';
        }

        // ─── Feature Flag Gates ───────────────────────────────────────────
        // LMS routes require lms flag
        if (state.matchedLocation.startsWith('/lms')) {
          final flagService = ref.read(featureFlagServiceProvider);
          if (!flagService.isEnabled(FeatureFlags.lms)) {
            return '/dashboard';
          }
        }

        // LiveKit routes require livekit flag
        if (state.matchedLocation.startsWith('/live-classes')) {
          final flagService = ref.read(featureFlagServiceProvider);
          if (!flagService.isEnabled(FeatureFlags.livekit)) {
            return '/dashboard';
          }
        }

        // People Hub requires userManagement flag
        if (state.matchedLocation.startsWith('/people')) {
          final flagService = ref.read(featureFlagServiceProvider);
          if (!flagService.isEnabled(FeatureFlags.userManagement)) {
            return '/dashboard';
          }
        }

        // Parent portal requires parentPortal flag
        if (state.matchedLocation.startsWith('/parent') ||
            state.matchedLocation.startsWith('/auth/parent')) {
          final flagService = ref.read(featureFlagServiceProvider);
          if (!flagService.isEnabled(FeatureFlags.parentPortal)) {
            if (userRole == AppConstants.roleParent) return '/auth';
            return '/dashboard';
          }
        }

        if ((userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) &&
            isOnDashboard) {
          return null;
        }
        if (userRole == AppConstants.roleStudent && isOnStudent) {
          return null;
        }
        if (userRole == AppConstants.roleParent && isOnParent) {
          return null;
        }

        if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {
          return '/dashboard';
        }
        if (userRole == AppConstants.roleStudent) return '/student';
        if (userRole == AppConstants.roleParent) return '/parent';
      }

      return null;
    },
    routes: [
      // ─── Splash ──────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashPlaceholder(),
      ),

      // ─── Auth Routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (context, state) => const _AuthPlaceholder(),
        routes: [
          GoRoute(
            path: 'teacher-login',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'teacher-register',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'student-login',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'parent-login',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'parent-register',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
          GoRoute(
            path: 'owner-register',
            builder: (context, state) => const _AuthPlaceholder(),
          ),
        ],
      ),

      // ─── Welcome / Org Naming ────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const _WelcomePlaceholder(),
      ),

      // ─── Parent Link Screen ──────────────────────────────────────────
      GoRoute(
        path: '/auth/parent-link',
        builder: (context, state) => const _AuthPlaceholder(),
      ),

      // ─── Owner/Teacher Shell Navigation ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          // Shell wrapper — will be replaced with OwnerShell/TeacherShell
          return child;
        },
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const _DashboardPlaceholder(),
          ),

          // Academic
          GoRoute(
            path: '/academic',
            builder: (context, state) => const _AcademicPlaceholder(),
            routes: [
              GoRoute(
                path: 'stages/:stageId/classes',
                builder: (context, state) {
                  final stageId = state.pathParameters['stageId']!;
                  return _ClassesPlaceholder(stageId: stageId);
                },
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) {
                      final stageId = state.extra as String? ??
                          state.pathParameters['stageId'] ?? '';
                      return _ClassFormPlaceholder(stageId: stageId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // People Hub (Sprint 1+2 — User Management + RBAC)
          GoRoute(
            path: '/people',
            builder: (context, state) => const PeopleHubScreen(),
            routes: [
              GoRoute(
                path: 'users/:userId',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  return UserDetailScreen(userId: userId);
                },
              ),
              GoRoute(
                path: 'roles',
                builder: (context, state) => const RoleMatrixScreen(),
              ),
            ],
          ),

          // Inbox
          GoRoute(
            path: '/inbox',
            builder: (context, state) => const _InboxPlaceholder(),
            routes: [
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const _InboxPlaceholder(),
              ),
              GoRoute(
                path: 'notifications/:id',
                builder: (context, state) {
                  final notificationId = state.pathParameters['id']!;
                  return _NotificationDetailPlaceholder(notificationId: notificationId);
                },
              ),
              GoRoute(
                path: 'messages',
                builder: (context, state) => const _MessagesPlaceholder(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) {
                      final conversationId = state.pathParameters['conversationId']!;
                      return _ChatPlaceholder(conversationId: conversationId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'announcements',
                builder: (context, state) => const _AnnouncementsPlaceholder(),
              ),
              GoRoute(
                path: 'announcements/create',
                builder: (context, state) => const _AnnouncementFormPlaceholder(),
              ),
              GoRoute(
                path: 'announcements/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _AnnouncementDetailPlaceholder(announcementId: id);
                },
              ),
            ],
          ),

          // Settings
          GoRoute(
            path: '/settings',
            builder: (context, state) => const _SettingsPlaceholder(),
            routes: [
              GoRoute(
                path: 'organization',
                builder: (context, state) => const _SettingsPlaceholder(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => const _SettingsPlaceholder(),
              ),
              GoRoute(
                path: 'feature-flags',
                builder: (context, state) => const _SettingsPlaceholder(),
              ),
            ],
          ),
        ],
      ),

      // ─── LMS Routes ───────────────────────────────────────────────────
      GoRoute(
        path: '/lms/subject/:subjectId',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          final subjectName = state.uri.queryParameters['name'] ?? 'Subject';
          final classId = state.uri.queryParameters['classId'] ?? '';
          return _LmsPlaceholder(
            subjectId: subjectId,
            subjectName: subjectName,
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '/lms/lessons/:lessonId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return _LmsLessonPlaceholder(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: '/lms/materials/:materialId',
        builder: (context, state) {
          final materialId = state.pathParameters['materialId']!;
          return _LmsMaterialPlaceholder(materialId: materialId);
        },
      ),

      // ─── LiveKit Routes (Sprint 1+2) ────────────────────────────────
      GoRoute(
        path: '/live-classes',
        builder: (context, state) => const _LiveClassesWrapper(),
      ),
      GoRoute(
        path: '/live-classes/analytics',
        builder: (context, state) => const _SessionAnalyticsWrapper(),
      ),

      // ─── Student Shell Navigation ─────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const _StudentDashboardPlaceholder(),
          ),
        ],
      ),

      // ─── Parent Shell Navigation ──────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/parent',
            builder: (context, state) => const _ParentDashboardPlaceholder(),
          ),
          GoRoute(
            path: '/parent/results',
            builder: (context, state) => const _ParentResultsPlaceholder(),
          ),
          GoRoute(
            path: '/parent/attendance',
            builder: (context, state) => const _ParentAttendancePlaceholder(),
          ),
          GoRoute(
            path: '/parent/assignments',
            builder: (context, state) => const _ParentAssignmentsPlaceholder(),
          ),
          GoRoute(
            path: '/parent/progress',
            builder: (context, state) => const _ParentProgressPlaceholder(),
          ),
          GoRoute(
            path: '/parent/announcements',
            builder: (context, state) => const _ParentAnnouncementsPlaceholder(),
          ),
        ],
      ),

      // ─── Student Settings Route ───────────────────────────────────────
      GoRoute(
        path: '/student/settings',
        builder: (context, state) => const _SettingsPlaceholder(),
      ),

      // ─── Student Deep Routes ──────────────────────────────────────────
      GoRoute(
        path: '/student/exams',
        builder: (context, state) => const _StudentExamsPlaceholder(),
        routes: [
          GoRoute(
            path: ':examId/take',
            builder: (context, state) {
              final examId = state.pathParameters['examId']!;
              return _ExamTakingPlaceholder(examId: examId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/student/results',
        builder: (context, state) => const _StudentResultsPlaceholder(),
      ),
      GoRoute(
        path: '/student/scan-qr',
        builder: (context, state) => const _QrScanPlaceholder(),
      ),
      GoRoute(
        path: '/student/notifications',
        builder: (context, state) => const _InboxPlaceholder(),
      ),
    ],
  );
});

// ─── Exported router instance for app.dart ──────────────────────────────────
GoRouter get klasivoRouter => _routerInstance;

// This would normally be obtained via provider scope; here we provide
// a late-initialized instance that gets set by the provider system.
late final GoRouter _routerInstance;

/// Initialize the router — called from main.dart after ProviderScope is ready.
void initializeRouter(GoRouter router) {
  _routerInstance = router;
}

// ─── Placeholder Screens ────────────────────────────────────────────────────
// These are temporary screens that will be replaced by actual feature screens
// when the v2.0 migration is complete. They exist so the router compiles.

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Splash Screen')));
  }
}

class _AuthPlaceholder extends StatelessWidget {
  const _AuthPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Auth Screen')));
  }
}

class _WelcomePlaceholder extends StatelessWidget {
  const _WelcomePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Welcome Screen')));
  }
}

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}

class _AcademicPlaceholder extends StatelessWidget {
  const _AcademicPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Academic')));
  }
}

class _ClassesPlaceholder extends StatelessWidget {
  final String stageId;
  const _ClassesPlaceholder({required this.stageId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Classes for Stage: $stageId')));
  }
}

class _ClassFormPlaceholder extends StatelessWidget {
  final String stageId;
  const _ClassFormPlaceholder({required this.stageId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Class Form for Stage: $stageId')));
  }
}

class _PeoplePlaceholder extends StatelessWidget {
  const _PeoplePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('People')));
  }
}

class _InboxPlaceholder extends StatelessWidget {
  const _InboxPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Inbox')));
  }
}

class _NotificationDetailPlaceholder extends StatelessWidget {
  final String notificationId;
  const _NotificationDetailPlaceholder({required this.notificationId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Notification: $notificationId')));
  }
}

class _MessagesPlaceholder extends StatelessWidget {
  const _MessagesPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Messages')));
  }
}

class _ChatPlaceholder extends StatelessWidget {
  final String conversationId;
  const _ChatPlaceholder({required this.conversationId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Chat: $conversationId')));
  }
}

class _AnnouncementsPlaceholder extends StatelessWidget {
  const _AnnouncementsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Announcements')));
  }
}

class _AnnouncementFormPlaceholder extends StatelessWidget {
  const _AnnouncementFormPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Create Announcement')));
  }
}

class _AnnouncementDetailPlaceholder extends StatelessWidget {
  final String announcementId;
  const _AnnouncementDetailPlaceholder({required this.announcementId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Announcement: $announcementId')));
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Settings')));
  }
}

class _LmsPlaceholder extends StatelessWidget {
  final String subjectId;
  final String subjectName;
  final String classId;
  const _LmsPlaceholder({
    required this.subjectId,
    required this.subjectName,
    required this.classId,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('LMS: $subjectName')));
  }
}

class _LmsLessonPlaceholder extends StatelessWidget {
  final String lessonId;
  const _LmsLessonPlaceholder({required this.lessonId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Lesson: $lessonId')));
  }
}

class _LmsMaterialPlaceholder extends StatelessWidget {
  final String materialId;
  const _LmsMaterialPlaceholder({required this.materialId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Material: $materialId')));
  }
}

class _StudentDashboardPlaceholder extends StatelessWidget {
  const _StudentDashboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Student Dashboard')));
  }
}

class _StudentExamsPlaceholder extends StatelessWidget {
  const _StudentExamsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Student Exams')));
  }
}

class _ExamTakingPlaceholder extends StatelessWidget {
  final String examId;
  const _ExamTakingPlaceholder({required this.examId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Taking Exam: $examId')));
  }
}

class _StudentResultsPlaceholder extends StatelessWidget {
  const _StudentResultsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Student Results')));
  }
}

class _QrScanPlaceholder extends StatelessWidget {
  const _QrScanPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('QR Scanner')));
  }
}

class _ParentDashboardPlaceholder extends StatelessWidget {
  const _ParentDashboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Dashboard')));
  }
}

class _ParentResultsPlaceholder extends StatelessWidget {
  const _ParentResultsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Results')));
  }
}

class _ParentAttendancePlaceholder extends StatelessWidget {
  const _ParentAttendancePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Attendance')));
  }
}

class _ParentAssignmentsPlaceholder extends StatelessWidget {
  const _ParentAssignmentsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Assignments')));
  }
}

class _ParentProgressPlaceholder extends StatelessWidget {
  const _ParentProgressPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Progress')));
  }
}

class _ParentAnnouncementsPlaceholder extends StatelessWidget {
  const _ParentAnnouncementsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent Announcements')));
  }
}

// ─── LiveKit Wrapper Screens (Sprint 1+2) ───────────────────────────────────
// These wrappers read runtime context from providers and pass to the
// actual LiveKit screens, which require orgId/userId/displayName.

class _LiveClassesWrapper extends ConsumerWidget {
  const _LiveClassesWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final box = Hive.box(AppConstants.authBox);
    final orgId = box.get('organizationId', defaultValue: '') as String;
    final userId = box.get('userId', defaultValue: '') as String;
    final displayName = box.get('displayName', defaultValue: '') as String;
    final role = box.get('userRole', defaultValue: '') as String;
    final isTeacher = role == AppConstants.roleTeacher || role == AppConstants.roleOwner;

    return ScheduledClassesScreen(
      orgId: orgId,
      userId: userId,
      displayName: displayName,
      isTeacher: isTeacher,
    );
  }
}

class _SessionAnalyticsWrapper extends ConsumerWidget {
  const _SessionAnalyticsWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final box = Hive.box(AppConstants.authBox);
    final orgId = box.get('organizationId', defaultValue: '') as String;
    final userId = box.get('userId', defaultValue: '') as String;

    return SessionAnalyticsDashboard(
      orgId: orgId,
      teacherId: userId,
    );
  }
}

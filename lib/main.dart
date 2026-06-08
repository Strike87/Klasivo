import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/theme.dart';
import 'core/config/app_constants.dart';
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/role_selection_screen.dart';
import 'features/auth/pages/teacher_login_screen.dart';
import 'features/auth/pages/teacher_registration_screen.dart';
import 'features/auth/pages/owner_register_screen.dart';
import 'features/auth/pages/student_login_screen.dart';
import 'features/auth/pages/welcome_screen.dart';
import 'features/auth/pages/forgot_password_screen.dart';
import 'features/shell/teacher_shell.dart';
import 'features/shell/student_shell.dart';
import 'features/shell/parent_shell.dart';
import 'features/dashboard/owner_dashboard.dart';
import 'features/dashboard/teacher_dashboard.dart';
import 'features/dashboard/student_dashboard.dart';
import 'features/classes/pages/class_list_screen.dart';
import 'features/classes/pages/class_form_screen.dart';
import 'features/students/pages/student_list_screen.dart';
import 'features/students/pages/student_form_screen.dart';
import 'features/students/pages/all_students_screen.dart';
import 'features/exams/pages/exam_list_screen.dart';
import 'features/exams/pages/exam_form_screen.dart';
import 'features/exams/pages/question_builder_screen.dart';
import 'features/exams/pages/exam_detail_screen.dart';
import 'features/student_exams/pages/student_exam_list_screen.dart';
import 'features/student_exams/pages/exam_taking_screen.dart';
import 'features/student_results/pages/student_results_screen.dart';
import 'features/teacher_results/pages/exam_results_screen.dart';
import 'features/stages/pages/stage_list_screen.dart';
import 'features/grades/pages/grade_list_screen.dart';
import 'features/groups/pages/group_list_screen.dart';
import 'features/question_bank/pages/question_bank_screen.dart';
import 'features/notifications/pages/notification_center_screen.dart';
import 'features/notifications/pages/notification_detail_screen.dart';
import 'features/excel_import/pages/excel_import_screen.dart';
import 'features/qr/pages/qr_generate_screen.dart';
import 'features/qr/pages/qr_scan_screen.dart';
import 'features/analytics/pages/teacher_analytics_dashboard.dart';
import 'features/reports/pages/report_generation_screen.dart';
import 'features/integrity/pages/exam_integrity_dashboard.dart';
import 'features/settings/pages/settings_screen.dart';
import 'features/settings/pages/organization_settings_screen.dart';
import 'features/settings/pages/profile_settings_screen.dart';
import 'features/settings/pages/student_settings_screen.dart';
import 'features/exam_instances/pages/exam_instances_screen.dart';
// ─── v1.7 Imports ─────────────────────────────────────────────────────────────
import 'features/assignments/pages/assignment_list_screen.dart';
import 'features/assignments/pages/assignment_form_screen.dart';
import 'features/assignments/pages/assignment_detail_screen.dart';
import 'features/gradebook/pages/gradebook_screen.dart';
import 'features/attendance/pages/attendance_screen.dart';
import 'features/parent/pages/parent_login_screen.dart';
import 'features/parent/pages/parent_register_screen.dart';
import 'features/parent/pages/parent_link_screen.dart';
import 'features/parent/pages/parent_dashboard.dart';
import 'providers/class_provider.dart';
import 'providers/student_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/auth_provider.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Initialize Firebase with error handling ────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  await Hive.initFlutter();
  await Hive.openBox(AppConstants.authBox);

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Klasivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

// ─── Auth Change Notifier for GoRouter refresh ──────────────────────────────

class AuthChangeNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _firebaseSub;
  StreamSubscription<dynamic>? _hivePollSub;

  AuthChangeNotifier() {
    _firebaseSub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
      onError: (_) => notifyListeners(),
    );
    _startHiveWatch();
  }

  void _startHiveWatch() {
    bool _lastValue = Hive.box(AppConstants.authBox).get('isLoggedIn', defaultValue: false);
    _hivePollSub = Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
      final currentValue = Hive.box(AppConstants.authBox).get('isLoggedIn', defaultValue: false);
      if (currentValue != _lastValue) {
        _lastValue = currentValue;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    _hivePollSub?.cancel();
    super.dispose();
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// ─── GoRouter with Auth Guards & v1.7 Navigation ─────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
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
          state.matchedLocation.startsWith('/teacher');
      final isOnStudent = state.matchedLocation.startsWith('/student');
      final isOnParent = state.matchedLocation.startsWith('/parent');

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

        // Owner setup check
        if (userRole == AppConstants.roleOwner && !hasCompletedSetup) {
          return '/welcome';
        }

        // Role-based access
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

        // Redirect to correct dashboard
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
        builder: (context, state) => const SplashScreen(),
      ),

      // ─── Auth Routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (context, state) => const RoleSelectionScreen(),
        routes: [
          GoRoute(
            path: 'teacher-login',
            builder: (context, state) => const TeacherLoginScreen(),
          ),
          GoRoute(
            path: 'teacher-register',
            builder: (context, state) => const TeacherRegistrationScreen(),
          ),
          GoRoute(
            path: 'owner-register',
            builder: (context, state) => const OwnerRegisterScreen(),
          ),
          GoRoute(
            path: 'student-login',
            builder: (context, state) => const StudentLoginScreen(),
          ),
          GoRoute(
            path: 'parent-login',
            builder: (context, state) => const ParentLoginScreen(),
          ),
          GoRoute(
            path: 'parent-register',
            builder: (context, state) => const ParentRegisterScreen(),
          ),
          GoRoute(
            path: 'parent-link',
            builder: (context, state) => const ParentLinkScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),

      // ─── Welcome / Org Naming ────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ─── Teacher/Owner Shell Navigation ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const OwnerDashboard(),
          ),

          // Academic
          GoRoute(
            path: '/academic',
            builder: (context, state) => const StageListScreen(),
          ),

          // People
          GoRoute(
            path: '/people',
            builder: (context, state) => const AllStudentsScreen(),
          ),

          // Inbox (Messages + Notifications + Announcements)
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
                  return NotificationDetailScreen(notificationId: notificationId);
                },
              ),
              GoRoute(
                path: 'messages',
                builder: (context, state) => const NotificationCenterScreen(),
              ),
            ],
          ),

          // Settings
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'organization',
                builder: (context, state) => const OrganizationSettingsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── Settings (outside shell for full-screen) ────────────────────
      GoRoute(
        path: '/settings/organization',
        builder: (context, state) => const OrganizationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),

      // ─── Legacy Teacher Routes (still functional, deep link compatible) ──
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
                builder: (context, state) => const ClassFormScreen(isEditing: false),
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
                path: ':stageId/grades',
                builder: (context, state) {
                  final stageId = state.pathParameters['stageId']!;
                  return GradeListScreen(stageId: stageId);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'question-bank',
            builder: (context, state) => const QuestionBankScreen(),
          ),

          // ─── v1.7 New Routes ──────────────────────────────────────────
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

          // ─── Existing v1.6 Routes ────────────────────────────────────
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
        ],
      ),

      // ─── Student Shell Navigation ────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboard(),
          ),
        ],
      ),

      // ─── Student Deep Routes (outside shell for full-screen) ─────────
      GoRoute(
        path: '/student/exams',
        builder: (context, state) => const StudentExamListScreen(),
        routes: [
          GoRoute(
            path: ':examId/take',
            builder: (context, state) {
              final examId = state.pathParameters['examId']!;
              return ExamTakingScreen(examId: examId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/student/results',
        builder: (context, state) => const StudentResultsScreen(),
        routes: [
          GoRoute(
            path: ':submissionId',
            builder: (context, state) {
              final submissionId = state.pathParameters['submissionId']!;
              return StudentResultDetailScreen(submissionId: submissionId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/student/scan-qr',
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/student/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/student/settings',
        builder: (context, state) => const StudentSettingsScreen(),
      ),

      // ─── v1.7 Parent Shell Navigation ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
        routes: [
          GoRoute(
            path: '/parent',
            builder: (context, state) => const ParentDashboard(),
          ),
          GoRoute(
            path: '/parent/results',
            builder: (context, state) => const ParentResultsView(),
          ),
          GoRoute(
            path: '/parent/attendance',
            builder: (context, state) => const ParentAttendanceView(),
          ),
        ],
      ),
    ],
  );
});

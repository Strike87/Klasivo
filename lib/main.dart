import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/theme.dart';
import 'core/config/app_constants.dart';
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/role_selection_screen.dart';
import 'features/auth/pages/teacher_login_screen.dart';
import 'features/auth/pages/teacher_registration_screen.dart';
import 'features/auth/pages/student_login_screen.dart';
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
// v1.5 imports
import 'features/stages/pages/stage_list_screen.dart';
import 'features/grades/pages/grade_list_screen.dart';
import 'features/groups/pages/group_list_screen.dart';
import 'features/question_bank/pages/question_bank_screen.dart';
import 'features/notifications/pages/notification_center_screen.dart';
import 'features/excel_import/pages/excel_import_screen.dart';
import 'features/qr/pages/qr_generate_screen.dart';
import 'features/qr/pages/qr_scan_screen.dart';
import 'features/analytics/pages/teacher_analytics_dashboard.dart';
// v1.5 Phase D imports
import 'features/reports/pages/report_generation_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/student_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/question_provider.dart';
import 'providers/submission_provider.dart';
import 'providers/exam_stats_provider.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.authBox);

  // Initialize notifications
  await NotificationService.initialize();

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
  StreamSubscription? _hiveSub;

  AuthChangeNotifier() {
    _firebaseSub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
      onError: (_) => notifyListeners(),
    );
    _startHiveWatch();
  }

  void _startHiveWatch() {
    bool _lastValue = Hive.box(AppConstants.authBox).get('isLoggedIn', defaultValue: false);
    Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
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
    super.dispose();
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// ─── GoRouter with Auth Guards ───────────────────────────────────────────────

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

      final isOnSplash = state.matchedLocation == '/';
      final isOnAuth = state.matchedLocation.startsWith('/auth');
      final isOnDashboard =
          state.matchedLocation.startsWith('/teacher') ||
          state.matchedLocation.startsWith('/student');

      if (isOnSplash) {
        if (isLoggedIn && userRole.isNotEmpty) {
          if (userRole == AppConstants.roleTeacher) return '/teacher';
          if (userRole == AppConstants.roleStudent) return '/student';
        }
        return '/auth';
      }

      if (isOnAuth) {
        if (isLoggedIn && userRole.isNotEmpty) {
          if (userRole == AppConstants.roleTeacher) return '/teacher';
          if (userRole == AppConstants.roleStudent) return '/student';
        }
        return null;
      }

      if (isOnDashboard) {
        if (!isLoggedIn) return '/auth';
        if (userRole.isEmpty) return '/auth';
        if (userRole == AppConstants.roleTeacher &&
            state.matchedLocation.startsWith('/teacher')) {
          return null;
        }
        if (userRole == AppConstants.roleStudent &&
            state.matchedLocation.startsWith('/student')) {
          return null;
        }
        if (userRole == AppConstants.roleTeacher) return '/teacher';
        if (userRole == AppConstants.roleStudent) return '/student';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
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
            path: 'student-login',
            builder: (context, state) => const StudentLoginScreen(),
          ),
        ],
      ),
      // ─── Teacher Routes ──────────────────────────────────────────────
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherDashboard(),
        routes: [
          // Classes
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
                  // v1.5: Excel Import
                  GoRoute(
                    path: 'import',
                    builder: (context, state) {
                      final classId = state.pathParameters['classId']!;
                      return ExcelImportScreen(classId: classId);
                    },
                  ),
                  // v1.5: QR Generate
                  GoRoute(
                    path: 'qr',
                    builder: (context, state) {
                      final classId = state.pathParameters['classId']!;
                      return QrGenerateScreen(classId: classId);
                    },
                  ),
                  // v1.5: Groups
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
          // Exams
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
                ],
              ),
            ],
          ),
          // v1.5: Stages
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
          // v1.5: Question Bank
          GoRoute(
            path: 'question-bank',
            builder: (context, state) => const QuestionBankScreen(),
          ),
          // v1.5: Notifications
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          // v1.5: Analytics
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const TeacherAnalyticsDashboard(),
          ),
          // v1.5 Phase D: Reports
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportGenerationScreen(),
          ),
        ],
      ),
      // ─── Student Routes ──────────────────────────────────────────────
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboard(),
        routes: [
          GoRoute(
            path: 'exams',
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
            path: 'results',
            builder: (context, state) => const StudentResultsScreen(),
            routes: [
              GoRoute(
                path: ':submissionId',
                builder: (context, state) {
                  final submissionId =
                      state.pathParameters['submissionId']!;
                  return StudentResultDetailScreen(
                    submissionId: submissionId,
                  );
                },
              ),
            ],
          ),
          // v1.5: QR Scan
          GoRoute(
            path: 'scan-qr',
            builder: (context, state) => const QrScanScreen(),
          ),
          // v1.5: Notifications
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
        ],
      ),
    ],
  );
});

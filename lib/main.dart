import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/student_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/question_provider.dart';
import 'providers/submission_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await HiveFlutter.init();
  await Hive.openBox(AppConstants.authBox);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Smart Exam Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

// ─── GoRouter with Auth Guards ───────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRole = ref.watch(userRoleProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isOnSplash = state.matchedLocation == '/';
      final isOnAuth = state.matchedLocation.startsWith('/auth');
      final isOnDashboard =
          state.matchedLocation.startsWith('/teacher') ||
          state.matchedLocation.startsWith('/student');

      // ── Splash screen logic ──
      if (isOnSplash) {
        if (isLoggedIn && userRole.isNotEmpty) {
          if (userRole == AppConstants.roleTeacher) return '/teacher';
          if (userRole == AppConstants.roleStudent) return '/student';
        }
        return null;
      }

      // ── Auth pages are always accessible when not logged in ──
      if (isOnAuth && !isLoggedIn) return null;

      // ── If logged in and trying to access auth pages, redirect to dashboard ──
      if (isOnAuth && isLoggedIn) {
        if (userRole == AppConstants.roleTeacher) return '/teacher';
        if (userRole == AppConstants.roleStudent) return '/student';
        return '/auth';
      }

      // ── Dashboard pages require authentication ──
      if (isOnDashboard && !isLoggedIn) {
        return '/auth';
      }

      // ── Role-based dashboard access ──
      if (state.matchedLocation.startsWith('/teacher') &&
          userRole != AppConstants.roleTeacher) {
        return '/auth';
      }
      if (state.matchedLocation.startsWith('/student') &&
          userRole != AppConstants.roleStudent) {
        return '/auth';
      }

      return null;
    },
    routes: [
      // ── Splash ──
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth Routes ──
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

      // ── Teacher Routes ──
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherDashboard(),
        routes: [
          // ── Classes ──
          GoRoute(
            path: 'classes',
            builder: (context, state) => const ClassListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const ClassFormScreen(
                  isEditing: false,
                ),
              ),
              GoRoute(
                path: 'edit/:classId',
                builder: (context, state) {
                  final classData = state.extra as ClassData?;
                  return ClassFormScreen(
                    isEditing: true,
                    classData: classData,
                  );
                },
              ),
              // ── Students in Class ──
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
                      return StudentFormScreen(
                        classId: classId,
                        isEditing: false,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'edit/:studentId',
                    builder: (context, state) {
                      final classId = state.pathParameters['classId']!;
                      final studentData = state.extra as StudentData?;
                      return StudentFormScreen(
                        classId: classId,
                        isEditing: true,
                        studentData: studentData,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // ── All Students ──
          GoRoute(
            path: 'students',
            builder: (context, state) => const AllStudentsScreen(),
          ),

          // ── Exams ──
          GoRoute(
            path: 'exams',
            builder: (context, state) => const ExamListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const ExamFormScreen(
                  isEditing: false,
                ),
              ),
              GoRoute(
                path: 'edit/:examId',
                builder: (context, state) {
                  final examData = state.extra as ExamData?;
                  return ExamFormScreen(
                    isEditing: true,
                    examData: examData,
                  );
                },
              ),
              // ── Exam Detail ──
              GoRoute(
                path: ':examId',
                builder: (context, state) {
                  final examId = state.pathParameters['examId']!;
                  return ExamDetailScreen(examId: examId);
                },
                routes: [
                  // ── Question Builder ──
                  GoRoute(
                    path: 'questions',
                    builder: (context, state) {
                      final examId = state.pathParameters['examId']!;
                      return QuestionBuilderScreen(examId: examId);
                    },
                  ),
                  // ── Exam Results (Teacher View) ──
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
        ],
      ),

      // ── Student Routes ──
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboard(),
        routes: [
          // ── Student Exams ──
          GoRoute(
            path: 'exams',
            builder: (context, state) => const StudentExamListScreen(),
            routes: [
              // ── Take Exam ──
              GoRoute(
                path: ':examId/take',
                builder: (context, state) {
                  final examId = state.pathParameters['examId']!;
                  return ExamTakingScreen(examId: examId);
                },
              ),
            ],
          ),

          // ── Student Results ──
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
        ],
      ),
    ],
  );
});

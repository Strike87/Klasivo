import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

// Auth
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/role_selection_screen.dart';
import 'features/auth/pages/teacher_login_screen.dart';
import 'features/auth/pages/teacher_registration_screen.dart';
import 'features/auth/pages/student_login_screen.dart';

// Dashboard
import 'features/dashboard/teacher_dashboard.dart';
import 'features/dashboard/student_dashboard.dart';

// Classes
import 'features/classes/pages/class_list_screen.dart';
import 'features/classes/pages/class_form_screen.dart';

// Students
import 'features/students/pages/student_list_screen.dart';
import 'features/students/pages/student_form_screen.dart';
import 'features/students/pages/all_students_screen.dart';

// Exams
import 'features/exams/pages/exam_list_screen.dart';
import 'features/exams/pages/exam_form_screen.dart';
import 'features/exams/pages/question_builder_screen.dart';
import 'features/exams/pages/exam_detail_screen.dart';

// Student Exams & Results
import 'features/student_exams/pages/student_exam_list_screen.dart';
import 'features/student_exams/pages/exam_taking_screen.dart';
import 'features/student_results/pages/student_results_screen.dart';

// Teacher Results
import 'features/teacher_results/pages/exam_results_screen.dart';

// Phase C - New Features
import 'features/excel_import/pages/excel_import_screen.dart';
import 'features/question_bank/pages/question_bank_screen.dart';
import 'features/qr/pages/qr_generate_screen.dart';
import 'features/qr/pages/qr_scan_screen.dart';
import 'features/exam_instances/pages/exam_instances_screen.dart';

// Phase C - Providers
import 'providers/question_bank_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox('auth_box');

  runApp(const ProviderScope(child: SmartExamProApp()));
}

class SmartExamProApp extends ConsumerWidget {
  const SmartExamProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Smart Exam Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authBox = Hive.box('auth_box');
      final isLoggedIn = authBox.get('isLoggedIn') as bool? ?? false;
      final userRole = authBox.get('userRole') as String? ?? '';

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/';

      // If on splash, let it handle routing
      if (isSplash) return null;

      // If not logged in and trying to access protected route
      if (!isLoggedIn && !isAuthRoute) {
        return '/auth';
      }

      // If logged in and trying to access auth routes
      if (isLoggedIn && isAuthRoute) {
        return userRole == 'teacher' ? '/teacher' : '/student';
      }

      // Role-based access control
      if (isLoggedIn) {
        if (userRole == 'student' && state.matchedLocation.startsWith('/teacher')) {
          return '/student';
        }
        if (userRole == 'teacher' && state.matchedLocation.startsWith('/student')) {
          return '/teacher';
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/auth',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/auth/teacher-login',
        builder: (context, state) => const TeacherLoginScreen(),
      ),
      GoRoute(
        path: '/auth/teacher-register',
        builder: (context, state) => const TeacherRegistrationScreen(),
      ),
      GoRoute(
        path: '/auth/student-login',
        builder: (context, state) => const StudentLoginScreen(),
      ),

      // ===== TEACHER ROUTES =====
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherDashboard(),
      ),
      GoRoute(
        path: '/teacher/classes',
        builder: (context, state) => const ClassListScreen(),
      ),
      GoRoute(
        path: '/teacher/classes/create',
        builder: (context, state) => const ClassFormScreen(isEditing: false),
      ),
      GoRoute(
        path: '/teacher/classes/edit/:classId',
        builder: (context, state) => ClassFormScreen(
          isEditing: true,
          classId: state.pathParameters['classId'],
        ),
      ),
      GoRoute(
        path: '/teacher/classes/:classId/students',
        builder: (context, state) => StudentListScreen(
          classId: state.pathParameters['classId']!,
        ),
      ),
      GoRoute(
        path: '/teacher/classes/:classId/students/create',
        builder: (context, state) => StudentFormScreen(
          classId: state.pathParameters['classId']!,
          isEditing: false,
        ),
      ),
      GoRoute(
        path: '/teacher/classes/:classId/students/edit/:studentId',
        builder: (context, state) => StudentFormScreen(
          classId: state.pathParameters['classId']!,
          studentId: state.pathParameters['studentId'],
          isEditing: true,
        ),
      ),

      // QR Code for class enrollment (Phase C)
      GoRoute(
        path: '/teacher/classes/:classId/qr',
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QRGenerateScreen(
            classId: classId,
            className: extra['className'] as String? ?? '',
            grade: extra['grade'] as String?,
          );
        },
      ),

      GoRoute(
        path: '/teacher/students',
        builder: (context, state) => const AllStudentsScreen(),
      ),

      // Exams
      GoRoute(
        path: '/teacher/exams',
        builder: (context, state) => const ExamListScreen(),
      ),
      GoRoute(
        path: '/teacher/exams/create',
        builder: (context, state) => const ExamFormScreen(isEditing: false),
      ),
      GoRoute(
        path: '/teacher/exams/edit/:examId',
        builder: (context, state) => ExamFormScreen(
          isEditing: true,
          examId: state.pathParameters['examId'],
        ),
      ),
      GoRoute(
        path: '/teacher/exams/:examId',
        builder: (context, state) => ExamDetailScreen(
          examId: state.pathParameters['examId']!,
        ),
      ),
      GoRoute(
        path: '/teacher/exams/:examId/questions',
        builder: (context, state) => QuestionBuilderScreen(
          examId: state.pathParameters['examId']!,
        ),
      ),
      GoRoute(
        path: '/teacher/exams/:examId/results',
        builder: (context, state) => ExamResultsScreen(
          examId: state.pathParameters['examId']!,
        ),
      ),

      // Exam instances (Phase C)
      GoRoute(
        path: '/teacher/exams/:examId/instances',
        builder: (context, state) => ExamInstancesScreen(
          examId: state.pathParameters['examId']!,
        ),
      ),

      // Question Bank (Phase C)
      GoRoute(
        path: '/teacher/question-bank',
        builder: (context, state) => ProviderScope(
          overrides: [
            teacherIdForBankProvider.overrideWithValue(
              Hive.box('auth_box').get('userId') as String?,
            ),
          ],
          child: const QuestionBankScreen(),
        ),
      ),

      // Excel Import (Phase C)
      GoRoute(
        path: '/teacher/excel-import',
        builder: (context, state) => const ExcelImportScreen(),
      ),

      // ===== STUDENT ROUTES =====
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboard(),
      ),
      GoRoute(
        path: '/student/exams',
        builder: (context, state) => const StudentExamListScreen(),
      ),
      GoRoute(
        path: '/student/exams/:examId/take',
        builder: (context, state) => ExamTakingScreen(
          examId: state.pathParameters['examId']!,
        ),
      ),
      GoRoute(
        path: '/student/results',
        builder: (context, state) => const StudentResultsScreen(),
      ),
      GoRoute(
        path: '/student/results/:submissionId',
        builder: (context, state) => StudentResultDetailScreen(
          submissionId: state.pathParameters['submissionId']!,
        ),
      ),

      // QR Scan for student enrollment (Phase C)
      GoRoute(
        path: '/student/qr-scan',
        builder: (context, state) => const QRScanScreen(),
      ),
    ],
  );
});

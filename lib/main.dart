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
import 'features/auth/pages/student_login_screen.dart';
import 'features/auth/pages/welcome_screen.dart';
import 'features/shell/teacher_shell.dart';
import 'features/shell/student_shell.dart';
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
import 'features/excel_import/pages/excel_import_screen.dart';
import 'features/qr/pages/qr_generate_screen.dart';
import 'features/qr/pages/qr_scan_screen.dart';
import 'features/analytics/pages/teacher_analytics_dashboard.dart';
import 'features/reports/pages/report_generation_screen.dart';
import 'features/integrity/pages/exam_integrity_dashboard.dart';
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

// ─── GoRouter with Auth Guards & v1.6 Navigation ─────────────────────────────

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

      // Splash → redirect based on auth state
      if (isOnSplash) {
        if (isLoggedIn && userRole.isNotEmpty) {
          // Owner hasn't completed setup → go to Welcome
          if (userRole == AppConstants.roleOwner && !hasCompletedSetup) {
            return '/welcome';
          }
          if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {
            return '/dashboard';
          }
          if (userRole == AppConstants.roleStudent) return '/student';
        }
        return '/auth';
      }

      // Welcome screen — only accessible to logged-in owners who haven't completed setup
      if (isOnWelcome) {
        if (!isLoggedIn) return '/auth';
        if (userRole != AppConstants.roleOwner) return '/dashboard';
        if (hasCompletedSetup) return '/dashboard';
        return null; // Allow access
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
        }
        return null;
      }

      // Protected screens → require login
      if (isOnDashboard || isOnStudent) {
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

        // Redirect to correct dashboard
        if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {
          return '/dashboard';
        }
        if (userRole == AppConstants.roleStudent) return '/student';
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
            path: 'student-login',
            builder: (context, state) => const StudentLoginScreen(),
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
                  return _NotificationDetailScreen(notificationId: notificationId);
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
            builder: (context, state) => const _SettingsPlaceholder(),
          ),
        ],
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
    ],
  );
});

// ─── Placeholder Screens (will be replaced with full implementations) ────────

class _NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;
  const _NotificationDetailScreen({required this.notificationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: Center(child: Text('Notification: $notificationId')),
    );
  }
}

class _SettingsPlaceholder extends ConsumerWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ref.watch(userNameProvider) ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: KlasivoColors.primary.withOpacity(0.1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: KlasivoTypography.headlineSmall.copyWith(
                        color: KlasivoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: KlasivoTypography.titleLarge),
                        const SizedBox(height: KlasivoSpacing.xs),
                        Text(
                          ref.watch(userIdProvider) ?? '',
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextTertiary
                                : KlasivoColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Settings Items
          _SettingsTile(
            icon: Icons.business_outlined,
            title: 'Organization',
            subtitle: 'Manage workspace settings',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Edit your profile information',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.vpn_key_outlined,
            title: 'Invite Codes',
            subtitle: 'Generate and manage invite codes',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Light and dark theme',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {},
          ),

          const Divider(),

          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: AppConstants.supportEmail,
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About Klasivo',
            subtitle: 'Version 1.6.0',
            onTap: () {},
          ),

          const Divider(),

          // Logout
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            isDestructive: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: KlasivoColors.error,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await clearAuthData();
                if (context.mounted) context.go('/auth');
              }
            },
          ),

          const SizedBox(height: KlasivoSpacing.xxxl),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? KlasivoColors.error
        : (isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: KlasivoTypography.titleMedium.copyWith(color: color)),
      subtitle: Text(
        subtitle,
        style: KlasivoTypography.bodySmall.copyWith(
          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

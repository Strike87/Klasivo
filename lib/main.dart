import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/config/theme.dart';
import 'core/config/app_constants.dart';
import 'core/config/app_environment.dart';
import 'core/services/sentry_service.dart';
import 'core/services/image_cache_service.dart';
import 'core/rbac/roles.dart';
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/role_selection_screen.dart';
import 'features/auth/pages/teacher_login_screen.dart';
import 'features/auth/pages/teacher_registration_screen.dart';
import 'features/auth/pages/student_login_screen.dart';
import 'features/auth/pages/welcome_screen.dart';
import 'features/auth/pages/forgot_password_screen.dart';
import 'features/auth/pages/owner_register_screen.dart';
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
import 'features/settings/pages/feature_flags_screen.dart';
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
import 'features/parent/pages/parent_assignments_screen.dart';
import 'features/parent/pages/parent_progress_screen.dart';
import 'features/parent/pages/parent_announcements_screen.dart';
import 'features/moderation/pages/moderation_queue_screen.dart';
import 'features/progress/pages/progress_tracking_screen.dart';
// ─── v1.7 LMS Imports ─────────────────────────────────────────────────────────
import 'features/lms/pages/subject_content_screen.dart';
import 'features/lms/pages/lesson_detail_screen.dart';
import 'features/lms/pages/material_viewer_screen.dart';
// ─── v1.8 Messaging Imports ────────────────────────────────────────────────────
import 'features/messaging/pages/conversation_list_screen.dart';
import 'features/messaging/pages/chat_screen.dart';
// ─── v1.9 Contact Us Import ────────────────────────────────────────────────────
import 'features/contact/pages/contact_us_screen.dart';

// ─── v1.6 Feature-Complete Imports ────────────────────────────────────────────
import 'features/announcements/pages/announcement_list_screen.dart';
import 'features/announcements/pages/announcement_form_screen.dart';
import 'features/announcements/pages/announcement_detail_screen.dart';
import 'features/calendar/pages/calendar_screen.dart';
import 'features/calendar/pages/calendar_event_form_screen.dart';
import 'features/academic_years/pages/academic_year_list_screen.dart';
import 'features/academic_years/pages/academic_year_form_screen.dart';
import 'features/audit_log/pages/audit_log_screen.dart';
import 'providers/class_provider.dart';
import 'providers/student_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/feature_flag_provider.dart';
import 'providers/event_bus_provider.dart';
import 'providers/permission_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/event_bus.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Resolve environment & package info early ──────────────────────────
  final envConfig = EnvironmentConfig.current;
  late final PackageInfo packageInfo;
  try {
    packageInfo = await PackageInfo.fromPlatform();
  } catch (_) {
    // Fallback if package_info_plus is unavailable (e.g. desktop test)
    packageInfo = PackageInfo(
      appName: envConfig.appName,
      packageName: 'com.klasivo.app',
      version: '2.0.0',
      buildNumber: '7',
    );
  }

  final releaseTag = 'klasivo@${packageInfo.version}+${packageInfo.buildNumber}';

  // ─── Sentry before-send callback: sanitize sensitive data ──────────────
  // Uses the centralized KlasivoSentrySanitizer from sentry_service.dart
  // instead of a duplicate local class.
  SentryEvent? beforeSendCallback(SentryEvent event) {
    return KlasivoSentrySanitizer.sanitizeEvent(event);
  }

  // ─── Initialize Firebase with error handling ────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Flutter Framework Errors → BOTH Crashlytics + Sentry ──────────
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    };

    // ── Platform/Async Errors → BOTH Crashlytics + Sentry ─────────────
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      Sentry.captureException(error, stackTrace: stack);
      return true;
    };

    // Use EnvironmentConfig for Crashlytics (respects dev/staging/prod)
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      envConfig.crashlyticsEnabled,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  await Hive.initFlutter();
  await Hive.openBox(AppConstants.authBox);
  await Hive.openBox(AppConstants.appSettingsBox);

  // ─── Initialize Image Cache Service ───────────────────────────────
  try {
    await ImageCacheService.instance.init();
  } catch (e) {
    debugPrint('Image cache initialization failed: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  // ─── Initialize Sentry (production-grade) ──────────────────────────
  await SentryFlutter.init(
    (options) {
      // ── DSN from EnvironmentConfig (hardcoded with compile-time override) ──
      options.dsn = envConfig.sentryDsn;

      // ── Environment from EnvironmentConfig ──────────────────────────
      options.environment = envConfig.environment.name;

      // ── Release tracking ────────────────────────────────────────────
      options.release = releaseTag;

      // ── Sampling rates from EnvironmentConfig (centralised) ─────────
      options.tracesSampleRate = envConfig.sentryTracesSampleRate;
      options.profilesSampleRate = envConfig.sentryProfilesSampleRate;

      // ── PII / Privacy ──────────────────────────────────────────────
      options.sendDefaultPii = false; // Never send PII by default

      // ── Before-send callback: sanitize all events ───────────────────
      options.beforeSend = (SentryEvent event, Hint hint) async {
        return beforeSendCallback(event);
      };

      // ── Auto breadcrumb tracking (handled automatically in SDK 9.x) ──

      // ── Attach screenshots to error events ──────────────────────────
      options.attachScreenshot = true;
      options.screenshotQuality = SentryScreenshotQuality.low;
      options.attachViewHierarchy = true;

      // ── Session Replay ──────────────────────────────────────────────
      // Mask all text and images by default for privacy
      // replay.maskAllText / maskAllImages removed in sentry_flutter 9.22.0
      options.replay.sessionSampleRate = envConfig.sentryReplaySessionSampleRate;
      options.replay.onErrorSampleRate = 1.0; // Always capture on error

      // ── Max breadcrumbs ─────────────────────────────────────────────
      options.maxBreadcrumbs = 200;

      // ── Diagnostic level ────────────────────────────────────────────
      options.diagnosticLevel = envConfig.isDev ? SentryLevel.debug : SentryLevel.error;

      // ── Swizzle (iOS) — handled automatically in SDK 9.x ────────────

      // ── ANR (Application Not Responding) ────────────────────────────
      options.anrEnabled = true;
      // anrTimeoutIntervalInSeconds removed in sentry_flutter 9.22.0

      // ── App lifecycle breadcrumbs ───────────────────────────────────
      options.enableAppLifecycleBreadcrumbs = true;

      // ── Navigation observer — handled automatically in SDK 9.x ──────
    },
    appRunner: () {
      // ── Set app version tags on Sentry scope ────────────────────────
      SentryUserContext.setAppVersion(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );

      // NOTE: runZonedGuarded removed — it creates a zone mismatch with
      // WidgetsFlutterBinding.ensureInitialized(). Error capture is already
      // handled by FlutterError.onError + PlatformDispatcher.instance.onError
      // which are set up above during Firebase initialization.
      runApp(ProviderScope(
        observers: [SentryRiverpodObserver()],
        child: const MyApp(),
      ));
    },
  );
}

// ─── Riverpod Sentry Observer ────────────────────────────────────────────────

/// Riverpod [ProviderObserver] that reports provider errors to Sentry.
/// Attached via [ProviderScope(observers:)] in the widget tree.
class SentryRiverpodObserver extends ProviderObserver {
  @override
  void providerDidFailUpdate(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('source', 'riverpod');
        scope.setTag('provider', provider.name ?? provider.runtimeType.toString());
      },
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeEnterpriseServices();
  }

  Future<void> _initializeEnterpriseServices() async {
    try {
      final box = Hive.box(AppConstants.authBox);
      final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
      final orgId = box.get('organizationId') as String?;

      if (isLoggedIn && orgId != null) {
        // Load feature flags for the organization
        final flagService = ref.read(featureFlagServiceProvider);
        await flagService.loadFlags(orgId);

        // Load custom permissions for the organization
        final permService = ref.read(permissionServiceProvider);
        await permService.loadPermissions(orgId);

        debugPrint('[MyApp] Enterprise services initialized for org: $orgId');
      }
    } catch (e) {
      debugPrint('[MyApp] Enterprise service initialization failed: $e');
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Show splash while enterprise services are loading
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: KlasivoSpacing.lg),
                Text(
                  'Loading Klasivo...',
                  style: KlasivoTypography.bodyMedium.copyWith(
                    color: KlasivoColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
    // Use Hive's built-in watch() instead of polling every 500ms
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

// ─── GoRouter Navigation Observer (Sentry breadcrumbs) ───────────────────────

/// Custom [NavigatorObserver] that logs route changes as Sentry breadcrumbs
/// for full navigation traceability in error reports.
class SentryNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('pop', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      KlasivoSentry.breadcrumb.navigation(
        newRoute.settings.name ?? newRoute.runtimeType.toString(),
        action: 'replace',
        data: {
          if (oldRoute?.settings.name != null)
            'from': oldRoute!.settings.name!,
        },
      );
    }
  }

  void _logNavigation(
    String action,
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    final name = route.settings.name ?? route.runtimeType.toString();
    KlasivoSentry.breadcrumb.navigation(name, action: action, data: {
      if (previousRoute?.settings.name != null)
        'from': previousRoute!.settings.name!,
    });
  }
}

// ─── GoRouter with Auth Guards & v1.7 Complete Navigation ─────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    observers: [SentryNavigationObserver()],
    // ── Navigation error builder — catches route errors and reports to Sentry ──
    errorBuilder: (context, state) {
      final error = state.error;
      if (error != null) {
        Sentry.captureException(
          error,
          withScope: (scope) {
            scope.setTag('source', 'go_router');
            scope.setTag('route', state.matchedLocation);
            scope.setExtra('uri', state.uri.toString());
          },
        );
        KlasivoSentry.breadcrumb.navigation(
          state.matchedLocation,
          action: 'error',
          data: {'error': error.toString()},
        );
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: KlasivoColors.error),
              const SizedBox(height: KlasivoSpacing.lg),
              Text(
                'Page not found',
                style: KlasivoTypography.headlineMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.sm),
              Text(
                'The page you are looking for does not exist.',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KlasivoSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
    redirect: (context, state) {
      final box = Hive.box(AppConstants.authBox);
      final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
      final userRole = box.get('userRole', defaultValue: '') as String;
      final hasCompletedSetup = box.get('hasCompletedSetup', defaultValue: false) as bool;
      final mustChangePassword = box.get('mustChangePassword', defaultValue: false) as bool;
      final isOnChangePassword = state.matchedLocation == '/change-password';

      // Force redirect to change password if required
      if (isLoggedIn && mustChangePassword && !isOnChangePassword) {
        return '/change-password';
      }
      // Prevent navigating away from change password if forced
      if (isLoggedIn && mustChangePassword && isOnChangePassword) {
        return null; // Allow staying on change password
      }
      // If no longer required, redirect away from change password
      if (isLoggedIn && !mustChangePassword && isOnChangePassword) {
        // Management roles → /dashboard; student → /student; parent → /parent
        if (KlasivoRole.managementRoles.contains(userRole)) return '/dashboard';
        if (userRole == KlasivoRole.student) return '/student';
        if (userRole == KlasivoRole.parent) return '/parent';
        return '/dashboard'; // Fallback for unknown roles
      }

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
          GoRoute(
            path: 'parent-login',
            builder: (context, state) => const ParentLoginScreen(),
          ),
          GoRoute(
            path: 'parent-register',
            builder: (context, state) => const ParentRegisterScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: 'owner-register',
            builder: (context, state) => const OwnerRegisterScreen(),
          ),
        ],
      ),

      // ─── Welcome / Org Naming ────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ─── Contact Us (public — no auth required) ─────────────────────
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactUsScreen(),
      ),

      // ─── Parent Link Screen ──────────────────────────────────────────
      GoRoute(
        path: '/auth/parent-link',
        builder: (context, state) => const ParentLinkScreen(),
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
                builder: (context, state) => const ConversationListScreen(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) {
                      final conversationId = state.pathParameters['conversationId']!;
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
                builder: (context, state) => const AnnouncementFormScreen(isEditing: false),
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
              GoRoute(
                path: 'feature-flags',
                builder: (context, state) => const FeatureFlagsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── LMS Routes (outside shell for full-screen content browser) ───
      GoRoute(
        path: '/lms/subject/:subjectId',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          final subjectName = state.uri.queryParameters['name'] ?? 'Subject';
          final classId = state.uri.queryParameters['classId'] ?? '';
          return SubjectContentScreen(
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
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final subjectId = extra['subjectId'] as String? ?? '';
          return LessonDetailScreen(
            lessonId: lessonId,
            subjectId: subjectId,
          );
        },
      ),
      GoRoute(
        path: '/lms/materials/:materialId',
        builder: (context, state) {
          final materialId = state.pathParameters['materialId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final subjectId = extra['subjectId'] as String?;
          return MaterialViewerScreen(
            materialId: materialId,
            subjectId: subjectId,
          );
        },
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

          // ─── Calendar ─────────────────────────────────────────────────
          GoRoute(
            path: 'calendar',
            builder: (context, state) => const CalendarScreen(),
          ),

          // ─── Academic Years ─────────────────────────────────────────────
          GoRoute(
            path: 'academic-years',
            builder: (context, state) => const AcademicYearListScreen(),
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

          // ─── Audit Log (Owners Only) ──────────────────────────────────
          GoRoute(
            path: 'audit-log',
            builder: (context, state) => const AuditLogScreen(),
          ),

          // ─── Moderation Queue ──────────────────────────────────────────
          GoRoute(
            path: 'moderation',
            builder: (context, state) => const ModerationQueueScreen(),
          ),

          // ─── Progress Tracking ───────────────────────────────────────
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

      // ─── Parent Shell Navigation ─────────────────────────────────────
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
          GoRoute(
            path: '/parent/assignments',
            builder: (context, state) => const ParentAssignmentsScreen(),
          ),
          GoRoute(
            path: '/parent/progress',
            builder: (context, state) => const ParentProgressScreen(),
          ),
          GoRoute(
            path: '/parent/announcements',
            builder: (context, state) => const ParentAnnouncementsScreen(),
          ),
        ],
      ),

      // ─── Student Settings Route ──────────────────────────────────────
      GoRoute(
        path: '/student/settings',
        builder: (context, state) => const StudentSettingsScreen(),
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



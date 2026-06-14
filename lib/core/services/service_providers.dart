// ══════════════════════════════════════════════════════════════════════════
// Klasivo — Central DI Provider Registry
//
// All service interfaces are registered here with their concrete
// implementations. Screens and features should import this file
// and depend on the interface providers, not concrete classes.
//
// In tests, override these providers with mocks:
//   container.override(authServiceProvider, MockAuthService())
// ══════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Interfaces (from abstractions layer)
import '../abstractions/auth_service.dart';
import '../abstractions/exam_security_service.dart';
import '../abstractions/connectivity_service.dart';

// Concrete implementations (same directory)
import 'auth_service.dart';
import 'exam_service.dart';
import 'exam_security_service.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';

// ─── Service Providers (Interface → Concrete Binding) ───────────────────

/// Authentication service — binds [IAuthService] to [AuthService].
///
/// Override in tests: `container.override(authServiceProvider, MockAuthService())`
final authServiceProvider = Provider<IAuthService>((ref) => AuthService());

/// Exam service — concrete provider (no interface yet).
///
/// Override in tests: `container.override(examServiceProvider, MockExamService())`
final examServiceProvider = Provider<ExamService>((ref) => ExamService());

/// Exam security service — binds [IExamSecurityService] to [ExamSecurityService].
///
/// Override in tests: `container.override(examSecurityServiceProvider, MockExamSecurityService())`
final examSecurityServiceProvider = Provider<IExamSecurityService>(
  (ref) => ExamSecurityService(),
);

/// Connectivity service — binds [IConnectivityService] to [ConnectivityService].
///
/// Override in tests: `container.override(connectivityServiceProvider, MockConnectivityService())`
final connectivityServiceProvider = Provider<IConnectivityService>(
  (ref) => ConnectivityService.instance,
);

/// Notification service — concrete provider (no interface yet).
///
/// Override in tests: `container.override(notificationServiceProvider, MockNotificationService())`
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

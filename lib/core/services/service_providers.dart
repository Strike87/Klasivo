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

// Interfaces
import 'interfaces/i_auth_service.dart';
import 'interfaces/i_exam_service.dart';
import 'interfaces/i_exam_security_service.dart';
import 'interfaces/i_connectivity_service.dart';
import 'interfaces/i_notification_service.dart';
import 'interfaces/i_offline_manager.dart';

// Concrete implementations
import '../auth_service.dart';
import '../exam_service.dart';
import '../exam_security_service.dart';
import '../connectivity_service.dart';
import '../notification_service.dart';
import '../offline_manager.dart';

// ─── Service Providers (Interface → Concrete Binding) ───────────────────

/// Authentication service — binds [IAuthService] to [AuthService].
///
/// Override in tests: `container.override(authServiceProvider, MockAuthService())`
final authServiceProvider = Provider<IAuthService>((ref) => AuthService());

/// Exam service — binds [IExamService] to [ExamService].
///
/// Override in tests: `container.override(examServiceProvider, MockExamService())`
final examServiceProvider = Provider<IExamService>((ref) => ExamService());

/// Exam security service — binds [IExamSecurityService] to [ExamSecurityService].
///
/// Uses singleton factory. Override in tests:
/// `container.override(examSecurityServiceProvider, MockExamSecurityService())`
final examSecurityServiceProvider = Provider<IExamSecurityService>(
  (ref) => ExamSecurityService(),
);

/// Connectivity service — binds [IConnectivityService] to [ConnectivityService].
///
/// Override in tests: `container.override(connectivityServiceProvider, MockConnectivityService())`
final connectivityServiceProvider = Provider<IConnectivityService>(
  (ref) => ConnectivityService.instance,
);

/// Notification service — binds [INotificationService] to [NotificationService].
///
/// Override in tests: `container.override(notificationServiceProvider, MockNotificationService())`
final notificationServiceProvider = Provider<INotificationService>(
  (ref) => NotificationService(),
);

/// Offline manager — binds [IOfflineManager] to [OfflineManager].
///
/// Override in tests: `container.override(offlineManagerProvider, MockOfflineManager())`
final offlineManagerProvider = Provider<IOfflineManager>(
  (ref) => OfflineManager.instance,
);

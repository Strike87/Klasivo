// ══════════════════════════════════════════════════════════════════════════
// Klasivo — Central DI Provider Registry
//
// Concrete service providers. NOTE: the canonical auth & connectivity
// providers live in lib/providers/auth_provider.dart and
// lib/providers/offline_provider.dart respectively — those are the ones
// imported throughout the app. The providers here are kept for legacy
// callers and bind to the concrete types directly (the abstract
// interfaces in lib/core/abstractions/ are out-of-sync with the
// concrete classes, so binding through them would require a refactor
// beyond the scope of this analyze-cleanup pass).
// ══════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Concrete implementations (same directory)
import 'auth_service.dart';
import 'exam_service.dart';
import 'exam_security_service.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';

// ─── Service Providers (Concrete Bindings) ──────────────────────────────

/// Authentication service — concrete binding.
///
/// Note: most callers import `authServiceProvider` from
/// `lib/providers/auth_provider.dart` instead. This one is kept for
/// legacy imports.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Exam service — concrete provider.
final examServiceProvider = Provider<ExamService>((ref) => ExamService());

/// Exam security service — concrete binding.
final examSecurityServiceProvider = Provider<ExamSecurityService>(
  (ref) => ExamSecurityService(),
);

/// Connectivity service — concrete binding.
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService.instance,
);

/// Notification service — concrete provider.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

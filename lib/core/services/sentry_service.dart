// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Centralized Sentry Observability Service
//
// Production-grade observability layer providing:
//   - Standardized breadcrumbs (auth, registration, firestore, cloud_function,
//     navigation, livekit)
//   - Firestore operation wrappers with automatic error tagging
//   - Guarded async operation runner (runGuarded)
//   - User context management
//   - Transaction / span helpers
//   - Security sanitization (never sends passwords, tokens, OTPs, invite codes)
//   - Doc ID audit trail for all user creation paths
//
// Usage:
//   import 'package:klasivo/core/services/sentry_service.dart';
//   await KlasivoSentry.breadcrumb.auth('login_started');
//   await KlasivoSentry.runGuarded('create_exam', () => examService.create(...));
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Sensitive Field Sanitization ─────────────────────────────────────────────

/// Keys that must NEVER be sent to Sentry in any breadcrumb, tag, or extra.
/// Covers passwords, tokens, OTP codes, invite codes, and secrets.
class _SensitiveFields {
  static const Set<String> keys = {
    'password',
    'passwordHash',
    'confirmPassword',
    'newPassword',
    'accessToken',
    'refreshToken',
    'idToken',
    'otp',
    'otpCode',
    'inviteCode',
    'secret',
    'apiKey',
    'authEmail', // Internal student auth email — PII
    'studentCode', // Sensitive — could be used to log in
  };

  /// Returns true if the key contains any sensitive substring.
  static bool isSensitive(String key) {
    final lower = key.toLowerCase();
    for (final s in keys) {
      if (lower.contains(s.toLowerCase())) return true;
    }
    return false;
  }

  /// Sanitize a map — replace sensitive values with '[REDACTED]'.
  static Map<String, dynamic> sanitize(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (isSensitive(key)) {
        return MapEntry(key, '[REDACTED]');
      }
      // Recursively sanitize nested maps
      if (value is Map<String, dynamic>) {
        return MapEntry(key, sanitize(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Sanitize a string by removing patterns that look like tokens/secrets.
  static String sanitizeString(String input) {
    // Redact Bearer tokens
    var result = input.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
      'Bearer [REDACTED]',
    );
    // Redact long hex strings (likely tokens)
    result = result.replaceAll(
      RegExp(r'\b[A-Fa-f0-9]{32,}\b'),
      '[REDACTED_TOKEN]',
    );
    return result;
  }
}

// ─── Breadcrumb Categories ────────────────────────────────────────────────────

/// Standardized breadcrumb categories for consistent filtering in Sentry.
class SentryCategories {
  static const String auth = 'auth';
  static const String registration = 'registration';
  static const String firestore = 'firestore';
  static const String cloudFunction = 'cloud_function';
  static const String navigation = 'navigation';
  static const String livekit = 'livekit';
  static const String hive = 'hive';
  static const String riverpod = 'riverpod';
  static const String sync = 'sync';
  static const String notification = 'notification';
}

// ─── Breadcrumb Builder ──────────────────────────────────────────────────────

/// Fluent API for creating standardized Sentry breadcrumbs.
///
/// Example:
///   KlasivoSentry.breadcrumb.auth('login_started', data: {'email': email});
///   KlasivoSentry.breadcrumb.firestore('create', collection: 'users', docId: uid);
class SentryBreadcrumbBuilder {
  /// Auth breadcrumb (login, logout, signup, password reset)
  void auth(String message, {Map<String, dynamic>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.auth,
      message: message,
      data: data != null ? _SensitiveFields.sanitize(data) : null,
      level: SentryLevel.info,
    ));
  }

  /// Registration breadcrumb (account creation steps)
  void registration(String message, {Map<String, dynamic>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.registration,
      message: message,
      data: data != null ? _SensitiveFields.sanitize(data) : null,
      level: SentryLevel.info,
    ));
  }

  /// Firestore breadcrumb (create, update, delete, read)
  void firestore(
    String operation, {
    required String collection,
    String? docId,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.firestore,
      message: '$operation $collection${docId != null ? '/$docId' : ''}',
      data: _SensitiveFields.sanitize({
        'collection': collection,
        'operation': operation,
        if (docId != null) 'documentId': docId,
        ...?data,
      }),
      level: SentryLevel.info,
    ));
  }

  /// Cloud Function breadcrumb (callable invoked/succeeded/failed)
  void cloudFunction(
    String functionName, {
    required String status, // 'invoked', 'succeeded', 'failed'
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.cloudFunction,
      message: '$functionName $status',
      data: _SensitiveFields.sanitize({
        'function': functionName,
        'status': status,
        ...?data,
      }),
      level: status == 'failed' ? SentryLevel.error : SentryLevel.info,
    ));
  }

  /// Navigation breadcrumb (route entered/exited)
  void navigation(
    String route, {
    String action = 'entered',
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.navigation,
      message: '$action $route',
      data: {
        'route': route,
        'action': action,
        ...?data,
      },
      level: SentryLevel.info,
    ));
  }

  /// LiveKit breadcrumb (room joined/left, token generated/failed)
  void livekit(
    String message, {
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.livekit,
      message: message,
      data: data != null ? _SensitiveFields.sanitize(data) : null,
      level: SentryLevel.info,
    ));
  }

  /// Hive local storage breadcrumb
  void hive(
    String message, {
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.hive,
      message: message,
      data: data,
      level: SentryLevel.info,
    ));
  }

  /// Riverpod provider breadcrumb
  void riverpod(
    String message, {
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.riverpod,
      message: message,
      data: data,
      level: SentryLevel.info,
    ));
  }

  /// Sync operation breadcrumb
  void sync(
    String message, {
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.sync,
      message: message,
      data: data,
      level: SentryLevel.info,
    ));
  }

  /// Notification breadcrumb
  void notification(
    String message, {
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: SentryCategories.notification,
      message: message,
      data: data,
      level: SentryLevel.info,
    ));
  }
}

// ─── Firestore Observability Helper ──────────────────────────────────────────

/// Wraps Firestore operations with automatic Sentry breadcrumbs, exception
/// capture, and scope tags for every critical write.
///
/// Every Firestore exception will:
///   1. Reach Sentry
///   2. Include collection name
///   3. Include document id
///   4. Include user role
///   5. Include organization id
class SentryFirestoreHelper {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Wrapped `.set()` with full observability.
  static Future<void> docSet({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    String? flow,
    String? step,
    SetOptions? options,
  }) async {
    final sanitizedData = _SensitiveFields.sanitize(data);
    KlasivoSentry.breadcrumb.firestore(
      'create',
      collection: collection,
      docId: docId,
      data: {'flow': flow, 'step': step},
    );

    try {
      await _db.collection(collection).doc(docId).set(data, options);
      KlasivoSentry.breadcrumb.firestore(
        'create_success',
        collection: collection,
        docId: docId,
      );
    } catch (e, st) {
      await _captureFirestoreException(
        e,
        st,
        collection: collection,
        operation: 'set',
        docId: docId,
        flow: flow,
        step: step,
        dataPreview: sanitizedData,
      );
      rethrow;
    }
  }

  /// Wrapped `.update()` with full observability.
  static Future<void> docUpdate({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    String? flow,
    String? step,
  }) async {
    final sanitizedData = _SensitiveFields.sanitize(data);
    KlasivoSentry.breadcrumb.firestore(
      'update',
      collection: collection,
      docId: docId,
      data: {'flow': flow, 'step': step},
    );

    try {
      await _db.collection(collection).doc(docId).update(data);
      KlasivoSentry.breadcrumb.firestore(
        'update_success',
        collection: collection,
        docId: docId,
      );
    } catch (e, st) {
      await _captureFirestoreException(
        e,
        st,
        collection: collection,
        operation: 'update',
        docId: docId,
        flow: flow,
        step: step,
        dataPreview: sanitizedData,
      );
      rethrow;
    }
  }

  /// Wrapped `.delete()` with full observability.
  static Future<void> docDelete({
    required String collection,
    required String docId,
    String? flow,
    String? step,
  }) async {
    KlasivoSentry.breadcrumb.firestore(
      'delete',
      collection: collection,
      docId: docId,
      data: {'flow': flow, 'step': step},
    );

    try {
      await _db.collection(collection).doc(docId).delete();
      KlasivoSentry.breadcrumb.firestore(
        'delete_success',
        collection: collection,
        docId: docId,
      );
    } catch (e, st) {
      await _captureFirestoreException(
        e,
        st,
        collection: collection,
        operation: 'delete',
        docId: docId,
        flow: flow,
        step: step,
      );
      rethrow;
    }
  }

  /// Wrapped batch commit with full observability.
  static Future<void> batchCommit({
    required WriteBatch batch,
    required String collection,
    required int operationCount,
    String? flow,
    String? step,
  }) async {
    KlasivoSentry.breadcrumb.firestore(
      'batch_commit',
      collection: collection,
      data: {'operationCount': operationCount, 'flow': flow, 'step': step},
    );

    try {
      await batch.commit();
      KlasivoSentry.breadcrumb.firestore(
        'batch_commit_success',
        collection: collection,
        data: {'operationCount': operationCount},
      );
    } catch (e, st) {
      await _captureFirestoreException(
        e,
        st,
        collection: collection,
        operation: 'batch_commit',
        flow: flow,
        step: step,
        dataPreview: {'operationCount': operationCount},
      );
      rethrow;
    }
  }

  /// Wrapped Firestore transaction with full observability.
  static Future<T> runTransaction<T>({
    required String collection,
    required Future<T> Function(Transaction tx) handler,
    String? flow,
    String? step,
    int maxAttempts = 5,
  }) async {
    KlasivoSentry.breadcrumb.firestore(
      'transaction_start',
      collection: collection,
      data: {'flow': flow, 'step': step},
    );

    try {
      final result = await _db.runTransaction<T>(
        handler,
        maxAttempts: maxAttempts,
      );
      KlasivoSentry.breadcrumb.firestore(
        'transaction_success',
        collection: collection,
      );
      return result;
    } catch (e, st) {
      await _captureFirestoreException(
        e,
        st,
        collection: collection,
        operation: 'transaction',
        flow: flow,
        step: step,
      );
      rethrow;
    }
  }

  /// Capture a Firestore exception with full context tags.
  static Future<void> _captureFirestoreException(
    Object exception,
    StackTrace stackTrace, {
    required String collection,
    required String operation,
    String? docId,
    String? flow,
    String? step,
    Map<String, dynamic>? dataPreview,
  }) async {
    // Determine if this is a permission-denied error
    String? errorCode;
    if (exception is FirebaseException) {
      errorCode = exception.code;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('collection', collection);
        scope.setTag('operation', operation);
        if (docId != null) scope.setTag('documentId', docId);
        if (flow != null) scope.setTag('flow', flow);
        if (step != null) scope.setTag('step', step);
        if (errorCode != null) scope.setTag('firebase_code', errorCode);

        // Attach user role and org from current Sentry context
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          scope.setTag('auth_uid', currentUser.uid);
        }

        if (dataPreview != null && dataPreview.isNotEmpty) {
          scope.setExtra('data_preview', dataPreview);
        }
      },
    );
  }
}

// ─── Guarded Async Operation ─────────────────────────────────────────────────

/// Runs an async operation with automatic Sentry breadcrumb, exception capture,
/// and metadata attachment. This is the recommended way to wrap any async
/// operation that should never fail silently.
///
/// Example:
///   final result = await KlasivoSentry.runGuarded(
///     'create_exam',
///     () => examService.createExam(...),
///     category: 'firestore',
///   );
class KlasivoSentryGuard {
  /// Execute [operation] inside a Sentry-guarded wrapper.
  ///
  /// - Automatically adds a breadcrumb before execution.
  /// - On success: adds a success breadcrumb.
  /// - On failure: captures the exception with scope tags and rethrows.
  /// - The [category] defaults to the operation name but can be overridden.
  /// - Additional [tags] and [data] are attached to both the breadcrumb
  ///   and the exception scope.
  static Future<T> runGuarded<T>(
    String operationName,
    Future<T> Function() operation, {
    String? category,
    Map<String, String>? tags,
    Map<String, dynamic>? data,
  }) async {
    final cat = category ?? 'operation';

    Sentry.addBreadcrumb(Breadcrumb(
      category: cat,
      message: '${operationName}_started',
      data: data != null ? _SensitiveFields.sanitize(data) : null,
      level: SentryLevel.info,
    ));

    try {
      final result = await operation();

      Sentry.addBreadcrumb(Breadcrumb(
        category: cat,
        message: '${operationName}_success',
        data: data != null ? _SensitiveFields.sanitize(data) : null,
        level: SentryLevel.info,
      ));

      return result;
    } catch (e, st) {
      Sentry.addBreadcrumb(Breadcrumb(
        category: cat,
        message: '${operationName}_failed',
        data: _SensitiveFields.sanitize({
          'error': e.toString().substring(0, (e.toString().length).clamp(0, 200)),
          ...?data,
        }),
        level: SentryLevel.error,
      ));

      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('operation', operationName);
          tags?.forEach(scope.setTag);
          if (data != null) {
            scope.setExtra('operation_data', _SensitiveFields.sanitize(data));
          }
        },
      );

      rethrow;
    }
  }

  /// Execute [operation] with a Sentry transaction span.
  ///
  /// Creates a child span under the given [transaction], measures duration,
  /// and sets the span status based on success/failure.
  static Future<T> runWithSpan<T>(
    ISentrySpan transaction,
    String spanName,
    Future<T> Function() operation, {
    Map<String, String>? tags,
  }) async {
    final span = transaction.startChild(spanName);

    try {
      final result = await operation();
      span.status = const SpanStatus.ok();
      return result;
    } catch (e, st) {
      span.status = const SpanStatus.internalError();

      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('span', spanName);
          tags?.forEach(scope.setTag);
        },
      );

      rethrow;
    } finally {
      await span.finish();
    }
  }
}

// ─── User Context Management ─────────────────────────────────────────────────

/// Manages Sentry user context — attached on sign-in, updated on role/org
/// changes, cleared on logout.
///
/// Attaches:
///   - uid
///   - email
///   - role (tag)
///   - organizationId (tag)
///   - app version (tag — set once at init)
///   - build number (tag — set once at init)
class SentryUserContext {
  /// Set user context after authentication.
  static Future<void> setUser({
    required String uid,
    required String email,
    String? role,
    String? organizationId,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: uid,
        email: email,
      ));
      if (role != null) {
        scope.setTag('role', role);
      }
      if (organizationId != null && organizationId.isNotEmpty) {
        scope.setTag('organizationId', organizationId);
      }
    });
  }

  /// Update role tag (e.g. after role assignment).
  static Future<void> setRole(String role) async {
    await Sentry.configureScope((scope) {
      scope.setTag('role', role);
    });
  }

  /// Update organization ID tag (e.g. after joining org or linking child).
  static Future<void> setOrganizationId(String orgId) async {
    await Sentry.configureScope((scope) {
      scope.setTag('organizationId', orgId);
    });
  }

  /// Set app version and build number tags (called once at init).
  static Future<void> setAppVersion({
    required String version,
    required String buildNumber,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setTag('app_version', version);
      scope.setTag('build_number', buildNumber);
    });
  }

  /// Clear user context on logout.
  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
      scope.removeTag('role');
      scope.removeTag('organizationId');
    });
  }
}

// ─── Transaction Helpers ──────────────────────────────────────────────────────

/// Factory methods for common Sentry transactions.
class SentryTransactions {
  // Registration flows
  static ISentrySpan ownerRegistration() =>
      Sentry.startTransaction('owner_registration', 'registration');
  static ISentrySpan teacherRegistration() =>
      Sentry.startTransaction('teacher_registration', 'registration');
  static ISentrySpan parentRegistration() =>
      Sentry.startTransaction('parent_registration', 'registration');
  static ISentrySpan studentEnrollment() =>
      Sentry.startTransaction('student_enrollment', 'registration');

  // Auth flows
  static ISentrySpan loginFlow(String role) =>
      Sentry.startTransaction('${role}_login', 'auth');
  static ISentrySpan logoutFlow(String role) =>
      Sentry.startTransaction('${role}_logout', 'auth');
  static ISentrySpan passwordReset() =>
      Sentry.startTransaction('password_reset', 'auth');

  // Google Sign-In
  static ISentrySpan googleSignIn(String role, {bool isNewUser = false}) =>
      Sentry.startTransaction(
        '${role}_google_${isNewUser ? 'registration' : 'login'}',
        'auth',
      );

  // LiveKit
  static ISentrySpan liveKitTokenGeneration() =>
      Sentry.startTransaction('livekit_token_generation', 'livekit');
  static ISentrySpan liveKitRoomJoin() =>
      Sentry.startTransaction('livekit_room_join', 'livekit');

  // Dashboard
  static ISentrySpan dashboardLoad(String role) =>
      Sentry.startTransaction('${role}_dashboard_load', 'ui');
}

// ─── Doc ID Audit Trail ──────────────────────────────────────────────────────

/// Documents the doc ID strategy for every user creation path.
/// This is critical for the ongoing investigation into missing users/{uid} docs.
///
/// | Path                  | Collection | Doc ID     | Status    |
/// |-----------------------|-----------|------------|-----------|
/// | Owner (email)         | users     | user.uid   | OK        |
/// | Owner (Google)        | users     | user.uid   | OK        |
/// | Teacher (invite)      | users     | user.uid   | OK        |
/// | Teacher (Google)      | users     | user.uid   | OK        |
/// | Parent (email)        | users     | user.uid   | OK        |
/// | Parent (Google)       | users     | user.uid   | OK        |
/// | Student (QR enroll)   | users     | auto-id    | BROKEN    |
/// | Student (Excel import)| users     | ?          | UNKNOWN   |
/// | onUserCreated trigger | users     | READ ONLY  | N/A       |
///
/// The QR enrollment path uses `.doc()` (auto-generated ID) instead of
/// `.doc(user.uid)`, which means:
///   1. The doc ID doesn't match the auth UID
///   2. Security rule `request.auth.uid == userId` ALWAYS FAILS
///   3. QR enrollment is 100% broken in production
class SentryDocIdAudit {
  /// Log a doc ID audit breadcrumb for any user creation path.
  static void logUserCreation({
    required String flow,
    required String collection,
    required String docIdStrategy, // 'uid' or 'auto_id'
    required String actualDocId,
    String? authUid,
  }) {
    final isMismatch = authUid != null && docIdStrategy == 'uid' && actualDocId != authUid;
    final isAutoId = docIdStrategy == 'auto_id';

    Sentry.addBreadcrumb(Breadcrumb(
      category: 'doc_id_audit',
      message: 'user_doc_created',
      data: _SensitiveFields.sanitize({
        'flow': flow,
        'collection': collection,
        'docIdStrategy': docIdStrategy,
        'actualDocId': actualDocId,
        if (authUid != null) 'authUid': authUid,
        'idMismatch': isMismatch,
        'autoIdUsed': isAutoId,
        'brokenByRules': isAutoId, // auto-id always fails security rules
      }),
      level: (isMismatch || isAutoId) ? SentryLevel.warning : SentryLevel.info,
    ));

    if (isMismatch || isAutoId) {
      Sentry.captureMessage(
        'Doc ID audit: $flow uses ${isAutoId ? 'auto-id' : 'mismatched uid'} '
        '(docId=$actualDocId, authUid=$authUid). '
        'This path is ${isAutoId ? "blocked by security rules" : "potentially broken"}.',
        level: SentryLevel.warning,
      );
    }
  }
}

// ─── Main Facade ──────────────────────────────────────────────────────────────

/// Top-level entry point for all Sentry observability in Klasivo.
///
/// Usage:
///   KlasivoSentry.breadcrumb.auth('login_started');
///   KlasivoSentry.firestore.docSet(collection: 'users', docId: uid, data: {...});
///   KlasivoSentry.runGuarded('create_exam', () => ...);
///   KlasivoSentry.userContext.setUser(uid: uid, email: email, role: 'owner');
class KlasivoSentry {
  KlasivoSentry._();

  /// Breadcrumb builder — use for all breadcrumb creation.
  static final breadcrumb = SentryBreadcrumbBuilder();

  /// Firestore operation helper — use for all critical Firestore writes.
  static final firestore = SentryFirestoreHelper();

  /// Guarded operation runner — use to wrap any async operation.
  static final guard = KlasivoSentryGuard();

  /// User context manager — use on sign-in, role change, org change, logout.
  static final userContext = SentryUserContext();

  /// Transaction factory — use to start named transactions for flows.
  static final transactions = SentryTransactions();

  /// Doc ID audit — use when creating any user document.
  static final docIdAudit = SentryDocIdAudit();

  /// Convenience method for runGuarded.
  static Future<T> runGuarded<T>(
    String operationName,
    Future<T> Function() operation, {
    String? category,
    Map<String, String>? tags,
    Map<String, dynamic>? data,
  }) {
    return KlasivoSentryGuard.runGuarded(
      operationName,
      operation,
      category: category,
      tags: tags,
      data: data,
    );
  }

  /// Capture an exception with optional scope tags.
  static Future<SentryId> captureException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, String>? tags,
    Map<String, dynamic>? extras,
  }) {
    return Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        tags?.forEach(scope.setTag);
        extras?.forEach((key, value) {
          scope.setExtra(key, _SensitiveFields.isSensitive(key) ? '[REDACTED]' : value);
        });
      },
    );
  }

  /// Capture a message with level.
  static Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
  }) {
    return Sentry.captureMessage(
      message,
      level: level,
    );
  }

  /// Check if Sentry is currently enabled (DSN was provided).
  static bool get isEnabled {
    final dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    return dsn.isNotEmpty;
  }
}

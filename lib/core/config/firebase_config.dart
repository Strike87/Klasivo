import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'app_environment.dart';
import '../../firebase_options.dart';

/// Environment-aware Firebase configuration for Klasivo.
///
/// Provides the correct [FirebaseOptions] for each environment and
/// configures Firestore, Auth, and Crashlytics with environment-specific
/// settings after Firebase has been initialised.
class FirebaseConfig {
  // ────────────────────────────────────────────────────────────────────────────
  // FirebaseOptions resolution
  // ────────────────────────────────────────────────────────────────────────────

  /// Returns the [FirebaseOptions] appropriate for [environment].
  ///
  /// Resolution order:
  /// 1. Dart-define overrides for individual Firebase fields
  ///    (e.g. `--dart-define=firebaseApiKey=...`).
  /// 2. Per-environment hardcoded options (currently all map to the same
  ///    FlutterFire-generated config; replace the body of each case when
  ///    separate Firebase projects are created for dev/staging).
  /// 3. Fallback: [DefaultFirebaseOptions.currentPlatform].
  static FirebaseOptions getOptions(AppEnvironment environment) {
    // Check for dart-define overrides first — they win over everything.
    final override = _buildFromDartDefines();
    if (override != null) return override;

    switch (environment) {
      case AppEnvironment.dev:
        // TODO: Replace with dev Firebase project options when available.
        return DefaultFirebaseOptions.currentPlatform;
      case AppEnvironment.staging:
        // TODO: Replace with staging Firebase project options when available.
        return DefaultFirebaseOptions.currentPlatform;
      case AppEnvironment.prod:
        return DefaultFirebaseOptions.currentPlatform;
    }
  }

  /// Attempts to construct [FirebaseOptions] entirely from dart-define values.
  /// Returns `null` if the mandatory fields are not present.
  static FirebaseOptions? _buildFromDartDefines() {
    const apiKey = String.fromEnvironment('firebaseApiKey', defaultValue: '');
    const appId = String.fromEnvironment('firebaseAppId', defaultValue: '');
    const messagingSenderId = String.fromEnvironment(
      'firebaseMessagingSenderId',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment(
      'firebaseProjectId',
      defaultValue: '',
    );

    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) {
      return null; // Not all mandatory defines present → skip override.
    }

    const storageBucket = String.fromEnvironment(
      'firebaseStorageBucket',
      defaultValue: '',
    );

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Firestore configuration
  // ────────────────────────────────────────────────────────────────────────────

  /// Applies environment-specific Firestore settings.
  ///
  /// Must be called **after** `Firebase.initializeApp()`.
  static void configureFirestore() {
    final config = EnvironmentConfig.current;
    final db = FirebaseFirestore.instance;

    final settings = Settings(
      persistenceEnabled: config.firestorePersistenceEnabled,
      cacheSizeBytes: config.firestoreCacheSizeMB * 1024 * 1024,
      sslEnabled: true,
      ignoreUndefinedProperties: config.isDev,
    );

    db.settings = settings;

    debugPrint('[FirebaseConfig] Firestore configured: '
        'persistence=${settings.persistenceEnabled}, '
        'cacheSize=${config.firestoreCacheSizeMB}MB, '
        'ignoreUndefined=${settings.ignoreUndefinedProperties}');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Auth configuration
  // ────────────────────────────────────────────────────────────────────────────

  /// Applies environment-specific Firebase Auth settings.
  ///
  /// Must be called **after** `Firebase.initializeApp()`.
  static void configureAuth() {
    final config = EnvironmentConfig.current;
    final auth = FirebaseAuth.instance;

    // In dev mode, bypass app verification for phone auth testing.
    if (config.isDev) {
      auth.setSettings(
        appVerificationDisabledForTesting: true,
        phoneNumber: null,
        smsCode: null,
      );
    } else {
      // Staging & prod: normal verification, with forced reset on staging
      // to avoid cached verification states between QA runs.
      auth.setSettings(
        appVerificationDisabledForTesting: false,
        phoneNumber: null,
        smsCode: null,
      );
    }

    debugPrint('[FirebaseConfig] Auth configured: '
        'appVerificationDisabled=${config.isDev}');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Crashlytics configuration
  // ────────────────────────────────────────────────────────────────────────────

  /// Enables or disables Crashlytics data collection based on environment.
  ///
  /// Must be called **after** `Firebase.initializeApp()`.
  static Future<void> configureCrashlytics() async {
    final config = EnvironmentConfig.current;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      config.crashlyticsEnabled,
    );

    debugPrint('[FirebaseConfig] Crashlytics configured: '
        'enabled=${config.crashlyticsEnabled}');
  }
}

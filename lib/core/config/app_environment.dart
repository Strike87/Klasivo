import 'package:flutter/foundation.dart';

/// Represents the deployment environment for the Klasivo app.
enum AppEnvironment {
  dev,
  staging,
  prod,
}

/// Centralised environment configuration for the Klasivo app.
///
/// The active environment is resolved once at startup from (in order):
/// 1. `--dart-define=environment=<value>` (dev | staging | prod)
/// 2. Fallback: `kDebugMode` → dev, `kReleaseMode` → prod
///
/// Access the current config via [EnvironmentConfig.current].
class EnvironmentConfig {
  // ────────────────────────────────────────────────────────────────────────────
  // Singleton-style access
  // ────────────────────────────────────────────────────────────────────────────

  static EnvironmentConfig get current => _instance;
  static EnvironmentConfig _instance = EnvironmentConfig._resolve();

  /// Allows tests or manual overrides to replace the current config.
  static void setOverride(EnvironmentConfig config) => _instance = config;

  /// Reset to the automatically resolved config (useful after tests).
  static void reset() => _instance = EnvironmentConfig._resolve();

  // ────────────────────────────────────────────────────────────────────────────
  // Instance fields
  // ────────────────────────────────────────────────────────────────────────────

  final AppEnvironment environment;

  const EnvironmentConfig._({required this.environment});

  // ────────────────────────────────────────────────────────────────────────────
  // Resolution logic
  // ────────────────────────────────────────────────────────────────────────────

  factory EnvironmentConfig._resolve() {
    const String envStr = String.fromEnvironment(
      'environment',
      defaultValue: '',
    );

    AppEnvironment env;
    switch (envStr.toLowerCase()) {
      case 'dev':
      case 'development':
        env = AppEnvironment.dev;
        break;
      case 'staging':
        env = AppEnvironment.staging;
        break;
      case 'prod':
      case 'production':
        env = AppEnvironment.prod;
        break;
      default:
        // Fallback: infer from build mode
        if (kDebugMode) {
          env = AppEnvironment.dev;
        } else if (kReleaseMode) {
          env = AppEnvironment.prod;
        } else {
          env = AppEnvironment.dev; // profile mode defaults to dev
        }
    }

    return EnvironmentConfig._(environment: env);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Convenience booleans
  // ────────────────────────────────────────────────────────────────────────────

  bool get isDev => environment == AppEnvironment.dev;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isProd => environment == AppEnvironment.prod;

  // ────────────────────────────────────────────────────────────────────────────
  // App identity
  // ────────────────────────────────────────────────────────────────────────────

  /// Display name varies per environment to make it obvious which build is running.
  String get appName {
    switch (environment) {
      case AppEnvironment.dev:
        return 'Klasivo Dev';
      case AppEnvironment.staging:
        return 'Klasivo Staging';
      case AppEnvironment.prod:
        return 'Klasivo';
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // API / Network
  // ────────────────────────────────────────────────────────────────────────────

  /// Base URL for the Klasivo REST API.
  String get apiBaseUrl {
    switch (environment) {
      case AppEnvironment.dev:
        return 'https://api-dev.klasivo.app/v1';
      case AppEnvironment.staging:
        return 'https://api-staging.klasivo.app/v1';
      case AppEnvironment.prod:
        return 'https://api.klasivo.app/v1';
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Firebase / Crashlytics / Analytics toggles
  // ────────────────────────────────────────────────────────────────────────────

  /// Crashlytics should be disabled in dev to avoid polluting the dashboard
  /// with debug crashes.
  bool get crashlyticsEnabled {
    switch (environment) {
      case AppEnvironment.dev:
        return false;
      case AppEnvironment.staging:
      case AppEnvironment.prod:
        return true;
    }
  }

  /// Analytics should be disabled in dev to keep metrics clean.
  bool get analyticsEnabled {
    switch (environment) {
      case AppEnvironment.dev:
        return false;
      case AppEnvironment.staging:
      case AppEnvironment.prod:
        return true;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Firestore
  // ────────────────────────────────────────────────────────────────────────────

  /// Offline persistence is useful in all environments.
  bool get firestorePersistenceEnabled => true;

  /// Cache size in megabytes — smaller in dev to save disk, larger in prod
  /// for a smoother offline experience.
  int get firestoreCacheSizeMB {
    switch (environment) {
      case AppEnvironment.dev:
        return 10;
      case AppEnvironment.staging:
        return 50;
      case AppEnvironment.prod:
        return 100;
    }
  }

  /// Prefix prepended to Firestore collection names in non-prod environments
  /// so that test data never mixes with production data.
  String get databasePrefix {
    switch (environment) {
      case AppEnvironment.dev:
        return 'dev_';
      case AppEnvironment.staging:
        return 'staging_';
      case AppEnvironment.prod:
        return '';
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Logging
  // ────────────────────────────────────────────────────────────────────────────

  /// Controls the verbosity of application-level logging.
  LogLevel get logLevel {
    switch (environment) {
      case AppEnvironment.dev:
        return LogLevel.verbose;
      case AppEnvironment.staging:
        return LogLevel.normal;
      case AppEnvironment.prod:
        return LogLevel.minimal;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Feature flags
  // ────────────────────────────────────────────────────────────────────────────

  /// When true, feature flags default to enabled so developers see everything
  /// without having to flip each flag manually.
  bool get featureFlagDefaultsEnabled {
    switch (environment) {
      case AppEnvironment.dev:
        return true;
      case AppEnvironment.staging:
      case AppEnvironment.prod:
        return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Debugging
  // ────────────────────────────────────────────────────────────────────────────

  @override
  String toString() {
    return 'EnvironmentConfig('
        'environment: ${environment.name}, '
        'appName: $appName, '
        'apiBaseUrl: $apiBaseUrl, '
        'crashlyticsEnabled: $crashlyticsEnabled, '
        'analyticsEnabled: $analyticsEnabled, '
        'firestoreCacheSizeMB: $firestoreCacheSizeMB, '
        'databasePrefix: "$databasePrefix", '
        'logLevel: ${logLevel.name}, '
        'featureFlagDefaultsEnabled: $featureFlagDefaultsEnabled'
        ')';
  }
}

/// Verbosity levels for application-level logging.
enum LogLevel {
  verbose,
  normal,
  minimal,
}

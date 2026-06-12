import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ENVIRONMENT PROVIDERS
// Riverpod integration for environment configuration.
// ═══════════════════════════════════════════════════════════════════════════════

/// Provides the current [EnvironmentConfig] singleton.
///
/// ```dart
/// final config = ref.watch(environmentProvider);
/// print(config.appName); // "Klasivo Dev"
/// ```
final environmentProvider = Provider<EnvironmentConfig>((ref) {
  return EnvironmentConfig.current;
});

/// Provides the current environment name as a lowercase string.
///
/// ```dart
/// final name = ref.watch(environmentNameProvider); // "dev" | "staging" | "prod"
/// ```
final environmentNameProvider = Provider<String>((ref) {
  final config = ref.watch(environmentProvider);
  return config.environment.name;
});

/// Convenience provider that is `true` when the app is running in the
/// **dev** environment.
///
/// ```dart
/// if (ref.watch(isDevEnvironmentProvider)) { /* dev-only logic */ }
/// ```
final isDevEnvironmentProvider = Provider<bool>((ref) {
  final config = ref.watch(environmentProvider);
  return config.isDev;
});

/// Provides whether Firebase Crashlytics is active for the current environment.
///
/// ```dart
/// if (ref.watch(crashlyticsEnabledProvider)) {
///   FirebaseCrashlytics.instance.recordError(error, stack);
/// }
/// ```
final crashlyticsEnabledProvider = Provider<bool>((ref) {
  final config = ref.watch(environmentProvider);
  return config.crashlyticsEnabled;
});

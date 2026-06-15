/// Klasivo v2.0 - Firebase configuration (v2 location)
/// 
/// Firebase initialization and configuration for Klasivo.
/// Enhanced to support multi-tenant Firestore paths and
/// environment-specific configuration.
library;

/// Firebase configuration for the Klasivo app.
class FirebaseConfig {
  static const String projectId = String.fromEnvironment(
    "FIREBASE_PROJECT_ID",
    defaultValue: "klasivo-app",
  );

  static const bool useEmulator = bool.fromEnvironment(
    "USE_FIREBASE_EMULATOR",
    defaultValue: false,
  );

  static Map<String, dynamic> get firestoreSettings => {
        "persistenceEnabled": true,
        "cacheSizeBytes": 100 * 1024 * 1024,
        if (useEmulator) "host": "localhost:8080",
        if (useEmulator) "sslEnabled": false,
      };
}

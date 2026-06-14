// ─── Abstraction Providers — Riverpod Generator ───────────────────────────────
//
// Wires up all abstract service interfaces to their production implementations.
// Import this file (or the generated .g.dart) to access service instances via Riverpod.
//
// All providers are keepAlive so that singleton services are not repeatedly
// recreated as widgets subscribe and unsubscribe.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../abstractions/abstractions.dart';
import '../abstractions/implementations/implementations.dart';

part 'abstraction_providers.g.dart';

// ─── Exam Security Service ────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
IExamSecurityService examSecurityService(ExamSecurityServiceRef ref) {
  return const NativeExamSecurityService();
}

// ─── Auth Service ─────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
IAuthService authService(AuthServiceRef ref) {
  return FirebaseAuthService();
}

// ─── Firebase / Firestore Service ─────────────────────────────────────────────

@Riverpod(keepAlive: true)
IFirebaseService firebaseService(FirebaseServiceRef ref) {
  return const FirestoreService();
}

// ─── Connectivity Service ─────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
IConnectivityService connectivityService(ConnectivityServiceRef ref) {
  return ConnectivityServiceImpl();
}

// ─── Sync Service ─────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
ISyncService syncService(SyncServiceRef ref) {
  return HiveSyncService();
}

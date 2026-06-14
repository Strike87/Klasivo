import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/interfaces/i_auth_service.dart';

// ══════════════════════════════════════════════════════════════════════════
// Service & Repository Providers
// ══════════════════════════════════════════════════════════════════════════

/// Production [IAuthService] implementation
final authServiceProvider = Provider<IAuthService>((ref) => AuthService());

/// [AuthRepository] provider — converts raw service responses into domain models
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});

// ══════════════════════════════════════════════════════════════════════════
// Auth State — Reactive FirebaseAuth + Firestore + Hive
// ══════════════════════════════════════════════════════════════════════════

/// Reactive stream of FirebaseAuth auth state changes.
/// Emits null when signed out, or the Firebase User when signed in.
final firebaseAuthProvider = StreamProvider<firebase_auth.User?>((ref) {
  return firebase_auth.FirebaseAuth.instance.authStateChanges();
});

/// Current [UserModel] derived from FirebaseAuth + Firestore.
///
/// This is the single source of truth for the current user's domain model.
/// It listens to FirebaseAuth auth state changes, then fetches the Firestore
/// user document to build a complete [UserModel] with role, organizationId, etc.
///
/// Falls back to Hive cache when offline or during cold start.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final firebaseUserAsync = ref.watch(firebaseAuthProvider);

  return firebaseUserAsync.when(
    data: (firebaseUser) {
      if (firebaseUser == null) {
        // Signed out — clear Hive cache
        _clearHiveCache();
        return Stream.value(null);
      }
      // Signed in — watch Firestore user document for real-time updates
      return FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) {
          // Firestore doc might not exist yet (race during registration)
          // Return a minimal model from Firebase Auth data
          return UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            fullName: firebaseUser.displayName ?? '',
            role: 'unknown',
            isEmailVerified: firebaseUser.emailVerified,
          );
        }
        final model = UserModel.fromFirestore(doc.data()!, doc.id);
        // Persist to Hive for offline/cold-start access
        _persistToHive(model);
        return model;
      });
    },
    loading: () {
      // During initial load, try reading from Hive cache
      final cached = _readFromHive();
      return Stream.value(cached);
    },
    error: (_, __) {
      // On error, try Hive cache
      final cached = _readFromHive();
      return Stream.value(cached);
    },
  );
});

/// Whether the user is currently logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user != null,
    loading: () {
      // Check Hive cache during loading
      return _readFromHive() != null;
    },
    error: (_, __) => _readFromHive() != null,
  );
});

/// Current user's role — derived from [currentUserProvider].
final currentUserRoleProvider = Provider<String>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user?.role ?? 'unknown',
    loading: () => _readFromHive()?.role ?? 'unknown',
    error: (_, __) => _readFromHive()?.role ?? 'unknown',
  );
});

/// Current user's organization ID — derived from [currentUserProvider].
final currentOrgIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user?.organizationId,
    loading: () => _readFromHive()?.organizationId,
    error: (_, __) => _readFromHive()?.organizationId,
  );
});

// ══════════════════════════════════════════════════════════════════════════
// Hive Cache Helpers
// ══════════════════════════════════════════════════════════════════════════

UserModel? _readFromHive() {
  try {
    final box = Hive.box(AppConstants.authBox);
    final uid = box.get('uid') as String?;
    if (uid == null) return null;
    return UserModel(
      uid: uid,
      email: box.get('email') as String? ?? '',
      fullName: box.get('fullName') as String? ?? '',
      role: box.get('role') as String? ?? 'unknown',
      organizationId: box.get('organizationId') as String?,
      organizationName: box.get('organizationName') as String?,
      profileImageUrl: box.get('profileImageUrl') as String?,
      authProvider: box.get('authProvider') as String? ?? 'password',
      isActive: box.get('isActive') as bool? ?? true,
      isEmailVerified: box.get('isEmailVerified') as bool? ?? false,
    );
  } catch (_) {
    return null;
  }
}

void _persistToHive(UserModel user) {
  try {
    final box = Hive.box(AppConstants.authBox);
    box.put('uid', user.uid);
    box.put('email', user.email);
    box.put('fullName', user.fullName);
    box.put('role', user.role);
    box.put('organizationId', user.organizationId);
    box.put('organizationName', user.organizationName);
    box.put('profileImageUrl', user.profileImageUrl);
    box.put('authProvider', user.authProvider);
    box.put('isActive', user.isActive);
    box.put('isEmailVerified', user.isEmailVerified);
  } catch (_) {
    // Non-critical — Hive cache is optional
  }
}

void _clearHiveCache() {
  try {
    final box = Hive.box(AppConstants.authBox);
    box.deleteAll([
      'uid', 'email', 'fullName', 'role', 'organizationId',
      'organizationName', 'profileImageUrl', 'authProvider',
      'isActive', 'isEmailVerified',
    ]);
  } catch (_) {
    // Non-critical
  }
}

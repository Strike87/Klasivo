import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../rbac/rbac.dart';
import '../config/app_constants.dart';

/// Service that manages custom claims syncing and roleVersion monitoring.
///
/// Flow:
/// 1. On auth state change → read claims from ID token
/// 2. Listen to user doc's roleVersion field
/// 3. If roleVersion changes (e.g., admin changed user's role) →
///    force token refresh → read new claims → update RBAC state
class ClaimsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _roleVersionSubscription;
  int _lastKnownRoleVersion = 0;

  /// Read current custom claims from the ID token.
  Future<CustomClaims> getCurrentClaims() async {
    final user = _auth.currentUser;
    if (user == null) return CustomClaims.empty;

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};
      return CustomClaims.fromTokenClaims(claims);
    } catch (e) {
      return CustomClaims.empty;
    }
  }

  /// Read the user's scope from their Firestore document.
  Future<UserScope> getUserScope(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (!doc.exists) return UserScope.empty;
      final data = doc.data()!;
      return UserScope(
        campusIds: List<String>.from(data['campusIds'] ?? []),
        stageIds: List<String>.from(data['stageIds'] ?? []),
        classIds: List<String>.from(data['classIds'] ?? []),
        subjectIds: List<String>.from(data['subjectIds'] ?? []),
        academicYearIds: List<String>.from(data['academicYearIds'] ?? []),
        studentIds: List<String>.from(data['studentIds'] ?? []),
      );
    } catch (e) {
      return UserScope.empty;
    }
  }

  /// Read mustChangePassword from user doc.
  Future<bool> getMustChangePassword(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (!doc.exists) return false;
      return doc.data()?['mustChangePassword'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Read roleVersion from user doc.
  Future<int> getRoleVersion(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (!doc.exists) return 0;
      return doc.data()?['roleVersion'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Read permissionOverrides from user doc.
  /// Returns an empty map if no overrides are set or on error.
  Future<Map<String, bool>> getPermissionOverrides(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (!doc.exists) return {};
      final raw = doc.data()?['permissionOverrides'];
      if (raw == null) return {};
      if (raw is Map<String, dynamic>) {
        return raw.map((key, value) => MapEntry(key, value as bool));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Start listening to roleVersion changes on the user doc.
  /// When roleVersion changes, call [onRoleVersionChanged] callback.
  void startRoleVersionListener({
    required String userId,
    required void Function(CustomClaims claims, UserScope scope, int newVersion) onRoleVersionChanged,
  }) {
    _roleVersionSubscription?.cancel();
    _lastKnownRoleVersion = 0;

    _roleVersionSubscription = _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final currentVersion = snapshot.data()?['roleVersion'] as int? ?? 0;

      // Skip initial load or if version hasn't changed
      if (_lastKnownRoleVersion == 0) {
        _lastKnownRoleVersion = currentVersion;
        return;
      }
      if (currentVersion <= _lastKnownRoleVersion) return;

      // roleVersion incremented — force token refresh + read new claims
      _lastKnownRoleVersion = currentVersion;
      final claims = await getCurrentClaims();
      final scope = await getUserScope(userId);

      onRoleVersionChanged(claims, scope, currentVersion);
    });
  }

  /// Stop the roleVersion listener.
  void stopRoleVersionListener() {
    _roleVersionSubscription?.cancel();
    _roleVersionSubscription = null;
    _lastKnownRoleVersion = 0;
  }

  /// Force refresh the ID token (e.g., after role change).
  Future<String?> forceRefreshToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(true);
  }

  /// Call the syncClaims Cloud Function to re-sync claims.
  /// This is a fallback if the roleVersion listener doesn't trigger.
  Future<void> syncClaimsViaFunction() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('syncClaims');
      await callable.call({});
    } catch (e) {
      // Fallback: just force refresh the token
      await forceRefreshToken();
    }
  }

  void dispose() {
    stopRoleVersionListener();
  }
}

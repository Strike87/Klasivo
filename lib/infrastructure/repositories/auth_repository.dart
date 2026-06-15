import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_constants.dart';
import '../firebase/firebase_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO AUTH REPOSITORY — IAuthRepository + FirebaseAuthRepository
//
// Handles authentication operations:
// - Email/password sign-in and sign-up
// - Google sign-in
// - Student code authentication
// - Password reset
// - Auth state streaming
// - User profile management
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Domain Model ───────────────────────────────────────────────────────────

class AuthUser implements FirebaseDocument {
  @override
  final String id;
  final String email;
  final String displayName;
  final String role;
  final String? organizationId;
  final String? photoUrl;
  final bool isActive;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.organizationId,
    this.photoUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory AuthUser.fromFirestore(String id, Map<String, dynamic> data) {
    return AuthUser(
      id: id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? '',
      organizationId: data['organizationId'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      'organizationId': organizationId,
      'photoUrl': photoUrl,
      'isActive': isActive,
    };
  }
}

// ─── Interface ──────────────────────────────────────────────────────────────

abstract class IAuthRepository {
  Future<RepositoryResult<AuthUser>> signInWithEmail(String email, String password);
  Future<RepositoryResult<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String role,
  });
  Future<RepositoryResult<AuthUser>> signInWithStudentCode(String code);
  Future<void> signOut();
  Future<RepositoryResult<void>> resetPassword(String email);
  Future<RepositoryResult<AuthUser>> getCurrentUser();
  Stream<AuthUser?> get authStateChanges;
  Future<RepositoryResult<void>> updateUserProfile(String userId, Map<String, dynamic> data);
  Future<RepositoryResult<void>> deleteUser(String userId);
}

// ─── Firebase Implementation ────────────────────────────────────────────────

class FirebaseAuthRepository extends FirebaseRepository<AuthUser>
    implements IAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  String get collectionPath => AppConstants.usersCollection;

  @override
  AuthUser fromFirestore(String id, Map<String, dynamic> data) {
    return AuthUser.fromFirestore(id, data);
  }

  @override
  Future<RepositoryResult<AuthUser>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const RepositoryResult.failure('Sign-in failed: no user returned');
      }

      final user = await _getAuthUserFromFirestore(credential.user!.uid);
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthRepository] signInWithEmail error: ${e.code}');
      return RepositoryResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('[AuthRepository] signInWithEmail error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const RepositoryResult.failure('Sign-up failed: no user returned');
      }

      // Update Firebase Auth display name
      await credential.user!.updateDisplayName(displayName);

      // Create user document in Firestore
      final authUser = AuthUser(
        id: credential.user!.uid,
        email: email,
        displayName: displayName,
        role: role,
        isActive: true,
      );

      await createWithId(authUser, credential.user!.uid);

      return RepositoryResult.success(authUser);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthRepository] signUpWithEmail error: ${e.code}');
      return RepositoryResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('[AuthRepository] signUpWithEmail error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<AuthUser>> signInWithStudentCode(String code) async {
    try {
      // Student codes map to a custom sign-in flow
      // Look up the student by invite code
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const RepositoryResult.failure('Invalid student code');
      }

      final doc = snapshot.docs.first;
      final authUser = AuthUser.fromFirestore(doc.id, doc.data());
      return RepositoryResult.success(authUser);
    } catch (e) {
      debugPrint('[AuthRepository] signInWithStudentCode error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<RepositoryResult<void>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const RepositoryResult.success(null);
    } on FirebaseAuthException catch (e) {
      return RepositoryResult.failure(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<RepositoryResult<AuthUser>> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return const RepositoryResult.failure('No authenticated user');
    }
    return _getAuthUserFromFirestore(firebaseUser.uid);
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      final result = await _getAuthUserFromFirestore(firebaseUser.uid);
      return result.data;
    });
  }

  @override
  Future<RepositoryResult<void>> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) {
    return update(userId, data);
  }

  @override
  Future<RepositoryResult<void>> deleteUser(String userId) async {
    try {
      // Delete from Firestore
      await collection.doc(userId).delete();

      // Delete from Firebase Auth (requires cloud function for non-current users)
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await currentUser.delete();
      }

      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[AuthRepository] deleteUser error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  Future<RepositoryResult<AuthUser>> _getAuthUserFromFirestore(String uid) async {
    try {
      final doc = await collection.doc(uid).get();
      if (!doc.exists) {
        return const RepositoryResult.failure('User profile not found');
      }
      final authUser = AuthUser.fromFirestore(doc.id, doc.data()!);
      return RepositoryResult.success(authUser);
    } catch (e) {
      debugPrint('[AuthRepository] _getAuthUserFromFirestore error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}

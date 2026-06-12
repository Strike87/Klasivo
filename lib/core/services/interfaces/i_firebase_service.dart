import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface wrapping FirebaseAuth, FirebaseFirestore, and
/// FirebaseMessaging into a single service contract.
///
/// Enables testability by allowing mock or fake implementations that
/// don't require a real Firebase project.
abstract class IFirebaseService {
  // ─── Auth ──────────────────────────────────────────────────────────────

  /// Currently signed-in Firebase user, or null.
  User? get currentUser;

  /// Create a new user with email & password.
  Future<UserCredential> registerWithEmail(String email, String password);

  /// Sign in with email & password.
  Future<UserCredential> loginWithEmail(String email, String password);

  /// Sign out.
  Future<void> logout();

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email);

  // ─── Firestore CRUD ────────────────────────────────────────────────────

  /// Add a document to a collection (auto-generated ID).
  Future<DocumentReference> addDocument(
    String collection,
    Map<String, dynamic> data,
  );

  /// Set a document (create or overwrite) with an explicit ID.
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  /// Get a single document by ID.
  Future<DocumentSnapshot> getDocument(String collection, String docId);

  /// Query a collection with optional where clauses, ordering & limit.
  ///
  /// Each entry in [where] is a list `[field, operator, value]`.
  Future<QuerySnapshot> getCollectionWhere(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool? descending,
    int? limit,
  });

  /// Update fields on an existing document.
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  /// Delete a document.
  Future<void> deleteDocument(String collection, String docId);

  // ─── Messaging ─────────────────────────────────────────────────────────

  /// Get the current FCM registration token.
  Future<String?> getFCMToken();
}

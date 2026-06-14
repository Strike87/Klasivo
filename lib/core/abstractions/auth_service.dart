/// Abstract interface for authentication services.
///
/// Covers all authentication flows in the Klasivo app:
/// - Owner registration & login (email + password, Google Sign-In)
/// - Teacher registration via invite code & login
/// - Student login via student code + password
/// - Parent registration & login (email + password, Google Sign-In)
/// - Password reset, email verification sync, and sign-out.
abstract class IAuthService {
  // ─── Owner ──────────────────────────────────────────────────────────────

  /// Register a new owner with email and password.
  /// Auto-creates an organization with a default name.
  Future<Map<String, dynamic>?> registerOwner({
    required String email,
    required String password,
    required String fullName,
  });

  /// Register a new owner via Google Sign-In.
  /// If the user already exists, logs them in instead.
  Future<Map<String, dynamic>?> registerOwnerWithGoogle();

  /// Complete owner setup by naming the workspace.
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  });

  /// Generate workspace name suggestions based on the owner's full name.
  List<String> generateWorkspaceSuggestions(String fullName);

  // ─── Email + Password Login (Owner / Teacher / Parent) ──────────────────

  /// Unified email + password login.
  /// Students are rejected — they must use [loginStudent].
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  });

  // ─── Student ────────────────────────────────────────────────────────────

  /// Student login using student code + password.
  Future<Map<String, dynamic>?> loginStudent({
    required String studentCode,
    required String password,
  });

  // ─── Teacher ────────────────────────────────────────────────────────────

  /// Register a teacher with email, password, and an invite code.
  Future<Map<String, dynamic>?> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  });

  /// Register a teacher via Google Sign-In with an invite code.
  Future<Map<String, dynamic>?> registerTeacherWithGoogle({
    required String inviteCode,
  });

  // ─── Parent ─────────────────────────────────────────────────────────────

  /// Register a parent with email, password, and full name.
  Future<Map<String, dynamic>?> registerParent({
    required String email,
    required String password,
    required String fullName,
  });

  /// Register a parent via Google Sign-In.
  Future<Map<String, dynamic>?> registerParentWithGoogle();

  // ─── Google Sign-In (Unified) ───────────────────────────────────────────

  /// Sign in with Google. Works for owners, teachers, and parents.
  Future<Map<String, dynamic>?> loginWithGoogle({String? expectedRole});

  // ─── Utility ────────────────────────────────────────────────────────────

  /// Sync the email verification status in Firestore.
  Future<void> syncEmailVerification(String userId, bool isVerified);

  /// Sign out the current user (Firebase Auth + Google Sign-In).
  Future<void> signOut();

  /// Whether a user is currently signed in.
  bool get isLoggedIn;

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email);

  /// Check if the current user needs to complete setup.
  Future<bool> needsSetup();
}

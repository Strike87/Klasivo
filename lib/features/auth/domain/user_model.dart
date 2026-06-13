/// Domain model for a Klasivo user.
/// This is the single source of truth for user data shape.
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String? organizationId;
  final String? organizationName;
  final String? profileImageUrl;
  final String authProvider;
  final bool isActive;
  final bool isEmailVerified;
  final bool mustChangePassword;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.fullName = '',
    required this.role,
    this.organizationId,
    this.organizationName,
    this.profileImageUrl,
    this.authProvider = 'password',
    this.isActive = true,
    this.isEmailVerified = false,
    this.mustChangePassword = false,
    this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      role: data['role'] as String? ?? 'unknown',
      organizationId: data['organizationId'] as String?,
      organizationName: data['organizationName'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      authProvider: data['authProvider'] as String? ?? 'password',
      isActive: data['isActive'] as bool? ?? true,
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime?
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'profileImageUrl': profileImageUrl,
      'authProvider': authProvider,
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'mustChangePassword': mustChangePassword,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? role,
    String? organizationId,
    String? organizationName,
    String? profileImageUrl,
    bool? isActive,
    bool? isEmailVerified,
    bool? mustChangePassword,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      authProvider: authProvider,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      createdAt: createdAt,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
  bool get isParent => role == 'parent';
  bool get isAdmin => role == 'admin';
  bool get isTeacherOrAbove => isTeacher || isOwner || isAdmin;
}

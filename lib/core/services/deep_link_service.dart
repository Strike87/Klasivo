import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../rbac/roles.dart';

class DeepLinkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Generate Deep Link URLs ─────────────────────────────────────────────

  /// Generate an invite join link for a teacher or student.
  /// Example: https://klasivo.app/join/7H92XP41
  String generateJoinLink(String code) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathJoin}/$code';
  }

  /// Generate an exam deep link.
  /// Example: https://klasivo.app/exam/abc123
  String generateExamLink(String examId) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathExam}/$examId';
  }

  /// Generate a student result page link.
  /// Example: https://klasivo.app/result/XYZ123
  String generateResultLink(String resultId) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathResult}/$resultId';
  }

  /// Generate a public organization portal link.
  /// Example: https://klasivo.app/org/ahmed-academy
  String generateOrgPortalLink(String slug) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathOrg}/$slug';
  }

  /// Generate a password reset link.
  /// Example: https://klasivo.app/reset?mode=resetPassword&oobCode=XXX
  String generatePasswordResetLink(String oobCode) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathReset}?oobCode=$oobCode';
  }

  /// Generate an email verification link.
  /// Example: https://klasivo.app/verify?mode=verifyEmail&oobCode=XXX
  String generateEmailVerificationLink(String oobCode) {
    return '${AppConstants.appBaseUrl}${AppConstants.pathVerify}?oobCode=$oobCode';
  }

  /// Generate a custom URI scheme deep link.
  /// Example: klasivo://join/7H92XP41
  String generateCustomSchemeLink(String path, [String? param]) {
    if (param != null) {
      return '${AppConstants.deepLinkScheme}://$path/$param';
    }
    return '${AppConstants.deepLinkScheme}://$path';
  }

  // ─── Parse Incoming Deep Links ───────────────────────────────────────────

  /// Parse an incoming deep link URL and return structured data.
  /// Handles both https://klasivo.app/* and klasivo://* formats.
  DeepLinkData? parseDeepLink(String url) {
    try {
      Uri uri = Uri.parse(url);

      // Handle custom scheme: klasivo://join/CODE
      if (uri.scheme == AppConstants.deepLinkScheme) {
        return _parseCustomScheme(uri);
      }

      // Handle HTTPS: https://klasivo.app/join/CODE
      if (uri.scheme == 'https' && uri.host == AppConstants.appDomain) {
        return _parseHttpsUrl(uri);
      }

      // Handle Dynamic Links fallback
      if (uri.host == AppConstants.dynamicLinkDomain) {
        final link = uri.queryParameters['link'];
        if (link != null) {
          return parseDeepLink(link);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  DeepLinkData? _parseCustomScheme(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return null;

    final action = pathSegments[0];
    final param = pathSegments.length > 1 ? pathSegments[1] : null;

    return _buildDeepLinkData(action, param, uri.queryParameters);
  }

  DeepLinkData? _parseHttpsUrl(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return null;

    final action = pathSegments[0];
    final param = pathSegments.length > 1 ? pathSegments[1] : null;

    return _buildDeepLinkData(action, param, uri.queryParameters);
  }

  DeepLinkData? _buildDeepLinkData(
    String action,
    String? param,
    Map<String, String> queryParams,
  ) {
    switch (action) {
      case 'join':
        if (param == null) return null;
        return DeepLinkData(
          type: DeepLinkType.join,
          code: param,
        );

      case 'exam':
        if (param == null) return null;
        return DeepLinkData(
          type: DeepLinkType.exam,
          examId: param,
        );

      case 'result':
        if (param == null) return null;
        return DeepLinkData(
          type: DeepLinkType.result,
          resultId: param,
        );

      case 'org':
        if (param == null) return null;
        return DeepLinkData(
          type: DeepLinkType.organization,
          slug: param,
        );

      case 'reset':
        return DeepLinkData(
          type: DeepLinkType.passwordReset,
          oobCode: queryParams['oobCode'],
        );

      case 'verify':
        return DeepLinkData(
          type: DeepLinkType.emailVerification,
          oobCode: queryParams['oobCode'],
        );

      default:
        return null;
    }
  }

  // ─── Resolve Deep Link Data ──────────────────────────────────────────────

  /// Resolve a join deep link: look up the invite code and return org info.
  Future<JoinLinkResult?> resolveJoinLink(String code) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final codeData = snapshot.docs.first.data();
      final organizationId = codeData['organizationId'] as String?;
      final type = codeData['type'] as String?;
      final classId = codeData['classId'] as String?;

      if (organizationId == null) return null;

      // Get organization info
      final orgDoc = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .get();

      if (!orgDoc.exists) return null;

      final orgData = orgDoc.data()!;

      return JoinLinkResult(
        inviteCodeId: snapshot.docs.first.id,
        code: code,
        type: type ?? AppConstants.inviteTypeTeacher,
        organizationId: organizationId,
        organizationName: orgData['name'] ?? 'Unknown Organization',
        organizationSlug: orgData['slug'],
        classId: classId,
        expiresAt: (codeData['expiresAt'] as Timestamp?)?.toDate(),
        useCount: codeData['useCount'] as int? ?? 0,
        maxUses: codeData['maxUses'] as int? ?? 1,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Resolve an organization portal deep link by slug.
  Future<OrgPortalResult?> resolveOrgPortal(String slug) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('slug', isEqualTo: slug)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final orgData = snapshot.docs.first.data();

      return OrgPortalResult(
        organizationId: snapshot.docs.first.id,
        name: orgData['name'] ?? '',
        slug: slug,
        description: orgData['description'],
        logoUrl: orgData['logoUrl'],
        ownerId: orgData['ownerId'] ?? '',
        contactEmail: orgData['contactEmail'],
        contactPhone: orgData['contactPhone'],
        website: orgData['website'],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Resolve a result page deep link.
  Future<ResultPageResult?> resolveResultLink(String resultId) async {
    try {
      // Result IDs could be a student code or a submission ID
      // First try as student code
      final studentSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: resultId)
          .where('role', isEqualTo: KlasivoRole.student)
          .limit(1)
          .get();

      if (studentSnapshot.docs.isNotEmpty) {
        final studentData = studentSnapshot.docs.first.data();
        return ResultPageResult(
          studentId: studentSnapshot.docs.first.id,
          studentName: studentData['fullName'] ?? 'Student',
          studentCode: resultId,
          organizationId: studentData['organizationId'] ?? '',
          classId: studentData['classId'],
        );
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Generate Firebase Action Code Settings for password reset / email verification
  /// with custom domain handling.
  ActionCodeSettings getActionCodeSettings() {
    return ActionCodeSettings(
      url: AppConstants.appBaseUrl,
      handleCodeInApp: true,
      iOSBundleId: AppConstants.iosBundleId,
      androidPackageName: AppConstants.androidPackageName,
      androidInstallApp: true,
      androidMinimumVersion: '21',
      dynamicLinkDomain: AppConstants.dynamicLinkDomain,
    );
  }

  /// Send password reset email with custom Klasivo branding.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final auth = FirebaseAuth.instance;
      await auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: getActionCodeSettings(),
      );
    } catch (e) {
      rethrow;
    }
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

/// Represents a parsed deep link with all necessary routing information.
class DeepLinkData {
  final DeepLinkType type;
  final String? code;         // For join links
  final String? examId;      // For exam links
  final String? resultId;    // For result links
  final String? slug;        // For org portal links
  final String? oobCode;     // For password reset / email verification

  DeepLinkData({
    required this.type,
    this.code,
    this.examId,
    this.resultId,
    this.slug,
    this.oobCode,
  });

  @override
  String toString() => 'DeepLinkData(type: $type, code: $code, examId: $examId, resultId: $resultId, slug: $slug)';
}

/// Types of deep links the app can handle.
enum DeepLinkType {
  join,               // /join/{code} — Teacher/Student invite
  exam,               // /exam/{examId} — Open specific exam
  result,             // /result/{code} — Student result page
  organization,       // /org/{slug} — Public org portal
  passwordReset,      // /reset — Password reset flow
  emailVerification,  // /verify — Email verification flow
}

/// Result of resolving a join link with organization details.
class JoinLinkResult {
  final String inviteCodeId;
  final String code;
  final String type;
  final String organizationId;
  final String organizationName;
  final String? organizationSlug;
  final String? classId;
  final DateTime? expiresAt;
  final int useCount;
  final int maxUses;

  JoinLinkResult({
    required this.inviteCodeId,
    required this.code,
    required this.type,
    required this.organizationId,
    required this.organizationName,
    this.organizationSlug,
    this.classId,
    this.expiresAt,
    this.useCount = 0,
    this.maxUses = 1,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isFullyUsed => useCount >= maxUses;

  bool get isValid => !isExpired && !isFullyUsed;

  /// Get the shareable join URL.
  String get joinUrl => '${AppConstants.appBaseUrl}${AppConstants.pathJoin}/$code';

  /// Get the display text for sharing.
  String get shareText {
    final roleLabel = type == AppConstants.inviteTypeTeacher ? 'teacher' : 'student';
    return 'Join $organizationName on Klasivo as a $roleLabel!\n\n$joinUrl';
  }
}

/// Result of resolving an organization portal link.
class OrgPortalResult {
  final String organizationId;
  final String name;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String ownerId;
  final String? contactEmail;
  final String? contactPhone;
  final String? website;

  OrgPortalResult({
    required this.organizationId,
    required this.name,
    required this.slug,
    this.description,
    this.logoUrl,
    required this.ownerId,
    this.contactEmail,
    this.contactPhone,
    this.website,
  });

  /// Get the public portal URL.
  String get portalUrl => '${AppConstants.appBaseUrl}${AppConstants.pathOrg}/$slug';
}

/// Result of resolving a student result page link.
class ResultPageResult {
  final String studentId;
  final String studentName;
  final String studentCode;
  final String organizationId;
  final String? classId;

  ResultPageResult({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.organizationId,
    this.classId,
  });

  /// Get the result page URL.
  String get resultUrl => '${AppConstants.appBaseUrl}${AppConstants.pathResult}/$studentCode';
}

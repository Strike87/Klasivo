class ModuleFlags {
  ModuleFlags._();

  // Feature module flags
  static const String attendance = 'attendance';
  static const String lms = 'lms';
  static const String finance = 'finance';
  static const String transport = 'transport';
  static const String messaging = 'messaging';
  static const String analytics = 'analytics';
  static const String parentPortal = 'parent_portal';
  static const String gradebook = 'gradebook';
  static const String examIntegrity = 'exam_integrity';
  static const String questionBank = 'question_bank';
  static const String multiCampus = 'multi_campus';
  static const String customBranding = 'custom_branding';
  static const String sso = 'sso';
  static const String auditLog = 'audit_log';
  static const String moderation = 'moderation';

  // Default flags per plan
  static const Map<String, Map<String, bool>> planDefaults = {
    'free': {
      attendance: true,
      lms: false,
      finance: false,
      transport: false,
      messaging: true,
      analytics: false,
      parentPortal: false,
      gradebook: true,
      examIntegrity: true,
      questionBank: false,
      multiCampus: false,
      customBranding: false,
      sso: false,
      auditLog: false,
      moderation: false,
    },
    'starter': {
      attendance: true,
      lms: true,
      finance: false,
      transport: false,
      messaging: true,
      analytics: true,
      parentPortal: true,
      gradebook: true,
      examIntegrity: true,
      questionBank: true,
      multiCampus: false,
      customBranding: false,
      sso: false,
      auditLog: true,
      moderation: false,
    },
    'professional': {
      attendance: true,
      lms: true,
      finance: true,
      transport: false,
      messaging: true,
      analytics: true,
      parentPortal: true,
      gradebook: true,
      examIntegrity: true,
      questionBank: true,
      multiCampus: true,
      customBranding: true,
      sso: false,
      auditLog: true,
      moderation: true,
    },
    'enterprise': {
      attendance: true,
      lms: true,
      finance: true,
      transport: true,
      messaging: true,
      analytics: true,
      parentPortal: true,
      gradebook: true,
      examIntegrity: true,
      questionBank: true,
      multiCampus: true,
      customBranding: true,
      sso: true,
      auditLog: true,
      moderation: true,
    },
  };
}

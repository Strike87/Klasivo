# Klasivo — Development Roadmap

## Version History

### v1.0 — Foundation (Weeks 1-2)
- [x] Flutter project with Riverpod + GoRouter
- [x] Firebase Auth (Email/Password, Google Sign-In)
- [x] Firestore backend with security rules
- [x] Auth screens: Splash, Login, Register, Role Selection
- [x] GoRouter with auth guards and redirect logic

### v1.1–v1.3 — Core Exam System (Weeks 3-8)
- [x] Teacher Dashboard with real-time stats
- [x] Class & Student CRUD with invite codes
- [x] Exam creation with question builder (MCQ, T/F, Short Answer)
- [x] Student exam taking with auto-save & timer
- [x] Auto-grading engine with partial credit
- [x] Results screens (student & teacher views)

### v1.4–v1.5 — Security & Notifications (Weeks 9-13)
- [x] App leave detection & violation tracking
- [x] Screen security (no screenshots during exam)
- [x] Firebase Cloud Messaging setup
- [x] Local notifications with type-specific triggers
- [x] Violation dashboard for teachers

### v1.6 — Feature Complete (Week 14)
- [x] Announcements (create, detail, list screens)
- [x] Calendar with event creation
- [x] Academic Years management
- [x] Audit Logs (owner-only access)
- [x] 6 new routes added
- [x] Organization → Stage → Class → Group hierarchy

### v1.7 — Enterprise Foundations (Week 15)
- [x] Design Tokens system (6 files: colors, spacing, radius, typography, elevation, animation)
- [x] Enterprise Component Library (7 widgets: KlasivoButton, KlasivoCard, KlasivoTextField, KlasivoBadge, KlasivoAvatar, KlasivoModal, KlasivoToast)
- [x] KlasivoPermissionGate & KlasivoFeatureGate
- [x] Feature Flag Service (27 flags, percentage rollout, user targeting)
- [x] Event Bus (25+ typed events across 8 domains)
- [x] Permission Service (8 roles, 80+ granular permissions, Firestore overrides)
- [x] Enterprise service initialization on app startup

### v1.8 — Feature Completion (Week 16)
- [x] LessonDetailScreen (1,346 lines) — YouTube, Zoom, Google Drive, Recorded lesson types
- [x] MaterialViewerScreen (918 lines) — File-type hero banner, metadata, open/share/download
- [x] ConversationListScreen (703 lines) — WhatsApp-style list with search, FAB, unread indicators
- [x] ChatScreen (717 lines) — Full chat UI with message bubbles, read receipts, auto-scroll
- [x] Fixed TODO navigation in SubjectContentScreen
- [x] Removed 3 orphaned GradeService files
- [x] 4 new routes: /lms/lessons/:lessonId, /lms/materials/:materialId, /inbox/messages, /inbox/messages/:conversationId

### v1.9 — Polish & Production Readiness (Current)
- [x] Owner Shell — role-aware shell that switches between OwnerShell and TeacherShell
- [x] Messaging UI integrated with ConversationListScreen + ChatScreen
- [x] LMS detail screens integrated (LessonDetailScreen + MaterialViewerScreen)
- [x] Firestore security rules hardened:
  - Added `isOwner()`, `isStudent()`, `isInSameOrg()`, `isResourceOwner()` helpers
  - Admin role included in `isTeacherOrOwner()`
  - Messages restricted to same-organization reads
  - Message updates restricted to sender only
  - Feature flags & permission overrides restricted to owner-only writes
  - Added search_keywords and deep_links collections
- [x] Removed orphaned grade_service.dart, grade_provider.dart, grade_list_screen.dart
- [x] Added url_launcher dependency for LMS external links
- [x] Version bumped to 1.9.0+6

---

## v2.0 — Next Phase (Planned)

### Component Migration
- [ ] Migrate remaining screens from raw Material widgets to KlasivoButton/KlasivoCard/KlasivoTextField
- [ ] Standardize all confirmation dialogs to use KlasivoModal.confirm()
- [ ] Replace all SnackBar usage with KlasivoToast

### Testing
- [ ] Unit tests for ExamService (create, publish, grade)
- [ ] Unit tests for AuthService (login, register, role routing)
- [ ] Unit tests for GradingEngine (MCQ, T/F, short answer)
- [ ] Integration tests for exam creation → taking → grading cycle
- [ ] Widget tests for KlasivoButton variants and states

### Performance & Quality
- [ ] Firestore composite indexes for common queries
- [ ] Lazy loading / pagination for large lists (students, exams, messages)
- [ ] Image caching for avatars and thumbnails
- [ ] Offline mode with Firestore cache persistence
- [ ] Error boundary wrapper for all screens

### Infrastructure
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Firebase Crashlytics integration (already wired, needs testing)
- [ ] App store listing (Google Play)
- [ ] Environment-based Firebase config (dev/staging/prod)

---

## Route Map (70+ routes)

| Path | Screen | Shell |
|------|--------|-------|
| `/` | SplashScreen | — |
| `/auth` | RoleSelectionScreen | — |
| `/auth/teacher-login` | TeacherLoginScreen | — |
| `/auth/teacher-register` | TeacherRegistrationScreen | — |
| `/auth/student-login` | StudentLoginScreen | — |
| `/auth/parent-login` | ParentLoginScreen | — |
| `/auth/parent-register` | ParentRegisterScreen | — |
| `/auth/parent-link` | ParentLinkScreen | — |
| `/welcome` | WelcomeScreen | — |
| `/dashboard` | OwnerDashboard | Owner/Teacher Shell |
| `/academic` | StageListScreen | Owner/Teacher Shell |
| `/academic/stages/:stageId/classes` | ClassListScreen | Owner/Teacher Shell |
| `/people` | AllStudentsScreen | Owner/Teacher Shell |
| `/inbox` | NotificationCenterScreen | Owner/Teacher Shell |
| `/inbox/messages` | ConversationListScreen | Owner/Teacher Shell |
| `/inbox/messages/:conversationId` | ChatScreen | Owner/Teacher Shell |
| `/inbox/announcements` | AnnouncementListScreen | Owner/Teacher Shell |
| `/settings` | SettingsScreen | Owner/Teacher Shell |
| `/lms/subject/:subjectId` | SubjectContentScreen | — |
| `/lms/lessons/:lessonId` | LessonDetailScreen | — |
| `/lms/materials/:materialId` | MaterialViewerScreen | — |
| `/student` | StudentDashboard | Student Shell |
| `/student/exams` | StudentExamListScreen | — |
| `/student/exams/:examId/take` | ExamTakingScreen | — |
| `/student/results` | StudentResultsScreen | — |
| `/parent` | ParentDashboard | Parent Shell |
| `/parent/assignments` | ParentAssignmentsScreen | Parent Shell |
| `/parent/progress` | ParentProgressScreen | Parent Shell |
| `/parent/announcements` | ParentAnnouncementsScreen | Parent Shell |
| `/teacher/exams` | ExamListScreen | — |
| `/teacher/calendar` | CalendarScreen | — |
| `/teacher/academic-years` | AcademicYearListScreen | — |
| `/teacher/assignments` | AssignmentListScreen | — |
| `/teacher/gradebook` | GradebookScreen | — |
| `/teacher/attendance` | AttendanceScreen | — |
| `/teacher/analytics` | TeacherAnalyticsDashboard | — |
| `/teacher/reports` | ReportGenerationScreen | — |
| `/teacher/integrity` | ExamIntegrityDashboard | — |
| `/teacher/audit-log` | AuditLogScreen | — |
| `/teacher/moderation` | ModerationQueueScreen | — |
| `/teacher/question-bank` | QuestionBankScreen | — |

---

## Architecture Summary

| Layer | Technology | Count |
|-------|-----------|-------|
| Services | FirebaseFirestore CRUD | 44 |
| Providers | Riverpod StateNotifier/Stream | 40 |
| Screens | ConsumerWidget/StatefulWidget | 67 |
| Routes | GoRouter | 70+ |
| Data Models | Firestore-mapped classes | 30+ |
| Widgets | Klasivo Component Library | 11 |
| Tokens | Design system constants | 7 files |

## Design System

- **Primary**: #3B5BDB (Royal Indigo)
- **Secondary**: #12B886 (Emerald)
- **Accent**: #F59F00 (Amber Gold)
- **Font**: PlusJakartaSans (Latin) + NotoSansArabic (Arabic)
- **Spacing**: 4px base grid
- **Radius**: sm=6, md=8, lg=12, xl=16, pill=999

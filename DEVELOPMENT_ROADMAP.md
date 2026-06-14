# Klasivo — Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x)  
> **Architecture:** Clean Architecture + Riverpod + Firebase  
> **Last Updated:** 2026-06-14

---

## Version History

| Version | Focus | Status |
|---------|-------|--------|
| **v1.0** | Core exam platform (auth, exams, grading) | ✅ Complete |
| **v1.1–v1.4** | Student dashboard, auto-save, timer, violations | ✅ Complete |
| **v1.5** | QR enrollment, notifications, PDF reports | ✅ Complete |
| **v1.6** | Announcements, Calendar, Academic Years, Audit Logs | ✅ Complete |
| **v1.7** | Enterprise foundations (Design Tokens, Component Library, Feature Flags, Event Bus, Permission Service) | ✅ Complete |
| **v1.8** | Feature Completion (LMS screens, Messaging UI, legacy cleanup) | ✅ Complete |
| **v1.9** | Polish & Integration (component migration, tests, CI/CD) | ✅ Complete |
| **v2.0** | Dark mode, Push notifications, Video player, Content tracking | ✅ Complete |
| **v2.1** | Chat attachments, Offline caching, Multi-tenant | 🔲 Planned |
| **v2.2** | iOS, Web, SSO, Analytics warehouse | 🔲 Planned |
| **v2.3** | Teacher Approval Workflow, Attendance Tracking | 🔲 Planned |
| **v2.4** | Assignment Submission API, Parent Accounts | 🔲 Planned |
| **v2.5** | School Accounts / Multi-Tenancy, Analytics Dashboard | 🔲 Planned |
| **v2.6** | Subscription & Billing | 🔲 Planned |

---

## v1.8 — Feature Completion ✅

### LMS Screens
- [x] Lesson Detail Screen — video player placeholder, type-specific cards (YouTube/Zoom/Drive/Recorded), metadata, related materials
- [x] Material Viewer Screen — file type hero banner, metadata, open/share/download actions
- [x] Fixed TODO navigations in SubjectContentScreen

### Messaging/Chat
- [x] Conversation List Screen — WhatsApp-style conversation list with search, FAB for new conversations
- [x] Chat Screen — full chat UI with message bubbles, read receipts, auto-scroll, message deletion
- [x] Routes wired: `/inbox/messages`, `/inbox/messages/:conversationId`

### Legacy Cleanup
- [x] Removed orphaned GradeService, GradeProvider, GradeListScreen (replaced by Stage → Class → Group)

### Routes Added
| Route | Screen |
|-------|--------|
| `/lms/lessons/:lessonId` | LessonDetailScreen |
| `/lms/materials/:materialId` | MaterialViewerScreen |
| `/inbox/messages` | ConversationListScreen |
| `/inbox/messages/:conversationId` | ChatScreen |

---

## v1.7 — Enterprise Foundations ✅

### Design Tokens System (7 files)
- [x] `app_colors.dart` — Full palette with semantic helpers
- [x] `app_spacing.dart` — 4px base grid with semantic aliases
- [x] `app_radius.dart` — Radius scale with semantic aliases
- [x] `app_typography.dart` — Complete type scale with Arabic variants
- [x] `app_elevation.dart` — Shadow system with "border-first" philosophy
- [x] `app_animation.dart` — Duration scale, curves, stagger patterns
- [x] `tokens.dart` — Barrel export

### Enterprise Component Library (8 files)
- [x] `klasivo_button.dart` — 5 variants, 3 sizes, loading state
- [x] `klasivo_card.dart` — 4 variants with accent support
- [x] `klasivo_text_field.dart` — Validation states
- [x] `klasivo_badge.dart` — 5 variants, factory methods
- [x] `klasivo_avatar.dart` — 4 sizes, role color coding
- [x] `klasivo_modal.dart` — confirm/showForm/showContent
- [x] `klasivo_toast.dart` — success/error/warning/info
- [x] `klasivo_permission_gate.dart` — Permission/Role/Feature gates

### Feature Flag Service
- [x] 27 feature flags covering v1.6–v2.0
- [x] Percentage rollout, user targeting, Firestore persistence
- [x] Real-time streaming via Riverpod providers
- [x] Feature Flags admin screen at `/settings/feature-flags`

### Event Bus
- [x] Singleton broadcast event bus with typed streams
- [x] 25+ event models across 8 domains (Auth, Exam, Academic, Attendance, Assignment, LMS, Parent, Integrity, Organization)

### Permission Service
- [x] 8 roles: owner, admin, teacher, student, parent, campus_manager, observer, super_admin
- [x] 80+ granular permissions
- [x] Firestore overrides (allow/deny), resource-level ownership, wildcard support
- [x] Riverpod providers with bulk checks and convenience providers

---

## v1.6 — Feature Expansion ✅

### Announcements
- [x] AnnouncementListScreen, AnnouncementFormScreen, AnnouncementDetailScreen
- [x] Routes: `/inbox/announcements`, `/inbox/announcements/create`, `/inbox/announcements/:id`

### Calendar
- [x] CalendarScreen, CalendarEventFormScreen
- [x] Route: `/teacher/calendar`

### Academic Years
- [x] AcademicYearListScreen, AcademicYearFormScreen
- [x] Route: `/teacher/academic-years`

### Audit Logs
- [x] AuditLogScreen with filtering
- [x] Route: `/teacher/audit-log`

---

## v1.0–v1.5 — Core Platform ✅

### Authentication
- [x] Firebase Auth (email/password + Google Sign-In)
- [x] Multi-role: Owner, Teacher, Student, Parent
- [x] Splash → Role Selection → Login/Register flow
- [x] Hive-persisted session management

### Teacher Features
- [x] Dashboard with analytics cards
- [x] Stage → Class → Group hierarchy with Smart Setup Wizard
- [x] Exam creation with 3 question types (MCQ, True/False, Short Answer)
- [x] Question Bank
- [x] Exam publishing and scheduling
- [x] Auto-grading engine
- [x] Results with export and visualization
- [x] Attendance tracking
- [x] Gradebook
- [x] Assignment management
- [x] Excel import for students
- [x] QR enrollment and generation

### Student Features
- [x] Dashboard with upcoming/active/completed exams
- [x] Exam taking with auto-save, countdown timer
- [x] Exam integrity (app leave detection, violation tracking, screen security)
- [x] Results review

### Parent Features
- [x] Dashboard with child overview
- [x] Results, attendance, assignments, progress, announcements views

### Notifications
- [x] Firebase Cloud Messaging integration
- [x] Local notifications
- [x] Notification center with read/unread

### Reports
- [x] PDF report generation
- [x] Exam statistics with charts
- [x] Analytics dashboard

---

## Current Codebase Stats

| Metric | Count |
|--------|-------|
| Services | 56 |
| Providers | 54 |
| Screens | 71 |
| Routes | 65+ |
| Custom Widgets | 14 |
| Feature Flags | 27 |
| Permissions | 80+ |
| Event Types | 25+ |
| User Roles | 8 |
| Firestore Indexes | 126 |
| Paginated Screens | 5 |
| CI/CD Workflows | 3 |
| Performance Traces | 30+ |

---

## v1.9 — Polish & Integration ✅

### Component Migration ✅
- [x] Migrate existing screens from raw `ElevatedButton` → `KlasivoButton`
- [x] Migrate raw `Card` → `KlasivoCard` variants
- [x] Migrate raw `TextField` → `KlasivoTextField` (added `borderless` + `autofocus` for AppBar search)
- [x] Migrate raw `SnackBar` → `KlasivoToast`
- [x] Migrate raw `showDialog` → `KlasivoModal`

### Testing
- [x] Unit tests for grading engine (1030 lines — submission_service_test.dart)
- [x] Unit tests for permission service (900+ lines — permission_service_test.dart)
- [x] Unit tests for feature flag service (700+ lines — feature_flag_service_test.dart)
- [x] Integration tests for auth flow (auth_flow_test.dart — 30+ tests)
- [x] Integration tests for exam creation flow (exam_creation_flow_test.dart — 25+ tests)

### CI/CD ✅
- [x] GitHub Actions for PR checks (test.yml, build.yml, pr-checks.yml)
- [x] Automated test execution — 3-workflow matrix (analyze, unit, integration)
- [x] APK build pipeline — debug APK, release APK, AAB with GitHub Release

### Performance ✅
- [x] Optimize Firestore queries (composite indexes) — 43 new indexes, 126 total
- [x] Add pagination to large lists — 5 major screens converted to KlasivoPaginatedList
- [x] Profile app performance — PerformanceTraceService, N+1 fixes, FirebaseService tracing

---

## v2.0 — Dark Mode, Push Notifications, Video Player, Content Tracking ✅

### Dark Mode ✅
- [x] Theme provider with light/dark/system toggle
- [x] Persist theme choice to Hive
- [x] Update all design tokens for dark palette
- [x] Settings screen theme selector UI

### Push Notifications for Messages ✅
- [x] FCM token management per user
- [x] Cloud Function for message push notifications
- [x] Notification routing (tap → open conversation)
- [x] Notification preferences per conversation

### Video Player + Progress Tracking ✅
- [x] YouTube player integration (youtube_player_flutter)
- [x] Video progress tracking service
- [x] Progress indicator on lesson cards
- [x] Resume playback where student left off

### Content Completion Tracking ✅
- [x] ContentProgress service enhanced (video progress, resume, completion rate)
- [x] Mark lesson/material as completed (auto on video >90%)
- [x] Progress percentage per subject (weighted: lessons 60% + materials 40%)
- [x] Completion badges and streaks (KlasivoCompletionBadge + KlasivoStreakBadge)

---

## Infrastructure — Cloud Functions Audit ✅ (2026-06-14)

### v1→v2 Migration
- [x] 5 RBAC callables migrated v1→v2 (assignRole, assignScope, syncClaims, changeUserPassword, setPermissionOverrides)
- [x] Auth triggers remain v1 (onUserCreated, onUserDeleted) — Firebase has no v2 after-event auth API
- [x] All other functions already v2 (api, generateLiveKitToken, removeParticipant, emailWorker, etc.)

### Cost Optimization
- [x] `maxInstances` caps on all v2 functions — prevents runaway billing from traffic spikes
- [x] `minInstances: 1` only on latency-critical functions (api gateway, generateLiveKitToken)
- [x] `minInstances: 0` on all event-driven & admin functions — scale-to-zero, no idle cost
- [x] `concurrency: 80–100` on all callables — v2 handles 80+ requests per instance (v1 was 1:1)
- [x] `maxInstances: 1` on scheduledClassReminder — single-instance job
- [x] Explicit `memory` + `timeoutSeconds` on v1 auth triggers

### Post-Deploy Verification Required
- [ ] Run `firebase deploy --only functions` to deploy v2 callables
- [ ] Run `firebase functions:list` to confirm all RBAC functions are Gen 2
- [ ] If old v1 versions remain, delete explicitly:
  ```bash
  firebase functions:delete assignRole
  firebase functions:delete assignScope
  firebase functions:delete syncClaims
  firebase functions:delete changeUserPassword
  firebase functions:delete setPermissionOverrides
  ```
- [ ] Confirm no duplicate Gen1 + Gen2 versions of RBAC functions exist

### Function Config Summary
| Function | Gen | minInstances | maxInstances | Concurrency | Memory |
|----------|-----|-------------|-------------|-------------|--------|
| api | v2 | 1 | 100 | 80 | 512MiB |
| generateLiveKitToken | v2 | 1 | 50 | 100 | 256MiB |
| removeParticipant | v2 | 0 | 20 | 80 | 256MiB |
| assignRole | v2 | 0 | 10 | 80 | 256MiB |
| assignScope | v2 | 0 | 10 | 80 | 256MiB |
| syncClaims | v2 | 0 | 20 | 80 | 256MiB |
| changeUserPassword | v2 | 0 | 10 | 80 | 256MiB |
| setPermissionOverrides | v2 | 0 | 10 | 80 | 256MiB |
| sendContactForm | v2 | 0 | 10 | 80 | 256MiB |
| sendTeacherInvitation | v2 | 0 | 10 | 80 | 256MiB |
| sendSchoolAnnouncement | v2 | 0 | 10 | 80 | 256MiB |
| emailWorker | v2 | 0 | — | — | 256MiB |
| onLiveKitRoomCreated | v2 | 0 | — | — | 256MiB |
| onLiveKitRoomUpdated | v2 | 0 | — | — | 256MiB |
| scheduledClassReminder | v2 | 0 | 1 | — | 256MiB |
| onUserCreated | v1 | — | — | — | 256MB |
| onUserDeleted | v1 | — | — | — | 256MB |

---

## v2.1 — Chat Attachments, Offline Caching, Multi-Tenant 🔲

### Communication
- [ ] File/image attachments in chat
- [ ] Message reactions

### Offline
- [ ] Offline content caching (lesson downloads)

### Platform
- [ ] Multi-tenant campus model

---

## v2.2 — iOS, Web, SSO, Analytics 🔲

### Platform
- [ ] iOS support
- [ ] Web support
- [ ] SSO integration

### Analytics
- [ ] Analytics warehouse (BigQuery integration)
- [ ] Custom report builder
- [ ] Student performance prediction

### LMS
- [ ] Lesson plan templates

---

## v2.3 — Teacher Approval Workflow & Attendance Tracking 🔲

### Teacher Approval Workflow
- [ ] Admin approves/rejects teacher registration requests
- [ ] Teacher onboarding flow with invite code verification
- [ ] Approval queue dashboard for owners/admins
- [ ] Email notifications on approval status change
- [ ] Auto-assign default scope (campus/stage/class) on approval

### Attendance Tracking (Enhanced)
- [ ] Real-time attendance during live classes (LiveKit integration)
- [ ] Manual attendance marking by teachers
- [ ] Attendance analytics per student/class/subject
- [ ] Parent notifications for student absences
- [ ] Export attendance reports (PDF/Excel)
- [ ] Attendance trends and heatmaps

---

## v2.4 — Assignment Submission API & Parent Accounts 🔲

### Assignment Submission API
- [ ] REST API for assignment creation, submission, and grading
- [ ] File upload support (PDF, images, documents)
- [ ] Submission deadlines with late penalty rules
- [ ] Plagiarism detection integration placeholder
- [ ] Rubric-based grading interface
- [ ] Batch grading and feedback
- [ ] Student submission status tracking

### Parent Accounts (Enhanced)
- [ ] Self-service parent registration (email verification)
- [ ] Link multiple children to one parent account
- [ ] Parent dashboard with real-time child progress
- [ ] Push notifications for grades, attendance, announcements
- [ ] Parent-teacher messaging channel
- [ ] Weekly progress summary emails
- [ ] Parent role scope isolation (view-only, no edit)

---

## v2.5 — School Accounts / Multi-Tenancy & Analytics Dashboard 🔲

### School Accounts / Multi-Tenancy
- [ ] School registration and onboarding wizard
- [ ] Organization settings (branding, logo, academic calendar)
- [ ] Campus/stage/class hierarchy management
- [ ] Role-based access per campus/stage
- [ ] Cross-campus analytics for district-level admins
- [ ] Data isolation between organizations (Firestore security)
- [ ] Organization-specific feature flag overrides
- [ ] Bulk import/export for school data

### Analytics Dashboard
- [ ] Teacher dashboard: class performance, assignment completion rates
- [ ] Student dashboard: personal progress, strengths/weaknesses
- [ ] Admin dashboard: organization-wide KPIs
- [ ] Attendance trends and patterns
- [ ] Grade distribution analysis
- [ ] Live class participation metrics
- [ ] Custom date range filters
- [ ] Exportable charts and reports

---

## v2.6 — Subscription & Billing 🔲

### Subscription Plans
- [ ] Free tier definition (limits: students, storage, features)
- [ ] Pro plan with expanded limits
- [ ] Enterprise plan with custom pricing
- [ ] Plan comparison page

### Billing Infrastructure
- [ ] Stripe integration for payment processing
- [ ] Subscription management (upgrade/downgrade/cancel)
- [ ] Invoice generation and history
- [ ] Trial period with automatic conversion
- [ ] Proration on plan changes

### Billing-aware Features
- [ ] Feature gating based on subscription tier
- [ ] Usage metering (student count, storage, API calls)
- [ ] Soft limits with upgrade prompts
- [ ] Admin billing dashboard
- [ ] Payment method management
- [ ] Revenue analytics for platform admin

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                     Presentation Layer                    │
│  Screens (71)  ·  Widgets (18)  ·  Shells (3)           │
├──────────────────────────────────────────────────────────┤
│                     State Management                      │
│  Providers (38)  ·  Riverpod  ·  StreamProviders        │
├──────────────────────────────────────────────────────────┤
│                     Business Logic                        │
│  Services (48)  ·  Event Bus  ·  Feature Flags           │
│  Permission Service  ·  Audit  ·  Grading Engine         │
├──────────────────────────────────────────────────────────┤
│                     Data Layer                            │
│  Firebase Auth  ·  Firestore  ·  FCM  ·  Hive  ·  PDF   │
└──────────────────────────────────────────────────────────┘
```

## Key Implementation Principles


1. **Use Design Tokens** — All colors, spacing, typography from `lib/core/tokens/`
2. **Use Enterprise Components** — KlasivoButton, KlasivoCard, KlasivoBadge, etc.
3. **Use Feature Flags** — Gate new features behind flags
4. **Use Permission Gates** — `KlasivoPermissionGate`, `KlasivoRoleGate`
5. **Use Event Bus** — Decouple feature modules via typed events
6. **Follow Clean Architecture** — Services → Providers → Screens
7. **Soft Delete** — All entities use `isArchived` + `archivedAt` pattern
8. **Riverpod Functional Style** — Functional providers, not Notifiers (except where needed)
9. **Firestore Security** — Role-based rules with field-level security
